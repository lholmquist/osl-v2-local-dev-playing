#!/usr/bin/env python3
"""Import plain Quarkus Flow YAML/JSON files as LogicFlowDefinition resources."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


def command(argv: list[str], *, input_text: str | None = None) -> str:
    result = subprocess.run(
        argv,
        input=input_text,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode:
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="")
        raise SystemExit(result.returncode)
    return result.stdout


def slug(value: str) -> str:
    value = re.sub(r"[^a-z0-9-]+", "-", value.lower())
    return re.sub(r"-+", "-", value).strip("-")


def resource_name(identity: str, relative_path: str) -> str:
    suffix = hashlib.sha256(relative_path.encode("utf-8")).hexdigest()[:8]
    prefix = slug(identity)[:48].strip("-") or "workflow"
    return f"flow-{prefix}-{suffix}"[:63].rstrip("-")


def load_workflow(path: Path, yq: list[str]) -> dict[str, Any]:
    raw = command([*yq, "-o=json", ".", str(path)])
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as error:
        raise SystemExit(f"{path}: expected one YAML/JSON workflow document: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"{path}: workflow root must be an object")
    document = value.get("document")
    if not isinstance(document, dict):
        raise SystemExit(f"{path}: missing document metadata")
    for field in ("namespace", "name", "version"):
        if not isinstance(document.get(field), str) or not document[field].strip():
            raise SystemExit(f"{path}: document.{field} is required")
    return value


def kubectl() -> list[str]:
    return shlex.split(os.environ.get("KUBECTL", "kubectl"))


def wait_for_deployment(kube: list[str], namespace: str, runtime: str) -> None:
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        result = subprocess.run(
            [*kube, "get", "deployment", runtime, "--namespace", namespace],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode == 0:
            return
        time.sleep(2)
    raise SystemExit(
        f"Timed out waiting for Deployment/{runtime} in namespace {namespace}; "
        "check that the Logic Operator is ready and the LogicFlowRuntime was accepted."
    )


def main() -> None:
    workflow_dir = Path(os.environ.get("WORKFLOWS_DIR", "workflows")).expanduser().resolve()
    namespace = os.environ.get("WORKFLOW_NAMESPACE", "default")
    runtime = os.environ.get("WORKFLOW_RUNTIME", "osl-local-runner")
    bundle = slug(os.environ.get("WORKFLOW_BUNDLE", "osl-local"))[:63]
    yq = shlex.split(os.environ.get("YQ", "yq"))

    if not bundle:
        raise SystemExit("WORKFLOW_BUNDLE must contain a lowercase label value")
    if not workflow_dir.is_dir():
        raise SystemExit(f"Workflow directory does not exist: {workflow_dir}")

    files = sorted(
        path
        for path in workflow_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in {".yaml", ".yml", ".json"}
    )
    if not files:
        raise SystemExit(f"No .yaml, .yml, or .json workflows found under {workflow_dir}")

    definitions: list[dict[str, Any]] = []
    identities: set[tuple[str, str, str]] = set()
    for path in files:
        flow = load_workflow(path, yq)
        document = flow["document"]
        # Logic Operator uses the Kubernetes namespace as the workflow
        # namespace when it materializes the ConfigMap for the Runner.
        document["namespace"] = namespace
        identity = (namespace, document["name"], document["version"])
        if identity in identities:
            raise SystemExit(
                f"Duplicate workflow identity {identity[0]}:{identity[1]}:{identity[2]}"
            )
        identities.add(identity)

        relative_path = path.relative_to(workflow_dir).as_posix()
        definitions.append(
            {
                "apiVersion": "logic.kubesmarts.org/v1",
                "kind": "LogicFlowDefinition",
                "metadata": {
                    "name": resource_name(
                        f"{namespace}-{document['name']}-{document['version']}",
                        relative_path,
                    ),
                    "namespace": namespace,
                    "labels": {
                        "app.kubernetes.io/managed-by": "osl-local-dev",
                        "osl.kubesmarts.org/workflow-bundle": bundle,
                    },
                    "annotations": {"osl.kubesmarts.org/source-file": relative_path},
                },
                "spec": {"runtimeRef": {"name": runtime}, "flow": flow},
            }
        )

    runtime_resource = {
        "apiVersion": "logic.kubesmarts.org/v1",
        "kind": "LogicFlowRuntime",
        "metadata": {
            "name": runtime,
            "namespace": namespace,
            "labels": {"app.kubernetes.io/managed-by": "osl-local-dev"},
        },
        "spec": {
            "replicas": 1,
            "logging": {
                "enabled": True,
                "includeWorkflowPayloads": False,
                "includeTaskPayloads": False,
            },
        },
    }

    kube = kubectl()
    command([*kube, "apply", "-f", "-"], input_text=json.dumps(runtime_resource))
    manifest = "\n---\n".join(json.dumps(item) for item in definitions)
    command([*kube, "apply", "-f", "-"], input_text=manifest)

    selector = f"osl.kubesmarts.org/workflow-bundle={bundle}"
    current = json.loads(
        command(
            [
                *kube,
                "get",
                "logicflowdefinitions",
                "--namespace",
                namespace,
                "--selector",
                selector,
                "-o",
                "json",
            ]
        )
    )
    wanted_names = {item["metadata"]["name"] for item in definitions}
    stale = [
        item["metadata"]["name"]
        for item in current.get("items", [])
        if item["metadata"]["name"] not in wanted_names
    ]
    for name in stale:
        command(
            [
                *kube,
                "delete",
                "logicflowdefinition",
                name,
                "--namespace",
                namespace,
                "--ignore-not-found=true",
            ]
        )

    # The Runner image watches for new files; restart after a sync so edits and
    # removals are reflected as well.
    wait_for_deployment(kube, namespace, runtime)
    command(
        [
            *kube,
            "rollout",
            "restart",
            f"deployment/{runtime}",
            "--namespace",
            namespace,
        ]
    )
    command(
        [
            *kube,
            "rollout",
            "status",
            f"deployment/{runtime}",
            "--namespace",
            namespace,
            "--timeout=180s",
        ]
    )
    print(f"Imported {len(definitions)} workflow(s) into namespace {namespace}:")
    for item in definitions:
        print(f"  {item['metadata']['name']}")
    if stale:
        print(f"Removed {len(stale)} workflow resource(s) no longer present in {workflow_dir}.")


if __name__ == "__main__":
    main()

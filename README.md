# OSL v2 local Kind setup

This standalone folder creates a Podman-backed Kind cluster and installs the published Logic Operator stack with Helm. It does not build the operator or depend on a `logic-operator` checkout.

The setup uses the `localhost` Gateway host, enables Data Index and Vector, and imports raw Quarkus Flow YAML/JSON files from a directory as `LogicFlowDefinition` resources. The operator turns each definition into a ConfigMap mounted into the Runner at `/deployments/workflows`; the Gateway continues to use its normal API paths.

## Requirements

Install Podman, Kind, kubectl, Helm 3.8+, curl, Python 3, and Mike Farah `yq` v4. This setup targets macOS with Podman, matching the local environment used during the initial OSL v2 trial.

## Start the stack

From this directory:

```sh
make up
```

By default this creates a Kind cluster named `osl-v2-local`, installs ingress-nginx and cert-manager, downloads the `2.0.0-Alpha3` CRDs, and installs the published `logic-operator-stack` Helm chart. It then imports the files in `workflows/` and waits for the Runner rollout.

The Gateway is exposed at `http://localhost`. For example:

```sh
curl -X POST http://localhost/v1/runtime/default/hello-world/1.0.0/sync \
  -H 'Content-Type: application/json' \
  -d '{"name":"World"}'
```

To use a workflow folder outside this setup directory, pass its path when starting or syncing:

```sh
make up WORKFLOWS_DIR=/absolute/path/to/workflows
make workflows WORKFLOWS_DIR=/absolute/path/to/workflows
```

This allows the folder to live in the RHDH orchestrator plugin workspace later. The helper reads the files and creates Kubernetes resources; it does not copy or modify the source workflow files.

## Versions and namespaces

Override the release version if needed:

```sh
make up OSL_VERSION=2.0.0-Alpha3
```

The default Workflow namespace is `default`, so the URL path is `/v1/runtime/default/...`. The LogicPlatform and Data Index run in `logic-operator-system`. The setup configures Vector to watch the workflow namespace, which is important when these namespaces differ.

Change the workflow namespace or Runner resource name with:

```sh
make up WORKFLOW_NAMESPACE=default WORKFLOW_RUNTIME=osl-local-runner
```

Each workflow file must contain one OWS YAML or JSON object with `document.namespace`, `document.name`, and `document.version`. The importer aligns `document.namespace` with `WORKFLOW_NAMESPACE`, matching the current Logic Operator behavior. Duplicate workflow identities in the directory are rejected.

The importer creates one `LogicFlowRuntime` named `osl-local-runner` by default, and points every imported definition at it. You generally do not need one runtime per workflow. A runtime is a shared Runner deployment; create another when you need to exercise different settings such as the standard image with durable PostgreSQL state, API key security, or a different resource profile. A definition and its referenced runtime must be in the same Kubernetes namespace, and all versions of one logical workflow must use the same runtime.

After editing, adding, or removing files, run `make workflows`. It reapplies the resources, removes stale definitions from this bundle, and restarts the Runner so all changes are picked up.

## Helpful targets

```sh
make status       # Show the platform, workflows, and pods
make workflows    # Sync workflow files into the cluster
make down         # Uninstall the Helm stack, keeping the cluster
make kind-delete  # Delete the local Kind cluster
```

`make kind-delete` removes the entire `osl-v2-local` cluster. It does not affect other Kind clusters.

## How workflow import works

The workflow directory is the source of truth for this local bundle. The importer wraps each file in a `LogicFlowDefinition` that references the single local Runner. The published operator then creates per-workflow ConfigMaps and mounts them under the Runner's configured workflow directory. This keeps the Gateway catalog and runtime definitions aligned while preserving the production-style API paths.

Data Index requires structured workflow events to be collected. The local Runner is configured to emit those events, and the LogicPlatform's Vector collector is pointed at `WORKFLOW_NAMESPACE`. Payload capture remains disabled by default.

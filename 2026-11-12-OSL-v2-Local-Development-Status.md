# OSL v2 Local Development — Status

**Date:** November 12, 2026

## Summary

A standalone local setup has been prepared to run the published OSL v2 Helm stack on a Podman-backed Kind cluster. It uses localhost for the Workflow Gateway and includes a default Hello World workflow. The setup is outside the logic-operator source repository, so it can later move into the RHDH orchestrator plugin workspace.

## Work completed

- Confirmed the Quarkus Flow Runner can load YAML and JSON workflows from a directory.
- Created the standalone setup folder at /Users/lholmqui/develop/kubesmarts/osl-local-dev. It includes a Makefile, Kind configuration, Helm values, a workflow importer, and a Hello World workflow.
- Configured it to install the published 2.0.0-Alpha3 Logic Operator stack with Gateway ingress at localhost, plus PostgreSQL, Data Index, and Vector.
- Set up workflow import to generate the LogicFlowDefinition resources the Gateway and Runner need. Vector is configured to watch the workflow namespace so it can collect runtime events for Data Index.
- Removed the duplicate setup folder; kubesmarts/osl-local-dev is the remaining copy.

## Questions raised and why

- **Can the Gateway, Data Index, and Runner run directly with Podman, without Kind?**  
  The Runner can run directly from a mounted workflow directory. The current Gateway still depends on Kubernetes resources for workflow discovery and routing. Data Index also needs PostgreSQL and a collector to ingest workflow events; the provided Vector configuration collects Kubernetes logs. That makes a full Podman-only setup unsupported without additional local modes.

- **Can the Runner use a workflow directory while requests still go through the Gateway API and instance queries?**  
  Yes, in the Kind setup. The importer turns each workflow file into a LogicFlowDefinition. The operator creates ConfigMaps from those definitions and mounts them in the Runner. This keeps Gateway discovery and Runner workflows aligned while preserving the Gateway API paths.

- **Could the Make-based setup use the published Helm release instead of building the operator locally?**  
  Yes. The standalone Makefile installs the published Helm chart and CRDs, so it doesn’t require a logic-operator checkout. It’s a first step toward putting the setup in the RHDH orchestrator plugin workspace.

- **What does spec.runtimeRef.name mean, and why have more than one runtime?**  
  It points a workflow definition to a LogicFlowRuntime Runner deployment in the same Kubernetes namespace. One runtime can serve many workflows. Multiple runtimes are useful for testing different images, persistence, security settings, or resource profiles. The local setup starts with one runtime.

- **Were the earlier Podman changes to the repository Makefile copied into this one?**  
  The standalone Makefile selects the Podman Kind provider. It doesn’t include the original CONTAINER_TOOL image-loading helper because it installs published images through Helm rather than building and loading local images.

- **Is there a default workflow if no directory is supplied?**  
  Yes. It uses the included workflows/hello-world.yaml, imported as hello-world version 1.0.0 in the default namespace.

## How to use it

From the setup directory, run:

    make up

To use a workflow folder elsewhere, such as one in the orchestrator plugin workspace:

    make up WORKFLOWS_DIR=/absolute/path/to/workflows

Use make workflows WORKFLOWS_DIR=... to sync later changes. Other targets include status, invoke, down, and kind-delete.

## Current status and next step

The setup files are ready, but make up has not been run yet. The current Kind cluster is awaiting cleanup; the plan is to stop and delete it, then try the standalone setup. Its end-to-end behavior remains to be confirmed.

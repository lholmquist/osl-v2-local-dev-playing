# OSL v2 Local Development — Status

**Date:** November 12, 2026

## Summary

A standalone local setup has been prepared to run the published OSL v2 Helm stack on a Podman-backed Kind cluster. It uses localhost for the Workflow Gateway and includes a default Hello World workflow. The setup is outside the logic-operator source repository, so it can later move into the RHDH orchestrator plugin workspace.

## Work completed

- Confirmed the Quarkus Flow Runner can load YAML and JSON workflows from a directory.
- Created the standalone setup folder at /Users/lholmqui/develop/kubesmarts/osl-local-dev. It includes a Makefile, Kind configuration, Helm values, a workflow importer, and a Hello World workflow. The setup was later moved to /Users/lholmqui/develop/lholmquist/osl-v2-local-dev-playing.
- Configured it to install the published 2.0.0-Alpha3 Logic Operator stack with Gateway ingress at localhost, plus PostgreSQL, Data Index, and Vector.
- Set up workflow import to generate the LogicFlowDefinition resources the Gateway and Runner need. Vector is configured to watch the workflow namespace so it can collect runtime events for Data Index.
- Removed the duplicate setup folder; kubesmarts/osl-local-dev was the remaining copy at that point. The repository was later moved to /Users/lholmqui/develop/lholmquist/osl-v2-local-dev-playing.

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

## Status at the time of the initial draft

The setup files are ready, but make up has not been run yet. The current Kind cluster is awaiting cleanup; the plan is to stop and delete it, then try the standalone setup. Its end-to-end behavior remains to be confirmed.


## Updates since the initial status

### Repository and setup

The repository is now at `/Users/lholmqui/develop/lholmquist/osl-v2-local-dev-playing`. A clean `make up` run created the `osl-v2-local` Kind cluster, installed the published OSL v2.0.0-Alpha3 Helm stack, and imported the Hello World workflow. The LogicPlatform became Ready and the workflow Runner was deployed.

The Kind configuration maps host ports 80 and 443 and labels the control-plane node `ingress-ready: "true"` for the ingress-nginx Kind manifest. The Makefile installs ingress-nginx and cert-manager, then the published Logic Operator CRDs and Helm chart. The Helm values expose the Gateway at `http://localhost` and enable PostgreSQL, Data Index, and Vector. Vector watches the workflow namespace to collect Runner events for Data Index.

The workflow importer reads `.yaml`, `.yml`, and `.json` files. For each workflow, it creates a LogicFlowRuntime and a LogicFlowDefinition, then restarts the Runner deployment so it loads the imported workflow. The default file is `workflows/hello-world.yaml`, deployed as `hello-world` version `1.0.0` in the `default` namespace.

### Startup issues and fixes

The first `make up` attempt failed at the ingress readiness check with `no matching resources found`. The Makefile was waiting for a matching Pod before Kubernetes had created one. It now waits for the ingress controller Deployment to become available.

A later run waited for the LogicPlatform to become Ready because ingress-nginx could not schedule: the Kind node was missing the `ingress-ready=true` label required by the provider-kind manifest. The label was added to `kind-config.yaml`, and a clean run then completed successfully.

### Intermittent Gateway request investigation

Some POST requests to execute the workflow and GET requests to `/v1/instances` hung, while other attempts returned quickly. Requests that completed through ingress returned HTTP 200. The timed-out requests also reproduced through ingress from inside the ingress controller Pod; five direct requests to the Gateway Service returned HTTP 200. Data Index logs showed the successful GraphQL instance query returning results, pointing to ingress-nginx as the source of the intermittent hangs.

NGINX was configured for six workers based on the available CPU count, but only two remained active. The ingress controller logged `pthread_create() failed` and worker processes exiting. Setting the ingress ConfigMap's `worker-processes` value to `1` resolved the reproduced problem in the running cluster:

- Ten consecutive GET requests to `http://localhost/v1/instances` returned HTTP 200 in 9–35 ms.
- A POST to the Hello World workflow returned HTTP 200 in about 19 ms.
- The Makefile now applies `worker-processes: "1"` for future setups. The final Makefile change has not yet been checked by recreating the cluster from scratch.

The [ingress-nginx ConfigMap documentation](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/) describes the `worker-processes` setting and its CPU-based default.

### Additional questions and answers

- **Do I need a port-forward to call the Gateway or query workflow instances?** No. The Gateway ingress at `http://localhost` serves the Gateway API, including `/v1/instances`. A port-forward is needed to access the Data Index GraphQL Service directly because that Service is internal to the cluster.
- **How can I import YAML workflows without `make kind-demo`?** Set `WORKFLOWS_DIR` to the workflow directory. Run `make up WORKFLOWS_DIR=/absolute/path/to/workflows` during setup, or `make workflows WORKFLOWS_DIR=/absolute/path/to/workflows` to import or sync workflows later.
- **Why did some workflow POSTs and instance GETs hang?** The local ingress-nginx controller could not reliably start the six workers it had configured. Reducing the worker count to one stopped the hangs observed in the repeated checks.

### Current status and next step

The `osl-v2-local` cluster is running the OSL stack and Hello World workflow. The live ingress ConfigMap has one worker, and the Gateway GET and POST checks passed after that change. The Makefile now applies the same setting on future setups; verify it during the next clean-cluster run.

To use the current Makefile from the repository directory, run `make up`. Use `make workflows WORKFLOWS_DIR=/absolute/path/to/workflows` to load another directory later, and `make invoke WORKFLOW=hello-world VERSION=1.0.0 INPUT='{"name":"World"}'` to invoke the example through the Gateway. Run `make status` to inspect resources, `make down` to uninstall the Helm release while keeping Kind, and `make kind-delete` to remove the cluster.

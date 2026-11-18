# OSL v2 Local Development — Status

**Date:** November 16, 2026

## Summary

The standalone Podman-backed Kind setup was first adapted for Alpha 4, but the CRD download returned 404. The default was restored to the published Alpha 3 release and its matching `LogicPlatform` chart schema. A subsequent `make up` completed: the chart deployed, `LogicPlatform` became Ready, and the Hello World workflow was imported.

## Work completed today

- Temporarily changed the standalone Makefile default from `2.0.0-Alpha3` to `2.0.0-Alpha4`, then restored Alpha 3 as the default after the Alpha 4 CRD URL returned 404.
- Restored the Alpha 3 `logicPlatform` Helm values, with Gateway ingress at `localhost`, ingress class `nginx`, and Data Index and Vector enabled.
- Restored Alpha 3 Make target commands for the namespaced `LogicPlatform` and its Vector `watchNamespaces` setting.
- Updated the README to describe the published Alpha 3 default and namespace layout.
- Added a follow-up note about reviewing workflow runtimes to the earlier [November 12 status doc](2026-11-12-OSL-v2-Local-Development-Status.md).

## Alpha 3 to Alpha 4 findings

The upstream `main` branch is versioned Alpha 4. Its changes since the Alpha 3 tag include:

- Replacing `LogicPlatform` with the cluster-scoped `ClusterLogicPlatform`, which has a `targetNamespace` for the components it manages.
- Updating the Helm values: platform settings now live under `clusterLogicPlatform`; Vector is configured at the platform level; Gateway ingress uses `ingressClassName`.
- Changing runtime persistence configuration. The platform now supplies datastore settings, while a runtime can reference a platform and select `PlatformDB` or `Ephemeral` persistence.
- Refactoring platform controllers and fixing duplicate `LogicFlowService` definition references.
- Updating deployment and API documentation.

**Release availability caveat:** As of today's check, the official GitHub release and tag lists still showed Alpha 3 as the newest published release, even though the source branch had been versioned Alpha 4. The Alpha 4 CRD bundle and chart may therefore be unavailable until the release artifacts are published. See the [release list](https://github.com/kubesmarts/logic-operator/releases) and [Alpha 3 to current main comparison](https://github.com/kubesmarts/logic-operator/compare/v2.0.0-Alpha3...main).

## Checks performed

- `git diff --check` passed.
- `make -n helm-up` shows the Alpha 3 CRD URL and chart version, plus the namespaced `LogicPlatform` patch and wait commands.
- `make -n status` shows the Alpha 3 platform and workflow namespaces.
- No tests were run. The Alpha 3 `make up` completed successfully, and three Hello World POST requests returned `COMPLETED`.

## First Alpha 4 setup attempt

`make up` created the Kind cluster, installed ingress-nginx, applied the one-worker setting, and installed cert-manager. It then failed in `helm-up` while downloading `https://github.com/kubesmarts/logic-operator/releases/download/v2.0.0-Alpha4/crds.yaml`: GitHub returned HTTP 404, followed by `kubectl apply` reporting that no objects were passed. The run stopped before Helm chart installation and workflow import. The Kind cluster remains available for a retry after the Alpha 4 release artifacts are published.

## Alpha 3 run and instance query

The first `GET /v1/instances` returned an empty list. After three successful workflow executions, the instances became visible in a later query after about a minute. This suggests a delay between workflow completion and instance visibility in the local stack.

## Next steps

1. Continue with workflow development on the verified Alpha 3 stack. Revisit Alpha 4 after its CRD bundle and chart are published.
2. Review workflow runtimes: how imported `LogicFlowDefinition` resources select a `LogicFlowRuntime`, when a shared runtime is sufficient versus multiple runtimes, and how `platformRef` and `persistenceMode` affect persistence.
3. Create a basic OSL v2-compliant workflow, then assess converting selected OSL v1 workflows to v2 equivalents.

## Later follow-up: OpenShift with RHDH

After RHDH is installed on an OpenShift cluster, try this OSL setup there and determine how to place the OSL components in the same namespace as RHDH.

## Workflow conversion candidates

- Start with [`random-success-or-error.sw.yaml`](/Users/lholmqui/develop/rhdhorchestrator/backstage-orchestrator-workflows/workflows/random-success-or-error.sw.yaml) and [`yamlgreet.sw.yaml`](/Users/lholmqui/develop/rhdhorchestrator/backstage-orchestrator-workflows/workflows/yamlgreet.sw.yaml) from the orchestrator workflow repository.
- Also identify workflows covered by end-to-end tests in the `rhdh-plugins` repository and the overlays repository. The workflow triage chat may already have identified those candidates; check it when selecting them.


## Initial `yamlgreet` v2 conversion

A first Open Workflow Specification (OWS) DSL 1.0.0 version is in `workflows/yamlgreet.yaml`, alongside Hello World. The [OWS DSL reference](https://github.com/open-workflow-specification/specification/blob/main/dsl-reference.md) defines the workflow format; [Quarkus Flow](https://github.com/quarkiverse/quarkus-flow) is the runtime used by the local setup and lists OWS DSL 1.0.0 compatibility.

### What changed to fit OWS DSL 1.0.0

- **Workflow identity:** Serverless Workflow 0.8's `id`, `version`, and `specVersion` fields become OWS `document.name`, `document.version`, and `document.dsl`. The converted workflow uses `yamlgreet` and version `1.0.0`; `document.namespace` is set to `examples` in the file and the importer rewrites it to the Kubernetes workflow namespace (`default` here).
- **Input schema:** The old `dataInputSchema` file reference becomes an inline OWS `input.schema` document. It preserves the optional `language` field, its English/Spanish enum and English default, and the required `name` field with its original pattern and default metadata.
- **State machine to tasks:** The v0.8 `start` and `states` structure becomes the OWS ordered `do` task list. The `switch` task selects a named greeting task with `then`; the default case preserves the original English fallback.
- **Inject to set:** The old `inject` states become OWS `set` tasks. They explicitly carry `name` forward with the greeting prefix before a shared task builds the final message.
- **Custom `sysout` action:** The v0.8 `functions`/`operation`/`functionRef` path is removed. That `sysout` operation was runtime-specific; the v2 workflow returns `{ message: ... }` as its output so the Gateway caller can see the greeting.

The local importer scans `workflows/` recursively, so the next `make workflows` or `make up` will include this definition and restart the Runner. The Gateway's `GET /v1/definitions/` has since listed `yamlgreet` in namespace `default`; I have not invoked it.


## Invoke `yamlgreet` through the Gateway

Use the synchronous Gateway endpoint with the workflow namespace, name, and version:

```sh
curl -X POST http://localhost/v1/runtime/default/yamlgreet/1.0.0/sync \
  -H 'Content-Type: application/json' \
  -d '{"name":"World","language":"English"}'
```

Use `"Spanish"` for the `language` value to exercise the Spanish branch. The `language` field is optional; the workflow's default branch greets in English.


## Initial `random-success-or-error` v2 conversion

The OWS DSL 1.0.0 draft is in `workflows/random-success-or-error.yaml`, next to Hello World and `yamlgreet`. The source is Serverless Workflow 0.8.0. Despite its name, it is clock-based rather than random: it checks the current second within the minute, raises an expression error when that second is below 30, and returns the number `8` otherwise.

### What changed to fit OWS DSL 1.0.0

- **Workflow identity:** `specVersion`, `id`, and `version` are represented as `document.dsl`, `document.name`, and `document.version`. The workflow version is normalized from `1.0` to `1.0.0`; the importer sets the Kubernetes namespace to `default`.
- **Expression function to `set`:** The v0.8 expression function and operation are replaced by one OWS `set` task with an inline jq runtime expression. It uses jq's `now`, floors the epoch timestamp before taking modulo 60, then retains the original threshold and result: divide by zero before second 30, return 8 otherwise.
- **No input schema:** The original workflow accepts no input, so the OWS definition has no `input` section.

The local importer recursively scans `workflows/`. The next `make workflows` or `make up` will import this file and restart the Runner; this draft has not yet been synced or invoked. To invoke it synchronously after syncing:

```sh
curl -X POST http://localhost/v1/runtime/default/random-success-or-error/1.0.0/sync \
  -H 'Content-Type: application/json' \
  -d '{}'
```

The outcome depends on the time of execution: seconds `00`–`29` should fault, and seconds `30`–`59` should return `8`.

## OWS DSL 1.0.0 compatibility review: workflows identified as used

I used the scope in the [workflow triage inventory](/Users/lholmqui/develop/lholmquist/orchestrator-workflow-triage/workflow-inventory.md), under “References from redhat-developer repositories.” This covers only the eight workflows identified there across the serverless-workflows and orchestrator-demo repositories. This is a source and spec comparison; I did not run, convert, or deploy these workflows.

“Direct support” below means OWS 1.0.0 has a standard construct for the workflow behavior. It does not mean the existing Serverless Workflow YAML can be loaded unchanged. All eight source files use the legacy start/states structure, so each needs a rewrite into OWS's document and do structure.

| Repository | Workflow | OWS 1.0.0 support and adaptation needed |
| --- | --- | --- |
| serverless-workflows | [greeting](/Users/lholmqui/develop/rhdhorchestrator/serverless-workflows/workflows/greeting/greeting.sw.yaml) | The branch and value-building logic map to switch and set; input/output schemas can use OWS schema fields. Replace the custom sysout operation. The old output-schema extension can be represented with OWS output.schema. |
| serverless-workflows | [failSwitch](/Users/lholmqui/develop/rhdhorchestrator/serverless-workflows/workflows/fail-switch/src/main/resources/fail-switch.sw.yaml) | Branching, a timed wait, and HTTP/OpenAPI calls have standard equivalents. The sysout operation and nextWorkflows result convention are runtime/plugin-specific and need replacement or a consumer-side adapter. |
| serverless-workflows | [test-object-type-uiprops](/Users/lholmqui/develop/rhdhorchestrator/serverless-workflows/workflows/test-object-type-uiprops/test-object-type-uiprops.sw.yaml) | The workflow's input/output data and schemas can be represented. The ui:props behavior being tested controls RHDH form rendering and is outside the workflow DSL; replace the custom sysout operation. |
| serverless-workflows | [universal-pr](/Users/lholmqui/develop/rhdhorchestrator/serverless-workflows/workflows/bulk-import-git-repos/src/main/resources/create-pr-universal.sw.yaml) | Branching, looping (foreach to OWS for), OpenAPI calls, and data transformations have OWS equivalents. Rewrite the legacy action/state filters as OWS task input/output expressions. The mock/custom functions, logging, Git provider credentials/configuration, and Backstage result.outputs contract need runtime or consumer integration. |
| serverless-workflows | [sample-retry-test](/Users/lholmqui/develop/rhdhorchestrator/serverless-workflows/workflows/sample-retry-test/sample-retry-test.sw.yaml) | The workflow itself is a constant result and maps directly to set. The E2E's fetch retry settings are RHDH form/client behavior carried in ui:props, not workflow retry behavior, so the E2E feature does not transfer as an OWS task. |
| serverless-workflows | [patch-k8s-resource](/Users/lholmqui/develop/rhdhorchestrator/serverless-workflows/workflows/patch-k8s-resource/patch-k8s-resource.sw.yaml) | Branching, value construction, schema, and an OpenAPI PATCH call have standard equivalents. SonataFlow's metadata.configKey, target-cluster resolution, endpoint, and credentials require environment/runtime configuration. |
| orchestrator-demo | [token-propagation](/Users/lholmqui/develop/rhdhorchestrator/orchestrator-demo/09_token_propagation/src/main/resources/token-propagation.sw.yaml) | The API calls and data shaping can be modeled with OWS calls and expressions; OWS also defines authentication policies for outbound calls. Extracting a user from the incoming token and propagating Orchestrator execution identity/headers rely on the current jwt-parser and runtime integration, so they need a new implementation and verification. |
| orchestrator-demo | [lock-flow](/Users/lholmqui/develop/rhdhorchestrator/orchestrator-demo/08_kafka_events/callback-flow/src/main/resources/lock.sw.yaml) | OWS has event emission/listening, event filters/correlation, and timed waits. Kafka topic/channel bindings, broker settings, and event-trigger/callback deployment wiring are runtime configuration; the custom sysLog operation also needs replacement. |

### Main findings

- OWS 1.0.0 covers much of the workflow logic found here: set, switch, for, OpenAPI call, event emit/listen, waits, schemas, and task data shaping.
- The main conversion work is moving from the legacy state/function format and replacing runtime-specific actions, plugin UI metadata, provider credentials, event transport configuration, and consumer-specific result formats.
- “Supported by the spec” does not guarantee that the current Logic Operator Runner implements every construct or extension. Verify behavior against the Runner version in use after converting a workflow.

### DSL version detail: direct-expression set

The tagged [OWS 1.0.0 schema](https://raw.githubusercontent.com/open-workflow-specification/specification/v1.0.0/schema/workflow.yaml) defines set as an object mapping. Support for a direct scalar runtime expression under set was added in [OWS 1.0.1](https://github.com/open-workflow-specification/specification/releases/tag/v1.0.1). Quarkus Flow's published compatibility table currently lists OWS DSL 1.0.0 ([project compatibility](https://github.com/quarkiverse/quarkus-flow#compatibility)).

This catches a mismatch in the earlier workflows/random-success-or-error.yaml draft in this repo: it declares DSL 1.0.0 but uses the scalar set form added in 1.0.1. To stay on DSL 1.0.0, represent the expression as a field in the set object and select that field with workflow output.as. The draft has not been changed as part of this comparison.


# OSL v2 Local Development — Status

**Date:** November 18, 2026

## Focus

Determine how OSL v2 loads workflow input schemas, how the local Podman/Kind setup carries them to the Runner, and how to retrieve a schema through the Workflow Gateway.

## Findings

### Schema location in an OWS workflow

An input schema is part of the workflow document, under `input.schema`. For JSON Schema, the OWS 1.0.0 model has `format: json` and allows either an inline `document` or a `resource` that identifies an external schema. The OWS reference describes both forms. The Quarkus Flow Runner guide demonstrates the inline form and labels `input.schema` optional but recommended.

The local workflow files currently use inline schemas:

- `workflows/hello-world.yaml` defines a required string `name`.
- `workflows/yamlgreet.yaml` defines `language` and `name`, including enum, defaults, descriptions, pattern, and required metadata.
- `workflows/random-success-or-error.yaml` has no input schema.

### How the local OSL v2 setup loads it

The `osl-v2-local-dev-playing` importer reads each YAML/JSON file as one complete workflow object and places that object in `LogicFlowDefinition.spec.flow`. It does not import a second schema file or perform a separate schema-registration step. It aligns `document.namespace` with the configured Kubernetes workflow namespace.

Logic Operator parses the full `spec.flow`, writes the workflow YAML into a per-definition ConfigMap, and mounts it under the Runner's `/deployments/workflows/` directory. The Runner loads workflow definitions from that directory. Thus, for the current inline-schema workflows, the schema travels with the workflow file through the same ConfigMap and Runner loading path.

The local sync target restarts the Runner after applying workflow resources, so today's local workflow edits do not depend on the Runner file watcher replacing an already loaded workflow identity.

### Getting the schema through the Gateway

The Gateway provides `GET /v1/definitions/{namespace}/{name}/{version}`. Its implementation returns the OWS workflow document itself (not the Kubernetes `LogicFlowDefinition` wrapper), so the schema is at `.input.schema` in the response. For the local `yamlgreet` workflow, the current setup uses namespace `default` and version `1.0.0`:

```sh
curl -fsS http://localhost/v1/definitions/default/yamlgreet/1.0.0 | jq '.input.schema'
```

This uses the same Gateway host and API surface as the workflow execution calls. The equivalent Runner-native definition endpoint is under `/q/flow/definitions/...`, but Gateway is the relevant route for this local integration path.

## Important open question

OWS 1.0.0 describes an external schema `resource`, but the local importer only passes through the workflow document; it does not fetch or package an external schema file. On November 18, 2026, the separate-file path was verified against the running Alpha 3 stack: the Runner resolved a `file:` URI to a schema mounted from a ConfigMap and enforced its pattern constraint. The Runner image was `quay.io/quarkiverse/quarkus-flow-runner:1.3.0-minimal`. The local Quarkus Flow Runner documentation still demonstrates inline `document` schemas and does not explain this `file:` workflow, so the working behavior should be recorded as tested implementation behavior rather than a documented packaging contract.

The published Quarkus Flow documentation is the current `dev` documentation and shows Runner 1.3.0 examples. The local Kind setup is pinned to Logic Operator `2.0.0-Alpha3`, so record the actual Runner image/version before treating current dev behavior as proof of Alpha 3 behavior.

## Documentation locations

- [Quarkus Flow Runner: load workflows, define input schemas, and query definitions](https://docs.quarkiverse.io/quarkus-flow/dev/runner.html)
- [Quarkus Flow: YAML/JSON workflow definitions](https://docs.quarkiverse.io/quarkus-flow/dev/workflow-definitions.html)
- [Open Workflow Specification 1.0.0 DSL reference: Schema](https://github.com/open-workflow-specification/specification/blob/v1.0.0/dsl-reference.md#schema)
- [OSL v2 Alpha 3 Kind local guide](https://kubesmarts.org/logic-operator/logic-operator/2.0.0-Alpha3/deployment/kind-local.html)
- [OSL v2 Alpha 3 Helm guide](https://kubesmarts.org/logic-operator/logic-operator/2.0.0-Alpha3/deployment/helm.html)
- Logic Operator source documentation: [Workflow Definitions](/Users/lholmqui/develop/kubesmarts/logic-operator/docs/antora/modules/ROOT/pages/concepts/workflow-definitions.adoc), [LogicFlowDefinition CRD](/Users/lholmqui/develop/kubesmarts/logic-operator/docs/antora/modules/ROOT/pages/crd-reference/logicflowdefinition.adoc), and [Workflow Gateway](/Users/lholmqui/develop/kubesmarts/logic-operator/docs/antora/modules/ROOT/pages/components/workflow-gateway.adoc).
- Local setup and importer: [README](/Users/lholmqui/develop/lholmquist/osl-v2-local-dev-playing/README.md), [import_workflows.py](/Users/lholmqui/develop/lholmquist/osl-v2-local-dev-playing/scripts/import_workflows.py), and [yamlgreet.yaml](/Users/lholmqui/develop/lholmquist/osl-v2-local-dev-playing/workflows/yamlgreet.yaml).

## Work completed today

- Traced the schema path from the local workflow YAML through the importer and `LogicFlowDefinition` into the Runner's mounted workflow directory.
- Confirmed the Gateway has a definition-fetch route that can return the input schema along with the rest of the OWS document.
- Verified that the Alpha 3 stack resolves and enforces an external schema referenced with `file:` when the JSON Schema is mounted into the Runner through a ConfigMap volume.
- At the time of this initial schema investigation, no workflow files, cluster resources, or plugin code had been changed, and no live Gateway request had been made.

## Next steps

1. Compare the Gateway-returned schema with the OSL v1 schema and record which JSON Schema fields and any RJSF widget metadata survive the OSL v2 path.
2. Compare the tested ConfigMap and Runtime mount packaging with the v1 manifests and decide what should be documented for OpenShift deployment.
3. Ask OSL developers to confirm the supported contract for `file:` schema resources and Runtime pod-template volume mounts.
4. Continue the OSL v2 workflow probe and compare schema discovery, execution input, result, and Data Index instance visibility against the saved OSL v1 baseline.

## Follow-up: separate schema ConfigMap test

The OSL v1 example in [02-configmap_01-basic-resources-schemas.yaml](/Users/lholmqui/develop/rhdhorchestrator/orchestrator-demo/01_basic/manifests/02-configmap_01-basic-resources-schemas.yaml) and [03-sonataflow_basic.yaml](/Users/lholmqui/develop/rhdhorchestrator/orchestrator-demo/01_basic/manifests/03-sonataflow_basic.yaml) uses a dedicated schema ConfigMap and mounts it through `SonataFlow.spec.resources.configMaps` with `workflowPath: schemas`; the workflow points to `schemas/basic__main-schema.json`. The OSL v1 `yamlgreet` workflow similarly uses `dataInputSchema: schemas/yamlgreet__main-schema.json`.

OSL v2 Alpha 3 does not have that same `resources.configMaps` field on `LogicFlowDefinition`. The definition stores the full OWS flow, and the operator materializes it into its workflow ConfigMap. However, `LogicFlowRuntime.spec.podTemplate` supports custom pod volumes and main-container volume mounts. That gives us a no-server route to mount a second ConfigMap directly into the Runner. The test copy uses `input.schema.resource.endpoint: file:///deployments/schemas/yamlgreet-separate-schema.json`.

The `file:` scheme worked in the probe: with the schema ConfigMap mounted at `/deployments/schemas`, the Alpha 3 Runner resolved `file:///deployments/schemas/yamlgreet-separate-schema.json` and returned a schema-validation error for a name that violated the file's regex. The documentation gap remains: Quarkus Flow docs do not describe this external-schema loading path.

The original `workflows/yamlgreet.yaml` remains unchanged. The no-server test files are:

- `schema-test-workflows/yamlgreet-separate-schema.yaml` — copied workflow with a new identity and `file:` schema resource reference. It is isolated from the default workflow directory so a normal `make up` does not load the experimental reference.
- `schemas/yamlgreet-separate-schema.json` — extracted JSON Schema.
- `manifests/yamlgreet-runtime-schema-volume-patch.json` — merge patch that mounts the schema ConfigMap into the Runner.
- `schemas/README.md` — ConfigMap creation, runtime patch, and rollout commands.

The schema ConfigMap, isolated LogicFlowDefinition, and Runtime volume mount were applied to the running Kind cluster; `file:` resolution was confirmed through Gateway execution and schema validation.

### Follow-up question for the OSL developers

The Alpha 3 Runner image used here successfully resolves `file:` when the schema is mounted from a ConfigMap. Is this a supported and intended scheme for `input.schema.resource.endpoint`, and is `LogicFlowRuntime.spec.podTemplate` volume mounting the recommended equivalent to SonataFlow's `spec.resources.configMaps` mechanism? Is a first-class Logic Operator resource/field for workflow sidecar resources planned, and how should the Gateway expose an external input schema to clients that build forms?

### Next test steps

1. Completed: create `yamlgreet-separate-schema` ConfigMap and import only `schema-test-workflows/` under the `yamlgreet-schema-test` bundle.
2. Completed: patch `LogicFlowRuntime/osl-local-runner` to mount the ConfigMap at `/deployments/schemas`; the Runner rollout succeeded.
3. Completed: inspect the Gateway definition and execute valid and invalid payloads; evidence is recorded below.
4. Compare the working v2 packaging with the v1 manifests and document any changes needed for OpenShift deployment.
5. Ask OSL developers to confirm whether the tested `file:` URI and Runtime volume mount are the supported long-term interface.


### Separate schema probe results

- Runner image: `quay.io/quarkiverse/quarkus-flow-runner:1.3.0-minimal`.
- Kubernetes ConfigMap: `default/yamlgreet-separate-schema`, mounted read-only at `/deployments/schemas` through `LogicFlowRuntime/osl-local-runner.spec.podTemplate`. `kubectl exec ... -- cat /deployments/schemas/yamlgreet-separate-schema.json` showed the expected schema.
- Test workflow: `default:yamlgreet-separate-schema:1.0.0`, imported from `schema-test-workflows/yamlgreet-separate-schema.yaml` using bundle `yamlgreet-schema-test`. The existing `workflows/yamlgreet.yaml` was left unchanged.
- `GET /v1/definitions/default/yamlgreet-separate-schema/1.0.0` returned the workflow with `input.schema.resource.endpoint` set to `file:///deployments/schemas/yamlgreet-separate-schema.json`.
- Valid POST input `{"name":"Alice","language":"English"}` returned HTTP 200 and `{"message":"Hello from YAML Workflow, Alice"}`.
- Invalid POST input `{"name":"Bad Name","language":"English"}` returned HTTP 400 with a schema-validation error identifying the `name` regex. This proves the Runner loaded and applied the mounted external schema.
- A temporary Gateway port-forward on local port 18080 was used for these requests and then stopped. No schema HTTP server was started.


## Orchestrator plugin: input-schema loading

Reviewed the local checkout at `/Users/lholmqui/develop/redhat-developer/rhdh-plugins`. The plugin's workflow execution page calls its backend API `GET /v2/workflows/{workflowId}/inputSchema`; the `/v2` here is the Orchestrator plugin API version. The frontend stores the returned `inputSchema` and passes it to the Orchestrator form.

The backend resolves the workflow source from Data Index and parses it through `@serverlessworkflow/sdk-typescript` 0.8.4, whose generated workflow model is schema version 0.8 and contains `dataInputSchema`. The input-schema route returns an empty object when `definition.dataInputSchema` is absent. When present, it calls the workflow service at `${serviceUrl}/management/processes/${workflowId}` and returns that response's `inputSchema`. The plugin does not open the schema file or dereference the schema path itself. The execute-workflow action follows the same legacy-field check and uses the runtime-returned schema for AJV validation before submitting inputs. `DataInputSchemaService` only extracts `workflowdata` from instance variables; it does not load schemas.

This is the v1 loading contract: the SonataFlow runtime resolves its configured schema and returns the usable JSON Schema to the plugin. The current code does not explicitly handle OWS 1.0 `input.schema` or its `resource.endpoint` form. The SDK parser's ability to parse an OWS 1.0 document also needs explicit verification before claiming compatibility. In the local Alpha 3 probe, the Workflow Gateway definition response retained the `file:` URI rather than returning the referenced schema contents, so the current plugin path would need an OWS 1.0-aware definition/schema mapping and a backend-reachable way to obtain external schema contents.

Relevant code: [ExecuteWorkflowPage.tsx](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator/src/components/ExecuteWorkflowPage/ExecuteWorkflowPage.tsx), [router.ts](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator-backend/src/service/router.ts), [getWorkflowSchema.ts](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator-backend/src/actions/getWorkflowSchema.ts), [executeWorkflow.ts](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator-backend/src/actions/executeWorkflow.ts), [SonataFlowService.ts](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator-backend/src/service/SonataFlowService.ts), and [WorkflowDefinition type](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator-common/src/types.ts).

### Follow-up

Verify whether the Orchestrator plugin must support both legacy `dataInputSchema` workflows and OWS 1.0 `input.schema` workflows during the OSL v2 spike. For external schemas, determine whether the Gateway should return resolved schema content or expose a schema retrieval endpoint that the plugin backend can call.


## OSL v2 schema retrieval endpoints

Checked the Alpha 3 Gateway and the running Quarkus Flow Runner 1.3.0-minimal. The Runner endpoint `GET /q/flow/definitions?namespace=default` returns workflow metadata and an `inputSchema` field. For inline schemas, the field includes the schema document. For `yamlgreet-separate-schema`, it returned `schemaExternal` with the mounted `file:///deployments/schemas/yamlgreet-separate-schema.json` URI; it did not return the JSON Schema contents. The endpoint therefore exposes the reference, not a form-ready schema document.

The Runner's generated `GET /q/openapi` also did not resolve this external schema: its generated POST operation for `yamlgreet-separate-schema` had only a generic `type: object` request body, with no schema properties or pattern. The workflow itself still validates input against the mounted schema during execution, as confirmed in the earlier test.

The Alpha 3 Gateway documents `GET /v1/definitions/` for identities and `GET /v1/definitions/{namespace}/{name}/{version}` for the full workflow document. The latter retains `input.schema.resource.endpoint`; the Gateway API has no documented schema-content endpoint. The Quarkus Flow Runner docs list `GET /q/flow/definitions` and full-definition retrieval but no separate endpoint to fetch a dereferenced external schema. Temporary Runner port-forward on local port 18081 was stopped after these read-only requests. It was used only to inspect Runner behavior and is not part of the planned plugin integration path.

### Integration implication and follow-up

Runtime validation of a mounted external schema is confirmed, but neither of the planned integration sources currently returns its resolved contents. The Gateway returns the workflow document with the external URI. The live Data Index GraphQL root exposes `getTaskExecution`, `getTaskExecutions`, `getTaskExecutionsByWorkflowInstance`, `getWorkflowInstance`, and `getWorkflowInstances`; it has no workflow-definition or input-schema query. The Runner endpoint was checked only as local diagnostic evidence and is not considered an integration path, since the plugin is expected to call the Gateway or Data Index directly. For schema-driven forms, ask OSL developers whether the Gateway will expose resolved external schemas or whether workflows should keep `input.schema` inline. Also clarify how any schema endpoint would be secured.

References: [Logic Operator Workflow Gateway API docs](/Users/lholmqui/develop/kubesmarts/logic-operator/docs/antora/modules/ROOT/pages/components/workflow-gateway.adoc), [Quarkus Flow Runner API docs](https://docs.quarkiverse.io/quarkus-flow/dev/runner.html), and [the separate-schema test README](/Users/lholmqui/develop/lholmquist/osl-v2-local-dev-playing/schemas/README.md).


The local Data Index was queried directly through a temporary port-forward on local port 18082, which was stopped after the read-only GraphQL checks. Its root query fields confirmed it is an instance/task API, not a workflow-definition or schema source for this setup.


## Dynamic Course Select source for the inline-schema probe

The widget baseline workflow that was actually run is the copy in the Orchestrator backend's temporary workflow repository. Use these as the source of truth for this probe:

- Workflow: `/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/packages/backend/.devModeTemp/repository/workflows/dynamic.course.select.sw.yaml`
- Its separate OSL v1 schema: `/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/packages/backend/.devModeTemp/repository/workflows/schemas/dynamic-course-select__main-schema.json`

The v1 workflow uses `specVersion: 0.8` and `dataInputSchema` to reference the sibling file. The new isolated OSL v2 probe is based on this exact pair and keeps the schema inline at `input.schema.document`. It carries over the original widget and fetch metadata; its simple OWS 1.0.0 `set` task returns a message plus the submitted student and course names. This keeps the probe focused on whether the Gateway definition includes the inline input schema. It does not depend on the widget HTTP server.

The probe lives in `widget-test-workflows/`, so default `make up` continues importing only `workflows/`. To import it explicitly, use `make workflows WORKFLOWS_DIR=widget-test-workflows WORKFLOW_BUNDLE=dynamic-course-select-inline-schema`; then query `GET /v1/definitions/default/dynamic-course-select-inline-schema/1.0.0`.

The earlier YamlGreet separate-schema files and test resources remain intact as an independent experiment. No source files in `.devModeTemp`, `orchestrator-demo`, or the OSL v2 `workflows/` directory were changed.


### Probe implementation and local cluster check

Created `widget-test-workflows/dynamic-course-select-inline-schema.json` as a separate OWS 1.0.0 copy. It embeds the JSON Schema from the confirmed OSL v1 widget-baseline workflow at `input.schema.document`, preserving its widget and fetch metadata. Its small `set` task returns a completion message, student name, and course name. The earlier YamlGreet separate-schema test remains untouched.

Imported the new workflow into the running Alpha 3 Kind cluster with `make workflows WORKFLOWS_DIR=widget-test-workflows WORKFLOW_BUNDLE=dynamic-course-select-inline-schema`. The importer created `default/flow-default-dynamic-course-select-inline-schema-1-0-f2b70afd` and restarted the Runner successfully. A Gateway request to `GET /v1/definitions/default/dynamic-course-select-inline-schema/1.0.0` succeeded once and returned the OWS 1.0.0 document with `input.schema.document` and the widget schema. Subsequent requests to host port 80 were refused. Kubernetes still reports the ingress controller and Gateway pods/endpoints as ready, and the Ingress host is `localhost`; local host-port access is therefore still intermittent in this check.

The Gateway definition read confirms inline schema retrieval is available from the Gateway document. The OSL v2 Orchestrator plugin has not yet been changed or tested against this definition.

## Endpoint integration work breakdown

The endpoint-to-capability mapping and proposed prototype, spike, and post-spike slices are in [OSL v2 Orchestrator Endpoint Work Breakdown](OSL-v2-Orchestrator-Endpoint-Work-Breakdown.md). The quick prototype begins with a Gateway source client and definition/schema retrieval. The Dynamic Course Select UI comparison remains paused until the workflow can be loaded in the Orchestrator UI.


## Started: Orchestrator access to OSL v2

Started reviewing how the existing two-Data-Index prototype can support the side-by-side OSL v1 and OSL v2 setup. The checkout is on `just-playing-two-DI-at-the-same-time-man`; its source registry currently creates Data Index GraphQL clients, so the OSL v2 Gateway needs a distinct client/source path. The first prototype slice is Gateway definition and inline-schema retrieval associated with `sourceId`, followed by execution and instance-history mapping. The Dynamic Course Select UI test remains paused. At that point, this was endpoint-integration exploration and no plugin code had yet been changed.


## Prototype update — Orchestrator access to OSL v2

The endpoint work has now moved from planning into a read-only backend prototype in the Orchestrator workspace on branch `just-playing-two-DI-at-the-same-time-man`.

- The existing OSL v1 SonataFlow configuration already uses `runtime: podman` and port `8899`. The v1 Data Index source now points to `http://localhost:8899`; a GraphQL `{ __typename }` request to `/graphql` returned HTTP 200.
- Added a distinct `workflowGatewayServices` configuration for source `osl-v2` at `http://localhost`. The old two demo Data Index entries at ports 8080 and 8081 were removed from this local app config.
- Added read-only plugin routes for Gateway definition listing, full definition retrieval, instance listing, and instance detail:
  - `GET /api/orchestrator/v2/gateway/osl-v2/definitions`
  - `GET /api/orchestrator/v2/gateway/osl-v2/definitions/default/yamlgreet/1.0.0`
  - `GET /api/orchestrator/v2/gateway/osl-v2/instances`
  - `GET /api/orchestrator/v2/gateway/osl-v2/instances/{instanceId}`
- The full Gateway definition contains the inline `input.schema.document`. Gateway instance responses currently provide metadata such as workflow identity, status, and timestamps.
- Direct read-only requests to the Kind Gateway returned HTTP 200 for `/v1/definitions/`, `/v1/instances`, and `/v1/instances/{id}`. This answers the initial query-path question: the Gateway exposes the instance metadata needed for this first history probe, so a separate direct OSL v2 Data Index connection is not needed for these reads. The Gateway itself depends on Data Index for the instance endpoints.
- The plugin routes are covered by the focused router tests; the Gateway client tests and router tests pass (70 tests total). `openapi:check` also passes.
- At the time of the initial prototype update, the local Orchestrator server had not yet been restarted; see the subsequent live route check below. These are prototype routes: OSL v2 definitions and instance metadata are not yet mapped into the existing Orchestrator UI/models, and execution, filtering/pagination, external schema resolution, and auth-token behavior remain open work.

### Frontend endpoint compatibility preference

The preferred direction is to keep the existing frontend-facing Orchestrator endpoints if the OSL v1 and v2 response data can be mapped or combined behind them. The new `/v2/gateway/...` routes are prototype probes for inspecting native Gateway responses; they are not a decision to add a permanent frontend API. Revisit the endpoint shape after the definition, schema, and instance mappings show which values can be combined and where explicit source selection is needed.

Next: execute one workflow through the Gateway and read its instance back through the plugin route. Then compare the native response with the existing Orchestrator API before deciding how the frontend-facing endpoints should evolve. The endpoint breakdown remains in [OSL-v2-Orchestrator-Endpoint-Work-Breakdown.md](OSL-v2-Orchestrator-Endpoint-Work-Breakdown.md).


## Live plugin route check — November 18, 2026

After running `yarn install`, the local `yarn start` backend was started. Unauthenticated requests to the prototype routes returned HTTP 401. Requests with the ExternalAccess bearer token already configured in `app-config.yaml` returned HTTP 200 for all four routes:

- Definitions returned five workflow identities from the Kind Gateway.
- The full `yamlgreet` definition returned its inline `input.schema.document`.
- Instance list and detail returned Gateway metadata including workflow identity, status, and timestamps.
- The detail check used instance `01M7QFNS4J9QNV0QYC2XF707QG` (`yamlgreet-separate-schema`).

This confirms the configured plugin backend can reach the OSL v2 Gateway for these reads. No direct OSL v2 Data Index query was needed for definition/schema retrieval or metadata-only instance history. The Gateway currently returns no workflow variables in its instance detail response. Gateway-side auth/token forwarding and full Orchestrator model/UI mapping remain unimplemented and need separate evaluation.


### Follow-up question for OSL developers

- Does the Workflow Gateway's `GET /v1/instances/{id}` intentionally return metadata only, or is there a supported way to retrieve workflow input/output variables? If variables are not exposed through the Gateway, is direct Data Index querying the intended client path, and which fields or endpoint should the Orchestrator use?

## Existing execute route prototype — November 18, 2026

The OSL v2 execution slice now uses the existing Orchestrator endpoint with an optional Gateway source selector:

```http
POST /api/orchestrator/v2/workflows/yamlgreet/execute?sourceId=osl-v2
Content-Type: application/json

{"inputData":{"name":"Codex"},"authTokens":[]}
```

For `sourceId=osl-v2`, the backend finds the Gateway definition by workflow name, requires that the name identify exactly one version, posts `inputData` directly to `/v1/runtime/{namespace}/{name}/{version}`, and maps the Gateway `instanceId` to the existing Orchestrator response `{ "id": "..." }`. The `sourceId` parameter is optional in the OpenAPI definition and generated client, so the existing OSL v1 call path remains unchanged.

The first execution prototype explicitly rejects event-triggered requests, provider auth tokens, and `targetEntity`; their OSL v2 mappings are still open. The current route also requires a unique workflow name because workflow version selection is not part of the existing path identifier.

Verification on November 18:

- Backend Gateway service and router tests: 72 passed.
- Orchestrator client tests: 24 passed.
- Existing Scaffolder action tests: 7 passed after updating the generated API call signature; Scaffolder actions still omit `sourceId` and stay on the OSL v1 path.
- `openapi:check`: generated artifacts are current.
- Through the restarted local plugin, `POST .../execute?sourceId=osl-v2` returned HTTP 200 with Gateway instance ID `01M7QXXGSDM50A3AB5AQ95GHGW`.
- `GET /api/orchestrator/v2/gateway/osl-v2/instances/01M7QXXGSDM50A3AB5AQ95GHGW` returned HTTP 200 and status `COMPLETED` for `default/yamlgreet/1.0.0`.

This proves API-level execution and metadata readback through the existing plugin execute route and the prototype Gateway routes. It does not yet wire OSL v2 definitions into the Orchestrator UI or implement the event, provider-token, target-entity, multi-version, or workflow-variable mappings. The local app must run under Node 22 for its installed `better-sqlite3` binary; a Node 24 shell produced an ABI mismatch during restart.

Next: decide how the UI should select a Gateway definition/version while retaining the existing execute API, then map v2 execution and instance data to the fields the UI needs. Keep the Dynamic Course Select widget comparison paused until the UI is ready for that work.

### Follow-up: Orchestrator Scaffolder integration

Review the existing Orchestrator Scaffolder actions and workflows for OSL v2 compatibility. Check how an action should select a Gateway source and workflow version, pass input data and provider tokens, preserve target-entity behavior, and return an instance link. The current prototype only adds `sourceId` to the API client; existing Scaffolder callers remain on the OSL v1 path.

## Existing instance-detail mapping and field gaps — November 18, 2026

The existing `GET /api/orchestrator/v2/workflows/instances/{instanceId}?sourceId=osl-v2` route returned the completed `yamlgreet` instance as HTTP 200. The route maps the Gateway's metadata-only detail response into `ProcessInstanceDTO` as follows:

| Existing response field | OSL v2 Gateway detail | Mapping or gap |
| --- | --- | --- |
| `id` | `id` | Passed through. |
| `sourceId` | Not returned | Set to the configured source ID, `osl-v2`. |
| `sourceName` | Not returned | Set from the configured Gateway source name. |
| `version` | `version` | Passed through. |
| `processId`, `processName` | `name` | Both currently use the workflow name. The Gateway `namespace` has no field in `ProcessInstanceDTO` and is dropped. |
| `state` | `status` | Passed through for supported states; Gateway `RUNNING` maps to Orchestrator `ACTIVE`. |
| `start`, `end` | `startedAt`, `endedAt` | Passed through. |
| `duration` | Not returned | Derived from start/end when both timestamps are valid. |
| `nodes` | Not returned | Set to an empty array because the existing DTO requires it; no node history is available. |
| `workflowdata` | Not returned | Missing. No workflow input/output variables are exposed by this detail response. |
| `initiatorEntity` | Not returned | Missing, so the existing ownership check cannot identify the initiating user. |
| `targetEntity` | Not returned | Missing. |
| `description`, `endpoint`, `serviceUrl`, `executionSummary`, `error`, `oslVersion` | Not returned | Not populated. |

The route still applies the existing instance ownership check. Because this Gateway response has no `initiatorEntity`, an instance can only pass that check when the caller has `orchestrator.instanceAdminView` permission, unless a supported ownership source is added. The local live check succeeded with the permission backend disabled; this does not establish production behavior when permissions are enabled.

### OSL developer follow-up

Can the Workflow Gateway, or another supported client API, return the instance namespace, initiating user/owner, workflow input variables, and workflow outputs? Which API should the Orchestrator use for each field if the Gateway intentionally exposes metadata only? Also confirm whether the Gateway status set can include values beyond the ones represented by the existing Orchestrator status enum.

### Instance-detail verification — November 18, 2026

- Focused router and mapping suites: 86 tests passed.
- Orchestrator backend TypeScript check passed.
- `openapi:check` reported generated artifacts current.
- Live `GET /api/orchestrator/v2/workflows/instances/01M7QXXGSDM50A3AB5AQ95GHGW?sourceId=osl-v2` returned HTTP 200 with status `COMPLETED`. The local permission backend was disabled for this check.

## Workflow overview mapping and field gaps — November 18, 2026

Compared the existing Orchestrator `WorkflowOverviewDTO` contract with the live OSL v2 Gateway responses through the local plugin routes:

- `GET /api/orchestrator/v2/gateway/osl-v2/definitions` returned five workflow references. Each has `namespace`, `name`, and `version`.
- `GET /api/orchestrator/v2/gateway/osl-v2/definitions/default/yamlgreet/1.0.0` returned the OWS document. Its `document` has `dsl`, `name`, `namespace`, and `version`; its input schema is under `input.schema.document`. The tested document did not include a description.
- `GET /api/orchestrator/v2/gateway/osl-v2/instances` returned individual instance records with `id`, `namespace`, `name`, `version`, `status`, `startedAt`, and `endedAt`.

The existing `WorkflowOverviewDTO` fields and the current evidence are:

| Existing overview field | OSL v2 Gateway source | Comparison / gap |
| --- | --- | --- |
| `workflowId` | Definition reference has `namespace/name/version`. | The identity parts are available. Choose a stable mapping that remains unique across namespaces and versions; the current overview contract has no separate namespace field. |
| `name` | Reference `name` and OWS `document.name`. | Directly available. |
| `version` | Reference `version` and OWS `document.version`. | Directly available. Keep this distinct from `document.dsl`, which identifies the DSL version. |
| `format` | Not returned as an authored-source format. The Gateway sends the parsed OWS document as JSON. | Cannot infer whether the original workflow was authored as YAML or JSON from the response serialization. Needs an explicit mapping rule or a model/API adjustment. |
| `description` | Not present in the live `yamlgreet` OWS document checked. | Missing from this example. Confirm whether the supported OWS definition has a standard description field and whether the Gateway preserves it. |
| `sourceId` | Plugin configuration identifies this Gateway source as `osl-v2`. | Can come from configured source identity; it is not part of the Gateway definition response. |
| `sourceName`, `sourceDescription` | Not returned in the definition or instance responses. | Must come from plugin source configuration or remain unset. |
| `oslVersion` | Not returned by the tested Gateway responses. | Treat as configured source metadata if the existing overview needs it; do not infer it from `document.dsl`. |
| `lastRunId` | Matching instance record's `id`. | Derivable from instance history only after selecting the latest run for the workflow identity. The definitions endpoint has no run data. |
| `lastTriggeredMs` | Matching instance `startedAt`. | Derivable by parsing the timestamp and converting to milliseconds, subject to history completeness and ordering. |
| `lastRunStatus` | Matching instance `status`. | Candidate mapping from Gateway status values; normalize and test all statuses against the existing Orchestrator status enum. |
| `isAvailable` | A definition reference being listed confirms that the Gateway returned that definition. | This does not establish that the workflow Runner is ready to execute it. Keep definition presence distinct from runtime availability. |
| `availability` | No per-workflow `statusCode/urlToFetch/reason` fields are returned. | No equivalent per-workflow ping result was found in the public Gateway responses checked. Availability semantics remain open. |
| `workflowRunStats.successRatio/runsLastMonth/successCount/errorCount/totalCount/averageTimeToComplete` | Instance history has per-run status and timestamps, but no aggregate statistics. | Not directly available. Some values could be computed only if the Gateway offers complete, queryable history with known pagination and status semantics; that contract is not established by the current prototype response. |

The existing v1 implementation builds overview data from workflow definitions plus Data Index instance queries, adds source labels from Data Index configuration, and separately checks workflow availability. The v2 Gateway definition route supplies identity and definition data, while the instance route supplies per-run metadata. This is enough to identify candidate inputs for an overview mapper, but not enough to claim parity for format, description, runtime availability, or aggregate statistics.

The full field-by-field mapping and implementation implications are also recorded in [OSL-v2-Orchestrator-Endpoint-Work-Breakdown.md](OSL-v2-Orchestrator-Endpoint-Work-Breakdown.md).

### OSL developer follow-ups

- Which OWS 1.0 definition field should provide a user-facing workflow description, and does the Gateway preserve it?
- Is there a supported per-workflow Runner availability or readiness query through the Gateway?
- Does the Gateway instance-list API guarantee complete history, and what filtering, pagination, and ordering contract should clients use to calculate latest-run values and statistics?
- What stable workflow identity should clients use when namespace, name, and version are all relevant?
- Should existing Orchestrator `format` and `oslVersion` fields be configured for OSL v2, redefined, or replaced with source/DSL metadata?

## Versioned OSL v2 workflow overview API — November 18, 2026

Kept the plugin API version separate from the OSL runtime version. The new overview endpoint is:

```http
GET /api/orchestrator/v3/osl-v2/gateways/{sourceId}/workflows/overview
```

It returns the existing `WorkflowOverviewListResultDTO` shape and is exposed through the typed frontend client as `listOslV2WorkflowOverviews(sourceId, paginationInfo?)`. The existing `/v2/workflows/overview` endpoint was not extended.

Mapping choices and limits:

- `workflowId` and `name` use the Gateway workflow name so they match the current name-based permission and execution prototype. `version`, `sourceId`, `sourceName`, and configured source description are included.
- The current overview contract has no namespace field. If a caller can see two definitions with the same name in a Gateway source, the new endpoint returns an input error instead of emitting colliding workflow IDs.
- `format` is `json` because the Gateway returns a parsed JSON document. This does not identify whether the workflow was originally authored as YAML or JSON.
- Description, latest-run fields, availability, and aggregate statistics remain unset because definition discovery does not provide those values and the current Gateway history contract is not confirmed as complete.

The typed client method is available, but the existing Orchestrator workflow table still calls the legacy list method. Passing `sourceId` through the workflow detail, schema, and execution pages remains UI integration work. The earlier Gateway probes and execution/instance prototypes also include plugin `/v2` paths; migrate those prototype paths into the new group before treating the version boundary as complete.

Verification: `yarn tsc:full` passed; `yarn openapi:check` reported generated artifacts current. The OpenAPI generator logged a Java normalizer exception during generation, but it emitted the new client operation and the generated-artifact check passed. Tests were not run.

### Live check — v3 OSL v2 workflow overview — November 18, 2026

After restarting `yarn start`, an authenticated request to `GET /api/orchestrator/v3/osl-v2/gateways/osl-v2/workflows/overview` returned HTTP 200. It returned five definitions: `dynamic-course-select-inline-schema`, `hello-world`, `random-success-or-error`, `yamlgreet`, and `yamlgreet-separate-schema`, each at version `1.0.0`.

Each result included the workflow name/ID, version, `format: json`, source ID `osl-v2`, and the configured Gateway source name/description. Pagination reported `pageSize: 5`, `offset: 0`. Latest-run, availability, and run-stat fields were absent as planned. This verifies the new backend route against the live local OSL v2 Gateway; the standard workflow table is not yet wired to call this versioned route.

## Start here tomorrow — November 19, 2026

The OSL v2 overview endpoint is live-verified. Start the next slice by adding a separate, read-only OSL v2 workflow list in the Orchestrator UI:

1. Call the typed client method `listOslV2WorkflowOverviews('osl-v2')`.
2. Render the results in a separate OSL v2 view so names such as `yamlgreet` do not collide with OSL v1 workflows in the legacy list.
3. Confirm the five local definitions and Gateway source labels appear.

Keep detail, schema, and execution navigation for a later slice. Those flows need v3 OSL v2 endpoints and source context carried through the UI.

### Follow-up question tracker — November 18, 2026

Consolidated the active OSL, Orchestrator, and deployment questions in [OSL v2 Follow-up Questions](2026-11-18-OSL-v2-Follow-up-Questions.md). The tracker includes the instance-detail and overview mapping questions, records the earliest date found in the existing status notes, and distinguishes questions recorded from questions confirmed sent.

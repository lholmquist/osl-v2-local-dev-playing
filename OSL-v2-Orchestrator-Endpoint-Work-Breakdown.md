# OSL v2 Orchestrator Endpoint Work Breakdown

**Date:** November 18, 2026  
**Related spike:** [RHIDP-18920 — Validate OSL v2 Workflow Gateway integration with Orchestrator](https://issues.redhat.com/browse/RHIDP-18920)

## Purpose

Break the Orchestrator-to-OSL v2 integration into small endpoint and capability slices. This is a planning document for the current Alpha 3 prototype and the implementation work that may follow the spike. Endpoint details should be checked against the OpenAPI document from the exact OSL build used for each test.

## Current context

The active plugin branch is `just-playing-two-DI-at-the-same-time-man`. It adds multiple Data Index sources under `orchestrator.dataIndexServices`, source-aware workflow and instance results, and source-specific lookups. Each registered Data Index source creates a `DataIndexService`; it does not represent a Workflow Gateway client. The local app config now points its OSL v1 Data Index source at `http://localhost:8899` (the Podman SonataFlow container) and defines a separate OSL v2 Workflow Gateway source at `http://localhost` for the Kind ingress.

For the side-by-side test, OSL v1 remains a SonataFlow/Data Index source, while OSL v2 is accessed through the Workflow Gateway in Kind. The v1 regular execution path queries Data Index for workflow metadata and `serviceUrl`, then POSTs to the SonataFlow runtime. The OSL v2 Gateway has a REST API and also provides instance queries backed by Data Index. The plugin API path `/api/orchestrator/v2/...` and the Gateway API path `/v1/...` are separate version namespaces.

A source configuration/client abstraction must distinguish these protocols while preserving existing single-Data-Index configuration. `sourceId` should identify the OSL source end to end. In the current branch, most detail/history actions accept `sourceId`, but the execute route does not yet pass it through.

## Endpoint and capability map

| Work slice | Current Orchestrator route(s) | OSL v2 Gateway endpoint(s) | Work and open questions |
|---|---|---|---|
| Source configuration and selection | `orchestrator.dataIndexService`, `orchestrator.dataIndexServices`; source-aware plugin routes | Gateway base URL; Gateway uses the platform's Data Index for instance queries | **Prototype added:** separate `workflowGatewayServices` config and client. Preserve legacy configuration; confirm source selection when identities overlap. |
| Workflow discovery and overview | `POST /v2/workflows/overview`, `POST /v2/workflows/overview/entity`, `GET /v2/workflows/{workflowId}/overview` | `GET /v1/definitions/`; `GET /v1/definitions/{namespace}/{name}/{version}` | **Prototype added:** raw identity and full definition routes. Map OWS identities into plugin models; determine entity filtering, run statistics, and source/version metadata. |
| Workflow source and input schema | `GET /v2/workflows/{workflowId}/source`, `GET /v2/workflows/{workflowId}/inputSchema` | `GET /v1/definitions/{namespace}/{name}/{version}` | **Prototype added:** full native OWS definition route; inline `input.schema.document` is included. Map it into the plugin's schema response. For `input.schema.resource`, the Gateway returns a URI, not resolved schema content; confirm the client contract with OSL. |
| Workflow availability | `GET /v2/workflows/{workflowId}/pingWorkflowService` | Gateway management `GET /ready` and `GET /health` | These management endpoints are not exposed through the public Gateway Service. Decide how plugin availability should be determined and whether per-workflow availability is supported. |
| Workflow execution | `POST /v2/workflows/{workflowId}/execute` | Async `POST /v1/runtime/{namespace}/{name}` or versioned `.../{name}/{version}`; synchronous variants append `/sync` | Map input payloads, auth headers/grants, response status and instance identity. Add source selection to execution. Confirm synchronous versus asynchronous behavior and error mapping. |
| Instance list and detail | `POST /v2/workflows/instances`, `POST /v2/workflows/{workflowId}/instances`, `GET /v2/workflows/instances/{instanceId}` | `GET /v1/instances`; `GET /v1/instances/{id}` | **Prototype added:** Gateway-backed list/detail routes return metadata and filter list results by workflow permission. Still map filters, pagination, and source identity; Gateway reports Data Index errors through these routes. |
| Instance lifecycle | `POST /v2/workflows/{workflowId}/{instanceId}/retrigger`, `DELETE /v2/workflows/instances/{instanceId}/abort` | `POST /v1/runtime/{namespace}/{name}/instance/{id}/{operation}`; versioned form also supported | Alpha 3 documents suspend, resume, and cancel. Map abort to cancel and determine whether retrigger has a direct equivalent or requires a new execution. |
| Logs, statuses, and run summaries | `GET /v2/workflows/instances/{instanceId}/logs`, `GET /v2/workflows/instances/statuses`; overview run statistics | No Gateway log route is listed. Instance state is available through instance queries. | Keep or adapt the existing log provider (for example, Loki). Normalize v1/v2 states and identify how overview statistics can be calculated from supported instance queries. |
| OpenAPI, errors, and diagnostics | Plugin OpenAPI and error responses | `GET /v1/openapi` or `/v1/openapi.json`; Gateway management health/readiness | Save the exact API contract for each tested build. Document response/error behavior, Data Index dependency, scheduler readiness, and installation requirements. |
| Authentication and permissions | Backstage permissions, source-aware authorization, provider auth tokens | Gateway forwards authorization headers; runtime security is configured on `LogicFlowRuntime` | Validate source-specific authorization and Secure Token Storage grant-reference behavior for direct, resolved, queued/long-running, and event-triggered runs. RHIDP-15907 is the related dependency. |
| Downstream consumers | Frontend, MCP actions, Scaffolder actions, generated client/OpenAPI | Preferred direction: preserve the existing frontend-facing plugin endpoints where the mapped response data supports it | After mapping v1/v2 definition, schema, execution, and history values, decide which existing responses can be combined and where explicit source selection or a new API is necessary. |

The Gateway paths above are from the [Alpha 3 Workflow Gateway documentation](/Users/lholmqui/develop/kubesmarts/logic-operator/docs/antora/modules/ROOT/pages/components/workflow-gateway.adoc). The plugin routes are listed in the [Orchestrator OpenAPI definition](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator-common/src/openapi/openapi.yaml).

## Suggested implementation slices

### Prototype in the current branch

1. **Implemented:** Separate `workflowGatewayServices` configuration and a Gateway client; the v1 Data Index remains configured separately.
2. **Implemented and unit-tested:** Read-only plugin endpoints retrieve Gateway definitions, the full OWS document (including inline schema), and instance metadata, associated with the configured `sourceId`.
3. **Initial finding:** Gateway definition and instance APIs return the data needed for discovery, inline-schema retrieval, and basic instance history. This does not yet prove the existing Orchestrator UI can consume the native response shapes.

The live Gateway endpoints were checked directly. At the time this initial progress note was written, end-to-end requests through the local Orchestrator server were still pending a restart; the follow-up live route check below completed that step. The prototype routes enforce workflow permissions but do not yet implement full OSL v2 mapping, query filters/pagination, owner scoping, or auth-token forwarding. This slice does not require the paused widget UI test; the Dynamic Course Select UI comparison remains a later check.

### Prototype progress (November 18, 2026)

- Added `orchestrator.workflowGatewayServices` with source ID `osl-v2`, separate from `orchestrator.dataIndexServices`.
- Added plugin routes `GET /v2/gateway/{sourceId}/definitions`, `GET /v2/gateway/{sourceId}/definitions/{namespace}/{name}/{version}`, `GET /v2/gateway/{sourceId}/instances`, and `GET /v2/gateway/{sourceId}/instances/{instanceId}`.
- The instance list route retrieves the Gateway's workflow identities and filters returned instances to the definitions the caller may access. Both list and detail responses are limited to Gateway instance metadata.
- Router and client test suites pass (70 tests); `openapi:check` passes. Workspace-wide TypeScript checking still reports missing dependencies in the unrelated `packages/app-legacy` app.

### Live plugin route verification (November 18, 2026)

After `yarn install` and starting the local `yarn start` backend, all four prototype routes returned HTTP 200 when called with the configured ExternalAccess bearer token. The definition list returned five identities; the `yamlgreet` full definition included its inline input schema; instance list and detail returned metadata only. Unauthenticated requests returned 401.

The live plugin path confirms the Gateway supplies these basic reads without a separate direct Data Index query. It does not yet prove that the Gateway supplies workflow variables or every field needed by the existing Orchestrator UI. Gateway-side authentication, workflow execution through the plugin, and response mapping remain open.

### Spike evidence

1. Record exact Logic Operator, Gateway, Runner, and Data Index image/version information and save the running Gateway OpenAPI document.
2. Capture definition and input-schema responses, then start one asynchronous workflow through the Gateway.
3. Record the returned instance identity and read that instance back through the Gateway history route; capture authentication, request/response details, and indexing delay.
4. Verify Secure Token Storage grant references and document action, readiness, error, and install semantics.
5. Produce the implementation decision record, revised story breakdown, documentation findings, and QE smoke-test steps required by RHIDP-18920.

### Post-spike implementation work

1. Source configuration, registry, identity, authorization, and backwards compatibility.
2. Definition discovery, overview mapping, source display, and availability.
3. Schema extraction, external-schema behavior, and form/widget compatibility.
4. Sync/async execution, event-triggered execution, token grants, and instance identity.
5. All-workflow and per-workflow history, detail, filtering, pagination, and partial-source failures.
6. Lifecycle actions and retrigger compatibility.
7. Logs, statuses, run statistics, health/readiness, and error mapping.
8. Frontend, MCP, Scaffolder, API generation, documentation, and smoke/E2E coverage.

## Related follow-ups

- Does the Workflow Gateway's `GET /v1/instances/{id}` intentionally return metadata only, or is there a supported way to retrieve workflow input/output variables? If variables are not exposed through the Gateway, is direct Data Index querying the intended client path, and which fields or endpoint should the Orchestrator use?

- After mapping native OSL v2 responses, revisit whether the current frontend-facing Orchestrator API can remain stable and document which v1/v2 fields combine versus require source-specific selection.

- Confirm whether `file:` schema resources and `LogicFlowRuntime.spec.podTemplate` ConfigMap mounts are supported interfaces, and how Gateway clients should retrieve external schema contents.
- Review runtime selection, multiple Runner configurations, `platformRef`, and persistence behavior.
- Revisit Alpha 4 when its release artifacts are available.
- Try the setup on OpenShift after RHDH installation, including same-namespace/coexistence requirements.
- Cross-check workflow candidates from `rhdh-plugins` and overlays E2E tests and manual-testing Jira issues. The Dynamic Course Select UI comparison is currently paused; `sample-retry-test`, `select-user`, and `test-object-type-uiprops` remain candidates to review.

### Existing execute route prototype (November 18, 2026)

- Added optional `sourceId` query support to `POST /v2/workflows/{workflowId}/execute`; `sourceId=osl-v2` selects the configured Workflow Gateway. Calls without a source continue through the existing OSL v1 implementation.
- The prototype resolves the given workflow name against Gateway definitions and requires a single matching version. It forwards the raw `inputData` to `POST /v1/runtime/{namespace}/{name}/{version}` and maps Gateway `instanceId` to the existing `{ id }` response.
- Event-triggered executions, provider auth tokens, `targetEntity`, and names with multiple versions are rejected with a clear request error until their mappings are defined.
- Added and generated the OpenAPI/client parameter, Gateway POST client, and focused tests. Verification: 72 backend tests, 24 client tests, and 7 Scaffolder action tests passed; `openapi:check` reported generated files current.
- Live verification through the restarted local plugin returned HTTP 200 for the execute call and for the Gateway instance detail route; the returned `yamlgreet` instance reached `COMPLETED`.

This is an API-level execution proof. UI workflow discovery/version selection and full mapping to existing Orchestrator frontend models remain future slices. The live app should be started with Node 22 because the workspace's `better-sqlite3` binary is built for that Node ABI.

### Follow-up: Orchestrator Scaffolder integration

Review the existing Orchestrator Scaffolder actions and workflows for OSL v2 compatibility. Check how an action should select a Gateway source and workflow version, pass input data and provider tokens, preserve target-entity behavior, and return an instance link. The current prototype only adds `sourceId` to the API client; existing Scaffolder callers remain on the OSL v1 path.

### Existing instance-detail route slice (November 18, 2026)

The existing `GET /v2/workflows/instances/{instanceId}?sourceId=osl-v2` now reads Gateway detail and returns a `ProcessInstanceDTO`. The live read of the `yamlgreet` instance returned HTTP 200 with status `COMPLETED`.

Field gaps and adaptation:

- `id`, `version`, and timestamps map from Gateway `id`, `version`, `startedAt`, and `endedAt`; `duration` is calculated from timestamps.
- `processId` and `processName` use Gateway `name`. Gateway `namespace` is not represented by `ProcessInstanceDTO` and is currently dropped.
- Gateway `RUNNING` maps to Orchestrator `ACTIVE`. The DTO-required `nodes` field is returned as an empty array.
- `workflowdata`, `initiatorEntity`, `targetEntity`, `description`, `endpoint`, `serviceUrl`, `executionSummary`, `error`, and `oslVersion` are not provided by Gateway detail and are omitted.
- `sourceId` and `sourceName` come from plugin configuration, not the Gateway response.
- The existing instance-ownership check remains active. Since Gateway detail has no initiator identity, callers need `orchestrator.instanceAdminView` unless a supported owner lookup is added. Local verification ran with the permission backend disabled.

Follow up with OSL developers on the supported way to retrieve namespace, owner/initiator, and workflow input/output variables, and on status values outside the existing Orchestrator enum. See the field-by-field inventory in [today’s status](2026-11-18-OSL-v2-Local-Development-Status.md).

Verification for this slice: 86 focused router/mapping tests passed, the Orchestrator backend TypeScript check passed, and `openapi:check` reported generated artifacts current. The live detail request for `01M7QXXGSDM50A3AB5AQ95GHGW` returned HTTP 200 and `COMPLETED` with the local permission backend disabled.

### Workflow overview mapping comparison (November 18, 2026)

The overview comparison is now based on the live local Gateway responses and the existing `WorkflowOverviewDTO` / v1 producer:

- Definition discovery supplies `namespace`, `name`, and `version`; the full OWS definition repeats its identity under `document`. A stable plugin workflow ID still needs a namespace/version policy because the existing DTO has no namespace field.
- The Gateway response is a parsed JSON document, so it does not establish whether the authored definition format was YAML or JSON. The tested `yamlgreet` definition had no description.
- Source display fields can only come from plugin configuration. The Gateway definition response does not return source labels or an OSL version.
- The definitions route does not return latest-run or statistics fields. Per-run `id/status/startedAt/endedAt` records from the instances route are candidate inputs for latest-run values and locally computed statistics, but completeness, pagination, ordering, and status normalization need confirmation.
- A listed definition is not proof that its Runner is currently available. The current prototype responses do not provide the per-workflow availability result expected by the existing DTO.

The full field-by-field table and OSL developer questions are in [today’s status](2026-11-18-OSL-v2-Local-Development-Status.md). The comparison completes the discovery phase for this slice; implementation still needs decisions on workflow identity, description/format, availability, and the history contract before mapping the overview into the existing UI API.

### Plugin API version boundary — November 18, 2026

The plugin's `/v2` API version is independent of the OSL runtime version. The new overview slice uses a separate namespace:

```http
GET /v3/osl-v2/gateways/{sourceId}/workflows/overview
```

It maps Gateway references to `WorkflowOverviewListResultDTO` and has a typed frontend client method. `workflowId` is currently the Gateway name to preserve the existing permission/execution prototype's identity convention; duplicate visible names within one source are rejected because the DTO has no namespace field. The Gateway JSON representation maps to `format: json`; this does not claim to preserve the source authoring format. Unsupported run, description, and availability fields are left unset.

The existing `/v2/workflows/overview` API remains unchanged. The current Orchestrator table is not yet switched to the new client method, and source identity is not yet carried through details/schema/execute navigation. Earlier Gateway probe and execution/instance prototype paths still include `/v2`; move those into the `/v3/osl-v2` group before considering the separation complete.

TypeScript check and `openapi:check` passed. The full field comparison remains in [today's status](2026-11-18-OSL-v2-Local-Development-Status.md).

### Live verification: versioned OSL v2 overview — November 18, 2026

After restarting the local Orchestrator backend, an authenticated request to `GET /api/orchestrator/v3/osl-v2/gateways/osl-v2/workflows/overview` returned HTTP 200 with five workflows and pagination metadata (`pageSize: 5`, `offset: 0`). The mapped entries contained the configured Gateway source metadata and expected identity fields. Latest-run and availability fields were omitted. The full result is recorded in [today's status](2026-11-18-OSL-v2-Local-Development-Status.md).

### Next slice to begin — November 19, 2026

Add a separate read-only OSL v2 workflow list to the Orchestrator UI. Use the typed `listOslV2WorkflowOverviews('osl-v2')` client method and the live-verified `GET /v3/osl-v2/gateways/{sourceId}/workflows/overview` endpoint. Keep the view separate from the legacy workflow list to avoid name collisions. Detail, schema, and execution navigation need their own v3 endpoints and source propagation in a later slice.

### Follow-up question log — November 18, 2026

The dated question tracker is [OSL v2 Follow-up Questions](2026-11-18-OSL-v2-Follow-up-Questions.md). It consolidates the external-schema, instance-detail, overview metadata, history, availability, identity, authentication, lifecycle, runtime, Scaffolder, and deployment questions. It tracks the date first recorded separately from whether a question was actually sent.

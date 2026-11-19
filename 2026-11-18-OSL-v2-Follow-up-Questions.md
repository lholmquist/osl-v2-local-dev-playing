# OSL v2 Follow-up Questions

**Created:** November 18, 2026  
**Purpose:** Keep OSL v2, Orchestrator, and deployment follow-up questions in one dated log, including questions raised by the instance-detail and workflow-overview mappings.

## Date and status convention

“First recorded” is the earliest date found in the local status or endpoint documents; it does not prove that the question was sent. “Sent” is marked “Not recorded” unless the chat or documents provide evidence that it was asked externally. Update the sent date and answer when a question is taken to the OSL, RHDH, or Install teams. Add future questions under a new date heading instead of replacing earlier entries.

## Questions for OSL / Logic Operator developers

### OSL-01 — External input-schema packaging and support

- **First recorded:** November 17, 2026; refined November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** What is the supported OSL v2 contract for packaging an input schema separately from its workflow? Is input.schema.resource.endpoint with a file: URI and a ConfigMap mounted through LogicFlowRuntime.spec.podTemplate a supported interface? Is this the recommended equivalent to the v1 spec.resources.configMaps workflow path, and is a first-class Logic Operator resource or field for workflow sidecar resources planned?

### OSL-02 — Resolving external schemas for Gateway clients

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** When an OWS definition uses input.schema.resource, should the Gateway resolve and return the schema document, or is there a supported Gateway endpoint for retrieving it? Should workflows keep schemas inline when clients need to build forms? How should schema retrieval be secured?

### OSL-03 — Preserving custom widget schema metadata

- **First recorded:** November 17, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** Does the OSL v2 definition and Gateway path preserve JSON Schema UI metadata such as ui:widget and ui:props, including the original types of their values? What is the supported request path for submitting the values produced by those forms to the workflow?

### OSL-04 — Instance variables, ownership, and namespace

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** Is GET /v1/instances/{id} intentionally metadata-only? Which supported Gateway or Data Index API returns workflow input/output variables and the initiating user or owner? Should Orchestrator query the Data Index directly for these fields? The instance response includes a namespace, but the current ProcessInstanceDTO does not; what identity/ownership fields should clients use?

### OSL-05 — Gateway instance status values

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** What status values can Gateway instance responses return across normal, failed, cancelled, suspended, and resumed runs? What mapping should clients use when those values do not match the Orchestrator status enum?

### OSL-06 — Instance history completeness and statistics

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** What are the filtering, pagination, ordering, and completeness guarantees of the Gateway instance-list API? Does it provide read-after-write consistency, and what indexing delay should clients expect after execution? Can clients safely derive the latest run and aggregate statistics from this API, or is there a dedicated query/aggregate contract?

### OSL-07 — Overview metadata and version semantics

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** Which OWS 1.0 definition field is intended for a user-facing description, and does the Gateway preserve it? Does the Gateway expose the original authored YAML/JSON format? How should clients distinguish document.dsl (DSL version) from document.version (workflow version), and should source OSL version be exposed separately?

### OSL-08 — Stable workflow identity

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** What stable workflow identifier should clients use when namespace, name, and version all matter? Can multiple namespaces or versions contain the same workflow name, and how should a client select and execute one exact definition?

### OSL-09 — Per-workflow availability

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** Is there a supported Gateway API for checking whether a particular workflow’s Runner is ready to execute it? Are Gateway management health/readiness endpoints intended for plugin clients, or is another availability contract recommended?

### OSL-10 — Authentication and provider-token grants

- **First recorded:** November 17, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** How should Gateway and runtime authentication be configured for Orchestrator clients? Which authorization headers are forwarded? What is the supported Secure Token Storage grant-reference flow for direct, resolved, queued/long-running, and event-triggered executions, so provider token values do not need to pass through Orchestrator?

### OSL-11 — Execution modes and request/response contract

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** What are the supported synchronous and asynchronous execution contracts, including response identity, status, and error shape? What is the supported event-triggered request path, and how should caller metadata such as a target entity be carried or persisted?

### OSL-12 — Lifecycle and retrigger operations

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** Which lifecycle operations does the Gateway support (cancel, suspend, resume), and what are their request/response semantics? Is retrigger a supported operation, or should a retry create a new workflow instance?

### OSL-13 — Logs

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** Is there a supported Gateway API for workflow or instance logs? If not, what log source and correlation identifiers should Orchestrator use?

### OSL-14 — Runtime selection and persistence

- **First recorded:** November 16, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** What is the supported meaning of runtimeRef.name, and when should an installation use multiple Runners? How do platformRef, persistence choices, and runtime configuration work across local development, staging, and production?

## Questions for RHDH / Orchestrator / Install follow-up

### INT-01 — Supporting both schema generations

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** During the spike, must the Orchestrator support both legacy v1 dataInputSchema workflows and OWS 1.0 input.schema workflows? What compatibility period or migration behavior is expected?

### INT-02 — Scaffolder integration

- **First recorded:** November 18, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** How should Orchestrator Scaffolder actions select a Gateway source and exact workflow version, pass Secure Token Storage grants and target-entity context, and return a link to the resulting instance?

### INT-03 — OpenShift namespace and installation ownership

- **First recorded:** November 16, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** After RHDH is installed on OpenShift, can the OSL v2 components run in the same namespace? Which component owns installation, permissions, service exposure, and lifecycle, and what namespace/coexistence constraints should the plugin assume?

### INT-04 — Workflow candidates for widget and manual-test coverage

- **First recorded:** November 17, 2026
- **Sent:** Not recorded
- **Status:** Draft
- **Question:** Which workflows from the triage list, manual-testing Jira issues, rhdh-plugins E2E tests, and overlays E2E tests should be added to the OSL v2 evaluation set, especially for custom widget behavior?

## Decisions recorded November 18, 2026

- The Orchestrator plugin API /v2 is distinct from the OSL runtime version. The overview prototype now uses /v3/osl-v2/...; the separate read-only OSL v2 workflow view is the next UI slice.
- The overview mapping uses workflow name as workflowId for the current prototype. Duplicate visible names are rejected because the existing DTO has no namespace field.
- The current Gateway overview response format is reported as json because the Gateway returns a parsed JSON document; that does not establish the original authoring format.

## Sources consolidated

- [November 17 status](2026-11-17-OSL-v2-Local-Development-Status.md)
- [November 18 status](2026-11-18-OSL-v2-Local-Development-Status.md)
- [Endpoint work breakdown](OSL-v2-Orchestrator-Endpoint-Work-Breakdown.md)
- [Separate-schema test notes](schemas/README.md)

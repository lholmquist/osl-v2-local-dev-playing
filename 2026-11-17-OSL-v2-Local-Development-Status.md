# OSL v2 Local Development — Status

**Date:** November 17, 2026

## Focus

Evaluate OSL v2 against the Orchestrator plugin's current behavior and identify compatibility gaps. Multi-source routing is one dimension of the spike, alongside workflow discovery, inputs, execution, history, lifecycle, authentication, widgets, readiness, and deployment.

## Work completed today

- Re-read the acceptance criteria for [RHIDP-18920](https://redhat.atlassian.net/browse/RHIDP-18920), “SPIKE: Validate OSL v2 Workflow Gateway integration with Orchestrator.” The Jira item is **New**, estimated at 5 story points, with Fix Version 2.2.0 and a 5–7 working-day timebox.
- Clarified that the spike is an OSL v2 capability and integration assessment, rather than only a multi-server connectivity exercise.
- Read the separate Codex chat, “Explore orchestrator custom widgets,” and carried its findings into this spike context.
- No Gateway API calls, workflow runs, or cluster changes were performed as part of today's review.

## Custom widget findings

Orchestrator's six custom widgets are optional React JSON Schema Form (RJSF) components selected through input-schema UI metadata:

- **SchemaUpdater** fetches schema fragments and updates fields in the form.
- **ActiveTextInput** can fetch initial text, autocomplete suggestions, and validation results.
- **ActiveDropdown** can fetch choices, defaults, and validation results.
- **ActiveMultiSelect** supports searchable, fetched suggestions and configured selections.
- **ActiveBoolean** can fetch and update a checkbox value based on dependencies.
- **ActiveText** displays Markdown text with values from the form, Backstage APIs, or fetched responses.

The widgets affect form presentation and can affect the input data the user submits. They do not define workflow tasks or execution logic. Orchestrator currently sends the form data as inputData when starting a workflow.

For OSL v2, verify that Orchestrator can obtain the workflow's JSON Schema input document with the ui:widget and ui:props annotations intact, and that the selected values can be sent through the v2 start request. OWS defines workflow input schemas; RHDH's rendering behavior for custom widgets is Orchestrator-specific. The likely integration seam is schema retrieval/mapping and the Gateway request contract. The widgets themselves may remain unchanged if those contracts preserve the schema and input data they expect.

Relevant implementation and documentation:
- [Orchestrator widget guide](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/docs/orchestratorFormWidgets.md)
- [Run form submission](/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/plugins/orchestrator/src/components/ExecuteWorkflowPage/ExecuteWorkflowPage.tsx)
- [Orchestrator workflow capability inventory](/Users/lholmqui/develop/lholmquist/orchestrator-workflow-triage/orchestrator-current-capabilities.md)

## Baseline carried forward from November 16

- The standalone Alpha 3 Kind stack completed make up; the chart and LogicPlatform became Ready, and the Hello World workflow ran. Workflow instances appeared after about a minute in a later query.
- The Alpha 4 setup stopped because the release CRD URL returned 404; Alpha 3 remains the working baseline.
- The workflow triage inventory scoped eight workflows used by Orchestrator. Their common workflow behavior has OWS equivalents, but their legacy start/states YAML requires conversion. UI metadata, custom operations, token propagation, Kafka wiring, and consumer-specific result formats need separate handling.
- The existing random-success-or-error OWS draft declares DSL 1.0.0 while using the scalar set syntax added in 1.0.1. Update it to the DSL 1.0.0 object form before importing it.

See the [November 16 status doc](2026-11-16-OSL-v2-Local-Development-Status.md) for the Alpha 3/Alpha 4 setup details and the workflow comparison.

## Plan for the spike

1. **Record the exact target build.** Capture versions or image tags for the Gateway, Runner, Data Index, and relevant schema. Obtain the OpenAPI/schema document from the running build rather than relying on the architecture slides alone.
2. **Prove one complete request path.** With a simple imported workflow such as yamlgreet, capture discovery and input-schema responses, start an asynchronous run through Gateway, record its response and instance identity, then query the resulting instance through the confirmed history API. Record authentication, requests, responses, and indexing delay.
3. **Build a current-versus-v2 capability matrix.** Compare discovery, input schema/forms, async execution, instance listing/details/logs, filtering and pagination, lifecycle actions, events, errors, readiness, source routing, and deployment. Classify each as compatible, needs changes, unavailable, or unverified.
4. **Include custom widgets in the matrix.** Identify where the current six widgets and ui:props are used; check that the v2 schema path preserves the JSON Schema and UI metadata and that inputData reaches execution correctly.
5. **Check authentication and provider-token grants.** Verify the Secure Token Storage grant-reference contract (direct grantId, optional resolver, queued/long-running execution, and supported event paths) without passing provider token values through Orchestrator.
6. **Record deployment and operational gaps.** Confirm authentication boundaries, namespace/coexistence assumptions, installation ownership, health/readiness, and lifecycle behavior with the OSL and RHDH Install teams. If the target build cannot validate an item, mark it unverified or blocked.
7. **Deliver the evidence and refined plan.** Keep the actual request/response examples and versioned API contract with the capability matrix, then use the findings to revise the implementation story breakdown.

The broader spike plan is in [orchestrator-multi-data-index-plan.md](/Users/lholmqui/Documents/ChatGPT/rhdh-plugins/orchestrator-multi-data-index-plan.md). The two v1 demo servers remain useful for exercising multi-source behavior, but they are not evidence of the OSL v2 Gateway contract.

## Status at end of this review

The Jira criteria and custom-widget integration seam are understood and today’s validation plan is recorded. The OSL v2 API proof and capability matrix remain to be completed. No workflows were modified or run today.

## Follow-up: expand workflow candidates

- Revisit the workflow triage list and consider adding widget-focused examples to the OWS v2 test/conversion candidates, including sample-retry-test (ActiveTextInput fetch/retry behavior), select-user (ActiveTextInput catalog autocomplete), and test-object-type-uiprops (ui:props value handling).
- Find the manual-testing Jira issues that exercise workflows, identify those workflow names, and check whether any belong in the candidate list for OWS v2 evaluation.

## RHIDP-18920 execution plan using sample-retry-test

### Goal

Use a workflow with real Orchestrator form-widget usage to test the OSL v2 schema-to-form-to-execution path, while using the broader spike matrix to assess other Orchestrator capabilities. The source sample is Serverless Workflow 0.8, so the v2 probe must be a separate OWS DSL 1.0 copy; importing the original file unchanged would test legacy format support, not widget compatibility.

### 1. Establish the current Orchestrator baseline

- Use the triage entry for sample-retry-test and its existing Orchestrator E2E as the reference.
- Record its three ActiveTextInput fields and their ui:props: one uses three retries with a 1.5-second delay and retryable status codes; one uses a narrower retry policy; the third has no retry settings.
- Confirm the current form behavior and the shape of the inputData submitted when the workflow is started. Capture the existing Orchestrator schema response shape for comparison.
- Keep this as the OSL v1 baseline; do not interpret it as evidence of OSL v2 behavior.


#### Additional observed baseline: Dynamic Course Select (2026-11-17)

This run supplements the planned `sample-retry-test` baseline with a broader widget workflow from `orchestrator-demo/06_form-widget-demo`.

- **Environment:** Local RHDH/Orchestrator started with `yarn start`, using the Podman runner image `quay.io/kubesmarts/incubator-kie-sonataflow-devmode:main`. Widget requests went through `/api/proxy/mytesthttpserver` to the local mock server on port `12345`.
- **Widget requests:** The local `yarn start` log showed the workflow's fetch and validation requests returning HTTP 200, including requests for `summary`, `rooms`, `suggested-courses`, `coursedetailsschema`, `preferred-teacher`, `certificatesschema`, and the room, drinks, and teacher validators.
- **Execution:** `dynamic-course-select` completed successfully as instance `5929c4d3-af76-475a-a4b5-2adc9f844b76`. Runner logs show `Start` -> `PrintSuccessData` -> `End` and a successful result.
- **Submitted input recorded by the runner:**

```json
{
  "studentName": "Luke",
  "courseName": "A course providing null value to be ignored as the default value for the Room selection",
  "courseDetails": {
    "room": "Dynamically fetched default room name (counter: 3)"
  },
  "hiddenEnrollmentId": "enroll-0001",
  "hiddenSummarySnapshot": "The Luke student selected A course providing null value to be ignored as the default value for the Room selection course",
  "hiddenStep": {
    "auditToken": "audit-0001"
  },
  "conditionalHiddenNote": "Visible unless the course is complexCourse.",
  "complimentaryDrinks": [],
  "favoriteMascot": [
    "penguin-is-mandatory",
    "pikachu-is-mandatory-as-well",
    "dragon-can-be-unselected"
  ],
  "preferredTeacher": "123_tim",
  "sendCertificatesAs": "post",
  "readOnlyActiveTextInput": "The Luke student selected A course providing null value to be ignored as the default value for the Room selection course",
  "regularArray": ["bar"]
}
```

- **Result:** The workflow returned `The workflow finished successfully.` with outputs for the student, course, room, teacher, and hidden values. `requestCertificate` and `reviewDetails` were `null` in this run; the fetched room included a counter and may vary on reruns.
- **Instance query follow-up:** The Orchestrator instance-details request returned HTTP 200, but this run did not record a direct Data Index query result or indexing delay.
- **Versioning note:** The RHDH request path `/api/orchestrator/v2/...` is the Orchestrator plugin API route; this run used the OSL v1 SonataFlow dev-mode runner.

For the v2 comparison, preserve the workflow, input schema, and Node server versions, repeat the same form interactions, compare the submitted `inputData` and result, then record the direct v2 instance-history/Data Index query and visibility delay.

### 2. Prepare an isolated OWS v2 probe

- Create a separate test copy in the local workflow directory; do not change the source workflow in serverless-workflows.
- Convert the trivial workflow body to OWS DSL 1.0 and place its input schema in the OWS input schema document.
- Resolve and document how input schemas are loaded in an OSL v2 environment. So far, the v2 setup has imported a workflow by itself; verify how the schema is packaged, referenced, or registered, and confirm the Gateway returns it after import. Do not assume the v1 `dataInputSchema` packaging carries over unchanged.
- Preserve the three fields, their ui:widget values, and ui:props values, including their string, number, and array types.
- Make the OWS test workflow return or otherwise expose the submitted input values so the request-to-runtime mapping can be checked.

### 3. Verify schema and execution through the v2 Gateway

- Record the exact Logic Operator, Gateway, Runner, Data Index, and schema versions from the running Alpha 3 stack; save the Gateway OpenAPI/schema document used.
- Import the test copy and query the Gateway's definition and input-schema routes.
- Compare the returned schema with the source copy. Check that ui:widget and ui:props survive intact and that typed values such as retry counts and status-code arrays are not stringified or dropped.
- Start the workflow asynchronously through the Gateway. Save the request, authentication details, response, and returned instance identity.
- Query the resulting instance through the confirmed history route. Record the returned data and the time until the instance becomes visible.

### 4. Check the Orchestrator form integration seam

- Compare the v2 schema response with the input shape the current Orchestrator form consumes, including its inputSchema/data response and inputData execution payload.
- Feed the v2-returned schema to the existing form-widget package and confirm the three fields render and their fetch/retry behavior works.
- Confirm the values produced by the form reach the v2 workflow unchanged.
- If the current plugin cannot retrieve the v2 schema or start through Gateway, record the smallest required adapter boundary. Decide whether a throwaway proof harness fits the spike timebox; keep production integration changes in the implementation stories.

### 5. Complete the wider OSL v2 gap matrix

For each capability in the current Orchestrator inventory, compare the v2 contract and behavior, then label it compatible, needs changes, unavailable, or unverified:

- Definition discovery, input schema, and custom widget rendering.
- Normal asynchronous execution and returned instance identity.
- Instance list/detail, logs, filters, sorting, pagination, and partial-source failures.
- Cancel/abort, suspend/resume, rerun/retrigger, and event-triggered execution.
- Authentication boundaries, permissions, and Secure Token Storage grantId handling for direct, resolved, queued/long-running, and supported event paths.
- Runtime and Data Index readiness, errors, deployment ownership, and namespace/coexistence requirements.
- Multiple workflow sources and source-aware routing, including duplicate workflow identities.

The multi-source checks belong in this matrix alongside the other capabilities; they are not a substitute for the v2 contract and end-to-end checks.

### 6. Close the spike with evidence and decisions

Keep a compact evidence record containing component versions, the OpenAPI/schema, request and response examples, instance-query results, widget-schema comparison, and the capability matrix. List blockers and questions for the OSL and RHDH Install teams. Use the findings to revise the implementation stories and identify the specific plugin changes, tests, and documentation work required.

If a richer widget example is needed after this probe, consider select-user from the triage inventory for catalog autocomplete. First cross-check it against the manual-testing Jira workflows noted in the follow-up above.

## Where we left off - November 17, 2026

### Completed today

- Ran the Dynamic Course Select workflow through local RHDH/Orchestrator with the OSL v1 SonataFlow dev-mode runner.
- The widget proxy fetch and validation requests returned HTTP 200, and `dynamic-course-select` completed as instance `5929c4d3-af76-475a-a4b5-2adc9f844b76`.
- Saved the submitted input and result details in the baseline subsection above.
- Confirmed the RHDH `/api/orchestrator/v2/...` route is the plugin API path; this run still used the OSL v1 runner.
- Added the open question of how OSL v2 packages, references, imports, and returns workflow input schemas. The current v2 setup has only imported a workflow by itself.

### Start here tomorrow

1. Resolve the OSL v2 input-schema loading path. Find the supported workflow/schema layout or registration mechanism, then confirm the Gateway returns the schema after import.
2. Confirm the conversion target. Today's concrete v1 baseline is Dynamic Course Select, while the existing RHIDP-18920 plan uses `sample-retry-test`. Decide whether to convert Dynamic Course Select for broader widget coverage, keep `sample-retry-test` as the initial probe, or use both in sequence. Keep the v1 sources unchanged.
3. Create the isolated OWS DSL 1.0 copy using the resolved schema-loading approach. Compare the returned schema and widget metadata, form requests, submitted input, workflow result, and instance/Data Index visibility against the v1 baseline.

Direct Data Index query results and indexing delay for today's v1 instance were not captured; record those if the instance remains available.


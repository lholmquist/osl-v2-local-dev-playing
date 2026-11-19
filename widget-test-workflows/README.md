# Dynamic Course Select inline-schema probe

This isolated OSL v2 workflow is based on the exact OSL v1 workflow copy used for the widget baseline:

- Workflow: `/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/packages/backend/.devModeTemp/repository/workflows/dynamic.course.select.sw.yaml`
- Schema: `/Users/lholmqui/develop/redhat-developer/rhdh-plugins/workspaces/orchestrator/packages/backend/.devModeTemp/repository/workflows/schemas/dynamic-course-select__main-schema.json`

The JSON Schema is embedded at `input.schema.document`, preserving the original widget and fetch metadata. The workflow uses OWS 1.0.0 and a small `set` task so it can be imported as a standalone schema-discovery probe. It does not start or depend on the widget HTTP server.

The existing `schema-test-workflows/yamlgreet-separate-schema.yaml` remains the separate-schema experiment. This directory is not imported by the default `make up`; import it explicitly with:

```sh
make workflows WORKFLOWS_DIR=widget-test-workflows WORKFLOW_BUNDLE=dynamic-course-select-inline-schema
```

After importing, the Gateway definition route is:

```text
GET /v1/definitions/default/dynamic-course-select-inline-schema/1.0.0
```

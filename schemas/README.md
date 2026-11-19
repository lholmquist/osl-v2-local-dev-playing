# Separate YAML Greet schema probe

This probe leaves `workflows/yamlgreet.yaml` unchanged. The copied workflow uses the OWS external schema resource form. Its separate JSON Schema file is placed in a Kubernetes ConfigMap and mounted directly into the Quarkus Flow Runner pod; no HTTP server is involved.

From the local setup repository root, create/update the ConfigMap:

```sh
kubectl create configmap yamlgreet-separate-schema \
  --namespace default \
  --from-file=yamlgreet-separate-schema.json=schemas/yamlgreet-separate-schema.json \
  --dry-run=client -o yaml | kubectl apply -f -
```

Import only the experimental copy (the normal `workflows/` directory remains unchanged), then mount the ConfigMap into the Runner using the Alpha 3 `LogicFlowRuntime.spec.podTemplate` volume customization:

```sh
make workflows WORKFLOWS_DIR=schema-test-workflows WORKFLOW_BUNDLE=yamlgreet-schema-test
kubectl patch logicflowruntime osl-local-runner \
  --namespace default --type=merge \
  --patch-file manifests/yamlgreet-runtime-schema-volume-patch.json
kubectl -n default rollout status deployment/osl-local-runner
```

The patch mounts the schema at `/deployments/schemas/yamlgreet-separate-schema.json`. The copied workflow refers to it with `file:///deployments/schemas/yamlgreet-separate-schema.json`. Verified on the running Alpha 3 stack: the `quay.io/quarkiverse/quarkus-flow-runner:1.3.0-minimal` Runner resolved this `file:` URI from the mounted ConfigMap and enforced the schema. Valid input completed with HTTP 200; a name violating the schema pattern returned HTTP 400. The Quarkus Flow Runner documentation does not currently describe this file-based schema-loading path, so the OSL developer follow-up remains whether it is a supported interface.

The test workflow is isolated in `schema-test-workflows/`, so a normal `make up` does not load this test workflow or its `file:` reference. The workflow importer scans only the directory passed as `WORKFLOWS_DIR`; the JSON schema in `schemas/` is not treated as a workflow. If you changed the workflow namespace or runtime name, adjust the ConfigMap namespace and patch target accordingly.

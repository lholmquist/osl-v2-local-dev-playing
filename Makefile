# Standalone local OSL v2 setup. This file intentionally does not include
# anything from the logic-operator source checkout.

KIND ?= kind
KUBECTL ?= kubectl
HELM ?= helm
CURL ?= curl
PYTHON ?= python3
YQ ?= yq

KIND_CLUSTER ?= osl-v2-local
KIND_PROVIDER ?= podman
KUBE_CONTEXT ?= kind-$(KIND_CLUSTER)
OPERATOR_NAMESPACE ?= logic-operator-system
WORKFLOW_NAMESPACE ?= default
WORKFLOW_RUNTIME ?= osl-local-runner
WORKFLOW_BUNDLE ?= osl-local
WORKFLOWS_DIR ?= workflows
INPUT ?= {}
HELM_RELEASE ?= osl-v2-local
OSL_VERSION ?= 2.0.0-Alpha3

INGRESS_NGINX_VERSION ?= v1.12.2
CERT_MANAGER_VERSION ?= v1.16.3
INGRESS_NGINX_URL ?= https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-$(INGRESS_NGINX_VERSION)/deploy/static/provider/kind/deploy.yaml
CERT_MANAGER_URL ?= https://github.com/cert-manager/cert-manager/releases/download/$(CERT_MANAGER_VERSION)/cert-manager.yaml
STACK_CHART ?= oci://ghcr.io/kubesmarts/charts/logic-operator-stack
CRDS_URL ?= https://github.com/kubesmarts/logic-operator/releases/download/v$(OSL_VERSION)/crds.yaml

KUBECTL_CONTEXT := --context $(KUBE_CONTEXT)
HELM_CONTEXT := --kube-context $(KUBE_CONTEXT)

.PHONY: help check-tools up kind-up helm-up workflows status invoke down kind-delete

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "%-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check-tools: ## Check required local tools
	@set -e; for tool in podman $(KIND) $(KUBECTL) $(HELM) $(CURL) $(PYTHON) $(YQ); do \
		command -v "$$tool" >/dev/null 2>&1 || { echo "Required tool not found: $$tool" >&2; exit 1; }; \
	done

up: check-tools ## Create Kind, install the published OSL stack, and load workflows/
	$(MAKE) --no-print-directory kind-up
	$(MAKE) --no-print-directory helm-up
	$(MAKE) --no-print-directory workflows
	@echo "Local OSL stack is ready at http://localhost"
	@echo "Workflow namespace: $(WORKFLOW_NAMESPACE)"

kind-up: check-tools ## Create the Podman-backed Kind cluster and its ingress/cert-manager prerequisites
	@if KIND_EXPERIMENTAL_PROVIDER=$(KIND_PROVIDER) $(KIND) get clusters | grep -Fxq "$(KIND_CLUSTER)"; then \
		echo "Kind cluster '$(KIND_CLUSTER)' already exists."; \
	else \
		echo "Creating Kind cluster '$(KIND_CLUSTER)' with the $(KIND_PROVIDER) provider..."; \
		KIND_EXPERIMENTAL_PROVIDER=$(KIND_PROVIDER) $(KIND) create cluster --name $(KIND_CLUSTER) --config kind-config.yaml; \
	fi
	$(KUBECTL) $(KUBECTL_CONTEXT) apply -f $(INGRESS_NGINX_URL)
	@for i in $$(seq 1 30); do \
		$(KUBECTL) $(KUBECTL_CONTEXT) get deployment -n ingress-nginx ingress-nginx-controller >/dev/null 2>&1 && break || sleep 2; \
	done
	$(KUBECTL) $(KUBECTL_CONTEXT) wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s
	$(KUBECTL) $(KUBECTL_CONTEXT) apply -f $(CERT_MANAGER_URL)
	@for i in $$(seq 1 30); do \
		$(KUBECTL) $(KUBECTL_CONTEXT) get deployment -n cert-manager cert-manager >/dev/null 2>&1 && break || sleep 2; \
	done
	$(KUBECTL) $(KUBECTL_CONTEXT) wait --namespace cert-manager --for=condition=available deployment --all --timeout=180s
	$(KUBECTL) $(KUBECTL_CONTEXT) wait --for=condition=Established --timeout=60s crd/certificates.cert-manager.io crd/issuers.cert-manager.io

helm-up: check-tools ## Install/upgrade the published Logic Operator Helm stack
	@crds_file=$$(mktemp); trap 'rm -f "$$crds_file"' EXIT; \
		$(CURL) -fsSL "$(CRDS_URL)" -o "$$crds_file"; \
		$(KUBECTL) $(KUBECTL_CONTEXT) apply --server-side -f "$$crds_file"
	$(HELM) $(HELM_CONTEXT) upgrade --install $(HELM_RELEASE) $(STACK_CHART) \
		--version $(OSL_VERSION) \
		--namespace $(OPERATOR_NAMESPACE) --create-namespace \
		--values values.yaml --wait --timeout 10m
	@echo "Pointing Vector at workflow namespace '$(WORKFLOW_NAMESPACE)'..."
	$(KUBECTL) $(KUBECTL_CONTEXT) patch logicplatform $(HELM_RELEASE) \
		--namespace $(OPERATOR_NAMESPACE) --type=merge \
		--patch '{"spec":{"dataIndex":{"vector":{"watchNamespaces":["$(WORKFLOW_NAMESPACE)"]}}}}'
	$(KUBECTL) $(KUBECTL_CONTEXT) wait --namespace $(OPERATOR_NAMESPACE) \
		--for=jsonpath='{.status.phase}'=Ready logicplatform/$(HELM_RELEASE) --timeout=300s

workflows: check-tools ## Import YAML/JSON workflows and restart their Runner (set WORKFLOWS_DIR=...)
	WORKFLOWS_DIR="$(WORKFLOWS_DIR)" \
	WORKFLOW_NAMESPACE="$(WORKFLOW_NAMESPACE)" \
	WORKFLOW_RUNTIME="$(WORKFLOW_RUNTIME)" \
	WORKFLOW_BUNDLE="$(WORKFLOW_BUNDLE)" \
	KUBECTL="$(KUBECTL) $(KUBECTL_CONTEXT)" \
	YQ="$(YQ)" $(PYTHON) scripts/import_workflows.py

status: ## Show the platform, workflow resources, and pods
	$(KUBECTL) $(KUBECTL_CONTEXT) get logicplatform -n $(OPERATOR_NAMESPACE)
	$(KUBECTL) $(KUBECTL_CONTEXT) get logicflowruntime,logicflowdefinition -n $(WORKFLOW_NAMESPACE)
	$(KUBECTL) $(KUBECTL_CONTEXT) get pods -n $(OPERATOR_NAMESPACE)
	$(KUBECTL) $(KUBECTL_CONTEXT) get pods -n $(WORKFLOW_NAMESPACE)

invoke: ## Invoke a workflow through the Gateway (set WORKFLOW, VERSION, INPUT)
	@test -n "$(WORKFLOW)" || { echo "Set WORKFLOW=<name>" >&2; exit 2; }
	@test -n "$(VERSION)" || { echo "Set VERSION=<version>" >&2; exit 2; }
	$(CURL) -fsS -X POST "http://localhost/v1/runtime/$(WORKFLOW_NAMESPACE)/$(WORKFLOW)/$(VERSION)/sync" \
		-H 'Content-Type: application/json' -d '$(INPUT)'

down: ## Uninstall the published Helm stack; keep the Kind cluster and CRDs
	$(HELM) $(HELM_CONTEXT) uninstall $(HELM_RELEASE) --namespace $(OPERATOR_NAMESPACE)

kind-delete: ## Delete this local Kind cluster
	KIND_EXPERIMENTAL_PROVIDER=$(KIND_PROVIDER) $(KIND) delete cluster --name $(KIND_CLUSTER)

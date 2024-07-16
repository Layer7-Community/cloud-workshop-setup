CLUSTER_NAME ?= cloud-workshop
NAMESPACE_PREFIX ?= workshopuser
ATTENDEE_COUNT ?= 25
CURRENT_ATTENDEE_COUNT ?= 25
SA_SECRET_NAME ?= attendee-sa-token
DOMAIN ?= brcmlabs.com
INGRESS_HOST_POSTFIX ?=
GRAFANA_HOST ?= grafana${INGRESS_HOST_POSTFIX}.${DOMAIN}
GRAFANA_ADMIN_PASS ?= mzVHFN5s8RKq3FUA
DEV_GATEWAY_HOST ?= mydevgw${INGRESS_HOST_POSTFIX}.${DOMAIN}
PROD_GATEWAY_HOST ?= myprodgw${INGRESS_HOST_POSTFIX}.${DOMAIN}

.SILENT:

wait:
ifeq ($(OS),Windows_NT)
	TIMEOUT /T $(t)
else
	sleep $(t)
endif

provision-components: cert-manager open-telemetry prometheus grafana-stack operator-crds external-secrets gateways
	echo "***************************************************"
	echo "Provisioning Complete"
	echo "***************************************************"
	echo "Kubeconfig can be found here"
	echo "$(pwd)/kubeconfig/${CLUSTER_NAME}"

provision-users:
	echo "***************************************************"
	echo "Provisioning admin user and"
	echo "${ATTENDEE_COUNT} user accounts"
	echo "***************************************************"
	./utilities/provision-users.sh ${CLUSTER_NAME} "" ${ATTENDEE_COUNT} ${NAMESPACE_PREFIX} ${SA_SECRET_NAME}

add-users:
	echo "***************************************************"
	echo "Adding additional user accounts"
	echo "${CURRENT_ATTENDEE_COUNT} will be increased to ${ATTENDEE_COUNT}"
	echo "***************************************************"
	./utilities/provision-users.sh ${CLUSTER_NAME} ${CURRENT_ATTENDEE_COUNT} ${ATTENDEE_COUNT} ${NAMESPACE_PREFIX} ${SA_SECRET_NAME}

update-user-role:
	echo "***************************************************"
	echo "Updating attendee roles"
	echo "***************************************************"
	./utilities/update-user-role.sh ${ATTENDEE_COUNT} ${NAMESPACE_PREFIX}

refresh-users:
	echo "***************************************************"
	echo "Refreshing attendee service accounts"
	echo "***************************************************"
	./utilities/refresh-service-accounts.sh ${CLUSTER_NAME} ${ATTENDEE_COUNT} ${NAMESPACE_PREFIX} ${SA_SECRET_NAME} true

refresh-workshop:
	echo "***************************************************"
	echo "Resetting attendee namespaces"
	echo "***************************************************"
	./utilities/refresh-workshop.sh ${ATTENDEE_COUNT} ${NAMESPACE_PREFIX}

remove-users:
	echo "***************************************************"
	echo "Removing all users"
	echo "***************************************************"
	./utilities/refresh-service-accounts.sh ${CLUSTER_NAME} ${ATTENDEE_COUNT} ${NAMESPACE_PREFIX} ${SA_SECRET_NAME} false

stress-test:
	echo "***************************************************"
	echo "Stress testing your environment"
	echo "***************************************************"
	./utilities/stress-test.sh ${ATTENDEE_COUNT} ${CLUSTER_NAME} ${NAMESPACE_PREFIX}

get-info:
	echo "***************************************************"
	echo "Environment Info"
	echo "***************************************************"
	echo "Cluster Name                 ==> ${CLUSTER_NAME}"
	echo "Attendee Count               ==> ${ATTENDEE_COUNT}"
	echo "Current Attendee Count       ==> ${CURRENT_ATTENDEE_COUNT}"
	echo "Namespace Prefix             ==> ${NAMESPACE_PREFIX}"
	echo "Serviceaccount Secret Name   ==> ${SA_SECRET_NAME}"
	echo "Domain                       ==> ${DOMAIN}"
	echo "Ingress host postfix         ==> ${INGRESS_HOST_POSTFIX}"
	echo "Grafana                      ==> ${GRAFANA_HOST}"
	echo "Grafana Admin Pass           ==> ${GRAFANA_ADMIN_PASS}"
	echo "Dev Gateway                  ==> ${DEV_GATEWAY_HOST}"
	echo "Prod Gateway                 ==> ${PROD_GATEWAY_HOST}"

operator-crds:
	echo "***************************************************"
	echo "Installing Layer7 Operator CRDs"
	echo "***************************************************"
	kubectl apply -f ./deploy/crd/crd.yaml

grafana-stack:
	echo "***************************************************"
	echo "Deploying Grafana LGTM Stack"
	echo "***************************************************"
	helm repo add grafana https://grafana.github.io/helm-charts
	helm upgrade --install --values ./manifests/otel-lgtm/grafana-stack/loki-overrides.yaml loki grafana/loki -n grafana-loki --create-namespace
	helm upgrade --install --values ./manifests/otel-lgtm/grafana-stack/promtail-overrides.yaml promtail grafana/promtail -n grafana-loki
	helm upgrade --install --values ./manifests/otel-lgtm/grafana-stack/tempo-overrides.yaml tempo grafana/tempo -n grafana-loki
	helm upgrade --install --values ./manifests/otel-lgtm/grafana-stack/mimir-distributed-overrides.yaml mimir grafana/mimir-distributed -n grafana-loki

gateways:
	echo "***************************************************"
	echo "Deploying Dev/Prod Gateways"
	echo "***************************************************"
	kubectl -n default apply -f ./deploy/rbac.yaml
	kubectl -n default apply -f ./deploy/operator.yaml
	cat ./manifests/gateway/dev/dev-gateway.yaml | sed -e 's/DEV_GATEWAY_HOST/'${DEV_GATEWAY_HOST}'/g' > ./manifests/gateway/dev/dev-gateway-tmp.yaml
	kubectl -n default apply -k ./manifests/gateway/dev/
	cat ./manifests/gateway/prod/prod-gateway.yaml | sed -e 's/PROD_GATEWAY_HOST/'${PROD_GATEWAY_HOST}'/g' > ./manifests/gateway/prod/prod-gateway-tmp.yaml
	kubectl -n default apply -k ./manifests/gateway/prod/

prometheus:
	echo "***************************************************"
	echo "Deploying Prometheus Stack"
	echo "***************************************************"
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update
	kubectl create ns monitoring
	-mkdir ./.tmp
	cp ./manifests/otel-lgtm/prometheus/prometheus-values.yaml ./.tmp
	sed -i -e 's/GRAFANA_HOST/'${GRAFANA_HOST}'/g' ./.tmp/prometheus-values.yaml
	sed -i -e 's/GRAFANA_ADMIN_PASS/'${GRAFANA_ADMIN_PASS}'/g' ./.tmp/prometheus-values.yaml
	kubectl apply -k ./manifests/otel-lgtm/prometheus/grafana-dashboard/
	helm upgrade -i prometheus -f ./.tmp/prometheus-values.yaml prometheus-community/kube-prometheus-stack -n monitoring
	rm -rf ./.tmp

cert-manager:
	echo "***************************************************"
	echo "Deploying Cert Manager Operator"
	echo "***************************************************"
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
	@$(MAKE) --silent t=10 wait
	kubectl wait --for=condition=ready --timeout=600s pod -l app=cert-manager -n cert-manager
	kubectl wait --for=condition=ready --timeout=600s pod -l app=cainjector -n cert-manager
	kubectl wait --for=condition=ready --timeout=600s pod -l app=webhook -n cert-manager

external-secrets:
	echo "***************************************************"
	echo "Deploying External Secrets Operator"
	echo "***************************************************"
	helm repo add external-secrets https://charts.external-secrets.io
	helm repo update
	helm install eso external-secrets/external-secrets -n external-secrets --set installCRDs=true --create-namespace

open-telemetry:
	echo "***************************************************"
	echo "Deploying OpenTelemetry Operator"
	echo "***************************************************"
	kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.97.1/opentelemetry-operator.yaml
	@$(MAKE) --silent t=10 wait
	kubectl wait --for=condition=ready --timeout=600s pod -l app.kubernetes.io/name=opentelemetry-operator -n opentelemetry-operator-system

nginx-kind:
	echo "***************************************************"
	echo "Deploying Nginx (Kind)"
	echo "***************************************************"
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@$(MAKE) --silent t=10 wait
	kubectl wait --for=condition=ready --timeout=600s pod -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller -n ingress-nginx

uninstall-nginx-kind:
	kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

nginx:
	echo "***************************************************"
	echo "Deploying Nginx (Generic)"
	echo "***************************************************"
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml
	@$(MAKE) --silent t=10 wait
	kubectl wait --for=condition=ready --timeout=600s pod -l app.kubernetes.io/name=ingress-nginx,app.kubernetes.io/component=controller -n ingress-nginx

uninstall-nginx:
	kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

kind-cluster:
	echo "***************************************************"
	echo "Creating Kind Cluster"
	echo "***************************************************"
	kind create cluster --name ${CLUSTER_NAME} --config ./kind-config.yaml

uninstall-kind:
	echo "***************************************************"
	echo "Removing Kind Cluster"
	echo "***************************************************"
	kind delete cluster --name ${CLUSTER_NAME}

uninstall:
	-helm uninstall loki -n grafana-loki
	-helm uninstall promtail -n grafana-loki
	-helm uninstall tempo -n grafana-loki
	-helm uninstall mimir -n grafana-loki	
	-helm uninstall prometheus -n monitoring
	-kubectl delete -k ./manifests/otel-lgtm/prometheus/grafana-dashboard/
	-helm uninstall eso -n external-secrets
	-kubectl -n default delete -f ./deploy/rbac.yaml
	-kubectl -n default delete -f ./deploy/operator.yaml
	-kubectl -n default delete -k ./manifests/gateway/dev/
	-kubectl -n default delete -k ./manifests/gateway/prod/
	-kubectl delete -f ./deploy/crd/crd.yaml
	-kubectl delete -f https://github.com/open-telemetry/opentelemetry-operator/releases/download/v0.97.1/opentelemetry-operator.yaml
	-kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml

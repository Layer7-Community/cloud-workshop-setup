# Cloud Workshop Provisioning
This repo contains provisioning tools and all resources required to deploy the [Cloud Native workshop lab](https://github.com/Gazza7205/cloud-workshop-labs) environment.

This repository should serve as a starting point for preparing your own Lab environment, the original version of this repository covered services that are not currently in the lab environment that you can use as examples, expanding this to cover provisioning additional services is simple and can be done via the Makefile.

**The included Layer7 Operator is based on [v1.0.6](https://github.com/CAAPIM/layer7-operator/releases/tag/v1.0.6)**

# Modes
- [Kind](https://kind.sigs.k8s.io/)
  - Useful for deploying everything locally or on-site where you have a limited number of attendees or expect each attendee to have their own environment.
- New or Existing Kubernetes Cluster
  - We strongly recommend creating a dedicated Kubernetes Cluster for this environment.

## Components
- [Kind](https://kind.sigs.k8s.io/) - Optional
- [Grafana LGTM Stack](https://grafana.com/about/grafana-stack/) (Observability - Layer7 Gateway OTEL)
- [Prometheus](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) (Observability - Kubernetes Cluster)
  - Grafana is deployed as part of Prometheus
    - This is primarily for the Cluster Monitoring dashboards that prometheus provides.
- [Cert-Manager Operator](https://cert-manager.io/docs/)
- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
  - Depends on Cert-Manager
- [External Secrets Operator](https://external-secrets.io/latest/)
- [Nginx](https://github.com/kubernetes/ingress-nginx)

## Sizing
The original cloud workshop lab environment was created to serve 25 users. Sizing is calculated based on the resources required for each attendee.

#### This illustrates how we determine sizing for each workshop environment.
- Attendees ==> 25
  - Maximum of 2 Gateways per attendee
  - Workshop components
    - 8 cores, 32GB RAM (can be lower)
  - Gateway Resources
    - 2 cores, 4GB RAM
    - Range
        - Cores ==> 25x(2-4) = 50-100 cores
        - RAM   ==> 25x(4-8) = 100-200GB RAM

Machine sizes (GCP) - with autoscaling
- 8vcpu, 16/32GB RAM
  - Minimum
    - Single-Zone = 1 (8cores, 16/32GB RAM)
    - Multi-Zone = 3 (24cores, 48/96GB RAM)
  - Maximum
    - 100/8 = 12.5
    - Single-Zone 13 (104cores, 208/416GB RAM)
    - Multi-Zone = 15 (120cores, 240/480GB RAM)

##### From an autoscaling perspective this would equate to a node pool of 1-5 instances across 3 zones.

# Prerequisites
This repo **has not** been adapted to Windows. If you are using Windows we recommend using a virtual machine or [WSL2](https://learn.microsoft.com/fr-fr/windows/wsl/install). Your docker host (if using kind) may be local or remote. Ubuntu works best in our experience.

- Gateway v11.x license
  - Place a v11.x license as license.xml [here](./manifests/gateway/base/secrets/license)
- [Kind](https://kind.sigs.k8s.io/)
  - Kind
  - Docker
- Common
  - Kubernetes CLI ([kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/))
  - [Helm](https://helm.sh/docs/intro/install/) 3.x
  - [Make](https://www.gnu.org/software/make/)
- DNS
  - The simplest way to configure DNS is using /etc/hosts
  - You can also expand Makefile to include a public DNS server
    - An example for GCP can be found in the [examples](./examples/dns/configure-dns.sh) folder

#### Creating an SSH Docker Context
The user must exist and be part of the Docker group
```
docker context create myubuntuvm --docker "host=ssh://user@vm-ip-address"
```
Configure your docker client to use the remote context
```
docker context use myubuntuvm
```

### Kind Config
If you are using a VM for Kind you will need to update your [kind config](./kind-config.yaml)
```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "vm-ip-address"
  apiServerPort: 6443
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```


#### Get Environment Info
```
make get-info
```

## Guide
* [Quickstart](#quickstart)
  * [Kind](#kind)
  * [New or Existing Kubernetes Cluster](#new-or-existing-kubernetes-cluster)
* [Configure DNS](#configure-dns)
* [Verify Services](#verify-services)
* [Utilities](#utilities)
  * [Add Users](#add-users)
  * [Clear Namespaces](#clear-namespaces)
  * [Refresh Service Accounts](#refresh-service-accounts)
  * [Remove All Users](#remove-all-users)
  * [Stress Test](#stress-test)
* [Configure External Secrets (Exercise 9)](#configure-external-secrets-exercise-9)


## Configuration
You can use the following environment variables to configure your lab workshop. You can either export these or update them directly in the [Makefile](./Makefile)

| Name                     | Description                                                                                                          | Default Value                               |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| `CLUSTER_NAME`           | Kubernetes Cluster name. This is used to populate the kubeconfig folder with admin, attendee and environment details | `cloud-workshop`                            |
| `NAMESPACE_PREFIX`       | Prefix used for workshop users, translates to $workshopUser$workshopUserNumber                                       | `workshopuser`                              |
| `ATTENDEE_COUNT`         | Number of attendees you intend to have. This creates x namespaces and kubeconfigs                                    | `25`                                        |
| `CURRENT_ATTENDEE_COUNT` | Used when adding new users                                                                                           | `25`                                        |
| `SA_SECRET_NAME`         | Service Account Secret Name                                                                                          | `attendee-sa-token`                         |
| `DOMAIN`                 | Demo services domain                                                                                                 | `brcmlabs.com`                              |
| `INGRESS_HOST_POSTFIX`   | Postfix for dns names, useful if you intend to have multiple environments.                                           | ``                                          |
| `GRAFANA_HOST`           | Grafana Host, used to configure ingress resources                                                                    | `grafana${INGRESS_HOST_POSTFIX}.${DOMAIN}`  |
| `GRAFANA_ADMIN_PASS`     | Grafana Admin Pass                                                                                                   | `mzVHFN5s8RKq3FUA`                          |
| `DEV_GATEWAY_HOST`       | Dev Gateway Host                                                                                                     | `mydevgw${INGRESS_HOST_POSTFIX}.${DOMAIN}`  |
| `PROD_GATEWAY_HOST`      | Prod Gateway Host                                                                                                    | `myprodgw${INGRESS_HOST_POSTFIX}.${DOMAIN}` |

## Quickstart
Make sure you have configured all of the [prerequisites](#prerequisites) and take a look at the [configuration table](#configuration)

### Kind
Please refer to [kind-config](#kind-config) for more kind configuration options. You can also refer to the [official documentation](https://kind.sigs.k8s.io/docs/user/configuration/).
```
make kind-cluster provision-components provision-users nginx-kind
```

### New or Existing Kubernetes Cluster
```
make provision-components provision-users
```
if you don't have an ingress controller you can deploy nginx with the following
```
make nginx
```
if you are using kind
```
make nginx-kind
```

#### Kubernetes Kubeconfigs
Once provision-users has completed you will find admin and attendee configs per cluster name in the [kubeconfig](./kubeconfig/) folder

## Configure DNS
The following hosts need to be configured in DNS. The easiest way to do this is using /etc/hosts (Linux) or C:\Windows\System32\drivers\etc\hosts (Windows)

Get configuration
```
make get-info
```
output
```
Cluster Name                 ==> cloud-workshop
Attendee Count               ==> 25
Current Attendee Count       ==> 25
Namespace Prefix             ==> workshopuser
Serviceaccount Secret Name   ==> attendee-sa-token
Domain                       ==> brcmlabs.com
Ingress host postfix         ==> 
Grafana                      ==> grafana.brcmlabs.com
Grafana Admin Pass           ==> mzVHFN5s8RKq3FUA
Dev Gateway                  ==> mydevgw.brcmlabs.com
Prod Gateway                 ==> myprodgw.brcmlabs.com
```

### Determining your IP Address
If you're using a dedicated Kubernetes Cluster it's likely that you have a LoadBalancer provisioner which will give Nginx an external IP Address. This should be visible on your ingress records

#### Kind
If you're using Kind the address will say localhost
```
kubectl get ingress -A
```
output (kind)
```
NAMESPACE    NAME                 CLASS   HOSTS                   ADDRESS     PORTS     AGE
default      ssg-dev              nginx   mydevgw.brcmlabs.com    localhost   80, 443   4m48s
default      ssg-prod             nginx   myprodgw.brcmlabs.com   localhost   80, 443   4m48s
monitoring   prometheus-grafana   nginx   grafana.brcmlabs.com    localhost   80, 443   6m16s
```

If you are using a local docker engine
```
127.0.0.1 mydevgw.brcmlabs.com myprodgw.brcmlabs.com grafana.brcmlabs.com
```
If you configured networking in [kind-config.yaml](./kind-config.yaml)

Kind config
```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "vm-address"
  apiServerPort: 6443
...
```
Hosts config
```
vm-address mydevgw.brcmlabs.com myprodgw.brcmlabs.com grafana.brcmlabs.com
```

#### Other
```
kubectl get ingress -A
```
output (kind)
```
NAMESPACE    NAME                 CLASS   HOSTS                   ADDRESS            PORTS     AGE
default      ssg-dev              nginx   mydevgw.brcmlabs.com    <ingress-address>   80, 443   4m48s
default      ssg-prod             nginx   myprodgw.brcmlabs.com   <ingress-address>   80, 443   4m48s
monitoring   prometheus-grafana   nginx   grafana.brcmlabs.com    <ingress-address>   80, 443   6m16s
```
If you do not have an address set, it's likely that your ingress records or nginx is not configured correctly. Nginx has a default ingressClass called nginx, if you have an existing Kubernetes Cluster that does not use this default, you will need to update your ingress configuration.

Hosts config
```
ingress-address mydevgw.brcmlabs.com myprodgw.brcmlabs.com grafana.brcmlabs.com
```


# Verify Services

## Gateway Info
The credentials for both dev and prod gateways are
```
username: admin
password: 7layer
server: myprodgw.brcmlabs.com:443 | mydevgw.brcmlabs.com:443
```
Verify that they are up and running
```
kubectl -n default get pods
```
output
```
NAME                                                  READY   STATUS    RESTARTS   AGE
layer7-operator-controller-manager-6bf9699596-z5tsr   2/2     Running   0          21m
ssg-dev-7b4d8f6875-l8zd5                              1/1     Running   0          21m
ssg-prod-5c8b655485-dkqpp                             1/1     Running   0          21m
```

## Grafana
Confirm all Grafana stack pods are up and running
```
kubectl get pods -n grafana-loki
```
output
```
NAME                                       READY   STATUS      RESTARTS   AGE
loki-0                                     1/1     Running     0          4m
loki-canary-hr5n6                          1/1     Running     0          4m
loki-chunks-cache-0                        2/2     Running     0          4m
loki-gateway-5cd888fb5b-lx68d              1/1     Running     0          4m
loki-minio-0                               1/1     Running     0          4m
loki-results-cache-0                       2/2     Running     0          4m
mimir-alertmanager-0                       1/1     Running     0          2m7s
mimir-compactor-0                          1/1     Running     0          2m7s
mimir-distributor-75db4845b5-fwgx5         1/1     Running     0          2m7s
mimir-ingester-0                           1/1     Running     0          2m7s
mimir-ingester-1                           1/1     Running     0          2m7s
mimir-make-minio-buckets-5.0.14-9ddtx      0/1     Completed   0          2m7s
mimir-minio-66c9c9446c-vr6tx               1/1     Running     0          2m7s
mimir-nginx-6c54df9bbf-xw5wm               1/1     Running     0          2m7s
mimir-overrides-exporter-75c74b879-l4vd2   1/1     Running     0          2m7s
mimir-querier-f4c7668c7-c2lkr              1/1     Running     0          2m7s
mimir-query-frontend-86f49bdd54-57njx      1/1     Running     0          2m7s
mimir-query-scheduler-9c9db55-ns8bw        1/1     Running     0          2m7s
mimir-rollout-operator-589445cccd-2gktd    1/1     Running     0          2m7s
mimir-ruler-87b575f97-xxv8z                1/1     Running     0          2m7s
mimir-store-gateway-0                      1/1     Running     0          2m7s
promtail-92scb                             1/1     Running     0          3m25s
tempo-0                                    1/1     Running     0          3m17s
```

- Confirm all datasources are configured correctly in Grafana
    - Open a browser and navigate to `https://grafana.brcmlabs.com` if you changed the grafana ingress host, navigate to the host that you configured. Accept the certificate warning and proceed to authenticate.
      The default username is `admin` with password `${GRAFANA_ADMIN_PASS}`. The default can be found in [configuration](#configuration)
    - Select the datasources tab on the left side menu and proceed to test them.
      - Loki
      - Prometheus
      - Tempo
    The animated gif below depicts the process you will need to follow.

    ![grafana-datasource-gif](./manifests/otel-lgtm/images/grafana-datasource-gif.gif)


# Utilities
The following utilities should make administering the workshop environment simpler. You can add and run your own utilities if one here doesn't fit your use case. Feel free to create a PR to add something that you think is missing or reach out to us.

## Add Users
If you require additional users you can run the following command. This makes use of the following environment variables (you can set these in the [Makefile](./Makefile))
```
ATTENDEE_COUNT ?= 25           <<== Desired Attendee Count
CURRENT_ATTENDEE_COUNT ?= 25   <<== Current Attendee Count
```
Scaling up from 25 to 30
```
ATTENDEE_COUNT ?= 30           <<== Desired Attendee Count
CURRENT_ATTENDEE_COUNT ?= 25   <<== Current Attendee Count
```
run the following command
```
make add-users
```

## Clear Namespaces
If you are using autoscaling your kubernetes cluster will have scaled up to meet your attendees needs during the workshop. This command removes all of the components that attendees may have deployed.
```
make refresh-workshop
```

## Refresh Service Accounts
After running a workshop it's good practice to rotate credentials. This command refreshes all of the service account tokens that provision-users creates.
```
make refresh-users
```

## Remove All Users
You may need to repurpose your Kubernetes Cluster for something else or just need to clean up unused resources. The following command will remove all of the $NAMESPACE_PREFIX(n) (default: workshopuser) namespaces and purge the kubeconfig folder for your current $CLUSTER_NAME (default: cloud-workshop).
```
make remove-users
```

## Update roles
You may add additional examples that require additional user permissions. You can update the user role [here](./manifests/attendee/role.yaml), you can then apply the updated role with the following command
```
make update-user-role
```

## Stress Test
The purpose of stress test is to confirm that autoscaling is working correctly. It will deploy 2 Gateways per namespace representing the sizing guidelines at the start of this readme. If you are running locally, you do not need to run this.
```
make stress-test
```

## Adding new components
You can use the [Makefile](./Makefile) to add additional tasks.

### Structure
- Kubernetes Manifests go into [manifests](./manifests/)
- Scripts go into [utilities](./utilities/).

You **do not** need to follow this structure in your own repository.

**NOTE:** there are manifests that are not utilised in the Makefile, these have been left as starting points for common Layer7 Gateway integrations and other useful tools.

### Examples
There is also an [examples](./examples/) folder that contains a Google Cloud DNS example.

## Configure External Secrets (Exercise 9)
Exercise 9 in the [cloud workshop labs](https://github.com/Gazza7205/cloud-workshop-labs) uses a restricted GCP Service account to retrieve secrets from the Google Secret Manager. You have two options in your own environment.

1. Use a Kubernetes Secret and update exercise 9 in your own repository
```
kubectl create secret generic mysecret --from-literal database_username=dbuser --from-literal database_password=dbpass
```
2. Configure your own external secret
- This is provider dependent, you can use the resources in [exercise 9](https://github.com/Gazza7205/cloud-workshop-labs/tree/main/exercise9-resources) as a starting point. Refer to the [external secrets operator](https://external-secrets.io/latest/provider/aws-secrets-manager/) documentation for detailed examples.


## Cleanup

### Uninstall
If you used the Quickstart option and deployed Kind, all you will need to do is remove the Kind Cluster.
```
make uninstall-kind
```
If you used an existing Kubernetes Cluster
```
make uninstall
```

- If you deployed nginx

If you used kind
```
make uninstall-nginx-kind
```
If you used an existing Kubernetes Cluster
```
make uninstall-nginx
```

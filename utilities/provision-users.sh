#!/bin/bash
CLUSTER_NAME=$1
CURRENT_ATTENDEE_COUNT=$2
ATTENDEE_COUNT=$3
NAMESPACE_PREFIX=$4
SECRET_NAME=$5

mkdir -p $(pwd)/kubeconfig/$CLUSTER_NAME/admin/
mkdir -p $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/

controlPlane=$(kubectl config view --minify --flatten | grep server: | awk '{print $2}')
server=$(echo ${controlPlane})

if [[ -z $CURRENT_ATTENDEE_COUNT ]]; then
    START=1
    echo "---------------------------------------------------"
    echo "---------------------------------------------------"
    echo "provisioning admin service account"
    echo "---------------------------------------------------"
    echo "---------------------------------------------------"
    echo "***************************************************"
    kubectl apply -f $(pwd)/manifests/admin >/dev/null 2>&1
    sleep 3
    kubectl apply -f $(pwd)/manifests/admin/secret >/dev/null 2>&1

    ca=$(kubectl -n kube-system get secret/workshop-admin-token -o jsonpath='{.data.ca\.crt}')
    token=$(kubectl -n kube-system get secret/workshop-admin-token -o jsonpath='{.data.token}' | base64 --decode)
    echo "
apiVersion: v1
kind: Config
clusters:
- name: cloud-workshop
  cluster:
    certificate-authority-data: ${ca}
    server: ${server}
contexts:
- name: cloud-workshop
  context:
    cluster: cloud-workshop
    namespace: default
    user: workshop-admin
current-context: cloud-workshop
users:
- name: workshop-admin
  user:
    token: ${token}
" >$(pwd)/kubeconfig/$CLUSTER_NAME/admin/admin.kubeconfig

    echo "admin kubeconfig created"
    echo "***************************************************"
else
    START=$(($CURRENT_ATTENDEE_COUNT + 1))
fi

echo "---------------------------------------------------"
echo "---------------------------------------------------"
echo "provisioning attendee service accounts"
echo "---------------------------------------------------"
echo "---------------------------------------------------"
echo "***************************************************"

for i in $(seq $START $ATTENDEE_COUNT); do
    tmp=$(mktemp -d)
    kubectl create ns $NAMESPACE_PREFIX$i
    kubectl -n $NAMESPACE_PREFIX$i apply -f $(pwd)/manifests/attendee >/dev/null 2>&1
    sleep 3
    kubectl -n $NAMESPACE_PREFIX$i apply -f $(pwd)/manifests/attendee/secret >/dev/null 2>&1
    ca=$(kubectl -n $NAMESPACE_PREFIX$i get secret/$SECRET_NAME -o jsonpath='{.data.ca\.crt}')
    token=$(kubectl -n $NAMESPACE_PREFIX$i get secret/$SECRET_NAME -o jsonpath='{.data.token}' | base64 --decode)

    echo "
apiVersion: v1
kind: Config
clusters:
- name: cloud-workshop
  cluster:
    certificate-authority-data: ${ca}
    server: ${controlPlane}
contexts:
- name: cloud-workshop
  context:
    cluster: cloud-workshop
    namespace: $NAMESPACE_PREFIX$i
    user: $NAMESPACE_PREFIX$i
current-context: cloud-workshop
users:
- name: $NAMESPACE_PREFIX$i
  user:
    token: ${token}
" >$(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig

    rm -rf $tmp
    echo "$NAMESPACE_PREFIX$i created and configured"
    echo "testing $NAMESPACE_PREFIX$i kubeconfig"
    echo "***************************************************"
    test=$(kubectl -n $NAMESPACE_PREFIX$i get secret --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig 1>/dev/null)

    if [[ "${test}" == *"(Forbidden)"* ]]; then
        echo "WARNING: $NAMESPACE_PREFIX$i kubeconfig is invalid"
    else
        echo "INFO: $NAMESPACE_PREFIX$i kubeconfig is valid"
        echo "***************************************************"
    fi
done
echo "***************************************************"

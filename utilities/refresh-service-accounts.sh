#!/bin/bash
CLUSTER_NAME=$1
ATTENDEE_COUNT=$2
NAMESPACE_PREFIX=$3
SECRET_NAME=$4
RECREATE=$5

controlPlane=$(kubectl config view --minify --flatten | grep server: | awk '{print $2}')
server=$(echo ${controlPlane})

echo "---------------------------------------------------"
echo "purging admin config"
echo "---------------------------------------------------"
rm $(pwd)/kubeconfig/$CLUSTER_NAME/admin/admin.kubeconfig
kubectl delete -f $(pwd)/manifests/admin/secret
kubectl delete -f $(pwd)/manifests/admin

echo "---------------------------------------------------"
echo "purging user kubeconfigs"
echo "---------------------------------------------------"
rm $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/*.kubeconfig
echo "user kubeconfigs purged"
echo "***************************************************"

echo "---------------------------------------------------"
echo "removing user namespaces"
echo "---------------------------------------------------"
existingNamespaces=$(kubectl get ns | grep $NAMESPACE_PREFIX | awk '{ print $1 }')
while IFS= read -r namespace; do kubectl delete ns $namespace; done <<<"$existingNamespaces"
echo "user namespaces removed"
echo "***************************************************"

if [[ $RECREATE == "true" ]]; then
  echo "---------------------------------------------------"
  echo "recreating accounts"
  echo "---------------------------------------------------"
  $(pwd)/utilities/provision-users.sh ${CLUSTER_NAME} "" ${ATTENDEE_COUNT} ${NAMESPACE_PREFIX} ${SECRET_NAME}
fi
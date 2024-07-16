#!/bin/bash
ATTENDEE_COUNT=$1
CLUSTER_NAME=$2
NAMESPACE_PREFIX=$3

for i in $(seq 1 $ATTENDEE_COUNT); do
    echo "---------------------------------------------------"
    echo "creating resources in $NAMESPACE_PREFIX$i"
    echo "---------------------------------------------------"
    kubectl -n $NAMESPACE_PREFIX$i apply -f $(pwd)/deploy/rbac.yaml --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
    kubectl -n $NAMESPACE_PREFIX$i apply -f $(pwd)/deploy/operator.yaml --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
    kubectl -n $NAMESPACE_PREFIX$i apply -k $(pwd)/manifests/gateway/base --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
    sleep 10
    kubectl -n $NAMESPACE_PREFIX$i wait --for=condition=ready --timeout=600s pod -l app.kubernetes.io/name=layer7-operator --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
    kubectl -n $NAMESPACE_PREFIX$i apply -f $(pwd)/manifests/stress-test/workshopuser-gateway.yaml --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
done

echo "---------------------------------------------------"
echo "pausing for 80 seconds"
sleep 80
echo "---------------------------------------------------"
echo "continuing"


for i in $(seq 1 $ATTENDEE_COUNT); do
    echo "---------------------------------------------------"
    echo "inspecting resources in $NAMESPACE_PREFIX$i"
    echo "---------------------------------------------------"
    kubectl -n $NAMESPACE_PREFIX$i get pods --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
done

sleep 30
for i in $(seq 1 $ATTENDEE_COUNT); do
    echo "---------------------------------------------------"
    echo "inspecting resources in $NAMESPACE_PREFIX$i"
    echo "---------------------------------------------------"
    kubectl -n $NAMESPACE_PREFIX$i get pods --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
done

sleep 30
for i in $(seq 1 $ATTENDEE_COUNT); do
    echo "---------------------------------------------------"
    echo "inspecting resources in $NAMESPACE_PREFIX$i"
    echo "---------------------------------------------------"
    kubectl -n $NAMESPACE_PREFIX$i get pods --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
done

echo "---------------------------------------------------"
echo "pausing for 15 minutes"
sleep 900
echo "---------------------------------------------------"
echo "continuing"


for i in $(seq 1 $ATTENDEE_COUNT); do
    echo "---------------------------------------------------"
    echo "removing resources in $NAMESPACE_PREFIX$i"
    echo "---------------------------------------------------"
    kubectl -n $NAMESPACE_PREFIX$i delete -f $(pwd)/manifests/stress-test/workshopuser-gateway.yaml --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
    kubectl -n $NAMESPACE_PREFIX$i delete -f $(pwd)/deploy/operator.yaml --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
    kubectl -n $NAMESPACE_PREFIX$i delete -f $(pwd)/deploy/rbac.yaml --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig
    kubectl -n $NAMESPACE_PREFIX$i delete -k $(pwd)/manifests/gateway/base --kubeconfig $(pwd)/kubeconfig/$CLUSTER_NAME/attendees/$NAMESPACE_PREFIX$i.kubeconfig

done

echo "---------------------------------------------------"
echo "stress test complete"
echo "---------------------------------------------------"
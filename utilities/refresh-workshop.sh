#!/bin/bash
ATTENDEE_COUNT=$1
NAMESPACE_PREFIX=$2

removeResource() {
    echo "---------------------------------------------------"
    echo "removing $1"
    echo "---------------------------------------------------"
    objArr=($(kubectl -n $NAMESPACE_PREFIX$i get $1 -oname | cut -d "/" -f 2))
    for r in ${objArr[@]}; do
        if [[ "${r}" == "attendee-sa-token" ]] || [[ "${r}" == "kube-root-ca.crt" ]]; then
            echo "not removing $r"
        else
            kubectl -n $NAMESPACE_PREFIX$i delete $1 $r
        fi
    done
}
for i in $(seq 1 $ATTENDEE_COUNT); do
    echo "---------------------------------------------------"
    echo "Refreshing $NAMESPACE_PREFIX$i"
    echo "---------------------------------------------------"
    removeResource gateways
    removeResource repositories
    echo "---------------------------------------------------"
    echo "removing layer7 operator"
    echo "---------------------------------------------------"
    kubectl -n $NAMESPACE_PREFIX$i delete -f $(pwd)/deploy/operator.yaml
    kubectl -n $NAMESPACE_PREFIX$i delete -f $(pwd)/deploy/rbac.yaml
    echo "---------------------------------------------------"
    echo "removing helm charts"
    echo "---------------------------------------------------"
    charts=($(helm list -n $NAMESPACE_PREFIX$i --short))
    for c in ${charts[@]}; do
        helm uninstall $c -n $NAMESPACE_PREFIX$i
    done

    removeResource deployments
    removeResource statefulsets
    removeResource pvc
    removeResource configmaps
    removeResource secrets
    removeResource secretstore
    removeResource opentelemetrycollectors
    removeResource instrumentations
    removeResource jobs
        kubectl -n $userNamespaceSeed$i delete externalsecret.external-secrets.io/database-credentials
    echo "---------------------------------------------------"
    echo "removing service accounts"
    echo "---------------------------------------------------"
    kubectl -n $NAMESPACE_PREFIX$i delete sa ssg-gateway
    kubectl -n $NAMESPACE_PREFIX$i delete sa ssg
    sleep 1
done

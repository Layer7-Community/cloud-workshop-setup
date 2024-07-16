#!/bin/bash
ATTENDEE_COUNT=$1
NAMESPACE_PREFIX=$2

for i in $(seq 1 $ATTENDEE_COUNT); do
    echo "Updating $NAMESPACE_PREFIX$i"
    kubectl -n $NAMESPACE_PREFIX$i apply -f $(pwd)/manifests/attendee/role.yaml
done
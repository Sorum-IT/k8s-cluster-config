#!/bin/bash

function install_vault(){
    GITHUB_TOKEN="$1"
    if [[ "$GITHUB_TOKEN" == "" ]]
    then
        echo "Missing argument: GITHUB_TOKEN"
        return 1
    fi;
    helm upgrade --install k8s-cluster-config \
    --repo https://ghcr.io/sorum-it/k8s-cluster-config \
    --username leevi978 \
    --password "$GITHUB_TOKEN" \
    k8s-cluster-config

}

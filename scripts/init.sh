#!/bin/bash
function init_microk8s(){
    microk8s enable ingress
    microk8s enable dns
    microk8s enable host-access
    microk8s enable metallb:10.64.140.43-10.64.140.49
}

function init_helm(){
    microk8s helm repo add sorum-it https://sorum-it.github.io/k8s-cluster-config
    microk8s helm repo update
}

function install_ingress(){
    microk8s helm upgrade -i sit-ingress sorum-it/sit-ingress
}

function install_vault(){
    microk8s helm upgrade -i sit-vault sorum-it/sit-vault -n sit-vault --create-namespace
    microk8s kubectl expose service sit-vault-ui --type=NodePort --name=sit-vault-ui -n sit-vault
}

function init_all(){
    init_microk8s
    init_helm
    install_ingress
    install_vault
}

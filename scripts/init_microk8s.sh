#!/bin/bash

function setup_microk8s(){
    microk8s install
    microk8s status --wait-ready
    microk8s disable ha-cluster --force
    microk8s enable ingress
    microk8s enable storage
    microk8s enable metallb
}

function setup_microk8s_addons(){
    microk8s enable rbac
    microk8s enable dns
    microk8s enable dashboard
    microk8s enable prometheus
    microk8s enable metrics-server
}

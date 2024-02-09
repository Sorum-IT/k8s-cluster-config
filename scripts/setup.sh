#!/bin/bash

function argo_setup(){
    GIT_USERNAME="$1"
    TOKEN="$2"
    if [[ "$GIT_USERNAME" == "" ]]
    then
        echo "Missing argument: GIT_USERNAME"
        return 1
    fi
    if [[ "$TOKEN" == "" ]]
    then
        echo "Missing argument: TOKEN"
        return 1
    fi
    echo "Creating argocd repo"
    argocd repo add https://github.com/Sorum-IT/k8s-applications.git --username "$GIT_USERNAME" --password "$TOKEN" --upsert

    echo "Creating argocd apps"
    argocd app create apps \
    --repo https://github.com/Sorum-IT/k8s-applications.git \
    --path apps --dest-server https://kubernetes.default.svc \
    --dest-namespace argo-cd \
    --helm-pass-credentials
    
    echo "Synching argocd apps"
    argocd app sync apps
}

function setup_git_ssh(){
    echo "Creating ssh key for git"
    EMAIL="$1"
    if [[ "$EMAIL" == "" ]]
    then
        echo "Missing argument: EMAIL"
        return 1
    fi
    mkdir -p temp/ssh
    ssh-keygen -t ed25519 -C "$EMAIL" -f ./temp/ssh/key
    open https://github.com/settings/ssh/new
    echo -e "\nCopy the following ssh public key and add it to your github account.\n"
    cat temp/ssh/key.pub
}

function test_shit(){
    echo "Creating ssh key pair"
    mkdir -p temp/ssh
    ssh-keygen -t ed25519 -C "$EMAIL" -f ./temp/ssh/key
    echo -e "\nCopy the following ssh public key and add it to your git account."
    echo -e "For Github, see https://github.com/settings/ssh/new\n\n"
    cat temp/ssh/key.pub
    rm -r temp/ssh
    echo -e "\n\nPress any key to continue..."
    read -s -n 1
    echo -e "\n\nContinuing setup\n"
}

function configure_vault(){
    kubectl exec --stdin=true --tty=true vault-0 -n vault -- /bin/sh \
    -c "vault auth enable -path auth-mount kubernetes \
    && vault write auth/auth-mount/config kubernetes_host=\"https://\$KUBERNETES_PORT_443_TCP_ADDR:443\" \
    && vault secrets enable -path=kvv2 kv-v2 && \
    vault policy write dev - <<EOF \
    path "kvv2/*" { \
    capabilities = ["read"] \
    } \
    EOF && \
    vault write auth/auth-mount/role/role1 \
    bound_service_account_names=default \
    bound_service_account_namespaces=app \
    policies=dev \
    audience=vault \
    ttl=24h \
    && vault kv put kvv2/webapp/config username="static-user" password="static-password""
}

function kube_setup(){
    kubectl create ns argo-cd
    kubectl config set-context --current --namespace=argo-cd
}

function setup_chart(){
    CHART="$1"
    microk8s helm dep update "charts/$CHART"
    microk8s helm dep build "charts/$CHART"
    microk8s helm install "$CHART" "charts/$CHART" --namespace "$CHART" --create-namespace --wait --wait-for-jobs
}

function teardown_chart(){
    CHART="$1"
    microk8s helm uninstall "$CHART" -n "$CHART"
    microk8s kubectl delete all --all -n "$CHART"
    microk8s kubectl delete ns "$CHART"
}

function helm_setup() {
    helm repo add argo-cd https://argoproj.github.io/argo-helm
    helm repo add empathyco https://empathyco.github.io/helm-charts/
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    setup_chart "argo-cd"
}

function create_gitops_repo_secret() {
    echo "Creating secret for gitops repo"
    GIT_USERNAME="$1"
    TOKEN="$2"
    if [[ "$GIT_USERNAME" == "" ]]
    then
        echo "Missing argument: GIT_USERNAME"
        return 1
    fi
    if [[ "$TOKEN" == "" ]]
    then
        echo "Missing argument: TOKEN"
        return 1
    fi
    kubectl create secret generic git-secret --type=stringData \
    --from-literal=type=git \
    --from-literal=url=https://github.com/Sorum-IT/k8s-applications \
    --from-literal=username="$GIT_USERNAME" \
    --from-literal=password="$TOKEN" \
    -n argo-cd
    
    kubectl label secret git-secret -n argo-cd "argocd.argoproj.io/secret-type=repository"

    kubectl create secret docker-registry ghcr \
    --docker-server="https://ghcr.io" \
    --docker-username="$GIT_USERNAME" \
    --docker-password="$TOKEN" \
    --docker-email="levi.sorum@gmail.com" \
    -n argo-cd
}

function setup(){
    GIT_USERNAME="$1"
    TOKEN="$2"
    if [[ "$GIT_USERNAME" == "" ]]
    then
        echo "Missing argument: GIT_USERNAME"
        return 1
    fi
    if [[ "$TOKEN" == "" ]]
    then
        echo "Missing argument: TOKEN"
        return 1
    fi
    kube_setup || return 1
    create_gitops_repo_secret "$GIT_USERNAME" "$TOKEN" || return 1
    helm_setup || return 1
    argo_setup "$GIT_USERNAME" "$TOKEN"
}

function teardown(){
    helm uninstall argo-cd
    kubectl delete all --all argo-cd
    kubectl delete all --all -n transmarkedet-backend
    kubectl delete all --all -n argocd-image-updater
    kubectl delete ns argo-cd transmarkedet-backend argocd-image-udpater
}

function restart(){
    minikube delete
    minikube start
}
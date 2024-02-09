#!/bin/bash

function install_snapd(){
    sudo apt update
    sudo apt install snapd
    sudo reboot
}

function install_microk8s(){
    sudo snap install core
    sudo snap install microk8s --classic
}

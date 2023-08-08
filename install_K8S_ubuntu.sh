#!/bin/bash
# Author m0zs0y
# Date 08/2023
# K8S Cluster install Script with containerd runtime

# ---- Vars ------
#podnetworkIP=$1
podnetworkIP="10.244.0.0"
getDate=`date +"%Y-%m-%d %T"`
logFileName=/tmp/k8sinstallerlog_$(date +"%d-%m-%Y").log

# Bold-Color
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White


function rootCheck() {
	if [ "${EUID}" -ne 0 ]; then
		echo -e "${BWhite} YoU MusT BecomE RooT or sudo permissions !"
		exit 1
	fi
}

function createConf() {
cat << EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
}

function modprobe() {
sudo modprobe overlay | tee -a $logFileName
sudo modprobe br_netfilter | tee -a $logFileName
echo " [ + ] Added Kernel Modules"
}

function swapOff() {
swapoff -a | tee -a $logFileName
sudo sed -i  '/ swap / s/^\(.*\ )$/#\1/g' /etc/fstab | tee -a $logFileName
echo " [ + ] Swap Off "
}

function createSysctl() {
cat << EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward =1
net.bridge.bridge-nf-call-ip6tables =1
EOF
sudo sysctl --system  | tee -a $logFileName
echo " [ + ] Created conf "
}


function installPackage() {
sudo apt install curl gnupg2 software-properties-common apt-transport-https ca-certificates -y | tee -a $logFileName
#curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - | tee -a $logFileName
#sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee -a $logFileName
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - | tee -a $logFileName
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list | tee -a $logFileName
sudo apt-get update | tee -a $logFileName
sudo apt -y install containerd vim git curl wget kubelet kubeadm kubectl  | tee -a $logFileName
sudo apt-mark hold kubelet kubeadm kubectl | tee -a $logFileName
echo " [ + ]  Packages Installed" 
}

function installContainerd() {
mkdir -p /etc/containerd  | tee -a $logFileName
sudo containerd config default | sudo tee -a /etc/containerd/config.toml
systemctl restart containerd | tee -a $logFileName
sudo systemctl enable containerd | tee -a $logFileName
echo " [ + ] Installed containerd Runtime"
}


function initMasterNode() {
    ps_out=`ps -ef | grep containerd | grep -v 'grep' | grep -v $0`
    result=$(echo $ps_out | grep "containerd")
        if [[ "$result" != "" ]];then
            echo " [ + ] Containerd is runnnig."
            echo " [ + ] initializing K8S MasterNode in Cluster"
            sudo kubeadm config images pull | tee -a $logFileName
            sudo kubeadm init --pod-network-cidr=$podnetworkIP/16 | tee -a $logFileName
            mkdir -p $HOME/.kube
            sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config | tee -a $logFileName
            sudo chown $(id -u):$(id -g) $HOME/.kube/config | tee -a $logFileName
            echo " [ + ] Create Config file for user" 
        else
            echo " [ ! ] Containerd is not Running"
        fi
}

rootCheck
createConf
modprobe
swapOff
createSysctl
installContainerd
installPackage
initMasterNode
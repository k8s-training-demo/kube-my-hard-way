#!/bin/bash
# Partie 1 - Pré-requis et installation des composants Kubernetes
# À exécuter sur TOUS les nœuds (master + workers)
# Compatible CentOS Stream 10

set -e

echo "=== Installation des pré-requis Kubernetes sur CentOS 10 ==="

# Désactiver le swap (requis par Kubernetes)
# POURQUOI: Kubernetes doit connaître la RAM réelle disponible pour le scheduling.
#           Le swap introduit des latences imprévisibles et fausse les limites mémoire des pods.
echo "Désactivation du swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Désactiver SELinux (mode permissive pour le TD)
# POURQUOI: Simplifie le troubleshooting. En production, utiliser SELinux enforcing
#           avec les policies container-selinux appropriées.
echo "Configuration de SELinux en mode permissive..."
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Charger les modules kernel nécessaires
# POURQUOI:
#   - overlay: Système de fichiers pour les layers des containers (utilisé par containerd)
#   - br_netfilter: Permet à iptables/nftables de voir le trafic bridgé (nécessaire pour CNI)
echo "Configuration des modules kernel..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configuration sysctl pour le réseau
# POURQUOI:
#   - bridge-nf-call-iptables: Le trafic bridgé passe par iptables (requis par kube-proxy)
#   - ip_forward: Active le routage IP entre interfaces (requis par CNI pour pod-to-pod)
echo "Configuration sysctl..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Configurer le firewall (ports Kubernetes)
# POURQUOI: Kubernetes nécessite plusieurs ports pour la communication entre composants
echo "Configuration du firewall..."
# Détecter si c'est un master ou un worker (basé sur le hostname ou argument)
if [[ "$1" == "master" ]] || [[ "$(hostname)" == *"master"* ]] || [[ "$(hostname)" == *"control"* ]]; then
    echo "  Configuration des ports pour le Control Plane..."
    sudo firewall-cmd --permanent --add-port=6443/tcp    # API Server
    sudo firewall-cmd --permanent --add-port=2379-2380/tcp # etcd
    sudo firewall-cmd --permanent --add-port=10250/tcp   # kubelet API
    sudo firewall-cmd --permanent --add-port=10259/tcp   # kube-scheduler
    sudo firewall-cmd --permanent --add-port=10257/tcp   # kube-controller-manager
else
    echo "  Configuration des ports pour Worker..."
    sudo firewall-cmd --permanent --add-port=10250/tcp   # kubelet API
    sudo firewall-cmd --permanent --add-port=10256/tcp   # kube-proxy
    sudo firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort Services
fi
sudo firewall-cmd --reload

# Installation de containerd depuis le repo Docker
# POURQUOI: containerd.io du repo Docker est plus récent et mieux maintenu que celui des repos CentOS
echo "Ajout du repo Docker pour containerd..."
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

echo "Installation de containerd..."
sudo dnf install -y containerd.io

# Configuration de containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Activer systemd cgroup driver (OBLIGATOIRE pour kubeadm)
# POURQUOI: CentOS 10 utilise systemd comme init system et gestionnaire de cgroups v2.
#           Le kubelet utilise aussi systemd cgroup driver par défaut depuis K8s 1.22+.
#           Si containerd et kubelet utilisent des drivers différents (cgroupfs vs systemd):
#           - Conflits de gestion mémoire
#           - Pods qui ne démarrent pas ou crashent
#           - Métriques incorrectes
#           - Comportement OOM imprévisible
echo "Activation du driver cgroup systemd pour containerd..."
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# Installation des paquets Kubernetes
echo "Configuration du repo Kubernetes..."
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

echo "Installation de kubeadm, kubelet, kubectl..."
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Verrouiller les versions pour éviter les mises à jour accidentelles
# POURQUOI: Une mise à jour non planifiée de kubelet peut casser le cluster.
#           L'upgrade doit être fait de manière contrôlée via kubeadm upgrade.
echo "Verrouillage des versions..."
sudo dnf install -y 'dnf-command(versionlock)' 2>/dev/null || true
sudo dnf versionlock add kubelet kubeadm kubectl 2>/dev/null || echo "Note: versionlock non disponible, pensez à surveiller les mises à jour"

# Activer kubelet
sudo systemctl enable kubelet

echo ""
echo "=== Vérifications ==="
echo "Swap désactivé:      $(free -h | grep Swap | awk '{print $2}') (doit être 0)"
echo "SELinux:             $(getenforce)"
echo "Modules kernel:      $(lsmod | grep -E 'overlay|br_netfilter' | wc -l)/2 chargés"
echo "containerd:          $(systemctl is-active containerd)"
echo "SystemdCgroup:       $(grep 'SystemdCgroup = true' /etc/containerd/config.toml > /dev/null && echo 'activé' || echo 'ATTENTION: non activé!')"
echo ""
echo "✓ Pré-requis installés avec succès!"
echo "Version kubeadm: $(kubeadm version -o short)"
echo "Version kubelet: $(kubelet --version)"
echo "Version kubectl: $(kubectl version --client -o yaml | grep gitVersion)"

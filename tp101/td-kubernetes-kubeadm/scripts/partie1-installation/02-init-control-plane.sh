#!/bin/bash
# Partie 1 - Initialisation du control plane
# À exécuter UNIQUEMENT sur le nœud MASTER

set -e

echo "=== Initialisation du Control Plane Kubernetes ==="

# Définir le réseau pod (utilisé par Flannel)
POD_NETWORK_CIDR="10.244.0.0/16"

echo "Initialisation de kubeadm avec le réseau pod $POD_NETWORK_CIDR..."
sudo kubeadm init --pod-network-cidr=$POD_NETWORK_CIDR --apiserver-advertise-address=$(hostname -I | awk '{print $1}')

echo ""
echo "Configuration de kubectl pour l'utilisateur courant..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo ""
echo "✓ Control plane initialisé avec succès!"
echo ""
echo "Pour joindre des workers au cluster, récupérez la commande 'kubeadm join' ci-dessus"
echo "ou régénérez-la avec: kubeadm token create --print-join-command"
echo ""
echo "Statut des composants du control plane:"
kubectl get nodes
kubectl get pods -n kube-system

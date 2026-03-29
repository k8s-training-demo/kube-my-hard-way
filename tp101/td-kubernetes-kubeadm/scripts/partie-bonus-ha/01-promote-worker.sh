#!/bin/bash
# Partie Bonus — HA Control Plane
# Script 01 : Promotion d'un worker en control plane
# À exécuter sur chaque WORKER
#
# Prérequis : /tmp/ha-join-info.sh doit être présent (copié depuis le master)
#   scp root@<master-ip>:/tmp/ha-join-info.sh /tmp/

set -e

echo "=== Bonus HA — Promotion en control plane ==="
echo ""

# Vérifier que le fichier de jonction est présent
if [[ ! -f /tmp/ha-join-info.sh ]]; then
    echo "❌ Fichier /tmp/ha-join-info.sh introuvable."
    echo "   Copier depuis le master :"
    echo "   scp root@<master-ip>:/tmp/ha-join-info.sh /tmp/"
    exit 1
fi

# Charger les infos de jonction
source /tmp/ha-join-info.sh
echo "  Master IP        : $MASTER_IP"
echo "  Token            : $JOIN_TOKEN"
echo "  Discovery hash   : $DISCOVERY_HASH"
echo "  Certificate key  : ${CERTIFICATE_KEY:0:12}... (tronqué)"
echo ""

# Étape 1 — Reset du worker
echo "=== Étape 1 : Reset du worker ==="
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F || true
sudo ipvsadm --clear 2>/dev/null || true

# Étape 2 — Rejoindre en tant que control plane
echo ""
echo "=== Étape 2 : Jonction en tant que control plane ==="
sudo kubeadm join "${MASTER_IP}:6443" \
    --token "${JOIN_TOKEN}" \
    --discovery-token-ca-cert-hash "${DISCOVERY_HASH}" \
    --control-plane \
    --certificate-key "${CERTIFICATE_KEY}"

# Étape 3 — Configurer kubectl sur ce nœud
echo ""
echo "=== Étape 3 : Configuration de kubectl ==="
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config

echo ""
echo "=== ✓ $(hostname) promu en control plane ==="
echo ""
kubectl get nodes -o wide

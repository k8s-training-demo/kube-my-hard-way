#!/bin/bash
# Partie Bonus — HA Control Plane
# Script 00 : Réinitialisation du master avec --control-plane-endpoint
# À exécuter sur le MASTER uniquement
#
# Ce script :
#   1. Draine les workers
#   2. Réinitialise le master
#   3. Relance kubeadm init avec --control-plane-endpoint + --upload-certs
#   4. Réinstalle Calico (mode VXLAN)
#   5. Génère le fichier de jonction pour les workers

set -e

CALICO_VERSION="v3.26.1"

echo "=== Bonus HA — Réinitialisation du master avec endpoint HA ==="
echo ""
echo "⚠️  Ce script va RÉINITIALISER le cluster entier."
echo "    À utiliser uniquement en fin de TD, avant suppression des VMs."
echo ""
read -p "Confirmer la réinitialisation ? (oui/non) : " CONFIRM
if [[ "$CONFIRM" != "oui" ]]; then
    echo "Annulé."
    exit 0
fi

# Détecter l'IP principale du master
MASTER_IP=$(hostname -I | awk '{print $1}')
ENDPOINT="${MASTER_IP}:6443"
echo "IP master détectée : $MASTER_IP"
echo "Endpoint HA        : $ENDPOINT"
echo ""

# Étape 1 — Drainer les workers depuis le master avant reset
echo "=== Étape 1 : Drain des workers ==="
WORKERS=$(kubectl get nodes --no-headers | grep -v 'control-plane\|master' | awk '{print $1}') || true
if [[ -n "$WORKERS" ]]; then
    for NODE in $WORKERS; do
        echo "  Drain de $NODE..."
        kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --force --timeout=60s || true
    done
else
    echo "  Aucun worker trouvé (ou kubectl non disponible) — on continue."
fi

# Étape 2 — Reset du master
echo ""
echo "=== Étape 2 : Reset du master ==="
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes /var/lib/etcd ~/.kube
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F || true
sudo ipvsadm --clear 2>/dev/null || true

# Étape 3 — kubeadm init avec HA endpoint
echo ""
echo "=== Étape 3 : kubeadm init avec --control-plane-endpoint ==="
echo "  Endpoint : $ENDPOINT"
sudo kubeadm init \
    --control-plane-endpoint="${ENDPOINT}" \
    --upload-certs \
    --pod-network-cidr=10.244.0.0/16 \
    | tee /tmp/kubeadm-init.log

# Configurer kubectl
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config

# Étape 4 — Extraire les infos de jonction
echo ""
echo "=== Étape 4 : Extraction des infos de jonction ==="

JOIN_TOKEN=$(kubeadm token list -o json | python3 -c "
import json,sys
items = json.load(sys.stdin)['items']
for i in items:
    if 'authentication,signing' in ','.join(i.get('usages',[])):
        print(i['token']); break
" 2>/dev/null || kubeadm token create)

DISCOVERY_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
    | openssl rsa -pubin -outform der 2>/dev/null \
    | sha256sum | awk '{print "sha256:"$1}')

CERTIFICATE_KEY=$(grep "certificate-key" /tmp/kubeadm-init.log | tail -1 | awk '{print $NF}')

# Sauvegarder pour les workers
cat > /tmp/ha-join-info.sh <<EOF
# Généré par 00-reinit-master.sh — à copier sur chaque worker
MASTER_IP="${MASTER_IP}"
JOIN_TOKEN="${JOIN_TOKEN}"
DISCOVERY_HASH="${DISCOVERY_HASH}"
CERTIFICATE_KEY="${CERTIFICATE_KEY}"
EOF

echo "  Infos sauvegardées dans /tmp/ha-join-info.sh"
echo ""
echo "  ┌─────────────────────────────────────────────────────────────┐"
echo "  │  Copier ce fichier sur chaque worker avant d'exécuter       │"
echo "  │  01-promote-worker.sh :                                     │"
echo "  │                                                             │"
echo "  │  scp /tmp/ha-join-info.sh root@<worker-ip>:/tmp/           │"
echo "  └─────────────────────────────────────────────────────────────┘"

# Étape 5 — Installer Calico (mode VXLAN)
echo ""
echo "=== Étape 5 : Installation de Calico (VXLAN) ==="
curl -sL "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" \
    -o /tmp/calico.yaml

# Patch CIDR
sed -i "s|192.168.0.0/16|10.244.0.0/16|g" /tmp/calico.yaml

# Forcer VXLAN (IPIP bloqué sur Exoscale/DO)
sed -i 's/value: "Always"$/value: "Never"/' /tmp/calico.yaml
python3 - <<'PYEOF'
import re
with open('/tmp/calico.yaml', 'r') as f:
    content = f.read()
if 'CALICO_IPV4POOL_VXLAN' not in content:
    content = re.sub(
        r'(name: CALICO_IPV4POOL_IPIP\n\s+value: "Never")',
        r'\1\n            - name: CALICO_IPV4POOL_VXLAN\n              value: "Always"',
        content
    )
    with open('/tmp/calico.yaml', 'w') as f:
        f.write(content)
    print("  ✓ VXLAN activé")
else:
    print("  ✓ VXLAN déjà configuré")
PYEOF

kubectl apply -f /tmp/calico.yaml

echo "  Attente de Calico sur le master..."
MASTER_NODE=$(kubectl get nodes --no-headers | awk '{print $1}' | head -1)
kubectl wait --for=condition=ready pod \
    -l k8s-app=calico-node \
    -n kube-system \
    --field-selector "spec.nodeName=${MASTER_NODE}" \
    --timeout=180s

echo ""
echo "=== ✓ Master réinitialisé avec succès ==="
echo ""
echo "Étapes suivantes :"
echo "  1. scp /tmp/ha-join-info.sh root@<worker1-ip>:/tmp/"
echo "  2. scp /tmp/ha-join-info.sh root@<worker2-ip>:/tmp/"
echo "  3. Sur chaque worker : kubeadm reset -f, puis ./01-promote-worker.sh"
echo ""
kubectl get nodes -o wide

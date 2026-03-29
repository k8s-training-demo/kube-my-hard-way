#!/bin/bash
# Partie 6 - Restauration etcd depuis un snapshot
# À exécuter sur le nœud MASTER uniquement
# ⚠️  OPÉRATION DESTRUCTIVE — pour TD ou cluster cassé uniquement
# Usage: sudo ./04-restore-etcd.sh <chemin-snapshot.db>

set -e

export PATH="/usr/local/bin:$PATH"

SNAPSHOT_FILE="$1"

if [ -z "$SNAPSHOT_FILE" ]; then
    echo "Usage: sudo $0 <chemin-snapshot.db>"
    echo "Exemple: sudo $0 /var/backup/etcd/snapshot-20250101-1200.db"
    false
fi

if [ ! -f "$SNAPSHOT_FILE" ]; then
    echo "❌ Snapshot introuvable: $SNAPSHOT_FILE"
    false
fi

if [ "$EUID" -ne 0 ]; then
    echo "❌ Ce script doit être exécuté avec sudo"
    false
fi

MASTER_NAME=$(hostname)
MASTER_IP=$(kubectl get node "$MASTER_NAME" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || hostname -I | awk '{print $1}')
RESTORE_DIR="/var/lib/etcd-restored"

echo "=== Restauration etcd depuis snapshot ==="
echo ""
echo "⚠️  ATTENTION: Cette opération revert l'état complet du cluster"
echo "   Tout ce qui a été créé APRÈS le snapshot sera PERDU"
echo ""
echo "   Snapshot   : $SNAPSHOT_FILE"
echo "   Master     : $MASTER_NAME ($MASTER_IP)"
echo "   Restore dir: $RESTORE_DIR"
echo ""
read -rp "   Tapez 'CONFIRMER' pour continuer : " CONFIRM
if [ "$CONFIRM" != "CONFIRMER" ]; then
    echo "Annulé."
    exit 0
fi

echo ""
echo "1. Vérification de l'intégrité du snapshot:"
# etcd 3.6 : snapshot status et restore sont dans etcdutl (pas etcdctl)
etcdutl snapshot status "$SNAPSHOT_FILE" --write-out=table
echo ""

echo "2. Arrêt de l'API Server et d'etcd (déplacement des manifests statiques):"
mv /etc/kubernetes/manifests/etcd.yaml /tmp/etcd.yaml.bak
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml.bak
sleep 5
echo "   ✓ Pods statiques arrêtés"

echo ""
echo "3. Restauration du snapshot:"
etcdutl snapshot restore "$SNAPSHOT_FILE" \
    --data-dir="$RESTORE_DIR" \
    --name="$MASTER_NAME" \
    --initial-cluster="${MASTER_NAME}=https://${MASTER_IP}:2380" \
    --initial-advertise-peer-urls="https://${MASTER_IP}:2380"

echo "   ✓ Snapshot restauré dans $RESTORE_DIR"

echo ""
echo "4. Mise à jour du data-dir dans le manifest etcd:"
sed -i "s|path: /var/lib/etcd|path: $RESTORE_DIR|g" /tmp/etcd.yaml.bak
# Mettre à jour aussi la volumeMount
sed -i "s|mountPath: /var/lib/etcd|mountPath: $RESTORE_DIR|g" /tmp/etcd.yaml.bak
echo "   ✓ Manifest mis à jour"

echo ""
echo "5. Remise en place des manifests (etcd puis API Server):"
mv /tmp/etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml
sleep 10
echo "   etcd redémarré — attente 10s..."
mv /tmp/kube-apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml

echo ""
echo "6. Attente de la disponibilité de l'API Server..."
for i in {1..12}; do
    if kubectl get nodes &>/dev/null; then
        echo "   ✓ API Server disponible (tentative $i)"
        break
    fi
    echo "   Tentative $i/12 — attente 10s..."
    sleep 10
done

echo ""
echo "7. Vérification post-restauration:"
etcdctl \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    --endpoints=https://127.0.0.1:2379 \
    endpoint health

kubectl get nodes

echo ""
echo "8. Vérification : les objets créés après le backup ont disparu :"
echo ""
echo "   Namespaces présents (etcd-demo-* doit être ABSENT) :"
kubectl get namespaces | grep -v "etcd-demo-" || true
echo ""
if kubectl get namespaces | grep -q "etcd-demo-"; then
    echo "   ⚠️  Des namespaces etcd-demo-* sont encore visibles — attendez quelques secondes et relancez"
else
    echo "   ✓ Aucun namespace etcd-demo-* — l'état pré-backup est restauré"
fi

echo ""
echo "✓ Restauration terminée"
echo ""
echo "⚠️  APRÈS RESTAURATION:"
echo "- Redémarrez kubelet sur tous les nœuds : sudo systemctl restart kubelet"
echo "- Vérifiez que tous les pods sont Running : kubectl get pods -A"
echo "- Les objets créés après le snapshot sont définitivement perdus"

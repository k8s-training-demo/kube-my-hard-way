#!/bin/bash
# Partie 6 - Créer des objets APRÈS le backup pour démontrer la restauration
# À exécuter sur le nœud MASTER — après 03-backup-etcd.sh, avant 04-restore-etcd.sh

set -e

export PATH="/usr/local/bin:$PATH"
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

DEMO_NS="etcd-demo-$(date +%H%M%S)"

echo "=== Création d'objets POST-backup (seront perdus après restauration) ==="
echo ""
echo "Namespace de démo : $DEMO_NS"
echo ""

echo "1. Namespace :"
kubectl create namespace "$DEMO_NS"
echo "   ✓ namespace/$DEMO_NS créé"

echo ""
echo "2. ConfigMap avec une valeur mémorable :"
kubectl create configmap demo-config \
    --from-literal=message="CE CONFIGMAP DOIT DISPARAITRE APRES RESTORE" \
    --from-literal=created-at="$(date '+%Y-%m-%d %H:%M:%S')" \
    -n "$DEMO_NS"
echo "   ✓ configmap/demo-config créé"

echo ""
echo "3. Deployment nginx :"
kubectl create deployment demo-nginx --image=nginx:alpine --replicas=2 -n "$DEMO_NS"
echo "   ✓ deployment/demo-nginx créé"

echo ""
echo "4. État actuel du cluster (objets créés APRÈS le snapshot) :"
kubectl get namespace "$DEMO_NS"
kubectl get all,configmap -n "$DEMO_NS"

echo ""
TOTAL_KEYS=$(etcdctl get / --prefix --keys-only 2>/dev/null | grep -c . || true)
echo "   Clés etcd actuelles : $TOTAL_KEYS"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  Ces objets EXISTENT dans le cluster maintenant.                    ║"
echo "║                                                                      ║"
echo "║  Après la restauration (04-restore-etcd.sh) :                       ║"
echo "║   - namespace '$DEMO_NS' → DISPARU                 ║"
echo "║   - configmap/demo-config                → DISPARU                  ║"
echo "║   - deployment/demo-nginx                → DISPARU                  ║"
echo "║                                                                      ║"
echo "║  C'est la preuve que etcd est bien revenu à l'état du snapshot.     ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Nom du namespace à vérifier après restore : $DEMO_NS"
echo "(notez-le ou copiez-le)"
echo ""
read -rp "   ↵  Prêt ? Lancez maintenant : sudo ./04-restore-etcd.sh <snapshot.db>. Appuyez sur Entrée..."

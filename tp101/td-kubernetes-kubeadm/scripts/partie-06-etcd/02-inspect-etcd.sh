#!/bin/bash
# Partie 6 - Inspection du cluster etcd et des données Kubernetes
# À exécuter sur le nœud MASTER uniquement

set -e

export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

echo "=== Inspection d'etcd ==="
echo ""

echo "1. Santé du cluster etcd:"
etcdctl endpoint health
echo ""

echo "2. Statut détaillé (leader, revision, taille DB):"
etcdctl endpoint status --write-out=table
echo ""
read -rp "   ↵  Notez la taille de la DB et si ce nœud est leader. Appuyez sur Entrée..."

echo ""
echo "3. Liste des membres etcd:"
etcdctl member list --write-out=table
echo ""
read -rp "   ↵  Avec kubeadm stacked : 1 seul membre. Appuyez sur Entrée..."

echo ""
echo "4. Nombre total de clés dans etcd:"
etcdctl get / --prefix --keys-only | grep -c . || true
echo ""

echo "5. Toutes les clés Kubernetes (premiers 30):"
etcdctl get / --prefix --keys-only | head -30
echo ""
read -rp "   ↵  Observez la structure /registry/<resource>/<namespace>/<name>. Appuyez sur Entrée..."

echo ""
echo "6. Lister les namespaces (raw etcd):"
etcdctl get /registry/namespaces --prefix --keys-only
echo ""

echo "7. Lister les pods dans le namespace kube-system (clés):"
etcdctl get /registry/pods/kube-system --prefix --keys-only
echo ""
read -rp "   ↵  Chaque pod stocké comme /registry/pods/<ns>/<name>. Appuyez sur Entrée..."

echo ""
echo "8. Lire un pod spécifique (données brutes protobuf):"
POD=$(etcdctl get /registry/pods/kube-system --prefix --keys-only | head -1)
if [ -n "$POD" ]; then
    echo "   Clé: $POD"
    echo "   (données binaires protobuf — l'API Server les désérialise pour kubectl)"
    etcdctl get "$POD" | strings | grep -E '"kind"|"name"|"namespace"' | head -5 || true
fi
echo ""
read -rp "   ↵  Ce que kubectl retourne = désérialisation de ces données. Appuyez sur Entrée..."

echo ""
echo "9. Secrets (clés seulement — contenu chiffré at rest):"
etcdctl get /registry/secrets --prefix --keys-only | head -10
echo ""

echo "✓ Inspection terminée"
echo ""
echo "POINTS CLÉS:"
echo "- Structure : /registry/<resource>/<namespace>/<name>"
echo "- Format : protobuf binaire (pas JSON lisible directement)"
echo "- Taille typique : 5-20 MB pour un cluster de TD"
echo "- Secrets : chiffrés si EncryptionConfiguration activée (pas par défaut avec kubeadm)"

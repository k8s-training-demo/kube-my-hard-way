#!/bin/bash
# Partie 4 - Drain progressif des nœuds pour migration CNI
# À exécuter sur le nœud MASTER

set -e

echo "=== Drain progressif des nœuds ==="
echo ""

# Lister tous les nœuds (workers uniquement)
WORKERS=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name')

echo "Nœuds workers à drainer:"
echo "$WORKERS"
echo ""

# Fonction pour drainer un nœud
drain_node() {
    local node=$1
    echo "----------------------------------------"
    echo "Drain du nœud: $node"
    echo "----------------------------------------"

    echo "1. État actuel:"
    kubectl get pods -o wide --all-namespaces --field-selector spec.nodeName=$node | grep -v kube-system || echo "   Aucun pod utilisateur"
    echo ""

    echo "2. Drain en cours..."
    # --ignore-daemonsets: Les DaemonSets ne peuvent pas être déplacés
    # --delete-emptydir-data: Accepte la perte de données emptyDir
    # --force: Force la suppression de pods non gérés par un controller
    kubectl drain $node \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --force \
        --timeout=120s

    echo "   ✓ Nœud $node drainé"
    echo ""

    echo "3. Vérification:"
    kubectl get node $node
    echo ""
}

# Drainer chaque worker
for node in $WORKERS; do
    drain_node $node
    echo "Attente de 10 secondes avant le prochain nœud..."
    sleep 10
done

echo "=== Tous les workers ont été drainés ==="
echo ""
echo "État final du cluster:"
kubectl get nodes
echo ""
echo "Pods restants (principalement kube-system):"
kubectl get pods --all-namespaces -o wide
echo ""
echo "IMPORTANT: Les nœuds sont maintenant en mode 'SchedulingDisabled'"
echo "           Ils n'accepteront plus de nouveaux pods jusqu'au 'uncordon'"

#!/bin/bash
# Partie 3 - Réinitialisation complète
# Remet le cluster dans l'état de départ de la Partie 3
# À exécuter sur le nœud MASTER

set -e

echo "=== Réinitialisation Partie 3 - Taints & Tolerations ==="
echo ""

# Récupérer les nœuds
MASTER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" != null) | .metadata.name')
WORKER_NODES=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name')

echo "Master  : $MASTER_NODE"
echo "Workers : $(echo $WORKER_NODES | tr '\n' ' ')"
echo ""

# 1. Supprimer les pods de test
echo "1. Suppression des pods de test..."
kubectl delete pod pod-no-toleration pod-with-toleration pod-tolerate-all \
    --ignore-not-found=true
echo "   ✓ Pods supprimés"
echo ""

# 2. Supprimer les taints personnalisés sur tous les workers
echo "2. Suppression des taints personnalisés sur les workers..."
for node in $WORKER_NODES; do
    echo "   Nœud: $node"
    kubectl taint nodes "$node" gpu=true:NoSchedule- 2>/dev/null \
        && echo "     ✓ taint gpu supprimé" || echo "     - taint gpu absent"
    kubectl taint nodes "$node" environment=production:NoExecute- 2>/dev/null \
        && echo "     ✓ taint environment supprimé" || echo "     - taint environment absent"
    kubectl taint nodes "$node" environment=production:NoSchedule- 2>/dev/null \
        && echo "     ✓ taint environment:NoSchedule supprimé" || true
done
echo ""

# 3. S'assurer que les workers sont uncordonés
echo "3. Vérification du cordoning des workers..."
for node in $WORKER_NODES; do
    UNSCHEDULABLE=$(kubectl get node "$node" -o json | jq -r '.spec.unschedulable // false')
    if [ "$UNSCHEDULABLE" = "true" ]; then
        kubectl uncordon "$node"
        echo "   ✓ $node uncordoné"
    else
        echo "   - $node déjà schedulable"
    fi
done
echo ""

# 4. État final
echo "4. État final des nœuds et taints:"
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): taints=\(.spec.taints // [])"'
echo ""

echo "=== Réinitialisation terminée ==="
echo ""
echo "Le cluster est prêt pour la Partie 3."
echo "Seul le taint système du master est conservé :"
echo "  node-role.kubernetes.io/control-plane:NoSchedule"
echo ""
echo "Lancez maintenant :"
echo "  ./01-explore-default-taints.sh"

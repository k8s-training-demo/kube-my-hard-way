#!/bin/bash
# Partie 3 - Explorer les taints par défaut
# À exécuter sur le nœud MASTER

set -e

echo "=== Exploration des Taints par défaut ==="
echo ""

echo "1. Affichage des taints sur tous les nœuds:"
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.spec.taints // [])"'
echo ""

echo "2. Description détaillée du nœud master:"
MASTER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" != null) | .metadata.name')
kubectl describe node $MASTER_NODE | grep -A 5 "Taints:"
echo ""

echo "3. Explication des taints du master:"
echo "   - node-role.kubernetes.io/control-plane:NoSchedule"
echo "     Empêche le scheduling de pods utilisateur sur le master"
echo "     Seuls les pods système avec toleration appropriée peuvent y être schedulés"
echo ""

echo "4. Liste des pods système sur le master (avec tolerations):"
kubectl get pods -n kube-system -o wide --field-selector spec.nodeName=$MASTER_NODE
echo ""

echo "5. Exemple de toleration dans un pod système:"
SYSTEM_POD=$(kubectl get pods -n kube-system -o json --field-selector spec.nodeName=$MASTER_NODE | jq -r '.items[0].metadata.name')
echo "   Pod: $SYSTEM_POD"
kubectl get pod -n kube-system $SYSTEM_POD -o json | jq '.spec.tolerations'
echo ""

echo "✓ Taints par défaut explorés!"

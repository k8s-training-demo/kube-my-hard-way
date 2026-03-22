#!/bin/bash
# Partie 3 - Ajout de taints personnalisés
# À exécuter sur le nœud MASTER

set -e

echo "=== Ajout de Taints personnalisés ==="
echo ""

# Sélectionner un worker
WORKER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' | head -1)

if [ -z "$WORKER_NODE" ]; then
    echo "❌ Aucun worker trouvé"
    false  # Arrête le script avec set -e sans exit
fi

echo "Nœud worker sélectionné: $WORKER_NODE"
echo ""

echo "1. État actuel du nœud (avant taints):"
kubectl describe node $WORKER_NODE | grep -A 3 "Taints:"
echo ""

echo "2. Ajout de taints personnalisés..."
echo "   a) Taint 'gpu=true:NoSchedule' - Réservé pour workloads GPU"
kubectl taint nodes $WORKER_NODE gpu=true:NoSchedule
echo "   ✓ Taint GPU ajouté"
echo ""

echo "   b) Taint 'environment=production:NoExecute' - Expulse pods existants"
kubectl taint nodes $WORKER_NODE environment=production:NoExecute
echo "   ✓ Taint environment ajouté"
echo ""

echo "3. État après ajout des taints:"
kubectl describe node $WORKER_NODE | grep -A 5 "Taints:"
echo ""

echo "4. Observation: Les pods sans toleration appropriée sont expulsés..."
kubectl get pods -o wide --field-selector spec.nodeName=$WORKER_NODE
echo ""

echo "✓ Taints personnalisés ajoutés!"
echo ""
echo "Pour supprimer un taint:"
echo "  kubectl taint nodes $WORKER_NODE gpu=true:NoSchedule-"
echo "  kubectl taint nodes $WORKER_NODE environment=production:NoExecute-"

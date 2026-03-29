#!/bin/bash
# Partie 5 - Drain avec PodDisruptionBudget
# À exécuter sur le nœud MASTER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Drain de nœud avec PodDisruptionBudget ==="
echo ""

echo "1. Déploiement d'une application avec PDB:"
kubectl apply -f "$PROJECT_ROOT/configs/workloads/deployment-with-pdb.yaml"

echo ""
echo "   Attente du déploiement..."
kubectl wait --for=condition=available deployment/frontend-app --timeout=60s

echo ""
echo "2. État du déploiement:"
kubectl get deployment frontend-app
kubectl get pods -l app=frontend -o wide
echo ""
read -rp "   ↵  Observez la distribution des pods sur les nœuds, puis appuyez sur Entrée..."

echo ""
echo "3. Vérification du PodDisruptionBudget:"
kubectl get pdb frontend-pdb
echo ""
kubectl describe pdb frontend-pdb
echo ""
read -rp "   ↵  Notez le minAvailable et le nombre de pods autorisés à interrompre, puis Entrée..."

echo ""
echo "4. Sélection d'un worker pour le drain:"
WORKER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' | head -1)
echo "   Nœud sélectionné: $WORKER_NODE"

echo ""
echo "5. Pods sur ce nœud avant drain:"
kubectl get pods -o wide --field-selector spec.nodeName=$WORKER_NODE
echo ""
read -rp "   ↵  Mémorisez quels pods sont sur ce nœud, puis appuyez sur Entrée..."

echo ""
echo "6. Drain du nœud avec PDB actif:"
echo "   ATTENTION: Le drain respectera le PDB (minAvailable: 3)"
echo "   Les pods seront évacués progressivement..."
echo ""
read -rp "   ↵  Prêt à lancer le drain ? Appuyez sur Entrée..."

# Drain avec respect du PDB
kubectl drain $WORKER_NODE \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=180s

echo ""
echo "7. État après drain:"
echo "   a) Nœud:"
kubectl get node $WORKER_NODE

echo ""
echo "   b) Pods frontend (tous déplacés vers d'autres nœuds):"
kubectl get pods -l app=frontend -o wide

echo ""
echo "   c) PDB status:"
kubectl get pdb frontend-pdb
echo ""
read -rp "   ↵  Comparez avec l'état avant drain. Les pods ont-ils été rebalancés ? Puis Entrée..."

echo ""
echo "8. Simulation de maintenance terminée - Uncordon du nœud:"
kubectl uncordon $WORKER_NODE
echo ""
kubectl get nodes
echo ""
read -rp "   ↵  Le nœud est de nouveau schedulable. Les pods existants bougent-ils ? Puis Entrée..."

echo ""
echo "9. Les nouveaux pods pourront maintenant être schedulés sur ce nœud"
echo "   (les pods existants ne seront pas automatiquement rebalancés)"

echo ""
echo "Nettoyage..."
kubectl delete -f "$PROJECT_ROOT/configs/workloads/deployment-with-pdb.yaml"

echo ""
echo "✓ Drain avec PDB démontré!"
echo ""
echo "OBSERVATIONS CLÉS:"
echo "- Le PDB garantit qu'au moins 'minAvailable' pods restent disponibles"
echo "- Le drain respecte le PDB et évacue les pods progressivement"
echo "- Si le PDB ne peut pas être respecté, le drain échoue (protection)"

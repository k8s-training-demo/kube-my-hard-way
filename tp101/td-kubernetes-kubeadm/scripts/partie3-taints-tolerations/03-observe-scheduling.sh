#!/bin/bash
# Partie 3 - Observer le comportement du scheduling avec taints
# À exécuter sur le nœud MASTER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Observation du Scheduling avec Taints et Tolerations ==="
echo ""

echo "1. État des nœuds et leurs taints:"
kubectl get nodes
kubectl get nodes -o json | jq -r '.items[] | "\n\(.metadata.name):\n  Taints: \(.spec.taints // [])"'
echo ""

echo "2. Test A - Pod SANS toleration:"
kubectl apply -f "$PROJECT_ROOT/configs/workloads/pod-no-toleration.yaml"
sleep 5
echo "   Statut:"
kubectl get pod pod-no-toleration -o wide
kubectl get pod pod-no-toleration -o json | jq -r '"   État: \(.status.phase) | Nœud: \(.spec.nodeName // "NON SCHEDULÉ")"'
echo ""

echo "3. Test B - Pod AVEC toleration (gpu + environment):"
kubectl apply -f "$PROJECT_ROOT/configs/workloads/pod-with-toleration.yaml"
sleep 5
echo "   Statut:"
kubectl get pod pod-with-toleration -o wide
kubectl get pod pod-with-toleration -o json | jq -r '"   État: \(.status.phase) | Nœud: \(.spec.nodeName // "NON SCHEDULÉ")"'
echo ""

echo "4. Test C - Pod qui tolère TOUT (peut aller sur le master):"
kubectl apply -f "$PROJECT_ROOT/configs/workloads/pod-tolerate-all.yaml"
sleep 5
echo "   Statut:"
kubectl get pod pod-tolerate-all -o wide
kubectl get pod pod-tolerate-all -o json | jq -r '"   État: \(.status.phase) | Nœud: \(.spec.nodeName // "NON SCHEDULÉ")"'
echo ""

echo "5. Récapitulatif du placement:"
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,TOLERATIONS:.spec.tolerations[*].key
echo ""

echo "6. Événements de scheduling:"
kubectl get events --sort-by='.lastTimestamp' | grep -i 'schedule\|taint' | tail -10
echo ""

echo "Nettoyage des pods de test..."
kubectl delete pod pod-no-toleration pod-with-toleration pod-tolerate-all --ignore-not-found=true

echo ""
echo "✓ Observation du scheduling terminée!"
echo ""
echo "OBSERVATIONS CLÉS:"
echo "- Pod sans toleration: Ne peut pas être schedulé sur nœuds taintés"
echo "- Pod avec toleration: Peut être schedulé sur nœuds avec taints correspondants"
echo "- Pod tolerate-all: Peut être schedulé n'importe où, même sur le master"

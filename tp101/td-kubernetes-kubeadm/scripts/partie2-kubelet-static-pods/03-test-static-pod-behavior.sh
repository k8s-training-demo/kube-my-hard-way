#!/bin/bash
# Partie 2 - Test du comportement des static pods
# À exécuter sur le nœud MASTER

set -e

echo "=== Test du comportement des Static Pods ==="
echo ""

# Identifier le nom complet du pod (static pod sur le node où le manifest existe)
# Le manifest est déployé sur le master via 02-deploy-static-pod.sh
# → le pod s'appelle disk-monitor-<hostname-du-master>
NODE_NAME=$(kubectl get nodes --no-headers | grep 'control-plane' | head -1 | awk '{print $1}')
POD_NAME="disk-monitor-${NODE_NAME}"

echo "1. Recherche du static pod sur le nœud: $NODE_NAME (master)"
kubectl get pods -n kube-system | grep disk-monitor
echo ""

echo "2. Description du pod:"
kubectl describe pod -n kube-system $POD_NAME | grep -A 5 "Controlled By\|Annotations"
echo "   Note: Pas de 'Controlled By' = géré directement par kubelet"
echo ""

echo "3. Affichage des logs (dernières lignes):"
kubectl logs -n kube-system $POD_NAME --tail=30
echo ""

echo "4. Test: Tentative de suppression du pod via kubectl..."
kubectl delete pod -n kube-system $POD_NAME 2>&1 || true
echo "   Attente de 10 secondes..."
sleep 10

echo ""
echo "5. Vérification: Le pod a-t-il été recréé automatiquement?"
kubectl get pods -n kube-system | grep disk-monitor
echo "   ✓ Le pod est recréé automatiquement par kubelet!"
echo ""

echo "6. Pour vraiment supprimer le static pod, exécutez sur le master:"
echo "   sudo rm /etc/kubernetes/manifests/disk-monitor.yaml"
echo ""

echo "=== Comportement des Static Pods démontré! ==="

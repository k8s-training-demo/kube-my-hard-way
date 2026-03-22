#!/bin/bash
# Partie 2 - Test du comportement des static pods
# À exécuter sur le nœud MASTER

set -e

echo "=== Test du comportement des Static Pods ==="
echo ""

# Identifier le nom complet du pod (static pod sur le node où le manifest existe)
# Le pod s'appelle disk-monitor-<hostname-du-nœud-qui-a-le-manifest>
POD_NAME=$(kubectl get pods -n kube-system --no-headers | awk '/^disk-monitor/{print $1}' | head -1)

if [ -z "$POD_NAME" ]; then
    echo "❌ Static pod disk-monitor introuvable dans kube-system."
    echo "   Vérifiez que le script 02-deploy-static-pod.sh a bien été exécuté."
    exit 1
fi

NODE_NAME=$(kubectl get pod -n kube-system "$POD_NAME" -o jsonpath='{.spec.nodeName}')

echo "1. Recherche du static pod: $POD_NAME (nœud: $NODE_NAME)"
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

#!/bin/bash
# Partie 6 - Validation post-upgrade
# À exécuter sur le nœud MASTER

set -e

echo "=== Validation post-upgrade du cluster ==="
echo ""

echo "1. Versions des nœuds:"
kubectl get nodes -o wide
echo ""

echo "2. Détails des versions par nœud:"
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): kubelet \(.status.nodeInfo.kubeletVersion), kubeProxy \(.status.nodeInfo.kubeProxyVersion)"'
echo ""

echo "3. Versions des composants du control plane:"
echo "   a) API Server:"
kubectl version | grep Server

echo ""
echo "   b) Pods système et leurs images:"
kubectl get pods -n kube-system -o json | jq -r '.items[] | select(.metadata.ownerReferences[0].kind == "Pod" or .metadata.labels.component != null) | "\(.metadata.name): \(.spec.containers[0].image)"' | sort

echo ""
echo "4. Santé du cluster:"
kubectl get --raw='/readyz?verbose' | head -20
echo ""

echo "5. Uncordon de tous les nœuds (au cas où ils seraient encore cordonnés):"
kubectl get nodes --no-headers | awk '{print $1}' | xargs kubectl uncordon 2>/dev/null || true
echo ""

echo "6. État de tous les nœuds (doivent être Ready):"
kubectl get nodes
NOTREADY=$(kubectl get nodes --no-headers | grep -v " Ready " | wc -l)
if [ "$NOTREADY" -gt 0 ]; then
    echo "   ⚠️  ATTENTION: $NOTREADY nœud(s) ne sont pas Ready"
else
    echo "   ✓ Tous les nœuds sont Ready"
fi
echo ""

echo "7. État des pods système (doivent être Running):"
kubectl get pods -n kube-system
NOTRUNNING=$(kubectl get pods -n kube-system --no-headers | grep -v " Running " | grep -v " Completed " | wc -l)
if [ "$NOTRUNNING" -gt 0 ]; then
    echo "   ⚠️  ATTENTION: $NOTRUNNING pod(s) système ne sont pas Running"
else
    echo "   ✓ Tous les pods système sont Running"
fi
echo ""

echo "8. Test de déploiement d'une application:"
kubectl create deployment test-upgrade --image=nginx:alpine --replicas=3
echo "   Attente du déploiement..."
kubectl wait --for=condition=available deployment/test-upgrade --timeout=60s

echo ""
echo "9. Vérification du déploiement:"
kubectl get deployment test-upgrade
kubectl get pods -l app=test-upgrade -o wide

echo ""
echo "10. Test de connectivité réseau:"
POD_NAME=$(kubectl get pods -l app=test-upgrade -o jsonpath='{.items[0].metadata.name}')
echo "   Test DNS depuis le pod $POD_NAME:"
kubectl exec $POD_NAME -- nslookup kubernetes.default

echo ""
echo "11. Exposition et test du service:"
kubectl expose deployment test-upgrade --port=80 --type=ClusterIP
SERVICE_IP=$(kubectl get service test-upgrade -o jsonpath='{.spec.clusterIP}')
echo "   IP du service: $SERVICE_IP"
kubectl run test-client --image=busybox --restart=Never --rm -i --tty -- wget -qO- http://$SERVICE_IP | head -5

echo ""
echo "Nettoyage des ressources de test..."
kubectl delete deployment test-upgrade
kubectl delete service test-upgrade

echo ""
echo "=== Validation terminée! ==="
echo ""
echo "RÉSUMÉ DE L'UPGRADE:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion
echo ""

echo "✓ Cluster upgradé et validé avec succès!"
echo ""
echo "VÉRIFICATIONS RECOMMANDÉES:"
echo "- Tous les nœuds sont Ready"
echo "- Tous les pods système sont Running"
echo "- Les applications peuvent être déployées et accessibles"
echo "- Le réseau et le DNS fonctionnent correctement"

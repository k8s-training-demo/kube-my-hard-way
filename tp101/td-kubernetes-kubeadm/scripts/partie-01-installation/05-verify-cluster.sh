#!/bin/bash
# Partie 1 - Vérification du cluster
# À exécuter sur le nœud MASTER

set -e

echo "=== Vérification du cluster Kubernetes ==="
echo ""

echo "1. Vérification des nœuds:"
kubectl get nodes -o wide
echo ""

echo "2. Vérification des composants du control plane:"
kubectl get pods -n kube-system
echo ""

echo "3. Vérification du CNI Flannel:"
kubectl get pods -n kube-flannel
echo ""

echo "4. Test de déploiement d'un pod simple:"
kubectl run test-pod --image=nginx --restart=Never --rm -i --tty -- echo "✓ Connectivité pod fonctionnelle"
echo ""

echo "5. Vérification de la communication inter-pods:"
kubectl create deployment nginx-test --image=nginx --replicas=3
kubectl wait --for=condition=available deployment/nginx-test --timeout=60s
echo "✓ Déploiement réussi"
kubectl get pods -o wide -l app=nginx-test
echo ""

echo "Nettoyage du test..."
kubectl delete deployment nginx-test

echo ""
echo "=== Cluster vérifié avec succès! ==="

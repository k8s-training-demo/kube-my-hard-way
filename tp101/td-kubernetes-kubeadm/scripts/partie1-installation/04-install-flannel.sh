#!/bin/bash
# Partie 1 - Installation du CNI Flannel
# À exécuter sur le nœud MASTER

set -e

echo "=== Installation du CNI Flannel ==="

# Télécharger et appliquer le manifest Flannel
echo "Application du manifest Flannel..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo ""
echo "Attente du déploiement de Flannel..."
kubectl wait --for=condition=ready pod -l app=flannel -n kube-flannel --timeout=180s

echo ""
echo "✓ Flannel installé avec succès!"
echo ""
echo "Vérification des pods réseau:"
kubectl get pods -n kube-flannel
echo ""
echo "Vérification des nœuds (tous doivent être Ready):"
kubectl get nodes

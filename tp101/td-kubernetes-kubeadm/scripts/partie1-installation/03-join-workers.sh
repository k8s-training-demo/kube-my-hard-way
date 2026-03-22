#!/bin/bash
# Partie 1 - Jonction des workers au cluster
# À exécuter sur chaque nœud WORKER

set -e

echo "=== Jonction d'un worker au cluster Kubernetes ==="
echo ""
echo "ATTENTION: Ce script nécessite la commande 'kubeadm join' générée par le master"
echo ""
echo "Si vous n'avez pas la commande, exécutez sur le master:"
echo "  kubeadm token create --print-join-command"
echo ""
read -p "Entrez la commande kubeadm join complète: " JOIN_COMMAND

echo ""
echo "Exécution de: $JOIN_COMMAND"
sudo $JOIN_COMMAND

echo ""
echo "✓ Worker joint au cluster avec succès!"
echo "Retournez sur le master et vérifiez avec: kubectl get nodes"

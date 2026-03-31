#!/bin/bash
# Partie 12 - Installer Helm sur CentOS Stream 10
# À exécuter sur le nœud MASTER (une seule fois)

set -e

echo "=== Installation de Helm ==="
echo ""

if command -v helm &>/dev/null; then
    echo "✓ Helm déjà installé : $(helm version --short)"
    exit 0
fi

echo "Téléchargement et installation via le script officiel..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo ""
echo "✓ Helm installé : $(helm version --short)"
echo ""
echo "Activation de l'autocomplétion bash :"
helm completion bash > /etc/bash_completion.d/helm
echo "  → Recharger avec : source /etc/bash_completion.d/helm"

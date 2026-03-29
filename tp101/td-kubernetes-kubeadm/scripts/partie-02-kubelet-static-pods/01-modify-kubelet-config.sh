#!/bin/bash
# Partie 2 - Modification de la configuration kubelet
# À exécuter sur n'importe quel nœud

set -e

echo "=== Modification de la configuration Kubelet ==="
echo ""

# Sauvegarder la config actuelle
echo "1. Sauvegarde de la configuration actuelle..."
sudo cp /var/lib/kubelet/config.yaml /var/lib/kubelet/config.yaml.backup
echo "✓ Sauvegarde créée: /var/lib/kubelet/config.yaml.backup"
echo ""

# Afficher la config actuelle
echo "2. Configuration actuelle de maxPods:"
grep maxPods /var/lib/kubelet/config.yaml || echo "maxPods non défini (défaut: 110)"
echo ""

# Modifier maxPods
echo "3. Modification de maxPods à 50..."
if grep -q "^maxPods:" /var/lib/kubelet/config.yaml; then
    sudo sed -i 's/^maxPods:.*/maxPods: 50/' /var/lib/kubelet/config.yaml
else
    echo "maxPods: 50" | sudo tee -a /var/lib/kubelet/config.yaml
fi
echo "✓ maxPods modifié"
echo ""

# Vérifier la modification
echo "4. Nouvelle valeur de maxPods:"
grep maxPods /var/lib/kubelet/config.yaml || echo "maxPods non trouvé"
echo ""

# Redémarrer kubelet
echo "5. Redémarrage de kubelet..."
sudo systemctl daemon-reload
sudo systemctl restart kubelet

echo ""
echo "6. Attente du redémarrage de kubelet..."
sleep 5

echo "7. Vérification du statut de kubelet:"
sudo systemctl status kubelet --no-pager | head -15
echo ""

echo "✓ Configuration kubelet modifiée avec succès!"
echo ""
echo "Pour vérifier les logs kubelet:"
echo "  sudo journalctl -u kubelet -f"
echo ""
echo "Pour restaurer la configuration précédente:"
echo "  sudo cp /var/lib/kubelet/config.yaml.backup /var/lib/kubelet/config.yaml"
echo "  sudo systemctl restart kubelet"

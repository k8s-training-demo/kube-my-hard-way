#!/bin/bash
# Partie 2 - Déploiement d'un static pod
# À exécuter sur un nœud worker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATIC_POD_MANIFEST="$PROJECT_ROOT/configs/static-pods/disk-monitor.yaml"

echo "=== Déploiement d'un Static Pod ==="
echo ""

# Vérifier que le manifest existe (plusieurs emplacements possibles)
if [ ! -f "$STATIC_POD_MANIFEST" ]; then
    # Essayer un chemin relatif au répertoire courant
    if [ -f "./configs/static-pods/disk-monitor.yaml" ]; then
        STATIC_POD_MANIFEST="./configs/static-pods/disk-monitor.yaml"
    # Essayer depuis le home
    elif [ -f "$HOME/td-kubernetes-kubeadm/configs/static-pods/disk-monitor.yaml" ]; then
        STATIC_POD_MANIFEST="$HOME/td-kubernetes-kubeadm/configs/static-pods/disk-monitor.yaml"
    # Chercher dans les emplacements courants
    elif [ -f "/root/td-kubernetes-kubeadm/configs/static-pods/disk-monitor.yaml" ]; then
        STATIC_POD_MANIFEST="/root/td-kubernetes-kubeadm/configs/static-pods/disk-monitor.yaml"
    else
        echo "❌ Erreur: Manifest non trouvé!"
        echo "   Recherché dans:"
        echo "   - $PROJECT_ROOT/configs/static-pods/disk-monitor.yaml"
        echo "   - ./configs/static-pods/disk-monitor.yaml"
        echo "   - $HOME/td-kubernetes-kubeadm/configs/static-pods/disk-monitor.yaml"
        echo ""
        echo "   Assurez-vous d'exécuter ce script depuis le répertoire du projet"
        echo "   ou copiez le fichier manuellement."
        false  # Déclenche l'erreur avec set -e sans exit
    fi
fi
echo "Manifest trouvé: $STATIC_POD_MANIFEST"

# Identifier le répertoire des static pods
STATIC_POD_PATH="/etc/kubernetes/manifests"
echo "1. Répertoire des static pods: $STATIC_POD_PATH"
ls -la $STATIC_POD_PATH
echo ""

# Copier le manifest
echo "2. Copie du manifest disk-monitor..."
sudo cp "$STATIC_POD_MANIFEST" "$STATIC_POD_PATH/disk-monitor.yaml"
echo "✓ Manifest copié"
echo ""

# Attendre que le pod soit créé
echo "3. Attente de la création du pod (par kubelet)..."
sleep 10

# Vérifier le pod depuis le master (si accessible)
echo "4. Vérification du pod:"
echo "   Sur le master, exécutez:"
echo "   kubectl get pods -n kube-system | grep disk-monitor"
echo ""

echo "5. Pour voir les logs du static pod:"
echo "   kubectl logs -n kube-system disk-monitor-<node-name>"
echo ""

echo "✓ Static pod déployé!"
echo ""
echo "NOTES:"
echo "- Le static pod est géré directement par kubelet"
echo "- Il apparaît dans kubectl mais ne peut pas être supprimé via kubectl"
echo "- Pour le supprimer, effacez le manifest: sudo rm $STATIC_POD_PATH/disk-monitor.yaml"
echo "- Si vous modifiez le manifest, kubelet détecte et recrée le pod automatiquement"

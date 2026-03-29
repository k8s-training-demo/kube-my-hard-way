#!/bin/bash
# Partie 6 - Vérification des versions et préparation upgrade
# À exécuter sur le nœud MASTER
# Compatible CentOS Stream 10

set -e

echo "=== Vérification des versions et préparation upgrade ==="
echo ""

echo "1. Versions actuelles des composants:"
echo "   a) kubeadm:"
kubeadm version -o short

echo ""
echo "   b) kubectl:"
kubectl version --client -o yaml | grep gitVersion

echo ""
echo "   c) kubelet (master):"
kubelet --version

echo ""
echo "   d) Version du cluster (API server):"
kubectl version

echo ""
echo "2. État des nœuds:"
kubectl get nodes -o wide

echo ""
echo "3. Santé du cluster:"
kubectl get componentstatuses 2>/dev/null || kubectl get --raw='/readyz?verbose'

echo ""
echo "4. Pods système:"
kubectl get pods -n kube-system -o wide

echo ""
echo "5. Versions disponibles de kubeadm pour l'upgrade:"
dnf list --showduplicates kubeadm | sort -r | head -10

echo ""
echo "6. Plan d'upgrade recommandé:"
echo "   Versions Kubernetes supportent N, N-1, N-2"
echo "   Upgrade incrémentale requise (pas de saut de version mineure)"
echo "   Ex: 1.28.x -> 1.29.x -> 1.30.x"
echo ""

# Définir la version cible
TARGET_VERSION="1.35.0"
echo "7. Version cible pour ce TD: $TARGET_VERSION"
echo ""

echo "8. Vérification de la disponibilité de la version cible:"
dnf list --showduplicates kubeadm | grep $TARGET_VERSION || echo "   Version $TARGET_VERSION non trouvée dans les dépôts (peut nécessiter le repo v1.35)"

echo ""
echo "✓ Vérification des versions terminée!"
echo ""
echo "PROCHAINES ÉTAPES:"
echo "1. Sauvegarder l'état du cluster (recommandé)"
echo "2. Upgrader kubeadm sur le master"
echo "3. Planifier et appliquer l'upgrade du control plane"
echo "4. Upgrader kubelet/kubectl sur le master"
echo "5. Upgrader les workers un par un"

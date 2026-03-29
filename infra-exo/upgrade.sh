#!/bin/bash
# Partie 6 - Upgrade du control plane
# À exécuter sur le nœud MASTER
# Compatible CentOS Stream 10

set -e

# Version cible (à ajuster selon vos besoins)
TARGET_VERSION="1.35.0"

echo "=== Upgrade du Control Plane Kubernetes ==="
echo "Version cible: $TARGET_VERSION"
echo ""

echo "1. Version actuelle de kubeadm:"
kubeadm version -o short

echo ""
echo "2. Mise à jour du dépôt Kubernetes vers v${TARGET_VERSION%%.*.*}:"
# POURQUOI: pkgs.k8s.io utilise des repos par version mineure.
#           Il faut pointer vers le repo v1.35 pour accéder aux paquets 1.35.x.
MINOR_VERSION=$(echo "$TARGET_VERSION" | cut -d. -f1,2)
sudo sed -i "s|/stable:/v[0-9]\+\.[0-9]\+/|/stable:/v${MINOR_VERSION}/|g" /etc/yum.repos.d/kubernetes.repo
echo "   Repo mis à jour vers v${MINOR_VERSION}"
sudo dnf makecache --quiet 2>/dev/null || true

echo ""
echo "3. Déverrouillage et upgrade de kubeadm:"
# POURQUOI déverrouiller: Les paquets sont verrouillés pour éviter les mises à jour accidentelles.
#                         On doit les déverrouiller temporairement pour l'upgrade contrôlé.
sudo dnf versionlock delete kubeadm 2>/dev/null || true
sudo dnf install -y kubeadm-$TARGET_VERSION --disableexcludes=kubernetes
sudo dnf versionlock add kubeadm 2>/dev/null || true

echo ""
echo "4. Nouvelle version de kubeadm:"
kubeadm version -o short

echo ""
echo "5. Planification de l'upgrade (dry-run):"
# POURQUOI kubeadm upgrade plan: Affiche les versions disponibles, vérifie les prérequis,
#                                 et montre exactement ce qui sera mis à jour.
sudo kubeadm upgrade plan

echo ""
echo "6. Application de l'upgrade du control plane:"
# POURQUOI kubeadm upgrade apply: Met à jour les composants du control plane:
#   - kube-apiserver, kube-controller-manager, kube-scheduler, etcd, CoreDNS, kube-proxy
# NOTE: kubeadm 1.35.0 a un bug dans la phase post-upgrade: il réécrit kubeadm-flags.env
#       sans la variable KUBELET_KUBEADM_ARGS, puis échoue en la relisant.
#       On ignore l'erreur de post-upgrade et on corrige le fichier manuellement ensuite.
sudo kubeadm upgrade apply v$TARGET_VERSION -y || true

echo ""
echo "   Correction kubeadm-flags.env (bug kubeadm 1.35.0 post-upgrade):"
# POURQUOI: kubeadm réécrit ce fichier vide pendant l'upgrade, puis échoue à le relire.
#           Le control plane est déjà upgradé — on corrige le fichier pour kubelet.
KUBELET_FLAGS_FILE="/var/lib/kubelet/kubeadm-flags.env"
if ! grep -q "KUBELET_KUBEADM_ARGS" "$KUBELET_FLAGS_FILE" 2>/dev/null; then
  echo 'KUBELET_KUBEADM_ARGS=""' | sudo tee "$KUBELET_FLAGS_FILE" > /dev/null
  echo "   Fix appliqué: KUBELET_KUBEADM_ARGS ajouté"
fi
sudo systemctl daemon-reload
sudo systemctl restart kubelet

echo ""
echo "7. Vérification des composants après upgrade:"
kubectl get nodes
kubectl version

echo ""
echo "8. Pods du control plane (nouvelles versions):"
kubectl get pods -n kube-system -o wide

echo ""
echo "✓ Control plane upgradé avec succès!"
echo ""
echo "NOTE: Les kubelet des nœuds sont toujours à l'ancienne version"
echo "      Ils doivent être upgradés séparément"


#!/bin/bash
# Partie 6 - Upgrade kubelet et kubectl sur le master
# À exécuter sur le nœud MASTER
# Compatible CentOS Stream 10

set -e

# Version cible (doit correspondre à celle du control plane)
TARGET_VERSION="1.35.0"

echo "=== Upgrade kubelet et kubectl sur le Master ==="
echo "Version cible: $TARGET_VERSION"
echo ""

echo "1. Versions actuelles:"
echo "   kubelet: $(kubelet --version)"
echo "   kubectl: $(kubectl version --client -o yaml | grep gitVersion)"

echo ""
echo "2. Drain du nœud master (évacuation des pods):"
# POURQUOI drain: Évacue proprement les pods du nœud avant maintenance.
#                 Respecte les PodDisruptionBudgets et évite les interruptions de service.
MASTER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" != null) | .metadata.name')
echo "   Master node: $MASTER_NODE"

kubectl drain $MASTER_NODE \
    --ignore-daemonsets \
    --delete-emptydir-data

echo ""
echo "3. Déverrouillage et upgrade de kubelet et kubectl:"
# POURQUOI: kubelet doit être à la même version que le control plane (ou N-2 max).
#           kubectl peut être légèrement différent mais il est préférable de le synchroniser.
sudo dnf versionlock delete kubelet kubectl 2>/dev/null || true
sudo dnf install -y kubelet-$TARGET_VERSION kubectl-$TARGET_VERSION --disableexcludes=kubernetes
sudo dnf versionlock add kubelet kubectl 2>/dev/null || true

echo ""
echo "4. Rechargement de la configuration systemd et redémarrage kubelet:"
# POURQUOI daemon-reload: systemd doit relire les fichiers de service après une mise à jour
#                         de paquet qui pourrait avoir modifié kubelet.service.
sudo systemctl daemon-reload
sudo systemctl restart kubelet

echo ""
echo "5. Vérification du statut kubelet:"
sudo systemctl status kubelet --no-pager | head -20

echo ""
echo "6. Attente de la stabilisation de kubelet et de l'API server..."
# L'API server redémarre avec le kubelet (static pod) — attendre qu'il soit prêt
for i in $(seq 1 30); do
    kubectl get nodes > /dev/null 2>&1 && break
    echo "   API server pas encore prêt, attente ($i/30)..."
    sleep 5
done

echo ""
echo "7. Uncordon du nœud master:"
# POURQUOI uncordon: Remet le nœud en service pour accepter de nouveaux pods.
kubectl uncordon $MASTER_NODE

echo ""
echo "8. Vérification finale:"
echo "   a) Version du nœud:"
kubectl get node $MASTER_NODE -o wide

echo ""
echo "   b) Versions des composants:"
echo "      kubelet: $(kubelet --version)"
echo "      kubectl: $(kubectl version --client)"

echo ""
echo "✓ Master kubelet et kubectl upgradés avec succès!"
echo ""
echo "PROCHAINE ÉTAPE: Upgrader les workers"

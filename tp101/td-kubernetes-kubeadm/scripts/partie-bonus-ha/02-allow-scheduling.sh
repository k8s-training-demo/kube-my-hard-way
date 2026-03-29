#!/bin/bash
# Partie Bonus — HA Control Plane
# Script 02 : Autoriser le scheduling des pods sur les control plane nodes
# À exécuter sur le MASTER (ou n'importe quel control plane)
#
# Par défaut kubeadm pose un taint NoSchedule sur les control plane nodes.
# Ce script le retire pour que les 3 nœuds acceptent aussi des pods applicatifs.

set -e

echo "=== Bonus HA — Retrait du taint NoSchedule des control planes ==="
echo ""

# Lister les nœuds control-plane
CP_NODES=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
    --no-headers -o custom-columns=NAME:.metadata.name)

if [[ -z "$CP_NODES" ]]; then
    echo "❌ Aucun nœud control-plane trouvé."
    exit 1
fi

echo "Nœuds control-plane détectés :"
echo "$CP_NODES"
echo ""

# Retirer le taint NoSchedule sur chacun
for NODE in $CP_NODES; do
    echo "  Retrait du taint sur $NODE..."
    kubectl taint node "$NODE" node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null \
        && echo "    ✓ Taint retiré" \
        || echo "    (taint déjà absent sur $NODE)"
done

echo ""
echo "=== Vérification des taints restants ==="
kubectl get nodes -o custom-columns=\
"NAME:.metadata.name,ROLES:.metadata.labels.node-role\.kubernetes\.io/control-plane,TAINTS:.spec.taints"

echo ""
echo "=== ✓ Les 3 nœuds acceptent maintenant le scheduling des pods ==="

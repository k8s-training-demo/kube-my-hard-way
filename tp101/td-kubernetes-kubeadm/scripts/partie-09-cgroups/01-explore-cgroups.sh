#!/bin/bash
# Partie 9 - Explorer le filesystem cgroup v2
# À exécuter sur n'importe quel nœud (master ou worker)

set -e

echo "=== Partie 9 — Explorer les cgroups ==="
echo ""

echo "1. Détecter la version cgroup du système :"
CGVER=$(stat -fc %T /sys/fs/cgroup)
echo "   stat -fc %T /sys/fs/cgroup → $CGVER"
if [ "$CGVER" = "cgroup2fs" ]; then
    echo "   ✓ cgroup v2 actif"
else
    echo "   ⚠ cgroup v1 détecté (tmpfs) — certaines commandes différeront"
fi

echo ""
echo "2. Contrôleurs disponibles :"
cat /sys/fs/cgroup/cgroup.controllers
echo ""

echo "3. Arborescence system.slice :"
ls /sys/fs/cgroup/system.slice/ | head -10
echo ""

echo "4. Fichiers de contrôle de containerd :"
CONTAINERD_CG=/sys/fs/cgroup/system.slice/containerd.service
if [ -d "$CONTAINERD_CG" ]; then
    echo "   Chemin : $CONTAINERD_CG"
    ls "$CONTAINERD_CG" | grep -E "memory|cpu|cgroup" | head -8
    echo ""
    echo "   Mémoire consommée par containerd :"
    cat "$CONTAINERD_CG/memory.current" | \
        awk '{printf "   → %d octets (%.1f MiB)\n", $1, $1/1024/1024}'
else
    echo "   ⚠ containerd non trouvé dans system.slice"
fi

echo ""
echo "5. Répartition kubepods (si nœud K8s) :"
KUBEPODS=/sys/fs/cgroup/kubepods.slice
if [ -d "$KUBEPODS" ]; then
    echo "   QoS Guaranteed :"
    ls "$KUBEPODS" | grep -v "burstable\|besteffort\|cgroup\|cpu\|mem\|io\|pid" | \
        grep "pod" | head -3 | sed 's/^/   - /'
    echo "   QoS Burstable  : $(ls $KUBEPODS/kubepods-burstable.slice/ 2>/dev/null | grep -c pod || echo 0) pods"
    echo "   QoS BestEffort : $(ls $KUBEPODS/kubepods-besteffort.slice/ 2>/dev/null | grep -c pod || echo 0) pods"
else
    echo "   (kubepods absent — nœud non joint au cluster ou cgroup path différent)"
fi

echo ""
echo "=== Exploration terminée ==="

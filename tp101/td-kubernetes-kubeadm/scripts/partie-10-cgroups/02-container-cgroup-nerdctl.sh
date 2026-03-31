#!/bin/bash
# Partie 9 - Inspecter le cgroup d'un container via nerdctl
# À exécuter sur un nœud worker (ou master si nerdctl installé)
# Prérequis : nerdctl disponible, containerd en cours d'exécution

set -e

CONTAINER_NAME="cgroup-demo"
IMAGE="nginx:alpine"

echo "=== Partie 9 — cgroup d'un container nerdctl ==="
echo ""

# Nettoyage préalable
nerdctl rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "1. Lancement du container avec limites CPU et mémoire :"
echo "   nerdctl run -d --name $CONTAINER_NAME --cpus 0.5 --memory 128m $IMAGE"
nerdctl run -d --name "$CONTAINER_NAME" --cpus 0.5 --memory 128m "$IMAGE"
echo "   ✓ Container démarré"

echo ""
echo "2. PID du processus principal du container :"
PID=$(nerdctl inspect -f '{{.State.Pid}}' "$CONTAINER_NAME")
echo "   PID = $PID"

echo ""
echo "3. Cgroup du processus (entrée 0:: = hiérarchie unifiée v2) :"
cat /proc/$PID/cgroup
CGPATH=$(awk -F: '/^0:/{print $3}' /proc/$PID/cgroup)
echo "   → Path relatif : $CGPATH"

echo ""
echo "4. Limites effectives dans /sys/fs/cgroup${CGPATH} :"
CG_ABS="/sys/fs/cgroup${CGPATH}"

if [ -f "$CG_ABS/memory.max" ]; then
    MEM_MAX=$(cat "$CG_ABS/memory.max")
    echo "   memory.max     = $MEM_MAX octets ($(echo "scale=0; $MEM_MAX/1024/1024" | bc) MiB)"
else
    echo "   memory.max : fichier non trouvé (chemin peut varier selon version containerd)"
fi

if [ -f "$CG_ABS/memory.current" ]; then
    MEM_CUR=$(cat "$CG_ABS/memory.current")
    echo "   memory.current = $MEM_CUR octets (consommation réelle)"
fi

if [ -f "$CG_ABS/cpu.max" ]; then
    CPU_MAX=$(cat "$CG_ABS/cpu.max")
    echo "   cpu.max        = $CPU_MAX"
    echo "   → interprétation : quota(µs) période(µs)"
    echo "     50000 100000 = 50% d'un CPU ; 250000 1000000 = 25%"
fi

echo ""
echo "5. Vue synthétique nerdctl stats :"
nerdctl stats --no-stream "$CONTAINER_NAME"

echo ""
echo "6. Nettoyage :"
nerdctl rm -f "$CONTAINER_NAME"
echo "   ✓ Container supprimé"

echo ""
echo "=== Exercice terminé ==="

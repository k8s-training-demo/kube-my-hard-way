#!/bin/bash
# Partie 9 - Manipulation manuelle d'un cgroup v2
# À exécuter en ROOT sur n'importe quel nœud
# Démontre : création, limites mémoire/CPU, OOM kill

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "⚠ Ce script doit être exécuté en root (sudo $0)"
    exit 1
fi

CG_NAME="demo-manual"
CG_PATH="/sys/fs/cgroup/$CG_NAME"

cleanup() {
    # Remettre le shell dans le cgroup racine avant de supprimer
    echo $$ > /sys/fs/cgroup/cgroup.procs 2>/dev/null || true
    # Tuer les processus éventuels dans le cgroup avant suppression
    if [ -f "$CG_PATH/cgroup.procs" ]; then
        while IFS= read -r pid; do
            kill "$pid" 2>/dev/null || true
        done < "$CG_PATH/cgroup.procs"
        sleep 0.5
    fi
    rmdir "$CG_PATH" 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Partie 9 — Manipulation manuelle d'un cgroup v2 ==="
echo ""

echo "1. Activation des contrôleurs mémoire et CPU dans la racine :"
echo "+memory +cpu" > /sys/fs/cgroup/cgroup.subtree_control
echo "   cgroup.subtree_control : $(cat /sys/fs/cgroup/cgroup.subtree_control)"

echo ""
echo "2. Création du cgroup $CG_NAME :"
mkdir -p "$CG_PATH"
echo "   ✓ $CG_PATH créé"

echo ""
echo "3. Limiter la mémoire à 64 MiB :"
echo $((64 * 1024 * 1024)) > "$CG_PATH/memory.max"
echo "   memory.max = $(cat $CG_PATH/memory.max) octets"

echo ""
echo "4. Limiter le CPU à 25% (250 ms quota / 1000 ms période) :"
echo "250000 1000000" > "$CG_PATH/cpu.max"
echo "   cpu.max = $(cat $CG_PATH/cpu.max)"

echo ""
echo "5. Placer le shell courant dans ce cgroup :"
echo $$ > "$CG_PATH/cgroup.procs"
echo "   Shell PID $$ dans : $(cat /proc/$$/cgroup | awk -F: '/^0:/{print $3}')"

echo ""
echo "6. Test de la limite CPU (boucle 3 secondes — devrait être throttlé à ~25%) :"
echo "   Lancement... observer avec 'top' dans un autre terminal"
timeout 3 bash -c 'while true; do :; done' || true
echo "   ✓ Boucle terminée (throttlée à 25% CPU)"

echo ""
echo "7. Test de la limite mémoire avec 'stress' (si installé) :"
if command -v stress >/dev/null 2>&1; then
    echo "   stress --vm 1 --vm-bytes 80M --timeout 2s (doit passer, < 64 MiB)"
    stress --vm 1 --vm-bytes 80M --timeout 2s 2>/dev/null && echo "   ✓ OK (80 MiB < 64 MiB… attention aux caches)" || echo "   (OOM ou erreur attendue)"
    echo ""
    echo "   stress --vm 1 --vm-bytes 200M (doit être OOM killed) :"
    stress --vm 1 --vm-bytes 200M --timeout 3s 2>/dev/null && echo "   (passé)" || echo "   ✓ OOM kill déclenché par le noyau"
else
    echo "   stress non installé — installer avec : dnf install -y stress"
    echo "   Test alternatif : allocation Python de 100 MiB"
    python3 -c "
import sys
try:
    buf = bytearray(100 * 1024 * 1024)
    print('   100 MiB alloués')
except MemoryError:
    print('   ✓ MemoryError levé par le noyau (OOM)')
" 2>/dev/null || echo "   ✓ Processus tué (OOM)"
fi

echo ""
echo "8. Sortir du cgroup et nettoyage (trap EXIT) :"
echo $$ > /sys/fs/cgroup/cgroup.procs
echo "   Shell replacé dans le cgroup racine"

echo ""
echo "=== Manipulation terminée ==="

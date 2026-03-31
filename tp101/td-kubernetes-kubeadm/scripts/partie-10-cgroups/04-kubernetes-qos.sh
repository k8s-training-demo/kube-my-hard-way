#!/bin/bash
# Partie 9 - Inspecter les cgroups des pods Kubernetes (QoS)
# À exécuter sur le nœud MASTER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Partie 9 — cgroups Kubernetes et classes QoS ==="
echo ""

echo "--- Déploiement des pods de test (Guaranteed / Burstable / BestEffort) ---"
kubectl apply -f "$PROJECT_ROOT/configs/cgroups/qos-pods.yaml"
echo ""
echo "Attente du démarrage des pods..."
sleep 5
kubectl get pods -l partie=9-cgroups -o wide
echo ""

echo "--- Classes QoS assignées par Kubernetes ---"
for pod in qos-guaranteed qos-burstable qos-besteffort; do
    QOS=$(kubectl get pod "$pod" -o jsonpath='{.status.qosClass}' 2>/dev/null || echo "N/A")
    NODE=$(kubectl get pod "$pod" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "N/A")
    echo "  $pod → QoS: $QOS  (nœud: $NODE)"
done
echo ""

echo "--- Identifier le cgroup de chaque pod sur son nœud ---"
echo "(à exécuter sur le nœud worker correspondant)"
echo ""
for pod in qos-guaranteed qos-burstable qos-besteffort; do
    UID=$(kubectl get pod "$pod" -o jsonpath='{.metadata.uid}' 2>/dev/null || echo "N/A")
    if [ "$UID" != "N/A" ]; then
        echo "  $pod (uid: $UID)"
        echo "    → path cgroup attendu :"
        QOS=$(kubectl get pod "$pod" -o jsonpath='{.status.qosClass}' 2>/dev/null)
        case "$QOS" in
            Guaranteed) echo "      /sys/fs/cgroup/kubepods.slice/kubepods-pod${UID//-/_}.slice/" ;;
            Burstable)  echo "      /sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod${UID//-/_}.slice/" ;;
            BestEffort) echo "      /sys/fs/cgroup/kubepods.slice/kubepods-besteffort.slice/kubepods-besteffort-pod${UID//-/_}.slice/" ;;
        esac
    fi
done
echo ""

echo "--- Sur chaque nœud worker, vérifier les limites ---"
cat << 'SNIPPET'
# Remplacer <uid> par l'UID du pod Guaranteed (ou adapter le chemin)
CG=/sys/fs/cgroup/kubepods.slice/kubepods-pod<uid>.slice
cat $CG/memory.max      # → limite mémoire (max = pas de limite si BestEffort)
cat $CG/cpu.max         # → quota CPU / période
SNIPPET
echo ""

echo "--- Nettoyage ---"
kubectl delete -f "$PROJECT_ROOT/configs/cgroups/qos-pods.yaml" --ignore-not-found
echo "✓ Pods supprimés"
echo ""
echo "=== Exercice QoS terminé ==="

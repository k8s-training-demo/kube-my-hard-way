#!/bin/bash
# Partie 5 - Drain et gestion des DaemonSets
# À exécuter sur le nœud MASTER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Drain et gestion des DaemonSets ==="
echo ""

echo "1. Déploiement d'un DaemonSet de test:"
kubectl apply -f "$PROJECT_ROOT/configs/workloads/test-daemonset.yaml"

echo ""
echo "   Attente du déploiement sur tous les nœuds..."
sleep 10

echo ""
echo "2. Vérification du DaemonSet:"
kubectl get daemonset node-exporter
kubectl get pods -l app=node-exporter -o wide
echo ""
read -rp "   ↵  Observez : 1 pod DaemonSet par nœud. Appuyez sur Entrée..."

echo ""
echo "3. Les DaemonSets s'exécutent sur TOUS les nœuds (y compris le master si toléré)"

echo ""
echo "4. Sélection d'un worker pour le drain:"
WORKER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' | head -1)
echo "   Nœud sélectionné: $WORKER_NODE"

echo ""
echo "5. Pods sur ce nœud (incluant DaemonSet):"
kubectl get pods -o wide --field-selector spec.nodeName=$WORKER_NODE
echo ""
read -rp "   ↵  Notez le pod DaemonSet présent sur ce nœud. Appuyez sur Entrée..."

echo ""
echo "6. Tentative de drain SANS --ignore-daemonsets:"
echo "   Cela devrait ÉCHOUER car les DaemonSets ne peuvent pas être évacués"
kubectl drain $WORKER_NODE --delete-emptydir-data --timeout=30s 2>&1 || true

echo ""
echo "   ❌ Échec attendu: les DaemonSets bloquent le drain"
read -rp "   ↵  Lisez l'erreur : 'cannot delete DaemonSet-managed Pods'. Appuyez sur Entrée..."

echo ""
echo "7. Drain AVEC --ignore-daemonsets:"
read -rp "   ↵  Prêt à relancer avec --ignore-daemonsets ? Appuyez sur Entrée..."
kubectl drain $WORKER_NODE \
    --ignore-daemonsets \
    --delete-emptydir-data \
    --timeout=60s

echo ""
echo "8. État après drain:"
kubectl get node $WORKER_NODE

echo ""
echo "9. Le pod DaemonSet reste sur le nœud drainé:"
kubectl get pods -l app=node-exporter -o wide
echo ""
read -rp "   ↵  Le pod DaemonSet est toujours sur $WORKER_NODE — c'est voulu. Appuyez sur Entrée..."

echo ""
echo "10. Uncordon du nœud:"
kubectl uncordon $WORKER_NODE

echo ""
echo "Nettoyage..."
kubectl delete -f "$PROJECT_ROOT/configs/workloads/test-daemonset.yaml"

echo ""
echo "✓ Comportement des DaemonSets démontré!"
echo ""
echo "OBSERVATIONS CLÉS:"
echo "- DaemonSets doivent s'exécuter sur chaque nœud (par design)"
echo "- --ignore-daemonsets est REQUIS pour drainer un nœud"
echo "- Les pods DaemonSet restent en place même après drain"
echo "- C'est normal: ils fournissent des services node-level (logs, monitoring, réseau)"

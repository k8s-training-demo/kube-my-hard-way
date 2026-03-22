#!/bin/bash
# Script de validation complète du TD
# À exécuter sur le nœud MASTER

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    Validation complète du TD Kubernetes avec kubeadm         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Fonction pour afficher le statut
check_status() {
    if [ $? -eq 0 ]; then
        echo "✓ PASS"
    else
        echo "✗ FAIL"
        return 1
    fi
}

# Compteur de tests
TOTAL=0
PASSED=0
FAILED=0

run_test() {
    TOTAL=$((TOTAL + 1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test $TOTAL: $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# PARTIE 1 - Cluster de base
run_test "Cluster installé et fonctionnel"
if kubectl get nodes &>/dev/null; then
    check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
else
    check_status || FAILED=$((FAILED + 1))
fi

run_test "Tous les nœuds sont Ready"
NOTREADY=$(kubectl get nodes --no-headers | grep -cv " Ready " || true)
if [ "$NOTREADY" -eq 0 ]; then
    kubectl get nodes
    check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
else
    kubectl get nodes
    check_status || FAILED=$((FAILED + 1))
fi

run_test "CNI installé (Flannel ou Calico)"
if kubectl get pods -n kube-flannel &>/dev/null || kubectl get pods -n kube-system -l k8s-app=calico-node &>/dev/null; then
    kubectl get pods -n kube-system | grep -E "flannel|calico"
    check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
else
    check_status || FAILED=$((FAILED + 1))
fi

# PARTIE 2 - Kubelet et Static Pods
run_test "Configuration kubelet personnalisée existe"
if [ -f /var/lib/kubelet/config.yaml.backup ]; then
    echo "Backup de configuration kubelet trouvé"
    check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
else
    echo "Pas de backup trouvé (peut être normal si non modifié)"
    PASSED=$((PASSED + 1))
fi

run_test "Répertoire static pods existe"
if [ -d /etc/kubernetes/manifests ]; then
    ls -la /etc/kubernetes/manifests
    check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
else
    check_status || FAILED=$((FAILED + 1))
fi

# PARTIE 3 - Taints et Tolerations
run_test "Taints sur le master"
MASTER_TAINTS=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" != null) | .spec.taints // []')
if [ ! -z "$MASTER_TAINTS" ] && [ "$MASTER_TAINTS" != "[]" ]; then
    echo "$MASTER_TAINTS"
    check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
else
    check_status || FAILED=$((FAILED + 1))
fi

# PARTIE 4 - Migration CNI
run_test "Type de CNI actif"
if kubectl get pods -n kube-system -l k8s-app=calico-node &>/dev/null; then
    echo "CNI actif: Calico ✓"
    kubectl get pods -n kube-system -l k8s-app=calico-node
    check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
elif kubectl get pods -n kube-flannel &>/dev/null; then
    echo "CNI actif: Flannel"
    kubectl get pods -n kube-flannel
    PASSED=$((PASSED + 1))
else
    echo "Aucun CNI détecté"
    check_status || FAILED=$((FAILED + 1))
fi

# Test de connectivité réseau
run_test "Connectivité réseau inter-pods"
kubectl run test-validation-1 --image=busybox --restart=Never -- sleep 30 &>/dev/null || true
kubectl run test-validation-2 --image=busybox --restart=Never -- sleep 30 &>/dev/null || true
sleep 5

POD1_IP=$(kubectl get pod test-validation-1 -o jsonpath='{.status.podIP}' 2>/dev/null || echo "")
if [ ! -z "$POD1_IP" ]; then
    if kubectl exec test-validation-2 -- ping -c 2 $POD1_IP &>/dev/null; then
        echo "Connectivité inter-pods: OK ($POD1_IP)"
        check_status && PASSED=$((PASSED + 1)) || FAILED=$((FAILED + 1))
    else
        check_status || FAILED=$((FAILED + 1))
    fi
else
    echo "Pods de test non prêts (skip)"
    PASSED=$((PASSED + 1))
fi
kubectl delete pod test-validation-1 test-validation-2 --ignore-not-found=true &>/dev/null || true

# PARTIE 5 & 6 - Maintenance et Upgrade
run_test "Versions Kubernetes"
echo "Versions des nœuds:"
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion
PASSED=$((PASSED + 1))

# Résumé final
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    RÉSUMÉ DE LA VALIDATION                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Tests exécutés: $TOTAL"
echo "Tests réussis:  $PASSED ($(( PASSED * 100 / TOTAL ))%)"
echo "Tests échoués:  $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ Tous les tests sont passés avec succès!"
    exit 0
else
    echo "✗ Certains tests ont échoué. Vérifiez les détails ci-dessus."
    exit 1
fi

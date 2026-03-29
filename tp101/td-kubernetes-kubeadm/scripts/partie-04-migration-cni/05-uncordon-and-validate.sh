#!/bin/bash
# Partie 4 - Uncordon des nœuds et validation de la connectivité
# À exécuter sur le nœud MASTER

set -e

# Fonction de nettoyage en cas d'échec
cleanup() {
    echo ""
    echo "⚠️  Nettoyage des ressources de test..."
    kubectl delete pod test-calico-1 test-calico-2 test-calico-3 2>/dev/null || true
    echo "   ✓ Ressources nettoyées"
}

# Configurer le trap pour appeler cleanup en cas d'échec
trap cleanup ERR

echo "=== Uncordon des nœuds et validation ==="
echo ""

# ─── Étape 0 : vérifier le mode encapsulation Calico (backend + IPPool) ────
echo "0. Vérification du mode encapsulation Calico..."
NEEDS_FIX=false

# a) Vérifier le backend ConfigMap (bird → BIRD/BGP démarré, vxlan → VXLAN pur)
BACKEND=$(kubectl get cm calico-config -n kube-system -o jsonpath='{.data.calico_backend}' 2>/dev/null || echo "")
if [[ "$BACKEND" != "vxlan" ]]; then
    echo "   ⚠️  Backend Calico = '$BACKEND' (BIRD/BGP) — passage en 'vxlan'..."
    kubectl patch cm calico-config -n kube-system --type=merge \
        -p '{"data":{"calico_backend":"vxlan"}}'
    echo "   ✓ Backend changé → vxlan (BIRD ne démarrera plus)"
    NEEDS_FIX=true
fi

# b) Vérifier l'IPPool (ipipMode/vxlanMode)
IPIP_MODE=$(kubectl get ippools default-ipv4-ippool -o jsonpath='{.spec.ipipMode}' 2>/dev/null || echo "")
VXLAN_MODE=$(kubectl get ippools default-ipv4-ippool -o jsonpath='{.spec.vxlanMode}' 2>/dev/null || echo "")

if [[ "$IPIP_MODE" == "Always" ]] || [[ "$VXLAN_MODE" != "Always" ]]; then
    echo "   ⚠️  IPPool : ipipMode=$IPIP_MODE, vxlanMode=$VXLAN_MODE — correction..."
    kubectl patch ippools default-ipv4-ippool --type=merge \
        -p '{"spec": {"ipipMode": "Never", "vxlanMode": "Always"}}'
    echo "   ✓ IPPool corrigé → VXLAN Always"
    NEEDS_FIX=true
fi

# c) Redémarrer si des corrections ont été appliquées
if [[ "$NEEDS_FIX" == "true" ]]; then
    kubectl rollout restart daemonset/calico-node -n kube-system
    echo "   Attente du redémarrage des calico-node..."
    kubectl rollout status daemonset/calico-node -n kube-system --timeout=180s
    echo "   ✓ Mode VXLAN activé"
else
    echo "   ✓ Calico déjà en mode VXLAN complet (backend + IPPool)"
fi
echo ""
# ───────────────────────────────────────────────────────────────────────────

# Vérifier que jq est installé
if ! command -v jq &> /dev/null; then
    echo "❌ jq est requis mais n'est pas installé. Veuillez installer jq d'abord."
    echo "   Sur Ubuntu/Debian: sudo apt-get install -y jq"
    echo "   Sur CentOS/RHEL: sudo yum install -y jq"
    exit 1
fi

# Lister tous les nœuds
WORKERS=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name')

echo "1. Uncordon des nœuds workers:"
for node in $WORKERS; do
    echo "   - Uncordon de $node..."
    kubectl uncordon $node
done
echo "   ✓ Tous les nœuds sont maintenant schedulables"
echo ""

echo "2. État du cluster après uncordon:"
kubectl get nodes
echo ""

echo "3. Vérification des pods Calico:"
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
echo ""

echo "4. Test de déploiement d'un pod de test:"

# Créer les pods un par un avec vérification
echo "   Création des pods de test..."
for i in 1 2 3; do
    if ! kubectl run test-calico-$i --image=busybox --restart=Never -- sleep 3600; then
        echo "   ❌ Échec de la création du pod test-calico-$i"
        echo "   Vérifiez l'état du cluster: kubectl get nodes"
        echo "   Vérifiez les pods Calico: kubectl get pods -n kube-system -l k8s-app=calico-node"
        exit 1
    fi
done

echo "   Attente du démarrage des pods..."
for i in 1 2 3; do
    if ! kubectl wait --for=condition=ready pod test-calico-$i --timeout=60s; then
        echo "   ❌ Le pod test-calico-$i n'est pas prêt après 60 secondes"
        echo "   Vérifiez les logs: kubectl logs test-calico-$i"
        echo "   Vérifiez les événements: kubectl get events --sort-by='.metadata.creationTimestamp'"
        exit 1
    fi
done

echo ""
echo "5. Placement des pods de test:"
kubectl get pods -o wide | grep test-calico

echo ""
echo "6. Test de connectivité réseau inter-pods:"
POD1_IP=$(kubectl get pod test-calico-1 -o jsonpath='{.status.podIP}')
POD2_IP=$(kubectl get pod test-calico-2 -o jsonpath='{.status.podIP}')

echo "   Pod 1 IP: $POD1_IP"
echo "   Pod 2 IP: $POD2_IP"
echo ""
echo "   Test: pod1 -> pod2"
if ! kubectl exec test-calico-1 -- ping -c 3 $POD2_IP; then
    echo "   ❌ Échec de la connectivité inter-pods"
    echo "   Vérifiez les routes: kubectl exec test-calico-1 -- ip route"
    echo "   Vérifiez les interfaces: kubectl exec test-calico-1 -- ip addr"
    echo "   Vérifiez les pods Calico: kubectl get pods -n kube-system -l k8s-app=calico-node -o wide"
    exit 1
fi
echo "   ✓ Connectivité inter-pods fonctionnelle"

echo ""
echo "7. Test de résolution DNS:"
if ! kubectl exec test-calico-1 -- nslookup kubernetes.default.svc.cluster.local; then
    echo "   ❌ Échec de la résolution DNS"
    echo "   Vérifiez le service kube-dns: kubectl get pods -n kube-system -l k8s-app=kube-dns"
    echo "   Vérifiez la configuration CoreDNS: kubectl get cm -n kube-system coredns -o yaml"
    exit 1
fi
echo "   ✓ DNS fonctionnel"

echo ""
echo "8. Test de connectivité externe:"
if ! kubectl exec test-calico-1 -- ping -c 3 8.8.8.8; then
    echo "   ❌ Échec de la connectivité externe"
    echo "   Vérifiez les règles iptables: sudo iptables -L -n"
    echo "   Vérifiez les politiques réseau: kubectl get networkpolicies --all-namespaces"
    exit 1
fi
echo "   ✓ Connectivité externe fonctionnelle"

echo ""
echo "9. Inspection des interfaces réseau Calico sur un pod:"
kubectl exec test-calico-1 -- ip addr show
echo ""

echo "10. Nettoyage des pods de test:"
kubectl delete pod test-calico-1 test-calico-2 test-calico-3

echo ""
echo "=== Migration CNI terminée avec succès! ==="
echo ""
echo "RÉSUMÉ:"
echo "✓ Flannel supprimé"
echo "✓ Calico installé et fonctionnel"
echo "✓ Tous les nœuds opérationnels"
echo "✓ Connectivité réseau validée (inter-pods, DNS, externe)"
echo ""
echo "Vérifications post-migration:"
echo "- Tous les nœuds sont Ready: kubectl get nodes"
echo "- Calico pods sont Running: kubectl get pods -n kube-system | grep calico"
echo "- Pas d'erreurs réseau: kubectl get events --all-namespaces | grep -i error"

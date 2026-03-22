#!/bin/bash
# Script de validation par partie
# Usage: ./validate-partie.sh <numero-partie>

PARTIE=$1

if [ -z "$PARTIE" ]; then
    echo "Usage: $0 <numero-partie>"
    echo ""
    echo "Parties disponibles:"
    echo "  1 - Installation du cluster"
    echo "  2 - Configuration kubelet et static pods"
    echo "  3 - Taints et tolerations"
    echo "  4 - Migration CNI"
    echo "  5 - Drain et maintenance"
    echo "  6 - Upgrade du cluster"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════"
echo "  Validation Partie $PARTIE"
echo "═══════════════════════════════════════════════════════════"
echo ""

case $PARTIE in
    1)
        echo "Partie 1 - Installation du cluster"
        echo "─────────────────────────────────────"
        echo ""
        echo "1. Nœuds du cluster:"
        kubectl get nodes -o wide
        echo ""
        echo "2. Composants système:"
        kubectl get pods -n kube-system
        echo ""
        echo "3. CNI (Flannel):"
        kubectl get pods -n kube-flannel 2>/dev/null || echo "   Flannel non trouvé"
        ;;

    2)
        echo "Partie 2 - Configuration kubelet et static pods"
        echo "────────────────────────────────────────────────"
        echo ""
        echo "1. Configuration kubelet:"
        sudo cat /var/lib/kubelet/config.yaml | grep -E "maxPods|staticPodPath"
        echo ""
        echo "2. Static pods définis:"
        sudo ls -la /etc/kubernetes/manifests/
        echo ""
        echo "3. Static pods en cours d'exécution:"
        kubectl get pods -n kube-system -o wide | grep -E "NAME|$(hostname)" | grep -v "kube-system"
        ;;

    3)
        echo "Partie 3 - Taints et tolerations"
        echo "─────────────────────────────────────"
        echo ""
        echo "1. Taints sur tous les nœuds:"
        kubectl get nodes -o json | jq -r '.items[] | "\n\(.metadata.name):\n  Taints: \(.spec.taints // "none")"'
        echo ""
        echo "2. Test de scheduling avec toleration:"
        cat > /tmp/test-toleration.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-toleration-validation
spec:
  containers:
  - name: nginx
    image: nginx:alpine
  tolerations:
  - operator: "Exists"
EOF
        kubectl apply -f /tmp/test-toleration.yaml
        sleep 5
        kubectl get pod test-toleration-validation -o wide
        kubectl delete -f /tmp/test-toleration.yaml
        rm /tmp/test-toleration.yaml
        ;;

    4)
        echo "Partie 4 - Migration CNI"
        echo "────────────────────────"
        echo ""
        echo "1. CNI actuel:"
        if kubectl get pods -n kube-system -l k8s-app=calico-node &>/dev/null; then
            echo "   ✓ Calico détecté (migration effectuée)"
            kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
        else
            echo "   Flannel détecté (migration non effectuée)"
            kubectl get pods -n kube-flannel 2>/dev/null || echo "   Aucun CNI détecté"
        fi
        echo ""
        echo "2. Test de connectivité:"
        kubectl run test-cni-1 --image=busybox --restart=Never -- sleep 20 &
        kubectl run test-cni-2 --image=busybox --restart=Never -- sleep 20 &
        sleep 8
        POD1_IP=$(kubectl get pod test-cni-1 -o jsonpath='{.status.podIP}')
        echo "   Pod 1 IP: $POD1_IP"
        kubectl exec test-cni-2 -- ping -c 3 $POD1_IP
        kubectl delete pod test-cni-1 test-cni-2
        ;;

    5)
        echo "Partie 5 - Drain et maintenance"
        echo "────────────────────────────────"
        echo ""
        echo "1. État des nœuds (vérifier SchedulingDisabled):"
        kubectl get nodes
        echo ""
        echo "2. Test de drain (simulé):"
        WORKER=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' | head -1)
        echo "   Worker: $WORKER"
        kubectl describe node $WORKER | grep -A 5 "Taints:"
        ;;

    6)
        echo "Partie 6 - Upgrade du cluster"
        echo "──────────────────────────────"
        echo ""
        echo "1. Versions des composants:"
        echo "   kubeadm: $(kubeadm version -o short)"
        echo "   kubectl: $(kubectl version --client -o yaml | grep gitVersion)"
        echo "   kubelet: $(kubelet --version)"
        echo ""
        echo "2. Versions des nœuds:"
        kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion
        echo ""
        echo "3. Version du control plane:"
        kubectl version
        ;;

    *)
        echo "❌ Partie invalide: $PARTIE"
        echo "Parties valides: 1, 2, 3, 4, 5, 6"
        exit 1
        ;;
esac

echo ""
echo "✓ Validation de la partie $PARTIE terminée"

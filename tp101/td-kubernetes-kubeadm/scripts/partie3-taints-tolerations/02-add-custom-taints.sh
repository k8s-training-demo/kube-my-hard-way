#!/bin/bash
# Partie 3 - Ajout de taints personnalisés
# À exécuter sur le nœud MASTER

set -e

echo "=== Ajout de Taints personnalisés ==="
echo ""

# Sélectionner un worker
WORKER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' | head -1)

if [ -z "$WORKER_NODE" ]; then
    echo "❌ Aucun worker trouvé"
    false  # Arrête le script avec set -e sans exit
fi

echo "Nœud worker sélectionné: $WORKER_NODE"
echo ""

echo "1. État actuel du nœud (avant taints):"
kubectl describe node $WORKER_NODE | grep -A 3 "Taints:"
echo ""

echo "2. Ajout de taints personnalisés..."
echo "   a) Taint 'gpu=true:NoSchedule' - Réservé pour workloads GPU"
kubectl taint nodes $WORKER_NODE gpu=true:NoSchedule
echo "   ✓ Taint GPU ajouté"
echo ""

echo "   b) Taint 'environment=production:NoExecute' - Expulse pods existants"
kubectl taint nodes $WORKER_NODE environment=production:NoExecute
echo "   ✓ Taint environment ajouté"
echo ""

echo "3. État après ajout des taints:"
kubectl describe node $WORKER_NODE | grep -A 5 "Taints:"
echo ""

echo "4. Observation: Les pods sans toleration appropriée sont expulsés..."
kubectl get pods -o wide --field-selector spec.nodeName=$WORKER_NODE
echo ""

echo "✓ Taints personnalisés ajoutés!"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "5. Démonstration — pod GPU simulé (sans GPU réel) :"
echo ""
echo "   Un pod 'fake-gpu-workload' avec la toleration gpu=true:NoSchedule"
echo "   → il PEUT être schedulé sur $WORKER_NODE malgré le taint"
echo ""
kubectl apply -f "$PROJECT_ROOT/configs/workloads/pod-fake-gpu.yaml"
sleep 5
kubectl get pod fake-gpu-workload -o wide
NODE_PLACED=$(kubectl get pod fake-gpu-workload -o jsonpath='{.spec.nodeName}')
echo ""
if [ "$NODE_PLACED" = "$WORKER_NODE" ]; then
    echo "   ✓ Pod schedulé sur $WORKER_NODE (nœud tainté GPU) — toleration OK"
else
    echo "   ℹ️  Pod schedulé sur : ${NODE_PLACED:-NON SCHEDULÉ}"
fi
echo ""

echo "6. Comparaison — pod SANS toleration gpu :"
cat <<'EOF'
   apiVersion: v1
   kind: Pod
   metadata:
     name: pod-sans-toleration
   spec:
     containers:
     - name: app
       image: nginx:alpine
     # Pas de tolerations → ne peut PAS aller sur le nœud GPU tainté
EOF
echo ""
echo "   → Ce pod sera schedulé uniquement sur les nœuds sans taint gpu."
echo ""

echo "Nettoyage du pod de démonstration..."
kubectl delete pod fake-gpu-workload --ignore-not-found=true
echo ""
echo "Pour supprimer les taints :"
echo "  kubectl taint nodes $WORKER_NODE gpu=true:NoSchedule-"
echo "  kubectl taint nodes $WORKER_NODE environment=production:NoExecute-"
echo "  (ou lancez : ./00-reset.sh)"

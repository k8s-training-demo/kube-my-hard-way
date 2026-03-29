#!/bin/bash
# Partie 4 - Sauvegarde de l'état du cluster avant migration CNI
# À exécuter sur le nœud MASTER

set -e

BACKUP_DIR="$HOME/k8s-backup-$(date +%Y%m%d-%H%M%S)"

echo "=== Sauvegarde de l'état du cluster ==="
echo "Répertoire de sauvegarde: $BACKUP_DIR"
echo ""

mkdir -p "$BACKUP_DIR"

echo "1. Sauvegarde des nœuds:"
kubectl get nodes -o yaml > "$BACKUP_DIR/nodes.yaml"
kubectl get nodes -o wide > "$BACKUP_DIR/nodes.txt"
echo "   ✓ Nœuds sauvegardés"

echo "2. Sauvegarde de la configuration réseau actuelle (Flannel):"
kubectl get all -n kube-flannel -o yaml > "$BACKUP_DIR/flannel-resources.yaml"
kubectl get configmap -n kube-flannel -o yaml > "$BACKUP_DIR/flannel-configmaps.yaml"
echo "   ✓ Flannel sauvegardé"

echo "3. Sauvegarde des pods dans tous les namespaces:"
kubectl get pods --all-namespaces -o yaml > "$BACKUP_DIR/all-pods.yaml"
kubectl get pods --all-namespaces -o wide > "$BACKUP_DIR/all-pods.txt"
echo "   ✓ Pods sauvegardés"

echo "4. Sauvegarde des services:"
kubectl get services --all-namespaces -o yaml > "$BACKUP_DIR/services.yaml"
echo "   ✓ Services sauvegardés"

echo "5. Sauvegarde des endpoints:"
kubectl get endpoints --all-namespaces -o yaml > "$BACKUP_DIR/endpoints.yaml"
echo "   ✓ Endpoints sauvegardés"

echo "6. Test de connectivité réseau actuel:"
cat > "$BACKUP_DIR/network-test.sh" <<'EOF'
#!/bin/bash
# Test de connectivité avant migration
kubectl run test-connectivity --image=busybox --restart=Never --rm -it -- sh -c "
echo 'Test DNS:' && nslookup kubernetes.default
echo 'Test réseau:' && ping -c 3 8.8.8.8
"
EOF
chmod +x "$BACKUP_DIR/network-test.sh"
echo "   ✓ Script de test créé"

echo ""
echo "✓ Sauvegarde complète créée dans: $BACKUP_DIR"
echo ""
echo "Contenu de la sauvegarde:"
ls -lh "$BACKUP_DIR/"

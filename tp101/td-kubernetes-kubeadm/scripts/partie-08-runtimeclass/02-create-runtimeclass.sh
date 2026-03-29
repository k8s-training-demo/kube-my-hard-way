#!/bin/bash
# Partie 7 - Création de la RuntimeClass Kubernetes
# À exécuter sur le MASTER uniquement

set -e

echo "=== Création de la RuntimeClass gVisor ==="
echo ""

echo "1. RuntimeClasses actuelles:"
kubectl get runtimeclass 2>/dev/null || echo "   Aucune RuntimeClass définie"

echo ""
echo "2. Création de la RuntimeClass 'gvisor'..."
# POURQUOI RuntimeClass:
#   Kubernetes délègue le choix du runtime à la RuntimeClass.
#   Sans RuntimeClass, tous les pods utilisent le runtime par défaut (runc).
#   Avec RuntimeClass 'gvisor', les pods qui la référencent utilisent runsc (gVisor).
#   Le champ 'handler' doit correspondre au nom configuré dans containerd.
kubectl apply -f - << 'EOF'
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    kubernetes.io/arch: amd64
EOF

echo ""
echo "3. RuntimeClasses disponibles:"
kubectl get runtimeclass -o wide

echo ""
echo "4. Détail de la RuntimeClass gvisor:"
kubectl describe runtimeclass gvisor

echo ""
echo "✓ RuntimeClass gvisor créée!"
echo ""
echo "PROCHAINE ÉTAPE: Exécutez 03-test-isolation.sh sur le MASTER"

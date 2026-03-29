#!/bin/bash
# Partie 7 - Démonstration de l'isolation gVisor vs runtime standard
# À exécuter sur le MASTER

set -e

echo "=== Démonstration de l'isolation gVisor ==="
echo ""

echo "1. Déploiement d'un pod standard (runc) et d'un pod gVisor (runsc)..."
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: runtime-standard
  labels:
    runtime: standard
spec:
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
---
apiVersion: v1
kind: Pod
metadata:
  name: runtime-gvisor
  labels:
    runtime: gvisor
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
EOF

echo "   Attente du démarrage des pods..."
kubectl wait --for=condition=Ready pod/runtime-standard pod/runtime-gvisor --timeout=90s
echo "   ✓ Les deux pods sont Ready"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Comparaison du kernel vu par chaque pod"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
STANDARD_KERNEL=$(kubectl exec runtime-standard -- uname -r)
GVISOR_KERNEL=$(kubectl exec runtime-gvisor -- uname -r)
HOST_KERNEL=$(uname -r)

echo "   Host (nœud):    $HOST_KERNEL"
echo "   Pod standard:   $STANDARD_KERNEL"
echo "   Pod gVisor:     $GVISOR_KERNEL"
echo ""
# POURQUOI le kernel diffère:
#   runc: les containers partagent le kernel du nœud (namespace isolation uniquement)
#   gVisor: chaque pod a son propre kernel en espace utilisateur (runsc implémente
#           les syscalls Linux, indépendamment du kernel hôte)
echo "   OBSERVATION: Le pod gVisor voit un kernel différent (gVisor user-space kernel)."
echo "   Le pod standard partage le kernel réel du nœud ($HOST_KERNEL)."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Vérification via /proc/version"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   Standard: $(kubectl exec runtime-standard -- cat /proc/version)"
echo "   gVisor:   $(kubectl exec runtime-gvisor -- cat /proc/version)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. dmesg — gVisor annonce son démarrage"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   Standard dmesg (premiere ligne):"
kubectl exec runtime-standard -- dmesg 2>/dev/null | head -1 || echo "   (dmesg non disponible dans le container standard)"
echo ""
echo "   gVisor dmesg:"
kubectl exec runtime-gvisor -- dmesg 2>/dev/null | head -3

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Comparaison des syscalls disponibles (/proc/kallsyms)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
STANDARD_SYMS=$(kubectl exec runtime-standard -- wc -l /proc/kallsyms 2>/dev/null | awk '{print $1}' || echo "N/A")
GVISOR_SYMS=$(kubectl exec runtime-gvisor -- wc -l /proc/kallsyms 2>/dev/null | awk '{print $1}' || echo "N/A")
echo "   Standard /proc/kallsyms: $STANDARD_SYMS symboles kernel"
echo "   gVisor   /proc/kallsyms: $GVISOR_SYMS symboles kernel"
echo "   (gVisor expose uniquement les syscalls qu'il implémente)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Placement des pods"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
kubectl get pods runtime-standard runtime-gvisor -o wide

echo ""
echo "Nettoyage..."
kubectl delete pod runtime-standard runtime-gvisor

echo ""
echo "✓ Démonstration terminée!"
echo ""
echo "OBSERVATIONS CLÉS:"
echo "  - runc: isolation via namespaces Linux (partage le kernel hôte)"
echo "  - gVisor: kernel user-space (runsc intercepte tous les syscalls)"
echo "  - gVisor renforce l'isolation: une faille kernel n'affecte pas le pod"
echo "  - gVisor a un coût en performance (overhead des syscalls interceptés)"
echo ""
echo "PROCHAINE ÉTAPE: Exécutez 04-deploy-with-runtimeclass.sh"

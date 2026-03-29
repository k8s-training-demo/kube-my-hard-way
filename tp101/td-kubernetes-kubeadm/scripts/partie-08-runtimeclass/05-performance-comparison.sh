#!/bin/bash
# Partie 7 - Comparaison de performance runc vs gVisor
# À exécuter sur le MASTER

set -e

echo "=== Comparaison de performance : runc vs gVisor ==="
echo ""
echo "Ce test mesure l'overhead de gVisor sur des opérations typiques."
echo "gVisor intercepte TOUS les syscalls → overhead systématique."
echo ""

# Lancer les deux pods de test
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: perf-runc
spec:
  containers:
  - name: bench
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
---
apiVersion: v1
kind: Pod
metadata:
  name: perf-gvisor
spec:
  runtimeClassName: gvisor
  containers:
  - name: bench
    image: busybox
    command: ['sh', '-c', 'sleep 3600']
EOF

kubectl wait --for=condition=Ready pod/perf-runc pod/perf-gvisor --timeout=90s

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Démarrage de pod (startup time approximatif)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
# Mesure via les timestamps Kubernetes
RUNC_START=$(kubectl get pod perf-runc -o jsonpath='{.metadata.creationTimestamp}')
GVISOR_START=$(kubectl get pod perf-gvisor -o jsonpath='{.metadata.creationTimestamp}')
echo "   (voir les timestamps dans kubectl get pods -o wide)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Performance I/O : lecture de fichiers (/proc)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
bench() {
    local pod="$1" label="$2" cmd="$3"
    # POURQUOI /proc/uptime: busybox ne supporte pas date +%N,
    # /proc/uptime donne des secondes avec décimales (ex: 4698.32)
    local start end ms
    start=$(kubectl exec "$pod" -- awk '{print $1}' /proc/uptime 2>/dev/null)
    kubectl exec "$pod" -- sh -c "$cmd" > /dev/null 2>&1 || true
    end=$(kubectl exec "$pod" -- awk '{print $1}' /proc/uptime 2>/dev/null)
    ms=$(awk "BEGIN{printf \"%.0f\", ($end - $start) * 1000}" 2>/dev/null)
    printf "   %-10s : %s ms\n" "$label" "$ms"
}

bench perf-runc   "runc  " 'for i in $(seq 1 100); do cat /proc/uptime > /dev/null; done'
bench perf-gvisor "gVisor" 'for i in $(seq 1 100); do cat /proc/uptime > /dev/null; done'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Performance syscall : fork/exec"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
bench perf-runc   "runc  " 'for i in $(seq 1 50); do /bin/true; done'
bench perf-gvisor "gVisor" 'for i in $(seq 1 50); do /bin/true; done'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Performance réseau : requêtes DNS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
bench perf-runc   "runc  " 'for i in $(seq 1 10); do nslookup kubernetes.default > /dev/null 2>&1; done'
bench perf-gvisor "gVisor" 'for i in $(seq 1 10); do nslookup kubernetes.default > /dev/null 2>&1; done'

echo ""
echo "Nettoyage..."
kubectl delete pod perf-runc perf-gvisor

echo ""
echo "✓ Comparaison de performance terminée!"
echo ""
echo "RÉSUMÉ:"
echo "  - gVisor a un overhead mesurable sur les syscalls (fork/exec, I/O)"
echo "  - Le coût est justifié pour les workloads qui nécessitent une isolation forte:"
echo "      * Exécution de code non-fiable (CI/CD, sandbox utilisateur)"
echo "      * Traitement de données sensibles"
echo "      * Multi-tenancy strict"
echo "  - Pour les workloads I/O-intensifs ou CPU-intensifs, runc est plus adapté"

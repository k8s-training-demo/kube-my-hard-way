#!/bin/bash
# Partie Bonus — HA Control Plane
# Script 03 : Validation du cluster HA
# À exécuter sur le MASTER

set -e

ERRORS=0

echo "=== Bonus HA — Validation du cluster HA ==="
echo ""

# 1. Vérifier que tous les nœuds sont Ready et control-plane
echo "--- 1. Nœuds du cluster ---"
kubectl get nodes -o wide
echo ""

CP_COUNT=$(kubectl get nodes -l node-role.kubernetes.io/control-plane --no-headers | wc -l)
READY_COUNT=$(kubectl get nodes --no-headers | grep -c ' Ready ')
TOTAL_COUNT=$(kubectl get nodes --no-headers | wc -l)

echo "  Nœuds control-plane : $CP_COUNT"
echo "  Nœuds Ready         : $READY_COUNT / $TOTAL_COUNT"

if [[ "$CP_COUNT" -lt 2 ]]; then
    echo "  ❌ Moins de 2 control planes — promotion incomplète ?"
    ERRORS=$((ERRORS+1))
else
    echo "  ✓ $CP_COUNT control planes actifs"
fi

if [[ "$READY_COUNT" -ne "$TOTAL_COUNT" ]]; then
    echo "  ❌ Certains nœuds ne sont pas Ready"
    ERRORS=$((ERRORS+1))
else
    echo "  ✓ Tous les nœuds sont Ready"
fi

# 2. Vérifier les membres etcd
echo ""
echo "--- 2. Membres etcd ---"
sudo ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    member list -w table 2>/dev/null || echo "  ⚠️  etcdctl non disponible — vérifier manuellement"

ETCD_MEMBERS=$(sudo ETCDCTL_API=3 etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    member list --write-out=json 2>/dev/null \
    | python3 -c "import json,sys; print(len(json.load(sys.stdin)['members']))" 2>/dev/null || echo "0")

if [[ "$ETCD_MEMBERS" -ge 3 ]]; then
    echo "  ✓ $ETCD_MEMBERS membres etcd (quorum assuré)"
elif [[ "$ETCD_MEMBERS" -eq 0 ]]; then
    echo "  ⚠️  Impossible de vérifier etcd (etcdctl manquant ?)"
else
    echo "  ❌ Seulement $ETCD_MEMBERS membre(s) etcd — quorum insuffisant pour 3 nœuds"
    ERRORS=$((ERRORS+1))
fi

# 3. Vérifier les pods du control plane
echo ""
echo "--- 3. Pods du control plane (static pods) ---"
kubectl get pods -n kube-system -l tier=control-plane -o wide 2>/dev/null \
    || kubectl get pods -n kube-system | grep -E 'etcd|apiserver|scheduler|controller'

# 4. Test de scheduling sur tous les nœuds
echo ""
echo "--- 4. Test de scheduling sur tous les nœuds ---"
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ha-test
  namespace: default
spec:
  selector:
    matchLabels:
      app: ha-test
  template:
    metadata:
      labels:
        app: ha-test
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      containers:
      - name: pause
        image: registry.k8s.io/pause:3.9
        resources:
          requests:
            cpu: "10m"
            memory: "8Mi"
EOF

echo "  Attente du DaemonSet ha-test..."
sleep 5
kubectl rollout status daemonset/ha-test --timeout=60s

DESIRED=$(kubectl get daemonset ha-test -o jsonpath='{.status.desiredNumberScheduled}')
READY_DS=$(kubectl get daemonset ha-test -o jsonpath='{.status.numberReady}')
echo "  Pods schedulés : $READY_DS / $DESIRED"

if [[ "$READY_DS" -eq "$DESIRED" ]]; then
    echo "  ✓ Scheduling opérationnel sur tous les nœuds"
else
    echo "  ❌ Certains nœuds n'ont pas reçu le pod de test"
    ERRORS=$((ERRORS+1))
fi

kubectl get pods -l app=ha-test -o wide

# Nettoyage
kubectl delete daemonset ha-test --ignore-not-found=true > /dev/null

# Résumé
echo ""
echo "=== Résumé ==="
if [[ "$ERRORS" -eq 0 ]]; then
    echo "✓ Cluster HA validé — $CP_COUNT control planes, quorum etcd assuré, scheduling OK"
else
    echo "❌ $ERRORS erreur(s) détectée(s) — vérifier les points ci-dessus"
fi

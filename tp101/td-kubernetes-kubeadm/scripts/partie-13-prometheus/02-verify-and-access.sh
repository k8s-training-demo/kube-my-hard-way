#!/bin/bash
# Partie 12 - Vérifier l'installation et accéder aux interfaces
# À exécuter sur le nœud MASTER

set -e

echo "=== Partie 12 — Vérification et accès ==="
echo ""

echo "1. État des pods dans le namespace monitoring :"
kubectl get pods -n monitoring -o wide
echo ""

echo "2. Services exposés :"
kubectl get svc -n monitoring | grep -E "NAME|grafana|prometheus|alertmanager"
echo ""

echo "3. CRDs installés par Prometheus Operator :"
kubectl get crd | grep -E "monitoring.coreos.com" | awk '{print "  -", $1}'
echo ""

echo "4. ServiceMonitors actifs (cibles de scrape) :"
kubectl get servicemonitor -n monitoring | head -15
echo ""

echo "5. Règles d'alerte :"
RULES=$(kubectl get prometheusrules -n monitoring --no-headers 2>/dev/null | wc -l)
echo "   $RULES PrometheusRule(s) installées"
kubectl get prometheusrules -n monitoring 2>/dev/null | head -8
echo ""

echo "=== Commandes d'accès ==="
echo ""

MASTER_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "<master-ip>")

echo "--- Grafana (admin / admin) ---"
echo "  Port-forward local :"
echo "    kubectl port-forward svc/kube-prom-grafana 3000:80 -n monitoring &"
echo "    http://localhost:3000"
echo ""
echo "  Ou via NodePort (si patché) :"
echo "    kubectl patch svc kube-prom-grafana -n monitoring \\"
echo "      --type='json' -p '[{\"op\":\"replace\",\"path\":\"/spec/type\",\"value\":\"NodePort\"}]'"
echo "    PORT=\$(kubectl get svc kube-prom-grafana -n monitoring \\"
echo "             -o jsonpath='{.spec.ports[0].nodePort}')"
echo "    http://$MASTER_IP:\$PORT"
echo ""

echo "--- Prometheus UI ---"
echo "  kubectl port-forward svc/kube-prom-kube-prometheus-stack-prometheus 9090 -n monitoring &"
echo "  http://localhost:9090"
echo ""

echo "--- Alertmanager ---"
echo "  kubectl port-forward svc/kube-prom-alertmanager 9093 -n monitoring &"
echo "  http://localhost:9093"
echo ""

echo "=== Vérification terminée ==="

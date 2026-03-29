#!/bin/bash
# Partie 12 - Installation de kube-prometheus-stack via Helm
# À exécuter sur le nœud MASTER
# Prérequis : helm installé (voir 00-install-helm.sh si besoin)

set -e

echo "=== Partie 12 — Installation kube-prometheus-stack ==="
echo ""

# --- Vérifications préalables ---
echo "1. Vérifications préalables :"

if ! command -v helm &>/dev/null; then
    echo "   ✗ helm non trouvé — installer avec :"
    echo "     curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    exit 1
fi
echo "   ✓ helm $(helm version --short)"

if ! kubectl cluster-info &>/dev/null; then
    echo "   ✗ cluster non accessible"
    exit 1
fi
echo "   ✓ cluster accessible"

# Vérifier qu'un StorageClass est disponible pour les PVCs
SC=$(kubectl get storageclass -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$SC" ]; then
    echo "   ⚠ Aucun StorageClass trouvé — Prometheus tournera sans persistance"
    echo "     (acceptable pour le TD, déconseillé en production)"
    STORAGE_OPTS="--set prometheus.prometheusSpec.storageSpec={} \
                  --set alertmanager.alertmanagerSpec.storage={}"
else
    echo "   ✓ StorageClass : $SC"
    STORAGE_OPTS=""
fi
echo ""

# --- Ajout du repo Helm ---
echo "2. Ajout du repo prometheus-community :"
helm repo add prometheus-community \
    https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
echo "   ✓ Repo à jour"
echo ""

# --- Installation ---
echo "3. Installation de kube-prometheus-stack :"
echo "   Namespace : monitoring"
echo "   Version   : 65.x (stable 2025)"
echo ""

helm upgrade --install kube-prom \
    prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    --set grafana.adminPassword=admin \
    --set prometheus.prometheusSpec.retention=7d \
    --set prometheus.prometheusSpec.scrapeInterval=30s \
    --set grafana.sidecar.dashboards.enabled=true \
    --set grafana.sidecar.dashboards.label=grafana_dashboard \
    $STORAGE_OPTS \
    --wait \
    --timeout 10m

echo ""
echo "=== Installation terminée ==="
echo ""
echo "Vérification : kubectl get pods -n monitoring"
kubectl get pods -n monitoring

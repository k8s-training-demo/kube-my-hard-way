#!/bin/bash
# Partie 13 - Exposition de Grafana via Gateway API + nip.io
# À exécuter sur le nœud MASTER
#
# nip.io : service DNS wildcard — grafana.<IP>.nip.io résout vers <IP>
# Aucune configuration DNS requise.
#
# Implémentation : Nginx Gateway Fabric (nginx/sig-network)
# Note NGF : chaque Gateway génère son propre Service nginx dans le même namespace.
#            Ce service est LoadBalancer par défaut — on le patche en NodePort.

set -e

echo "=== Exposition de Grafana — Gateway API + nip.io ==="
echo ""

# --- 1. CRDs Gateway API standard ---
echo "1. Installation des CRDs Gateway API v1.2 :"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
echo "   ✓ CRDs installés"
echo ""

# --- 2. Nginx Gateway Fabric ---
echo "2. Installation de Nginx Gateway Fabric :"
# POURQUOI: NGF est l'implémentation officielle nginx du standard Gateway API.
#           Le chart installe le controller ; chaque Gateway crée son propre pod+service nginx.
helm upgrade --install ngf \
    oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
    --namespace nginx-gateway \
    --create-namespace \
    --wait --timeout 3m
echo "   ✓ Nginx Gateway Fabric prêt"
echo ""

# --- 3. IP publique du master ---
echo "3. Récupération de l'IP du master :"
MASTER_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
GRAFANA_HOST="grafana.${MASTER_IP}.nip.io"
echo "   IP master  : $MASTER_IP"
echo "   Hostname   : $GRAFANA_HOST"
echo ""

# --- 4. Gateway ---
echo "4. Création du Gateway (namespace monitoring) :"
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: monitoring-gateway
  namespace: monitoring
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.${MASTER_IP}.nip.io"
EOF
echo "   ✓ Gateway créé"
echo ""

# --- 5. Configuration NodePort via NginxProxy ---
echo "5. Configuration du service Gateway en NodePort (via NginxProxy) :"
# POURQUOI: NGF v2 crée un Service LoadBalancer par Gateway et le reconcilie en continu.
#           Patcher le service directement ne tient pas — NGF le réécrase.
#           La seule façon correcte est de passer par la CR NginxProxy référencée par le Gateway.
kubectl apply -f - <<EOF
apiVersion: gateway.nginx.org/v1alpha2
kind: NginxProxy
metadata:
  name: monitoring-proxy-config
  namespace: monitoring
spec:
  kubernetes:
    service:
      type: NodePort
EOF
echo "   ✓ NginxProxy créé"
echo ""

# Mettre à jour le Gateway pour référencer le NginxProxy
echo "   Attachement du NginxProxy au Gateway :"
kubectl patch gateway monitoring-gateway -n monitoring --type='merge' -p '{
  "spec": {
    "infrastructure": {
      "parametersRef": {
        "group": "gateway.nginx.org",
        "kind": "NginxProxy",
        "name": "monitoring-proxy-config"
      }
    }
  }
}'
echo "   ✓ Gateway mis à jour"
echo ""

echo "   Attente de la recréation du service en NodePort (30s max)..."
for i in $(seq 1 10); do
    SVC_TYPE=$(kubectl get svc monitoring-gateway-nginx -n monitoring \
        -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
    if [ "$SVC_TYPE" = "NodePort" ]; then
        echo "   ✓ Service en NodePort"
        break
    fi
    sleep 3
done
echo ""

# --- 6. HTTPRoute Grafana ---
echo "6. Création de l'HTTPRoute pour Grafana :"
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: grafana
  namespace: monitoring
spec:
  parentRefs:
  - name: monitoring-gateway
    namespace: monitoring
  hostnames:
  - "${GRAFANA_HOST}"
  rules:
  - backendRefs:
    - name: kube-prom-grafana
      port: 80
EOF
echo "   ✓ HTTPRoute créé"
echo ""

# --- 7. Attente que la Gateway soit programmée ---
echo "7. Attente de la Gateway (30s max) :"
for i in $(seq 1 15); do
    STATUS=$(kubectl get gateway monitoring-gateway -n monitoring \
        -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null || echo "")
    if [ "$STATUS" = "True" ]; then
        echo "   ✓ Gateway programmée"
        break
    fi
    echo "   attente... ($i/15)"
    sleep 2
done
echo ""

# --- 8. Récupération du NodePort final ---
HTTP_NODEPORT=$(kubectl get svc monitoring-gateway-nginx -n monitoring \
    -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# --- 9. Résumé ---
echo "=== Accès Grafana ==="
echo ""
echo "  URL  : http://${GRAFANA_HOST}:${HTTP_NODEPORT}"
echo "  User : admin"
echo "  Pass : admin"
echo ""
echo "Note : nip.io résout automatiquement ${GRAFANA_HOST} → ${MASTER_IP}"
echo "       Aucune entrée DNS à créer."
echo ""
echo "Vérification des ressources Gateway API :"
kubectl get gateway,httproute -n monitoring
echo ""
kubectl get svc monitoring-gateway-nginx -n monitoring

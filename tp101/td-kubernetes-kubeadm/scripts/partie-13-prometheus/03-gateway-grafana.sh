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

# --- 5. Patch du service généré en NodePort ---
echo "5. Passage du service Gateway en NodePort :"
# POURQUOI: NGF crée un Service LoadBalancer par Gateway (monitoring-gateway-nginx).
#           Sur Exoscale sans CCM, l'EXTERNAL-IP reste <pending>.
#           On le patche en NodePort pour un accès direct via l'IP du nœud.
echo "   Attente du service monitoring-gateway-nginx..."
for i in $(seq 1 20); do
    kubectl get svc monitoring-gateway-nginx -n monitoring &>/dev/null && break
    sleep 3
done

kubectl patch svc monitoring-gateway-nginx -n monitoring \
    --type='json' \
    -p '[{"op":"replace","path":"/spec/type","value":"NodePort"}]'
echo "   ✓ Service patché en NodePort"
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

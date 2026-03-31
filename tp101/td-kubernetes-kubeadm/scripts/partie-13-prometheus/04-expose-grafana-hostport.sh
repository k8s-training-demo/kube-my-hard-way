#!/bin/bash
# Partie 13 - Option B : Exposer Grafana sur le port 80 via un static pod nginx
# À exécuter sur le nœud MASTER
#
# Déploie un pod nginx en hostPort 80 qui proxifie vers le service Grafana (ClusterIP).
# Résultat : Grafana accessible sur http://<master-ip>:80 — aucun NLB, aucun token requis.
#
# Deux routes d'accès :
#   - http://<master-ip>:80      ← via reverse proxy (simule un LoadBalancer)
#   - http://<master-ip>:30812   ← via NodePort direct

set -e

echo "=== Exposition de Grafana sur le port 80 (reverse proxy nginx) ==="
echo ""

# --- 1. Vérifications ---
echo "1. Vérification que Grafana est déployé :"
GRAFANA_SVC=$(kubectl get svc kube-prom-grafana -n monitoring \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -z "$GRAFANA_SVC" ]; then
    echo "   ✗ Service kube-prom-grafana introuvable dans le namespace monitoring"
    echo "   → Installer kube-prometheus-stack d'abord (01-install-stack.sh)"
    false
fi
echo "   ✓ Grafana ClusterIP : $GRAFANA_SVC"
echo ""

# --- 2. Déploiement du reverse proxy nginx ---
echo "2. Déploiement du reverse proxy nginx :"
# POURQUOI un Deployment avec hostPort: On veut un pod nginx qui écoute directement
# sur le port 80 du master et proxifie vers le ClusterIP de Grafana.
# hostPort = le port est exposé sur l'interface réseau du nœud, comme un mini-LB local.
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-lb
  namespace: monitoring
  labels:
    app: grafana-lb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana-lb
  template:
    metadata:
      labels:
        app: grafana-lb
    spec:
      # Forcer le pod sur le master (pour que le port 80 soit sur l'IP connue)
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
          hostPort: 80
          protocol: TCP
        volumeMounts:
        - name: nginx-conf
          mountPath: /etc/nginx/conf.d/default.conf
          subPath: default.conf
          readOnly: true
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        resources:
          requests:
            cpu: 10m
            memory: 16Mi
          limits:
            cpu: 100m
            memory: 64Mi
      volumes:
      - name: nginx-conf
        configMap:
          name: grafana-lb-nginx-conf
EOF
echo "   ✓ Deployment créé"
echo ""

# --- 3. ConfigMap nginx ---
echo "3. Configuration nginx (reverse proxy → Grafana) :"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-lb-nginx-conf
  namespace: monitoring
data:
  default.conf: |
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://kube-prom-grafana.monitoring.svc.cluster.local:80;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }
    }
EOF
echo "   ✓ ConfigMap créé"
echo ""

# --- 4. Redémarrage du pod pour prendre la ConfigMap ---
echo "4. Redémarrage du pod :"
kubectl rollout restart deployment/grafana-lb -n monitoring
kubectl rollout status deployment/grafana-lb -n monitoring --timeout=60s
echo "   ✓ Pod prêt"
echo ""

# --- 5. Récupération de l'IP et affichage ---
MASTER_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo "=== Accès Grafana ==="
echo ""
echo "  Option A — LoadBalancer (reverse proxy) :"
echo "    URL  : http://${MASTER_IP}"
echo ""
echo "  Option B — NodePort direct :"
echo "    URL  : http://${MASTER_IP}:30812"
echo ""
echo "  Credentials : admin / admin"
echo ""
echo "Les deux routes mènent au même Grafana — comparer les approches !"
echo ""

# --- 6. Test rapide ---
echo "6. Test de connexion :"
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 || echo "000")
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "   ✓ Port 80 répond (HTTP $HTTP_CODE)"
else
    echo "   ⚠ Port 80 retourne HTTP $HTTP_CODE — vérifier le pod grafana-lb"
fi

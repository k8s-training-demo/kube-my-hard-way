#!/bin/bash
# Partie 13 - Option A : Installation du Cloud Controller Manager Exoscale
# À exécuter sur le nœud MASTER
#
# Prérequis : le Secret "exoscale-ccm-credentials" doit déjà exister dans kube-system
#             (fichier ccm-secret-etudiant-XX.yaml fourni par l'instructeur)
#
# Résultat : Service type:LoadBalancer → NLB Exoscale créé automatiquement
#            kube-prom-grafana passera en LoadBalancer → EXTERNAL-IP assignée

set -e

CCM_VERSION="0.34.0"
ZONE="${1:-de-fra-1}"

echo "=== Installation du Cloud Controller Manager Exoscale ==="
echo "   Version : $CCM_VERSION"
echo "   Zone    : $ZONE"
echo ""

# --- 1. Vérification du secret ---
echo "1. Vérification du secret Exoscale :"
if ! kubectl get secret exoscale-ccm-credentials -n kube-system &>/dev/null; then
    echo "   ✗ Secret 'exoscale-ccm-credentials' absent de kube-system"
    echo ""
    echo "   → Appliquer le fichier fourni par l'instructeur :"
    echo "     kubectl apply -f ccm-secret-etudiant-XX.yaml"
    false
fi
echo "   ✓ Secret présent"
echo ""

# --- 2. Configurer kubeadm pour le cloud-provider externe ---
echo "2. Configuration du cloud-provider externe :"
# POURQUOI: kubeadm doit savoir qu'un CCM externe gère le cloud-provider.
#           Sans ça, kubelet tente de gérer lui-même les routes cloud et échoue.
KUBELET_EXTRA="/etc/default/kubelet"
if ! grep -q "cloud-provider=external" "$KUBELET_EXTRA" 2>/dev/null; then
    echo 'KUBELET_EXTRA_ARGS="--cloud-provider=external"' | sudo tee "$KUBELET_EXTRA" > /dev/null
    sudo systemctl daemon-reload
    sudo systemctl restart kubelet
    echo "   ✓ kubelet configuré avec --cloud-provider=external"
else
    echo "   ✓ cloud-provider=external déjà configuré"
fi
echo ""

# --- 3. Installation du CCM Exoscale ---
echo "3. Installation du CCM Exoscale :"
# POURQUOI: Le CCM surveille les Service type:LoadBalancer et crée/supprime
#           automatiquement les NLB Exoscale correspondants.
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-controller-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:cloud-controller-manager
rules:
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "create", "update"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["nodes/status"]
  verbs: ["patch"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["services/status"]
  verbs: ["list", "patch", "update", "watch"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["create"]
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["create", "get", "list", "watch", "update"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests"]
  verbs: ["list", "watch"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests/approval"]
  verbs: ["update"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["signers"]
  resourceNames: ["kubernetes.io/kubelet-serving"]
  verbs: ["approve"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:cloud-controller-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:cloud-controller-manager
subjects:
- kind: ServiceAccount
  name: cloud-controller-manager
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: exoscale-cloud-controller-manager
  namespace: kube-system
  labels:
    app: exoscale-cloud-controller-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: exoscale-cloud-controller-manager
  template:
    metadata:
      labels:
        app: exoscale-cloud-controller-manager
    spec:
      dnsPolicy: Default
      hostNetwork: true
      serviceAccountName: cloud-controller-manager
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node.cloudprovider.kubernetes.io/uninitialized
        value: "true"
        effect: NoSchedule
      - key: CriticalAddonsOnly
        operator: Exists
      nodeSelector:
        node-role.kubernetes.io/control-plane: ""
      containers:
      - name: exoscale-cloud-controller-manager
        image: exoscale/cloud-controller-manager:${CCM_VERSION}
        args:
        - --leader-elect=false
        - --allow-untagged-cloud
        env:
        - name: EXOSCALE_API_KEY
          valueFrom:
            secretKeyRef:
              name: exoscale-ccm-credentials
              key: api-key
        - name: EXOSCALE_API_SECRET
          valueFrom:
            secretKeyRef:
              name: exoscale-ccm-credentials
              key: api-secret
        - name: EXOSCALE_API_ZONE
          valueFrom:
            secretKeyRef:
              name: exoscale-ccm-credentials
              key: zone
EOF
echo "   ✓ CCM déployé"
echo ""

# --- 4. Attente du CCM ---
echo "4. Attente du démarrage du CCM (60s max) :"
kubectl rollout status deployment/exoscale-cloud-controller-manager \
    -n kube-system --timeout=60s
echo "   ✓ CCM opérationnel"
echo ""

# --- 5. Patch de Grafana en LoadBalancer ---
echo "5. Patch du service Grafana en type LoadBalancer :"
# POURQUOI: Le CCM surveille les Service type:LoadBalancer.
#           En passant Grafana en LoadBalancer, Exoscale crée automatiquement un NLB.
kubectl patch svc kube-prom-grafana -n monitoring \
    --type='json' \
    -p '[{"op":"replace","path":"/spec/type","value":"LoadBalancer"}]'
echo "   ✓ Service Grafana patché en LoadBalancer"
echo ""

# --- 6. Attente de l'EXTERNAL-IP ---
echo "6. Attente de l'EXTERNAL-IP (NLB en cours de création, 3 min max) :"
MASTER_IP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane \
    -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

for i in $(seq 1 36); do
    EXTERNAL_IP=$(kubectl get svc kube-prom-grafana -n monitoring \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "<pending>" ]; then
        echo ""
        echo "   ✓ NLB Exoscale créé !"
        break
    fi
    printf "\r   Attente du NLB... (%ds)" $((i * 5))
    sleep 5
done

EXTERNAL_IP=$(kubectl get svc kube-prom-grafana -n monitoring \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

echo ""
echo "=== Accès Grafana ==="
echo ""
if [ -n "$EXTERNAL_IP" ]; then
    echo "  Option A — NLB Exoscale (Service LoadBalancer) :"
    echo "    URL  : http://${EXTERNAL_IP}"
    echo ""
fi
echo "  Option B — NodePort direct :"
echo "    URL  : http://${MASTER_IP}:30812"
echo ""
echo "  Credentials : admin / admin"
echo ""
echo "kubectl get svc kube-prom-grafana -n monitoring"
kubectl get svc kube-prom-grafana -n monitoring

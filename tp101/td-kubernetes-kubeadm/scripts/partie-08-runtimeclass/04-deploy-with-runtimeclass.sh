#!/bin/bash
# Partie 8 - Déploiement d'une application avec RuntimeClass
# Démontre :
#   1. runtimeClassName dans un Deployment (tous les pods utilisent gVisor)
#   2. Organisation par namespace : namespace dédié aux workloads sandboxés
#      (le namespace n'impose PAS gVisor automatiquement — runtimeClassName
#       doit toujours être spécifié dans chaque podSpec)
# À exécuter sur le MASTER

set -e

echo "=== Déploiement d'applications avec RuntimeClass ==="
echo ""

echo "1. Deployment avec runtimeClassName..."
# POURQUOI: runtimeClassName se place dans le podSpec (.spec.template.spec).
# Tous les pods créés par ce Deployment utiliseront runsc (gVisor).
# Sans ce champ, le runtime par défaut (runc) serait utilisé.
kubectl apply -f - << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  labels:
    app: secure-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      runtimeClassName: gvisor
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
EOF

echo "   Attente du déploiement..."
kubectl rollout status deployment/secure-app --timeout=90s

echo ""
echo "2. Pods créés et leur placement:"
kubectl get pods -l app=secure-app -o wide

echo ""
echo "3. Vérification du runtime sur chaque pod:"
for pod in $(kubectl get pods -l app=secure-app -o name | sed 's|pod/||'); do
    KERNEL=$(kubectl exec $pod -- uname -r 2>/dev/null)
    NODE=$(kubectl get pod $pod -o jsonpath='{.spec.nodeName}')
    echo "   $pod (nœud: $NODE) — kernel: $KERNEL"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Namespace dédié pour les workloads sandboxés"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
# POURQUOI un namespace dédié:
#   Un namespace "secure-ns" n'impose PAS gVisor automatiquement —
#   runtimeClassName doit toujours être spécifié dans chaque podSpec.
#
#   L'intérêt est organisationnel :
#     - RBAC restreint : seuls certains utilisateurs peuvent créer des pods ici
#     - NetworkPolicy : isolation réseau des workloads sensibles
#     - ResourceQuota : limiter les ressources allouées aux workloads sandbox
#     - Visibilité : "tout ce qui est dans secure-ns tourne sous gVisor" par convention
#
#   Pour imposer gVisor sans runtimeClassName dans le podSpec (enforcement réel),
#   il faut activer le feature gate RuntimeClassInPodDefaults (beta K8s 1.31)
#   et annoter la RuntimeClass avec "pod.kubernetes.io/default-runtimeclass".
#   Ce n'est pas ce qu'on démontre ici — voir les slides pour l'explication.
kubectl create namespace secure-ns 2>/dev/null || true

kubectl apply -n secure-ns -f - << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: sandboxed-workload
spec:
  runtimeClassName: gvisor
  containers:
  - name: app
    image: busybox
    command: ['sh', '-c', 'echo "Running in gVisor sandbox" && uname -r && sleep 60']
EOF

kubectl wait -n secure-ns --for=condition=Ready pod/sandboxed-workload --timeout=60s
echo "   Output du pod sandboxé:"
kubectl logs -n secure-ns sandboxed-workload

echo ""
echo "5. État final:"
kubectl get pods -l app=secure-app -o wide
kubectl get pods -n secure-ns

echo ""
echo "Nettoyage..."
kubectl delete deployment secure-app
kubectl delete namespace secure-ns

echo ""
echo "✓ Déploiement avec RuntimeClass démontré!"
echo ""
echo "PROCHAINE ÉTAPE: Exécutez 05-performance-comparison.sh pour mesurer l'overhead"

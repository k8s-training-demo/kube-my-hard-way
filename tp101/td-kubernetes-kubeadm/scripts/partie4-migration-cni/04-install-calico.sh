#!/bin/bash
# Partie 4 - Installation de Calico
# À exécuter sur le nœud MASTER

set -e

echo "=== Installation de Calico CNI ==="
echo ""

# Version de Calico
CALICO_VERSION="v3.26.1"

# Vérifier la version de Kubernetes pour la compatibilité
echo "Vérification de la compatibilité Calico..."
K8S_VERSION=$(kubectl version --short 2>/dev/null | grep 'Server Version' | awk '{print $3}' | cut -d. -f1-2)
if [ -z "$K8S_VERSION" ]; then
    echo "   ⚠️  Impossible de détecter la version de Kubernetes"
    echo "   Continuons avec Calico $CALICO_VERSION"
else
    echo "   Version Kubernetes détectée: $K8S_VERSION"
    echo "   Calico $CALICO_VERSION est généralement compatible avec Kubernetes 1.25-1.28"
    if [[ "$K8S_VERSION" == "1.24" ]] || [[ "$K8S_VERSION" == "1.23" ]] || [[ "$K8S_VERSION" == "1.22" ]]; then
        echo "   ⚠️  Votre version de Kubernetes ($K8S_VERSION) est ancienne"
        echo "   Pour Kubernetes < 1.25, utilisez Calico v3.25.x ou antérieur"
        echo "   Continuons mais des problèmes peuvent survenir..."
    fi
fi

echo "1. Téléchargement du manifest Calico $CALICO_VERSION:"

# Télécharger le manifest avec vérification
echo "   Téléchargement en cours..."
if ! curl -O -L --fail https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml; then
    echo "   ❌ Échec du téléchargement du manifest Calico"
    echo "   Vérifiez votre connexion internet ou essayez une autre version"
    echo "   Vous pouvez télécharger manuellement le manifest depuis:"
    echo "   https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/calico.yaml"
    exit 1
fi

# Vérifier que le fichier a été téléchargé
if [ ! -f "calico.yaml" ] || [ ! -s "calico.yaml" ]; then
    echo "   ❌ Le fichier calico.yaml est vide ou n'a pas été téléchargé correctement"
    exit 1
fi

echo "   ✓ Manifest Calico téléchargé avec succès"

echo ""
echo "2. Configuration du réseau pod pour Calico:"

# Détecter automatiquement le POD_CIDR du cluster
echo "   Détection du CIDR des pods..."

# Essayer de récupérer le CIDR depuis la configuration kubeadm
if [ -f /etc/kubernetes/manifests/kube-controller-manager.yaml ]; then
    POD_CIDR=$(grep -oP '--pod-network-cidr=\K[^\s]+' /etc/kubernetes/manifests/kube-controller-manager.yaml 2>/dev/null || true)
elif [ -f /etc/kubernetes/kube-controller-manager.conf ]; then
    # Alternative method for some distributions
    POD_CIDR=$(kubectl get cm -n kube-system kube-controller-manager -o jsonpath='{.data.kube-controller-manager.yaml}' 2>/dev/null | grep -oP '--pod-network-cidr=\K[^\s]+' || true)
fi

# Si la détection automatique échoue, utiliser la valeur par défaut
if [ -z "$POD_CIDR" ]; then
    echo "   ⚠️  Impossible de détecter automatiquement le CIDR des pods"
    echo "   Utilisation de la valeur par défaut: 10.244.0.0/16"
    POD_CIDR="10.244.0.0/16"
else
    echo "   CIDR des pods détecté: $POD_CIDR"
fi

# Modifier le manifest pour utiliser le bon CIDR
if grep -q "192.168.0.0/16" calico.yaml; then
    echo "   Configuration du manifest Calico avec le CIDR: $POD_CIDR"
    sed -i.bak "s|192.168.0.0/16|$POD_CIDR|g" calico.yaml
    echo "   ✓ Manifest configuré"
else
    echo "   ⚠️  Le manifest Calico ne contient pas le CIDR par défaut 192.168.0.0/16"
    echo "   Vérifiez manuellement que le CIDR est correct dans calico.yaml"
fi

echo ""
echo "3. Configuration du mode réseau (VXLAN pour Exoscale/cloud providers):"

# Sur Exoscale et la plupart des cloud providers, IPIP (IP protocol 4) est bloqué
# par les security groups. On force VXLAN dès le départ dans le manifest.
echo "   Passage en mode VXLAN (compatibilité cloud — IPIP bloqué sur Exoscale)..."
# Désactiver IPIP dans les variables d'environnement du DaemonSet calico-node
sed -i 's/value: "Always"$/value: "Never"/' calico.yaml
# Activer VXLAN en ajoutant la variable après CALICO_IPV4POOL_IPIP
python3 - <<'PYEOF'
import re, sys

with open('calico.yaml', 'r') as f:
    content = f.read()

# Vérifier si CALICO_IPV4POOL_VXLAN est déjà présent
if 'CALICO_IPV4POOL_VXLAN' not in content:
    # Insérer CALICO_IPV4POOL_VXLAN: Always après CALICO_IPV4POOL_IPIP block
    content = re.sub(
        r'(name: CALICO_IPV4POOL_IPIP\n\s+value: "Never")',
        r'\1\n            - name: CALICO_IPV4POOL_VXLAN\n              value: "Always"',
        content
    )
    with open('calico.yaml', 'w') as f:
        f.write(content)
    print("   ✓ VXLAN activé dans le manifest")
else:
    print("   ✓ VXLAN déjà configuré dans le manifest")
PYEOF
echo ""

echo "4. Application du manifest Calico:"
kubectl apply -f calico.yaml

echo ""
echo "5. Attente du déploiement de Calico..."
echo "   Cela peut prendre 2-5 minutes..."

# Attendre uniquement le calico-node du master (les workers ont kubelet arrêté à ce stade)
MASTER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" != null) | .metadata.name')
echo "   Attente du calico-node sur le master ($MASTER_NODE)..."
kubectl wait --for=condition=ready pod \
    -l k8s-app=calico-node \
    -n kube-system \
    --field-selector "spec.nodeName=$MASTER_NODE" \
    --timeout=420s

# Attendre que calico-kube-controllers soit prêt
kubectl wait --for=condition=ready pod -l k8s-app=calico-kube-controllers -n kube-system --timeout=120s

echo ""
echo "6. Vérification de la configuration Calico:"

# Vérifier que les pods Calico sont en cours d'exécution
echo "   Vérification des pods Calico..."
CALICO_NODES=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers | wc -l)
if [ "$CALICO_NODES" -eq 0 ]; then
    echo "   ❌ Aucun pod calico-node trouvé"
    exit 1
fi

echo ""
echo "✓ Calico installé avec succès (mode VXLAN) sur le master !"
echo "══════════════════════════════════════════════════════════"
echo "  → MAINTENANT vous pouvez démarrer kubelet sur les workers"
echo "══════════════════════════════════════════════════════════"
echo ""

echo "   Composants Calico:"
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
kubectl get pods -n kube-system -l k8s-app=calico-kube-controllers

echo ""
echo "7. Recyclage de kube-proxy et CoreDNS (post-migration CNI)..."
kubectl rollout restart daemonset/kube-proxy -n kube-system
kubectl delete pods -n kube-system -l k8s-app=kube-dns
echo "   ✓ kube-proxy redémarré, CoreDNS pods recyclés"
echo ""

echo "8. Redémarrage de kubelet sur les workers..."
echo "   Le script vient d'afficher 'Calico installé avec succès' — c'est le signal."
echo "   Exécutez maintenant sur CHAQUE nœud worker :"
echo "   sudo systemctl start kubelet"
echo ""

echo "9. Sauvegarde du manifest:"
mkdir -p ~/calico-manifests
mv calico.yaml ~/calico-manifests/
mv calico.yaml.bak ~/calico-manifests/ 2>/dev/null || true
echo "   ✓ Manifest sauvegardé dans ~/calico-manifests/"

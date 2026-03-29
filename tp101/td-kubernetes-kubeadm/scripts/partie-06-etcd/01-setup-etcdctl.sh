#!/bin/bash
# Partie 6 - Setup etcdctl et vérification de la connexion
# À exécuter sur le nœud MASTER uniquement (stacked etcd)

set -e

echo "=== Setup etcdctl ==="
echo ""

# Vérifier qu'on est bien sur le master
if ! [ -f /etc/kubernetes/pki/etcd/ca.crt ]; then
    echo "❌ Certificats etcd introuvables — ce script doit s'exécuter sur le master"
    false
fi

echo "1. Installation d'etcdctl:"
# etcdctl est fourni dans le package etcd-client sur certaines distros,
# mais sur CentOS/RHEL la façon la plus fiable est de l'extraire depuis l'image etcd du cluster.
if ! command -v etcdctl &>/dev/null; then
    echo "   etcdctl absent — installation depuis l'image etcd du cluster..."
    ETCD_VERSION=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}' | cut -d: -f2)
    echo "   Version etcd du cluster : $ETCD_VERSION"
    # Extraire etcdctl depuis le conteneur etcd en cours d'exécution
    ETCD_POD=$(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}')
    kubectl -n kube-system cp "${ETCD_POD}:/usr/local/bin/etcdctl" /usr/local/bin/etcdctl
    chmod +x /usr/local/bin/etcdctl
    echo "   ✓ etcdctl installé dans /usr/local/bin/etcdctl"
else
    echo "   ✓ etcdctl déjà présent : $(which etcdctl)"
fi
echo ""

echo "2. Variables d'environnement obligatoires:"
echo ""
echo "   # Copiez-collez ces exports dans votre shell :"
echo "   export ETCDCTL_API=3"
echo "   export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt"
echo "   export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt"
echo "   export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key"
echo "   export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379"
echo ""

# Les appliquer pour ce script
export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

echo "3. Vérification des certificats:"
for f in "$ETCDCTL_CACERT" "$ETCDCTL_CERT" "$ETCDCTL_KEY"; do
    if [ -f "$f" ]; then
        echo "   ✓ $f"
    else
        echo "   ❌ $f introuvable"
        false
    fi
done

echo ""
echo "4. Test de connexion à etcd:"
etcdctl endpoint health
echo ""

echo "5. Version d'etcd:"
etcdctl version
echo ""

echo "✓ etcdctl est opérationnel"
echo ""
echo "RAPPEL: Ces variables ne persistent pas d'un terminal à l'autre."
echo "Ajoutez-les à votre ~/.bashrc ou relancez ce script pour les réappliquer."
echo ""
echo "Fichier de commodité — sourcez-le pour définir les variables :"
echo ""

# Générer un fichier source pratique
cat <<'EOF' | sudo tee /etc/profile.d/etcdctl.sh > /dev/null
# etcdctl environment — généré par partie-06-etcd/01-setup-etcdctl.sh
export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
EOF

echo "   sudo tee /etc/profile.d/etcdctl.sh → créé"
echo "   Pour l'activer immédiatement : source /etc/profile.d/etcdctl.sh"

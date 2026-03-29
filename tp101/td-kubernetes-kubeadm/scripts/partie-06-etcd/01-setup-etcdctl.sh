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
    echo "   etcdctl absent — téléchargement depuis les releases GitHub etcd..."
    # Extraire la version depuis l'image etcd du cluster (ex: 3.6.5-0 → 3.6.5)
    RAW_VERSION=$(kubectl -n kube-system get pod -l component=etcd \
        -o jsonpath='{.items[0].spec.containers[0].image}' | cut -d: -f2)
    ETCD_VERSION="${RAW_VERSION%-*}"   # supprime le suffixe -0 de Kubernetes
    echo "   Version etcd du cluster : v${ETCD_VERSION}"
    ARCHIVE="etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
    URL="https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/${ARCHIVE}"
    echo "   Téléchargement : $URL"
    curl -fsSL "$URL" -o "/tmp/${ARCHIVE}"
    tar xzf "/tmp/${ARCHIVE}" --strip-components=1 \
        -C /usr/local/bin \
        "etcd-v${ETCD_VERSION}-linux-amd64/etcdctl"
    rm -f "/tmp/${ARCHIVE}"
    chmod +x /usr/local/bin/etcdctl
    echo "   ✓ etcdctl installé dans /usr/local/bin/etcdctl"
else
    echo "   ✓ etcdctl déjà présent : $(which etcdctl)"
fi
echo ""

echo "2. Variables d'environnement obligatoires:"
echo ""
echo "   # Copiez-collez ces exports dans votre shell :"
echo "   # ETCDCTL_API=3 n'est plus nécessaire depuis etcd 3.6 (v3 par défaut)"
echo "   export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt"
echo "   export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt"
echo "   export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key"
echo "   export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379"
echo ""

# Les appliquer pour ce script
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
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
EOF

echo "   sudo tee /etc/profile.d/etcdctl.sh → créé"
echo "   Pour l'activer immédiatement : source /etc/profile.d/etcdctl.sh"

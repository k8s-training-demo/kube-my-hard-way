#!/bin/bash
# Partie 4 - Suppression de Flannel et nettoyage
# À exécuter sur le nœud MASTER, puis sur TOUS les nœuds

set -e

echo "=== Suppression de Flannel ==="
echo ""

if [ "$1" == "master" ]; then
    echo "ÉTAPE 1 - Sur le MASTER"
    echo "----------------------------------------"

    echo "1. Suppression des ressources Flannel dans Kubernetes:"
    kubectl delete -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml --ignore-not-found=true

    echo ""
    echo "2. Suppression du namespace kube-flannel:"
    kubectl delete namespace kube-flannel --ignore-not-found=true --timeout=60s

    echo ""
    echo "3. Vérification:"
    kubectl get pods -n kube-flannel 2>&1 || echo "   ✓ Namespace kube-flannel supprimé"

    echo ""
    echo "✓ Ressources Flannel supprimées du cluster"
    echo ""
    echo "PROCHAINE ÉTAPE: Exécutez ce script sur CHAQUE nœud avec l'argument 'node':"
    echo "  sudo $0 node"

elif [ "$1" == "node" ]; then
    echo "ÉTAPE 2 - Sur un NŒUD (master ou worker)"
    echo "----------------------------------------"

    if [ "$EUID" -ne 0 ]; then
        echo "❌ Ce script doit être exécuté avec sudo sur les nœuds"
        false  # Arrête le script avec set -e sans exit
    fi

    echo "1. Arrêt de kubelet:"
    systemctl stop kubelet

    echo "2. Suppression de l'interface réseau flannel.1:"
    ip link delete flannel.1 2>/dev/null || echo "   Interface flannel.1 déjà supprimée"

    echo "3. Suppression de l'interface cni0:"
    ip link delete cni0 2>/dev/null || echo "   Interface cni0 déjà supprimée"

    echo "4. Nettoyage des règles iptables liées à Flannel:"
    iptables -t nat -F || true
    iptables -t mangle -F || true
    iptables -F || true
    iptables -X || true

    echo "5. Suppression de la configuration CNI:"
    rm -rf /etc/cni/net.d/*

    echo "6. Suppression du répertoire de données Flannel:"
    rm -rf /var/lib/cni/flannel
    rm -rf /run/flannel

    echo "7. Redémarrage de containerd:"
    systemctl restart containerd

    echo ""
    echo "✓ Flannel nettoyé sur ce nœud"
    echo ""
    echo "⚠️  IMPORTANT: NE PAS redémarrer kubelet maintenant!"
    echo "   Attendez que le script d'installation de Calico (04-install-calico.sh) affiche:"
    echo "   'Calico installé avec succès!' avant de redémarrer kubelet."
    echo ""
    echo "   Quand Calico est prêt, exécutez: sudo systemctl start kubelet"

else
    echo "Usage:"
    echo "  Sur le master:  $0 master"
    echo "  Sur les nœuds:  sudo $0 node"
    false  # Arrête le script avec set -e sans exit
fi

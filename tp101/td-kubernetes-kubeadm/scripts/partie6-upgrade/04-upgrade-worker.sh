#!/bin/bash
# Partie 6 - Upgrade d'un worker
# PARTIE A: À exécuter sur le MASTER
# PARTIE B: À exécuter sur le WORKER
# Compatible CentOS Stream 10

set -e

# Version cible
TARGET_VERSION="1.35.0"

if [ "$1" == "master-drain" ]; then
    echo "=== PARTIE A - Drain du worker (depuis le master) ==="
    echo ""

    if [ -z "$2" ]; then
        echo "Usage: $0 master-drain <worker-node-name>"
        echo ""
        echo "Workers disponibles:"
        kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name'
        false  # Arrête le script avec set -e sans exit
    fi

    WORKER_NODE="$2"
    echo "Worker à drainer: $WORKER_NODE"
    echo ""

    echo "1. État actuel du worker:"
    kubectl get node $WORKER_NODE -o wide

    echo ""
    echo "2. Pods sur ce worker:"
    kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=$WORKER_NODE

    echo ""
    echo "3. Drain du worker:"
    # POURQUOI drain: Évacue les pods proprement avant maintenance.
    #   --ignore-daemonsets: Les DaemonSets (CNI, monitoring) doivent rester sur le nœud
    #   --delete-emptydir-data: Supprime les données emptyDir (temporaires par définition)
    #   --timeout: Évite de bloquer indéfiniment si un pod refuse de s'arrêter
    kubectl drain $WORKER_NODE \
        --ignore-daemonsets \
        --delete-emptydir-data \
        --timeout=120s

    echo ""
    echo "✓ Worker drainé avec succès!"
    echo ""
    echo "PROCHAINE ÉTAPE: Exécutez sur le worker $WORKER_NODE:"
    echo "  sudo $0 worker-upgrade"

elif [ "$1" == "worker-upgrade" ]; then
    echo "=== PARTIE B - Upgrade sur le worker ==="
    echo ""

    if [ "$EUID" -ne 0 ]; then
        echo "❌ Ce script doit être exécuté avec sudo sur le worker"
        false  # Arrête le script avec set -e sans exit
    fi

    echo "1. Versions actuelles:"
    echo "   kubeadm: $(kubeadm version -o short)"
    echo "   kubelet: $(kubelet --version)"
    echo "   kubectl: $(kubectl version --client --short 2>/dev/null || echo 'non installé')"

    echo ""
    echo "2. Mise à jour du dépôt Kubernetes vers v${TARGET_VERSION%%.*.*}:"
    MINOR_VERSION=$(echo "$TARGET_VERSION" | cut -d. -f1,2)
    sed -i "s|/stable:/v[0-9]\+\.[0-9]\+/|/stable:/v${MINOR_VERSION}/|g" /etc/yum.repos.d/kubernetes.repo
    echo "   Repo mis à jour vers v${MINOR_VERSION}"
    dnf makecache --quiet 2>/dev/null || true

    echo ""
    echo "3. Déverrouillage et upgrade de kubeadm:"
    # POURQUOI: kubeadm doit être upgradé en premier pour pouvoir exécuter 'kubeadm upgrade node'
    dnf versionlock delete kubeadm 2>/dev/null || true
    dnf install -y kubeadm-$TARGET_VERSION --disableexcludes=kubernetes
    dnf versionlock add kubeadm 2>/dev/null || true

    echo ""
    echo "4. Upgrade de la configuration kubelet locale:"
    # POURQUOI kubeadm upgrade node: Met à jour la configuration locale du kubelet
    #          pour correspondre à la nouvelle version du cluster.
    #          Sur un worker, cela met à jour kubelet.conf et le certificat client.
    kubeadm upgrade node

    echo ""
    echo "5. Déverrouillage et upgrade de kubelet et kubectl:"
    # POURQUOI: kubelet doit être à la même version (ou N-2 max) que le control plane.
    dnf versionlock delete kubelet kubectl 2>/dev/null || true
    dnf install -y kubelet-$TARGET_VERSION kubectl-$TARGET_VERSION --disableexcludes=kubernetes
    dnf versionlock add kubelet kubectl 2>/dev/null || true

    echo ""
    echo "6. Rechargement et redémarrage de kubelet:"
    # POURQUOI daemon-reload: systemd doit relire la configuration du service
    #                         après mise à jour du paquet kubelet.
    systemctl daemon-reload
    systemctl restart kubelet

    echo ""
    echo "7. Vérification du statut:"
    systemctl status kubelet --no-pager | head -20

    echo ""
    echo "✓ Worker upgradé avec succès!"
    echo ""
    echo "PROCHAINE ÉTAPE: Retournez sur le master et exécutez:"
    echo "  kubectl uncordon $(hostname)"

elif [ "$1" == "master-uncordon" ]; then
    echo "=== PARTIE C - Uncordon du worker (depuis le master) ==="
    echo ""

    if [ -z "$2" ]; then
        echo "Usage: $0 master-uncordon <worker-node-name>"
        false  # Arrête le script avec set -e sans exit
    fi

    WORKER_NODE="$2"
    echo "Worker à remettre en service: $WORKER_NODE"
    echo ""

    echo "1. Uncordon du worker:"
    # POURQUOI uncordon: Remet le nœud en service pour accepter de nouveaux pods.
    #                    Sans cette commande, le nœud reste en mode "SchedulingDisabled".
    kubectl uncordon $WORKER_NODE

    echo ""
    echo "2. Vérification:"
    kubectl get node $WORKER_NODE -o wide

    echo ""
    echo "✓ Worker remis en service avec succès!"

else
    echo "=== Upgrade d'un worker - Guide d'utilisation ==="
    echo ""
    echo "Cet upgrade se fait en 3 étapes:"
    echo ""
    echo "1. Sur le MASTER - Drain du worker:"
    echo "   $0 master-drain <worker-node-name>"
    echo ""
    echo "2. Sur le WORKER - Upgrade des composants:"
    echo "   sudo $0 worker-upgrade"
    echo ""
    echo "3. Sur le MASTER - Uncordon du worker:"
    echo "   $0 master-uncordon <worker-node-name>"
    echo ""
    echo "Workers disponibles:"
    kubectl get nodes -o json 2>/dev/null | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' || echo "Exécutez depuis le master pour voir les workers"
fi

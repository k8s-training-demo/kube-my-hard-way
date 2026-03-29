#!/bin/bash
# Partie 6 - Backup etcd par snapshot
# À exécuter sur le nœud MASTER — OBLIGATOIRE avant tout upgrade
# Usage: ./03-backup-etcd.sh [chemin-destination]

set -e

BACKUP_DIR="${1:-/var/backup/etcd}"
SNAPSHOT_FILE="$BACKUP_DIR/snapshot-$(date +%Y%m%d-%H%M%S).db"

export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

echo "=== Backup etcd par snapshot ==="
echo ""

echo "1. Vérification de la santé d'etcd avant backup:"
etcdctl endpoint health
echo ""

echo "2. Création du répertoire de backup:"
sudo mkdir -p "$BACKUP_DIR"
echo "   Destination: $SNAPSHOT_FILE"
echo ""

echo "3. Création du snapshot:"
sudo ETCDCTL_API=3 etcdctl snapshot save "$SNAPSHOT_FILE" \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    --endpoints=https://127.0.0.1:2379

echo ""
echo "4. Vérification de l'intégrité du snapshot:"
sudo ETCDCTL_API=3 etcdctl snapshot status "$SNAPSHOT_FILE" --write-out=table

echo ""
echo "5. Taille du fichier:"
ls -lh "$SNAPSHOT_FILE"

echo ""
echo "✓ Snapshot créé avec succès : $SNAPSHOT_FILE"
echo ""
echo "BONNES PRATIQUES:"
echo "- Copier ce fichier hors du cluster (scp vers machine de sauvegarde)"
echo "- Conserver aussi /etc/kubernetes/pki/ (certificats et clés CA)"
echo "- Fréquence recommandée : avant chaque upgrade + quotidien en production"
echo ""
echo "Copie externe (exemple):"
echo "  scp $SNAPSHOT_FILE user@backup-server:/backups/k8s/"

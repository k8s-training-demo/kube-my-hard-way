#!/bin/bash
# Partie 6 - Inspection du cluster etcd et des données Kubernetes
# À exécuter sur le nœud MASTER uniquement

set -e

export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

echo "=== Inspection d'etcd ==="
echo ""

# --- Collecte des données ---
HEALTH=$(etcdctl endpoint health 2>&1)
STATUS_JSON=$(etcdctl endpoint status --write-out=json 2>/dev/null)
MEMBER_JSON=$(etcdctl member list --write-out=json 2>/dev/null)
TOTAL_KEYS=$(etcdctl get / --prefix --keys-only 2>/dev/null | grep -c . || true)

# Extraire les champs depuis le JSON
ENDPOINT=$(echo "$STATUS_JSON"    | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['Endpoint'])" 2>/dev/null || echo "?")
DB_SIZE=$(echo "$STATUS_JSON"     | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; s=d['Status']['dbSize']; print(f'{s/1024/1024:.1f} MB')" 2>/dev/null || echo "?")
REVISION=$(echo "$STATUS_JSON"    | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['Status']['header']['revision'])" 2>/dev/null || echo "?")
IS_LEADER=$(echo "$STATUS_JSON"   | python3 -c "
import sys,json
d=json.load(sys.stdin)[0]['Status']
hdr=d.get('header',{})
mid=hdr.get('memberId') or hdr.get('member_id')
ldr=d.get('leader')
print('OUI' if ldr and str(ldr)==str(mid) else 'non')
" 2>/dev/null || echo "?")
ETCD_VER=$(echo "$STATUS_JSON"    | python3 -c "import sys,json; d=json.load(sys.stdin)[0]; print(d['Status']['version'])" 2>/dev/null || echo "?")
MEMBER_NAME=$(echo "$MEMBER_JSON" | python3 -c "import sys,json; m=json.load(sys.stdin)['members'][0]; print(m['name'])" 2>/dev/null || echo "?")
NB_MEMBERS=$(echo "$MEMBER_JSON"  | python3 -c "import sys,json; print(len(json.load(sys.stdin)['members']))" 2>/dev/null || echo "?")

# --- Affichage du tableau de bord ---
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                  TABLEAU DE BORD ETCD                      │"
echo "├──────────────────────────┬──────────────────────────────────┤"
printf "│ %-24s │ %-32s │\n" "Endpoint"    "$ENDPOINT"
printf "│ %-24s │ %-32s │\n" "Version etcd"  "$ETCD_VER"
printf "│ %-24s │ %-32s │\n" "Sante"        "$(echo "$HEALTH" | grep -o 'healthy\|unhealthy' | head -1)"
printf "│ %-24s │ %-32s │\n" "Est leader"   "$IS_LEADER"
printf "│ %-24s │ %-32s │\n" "Taille DB"    "$DB_SIZE"
printf "│ %-24s │ %-32s │\n" "Revision"     "$REVISION"
printf "│ %-24s │ %-32s │\n" "Membres"      "$NB_MEMBERS  (stacked kubeadm = 1)"
printf "│ %-24s │ %-32s │\n" "Nom du membre" "$MEMBER_NAME"
printf "│ %-24s │ %-32s │\n" "Cles totales"  "$TOTAL_KEYS"
echo "└──────────────────────────┴──────────────────────────────────┘"
echo ""
read -rp "   ↵  Notez taille DB, révision et statut leader. Appuyez sur Entrée..."

echo ""
echo "1. Toutes les clés Kubernetes (premiers 30):"
etcdctl get / --prefix --keys-only | head -30
echo ""
read -rp "   ↵  Observez la structure /registry/<resource>/<namespace>/<name>. Appuyez sur Entrée..."

echo ""
echo "2. Lister les namespaces (raw etcd):"
etcdctl get /registry/namespaces --prefix --keys-only
echo ""

echo "3. Lister les pods dans le namespace kube-system (clés):"
etcdctl get /registry/pods/kube-system --prefix --keys-only
echo ""
read -rp "   ↵  Chaque pod stocké comme /registry/pods/<ns>/<name>. Appuyez sur Entrée..."

echo ""
echo "4. Lire un pod spécifique (données brutes protobuf):"
POD=$(etcdctl get /registry/pods/kube-system --prefix --keys-only | head -1)
if [ -n "$POD" ]; then
    echo "   Clé: $POD"
    echo "   (données binaires protobuf — l'API Server les désérialise pour kubectl)"
    etcdctl get "$POD" | strings | grep -E '"kind"|"name"|"namespace"' | head -5 || true
fi
echo ""
read -rp "   ↵  Ce que kubectl retourne = désérialisation de ces données. Appuyez sur Entrée..."

echo ""
echo "5. Secrets (clés seulement — contenu chiffré at rest):"
etcdctl get /registry/secrets --prefix --keys-only | head -10
echo ""

echo "✓ Inspection terminée"
echo ""
echo "POINTS CLÉS:"
echo "- Structure : /registry/<resource>/<namespace>/<name>"
echo "- Format : protobuf binaire (pas JSON lisible directement)"
echo "- Taille typique : 5-20 MB pour un cluster de TD"
echo "- Secrets : chiffrés si EncryptionConfiguration activée (pas par défaut avec kubeadm)"

#!/bin/bash
# setup-sg.sh — Créer/configurer le security group Exoscale pour le TP Kubernetes
#
# Règles créées :
#   - SSH (TCP 22) depuis partout
#   - TCP all-ports intra-groupe (trafic Kubernetes inter-nœuds)
#   - UDP all-ports intra-groupe (Flannel/Calico VXLAN UDP 8472, etc.)
#   - HTTP (TCP 80) depuis partout (hostPort reverse proxy)
#   - NodePorts (TCP 30000-32767) depuis partout (accès services exposés)
#   - Kubernetes API (TCP 6443) depuis partout

set -e

ZONE="de-fra-1"
SG_NAME="tp-k8s"

if [ -f .env ]; then
    # shellcheck source=/dev/null
    source .env
fi

# Surcharge depuis les arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sg)   SG_NAME="$2"; shift ;;
        --zone) ZONE="$2";    shift ;;
        -h|--help)
            echo "Usage: $0 [--sg NOM] [--zone ZONE]"
            echo "  --sg    Nom du security group (défaut: tp-k8s)"
            echo "  --zone  Zone Exoscale (défaut: de-fra-1)"
            exit 0 ;;
        *) echo "Option inconnue: $1"; exit 1 ;;
    esac
    shift
done

if ! command -v exo &> /dev/null; then
    echo "❌ exo (Exoscale CLI) n'est pas installé."
    exit 1
fi

echo "=== Setup Security Group : $SG_NAME (zone: $ZONE) ==="
echo ""

# 1. Créer le SG s'il n'existe pas
if exo compute security-group show "$SG_NAME" --output-format json > /dev/null 2>&1; then
    echo "ℹ️  Security group '$SG_NAME' existe déjà."
else
    echo "🔧 Création du security group '$SG_NAME'..."
    exo compute security-group create "$SG_NAME" --description "TP Kubernetes — trafic inter-nœuds + SSH"
    echo "✅ Security group créé."
fi

echo ""

# Helper : vérifie si une règle existe déjà (par description)
rule_exists() {
    local sg="$1" desc="$2"
    exo compute security-group show "$sg" --output-format json 2>/dev/null | \
        grep -q "\"$desc\"" 2>/dev/null
}

# 2. SSH depuis partout (TCP 22)
echo -n "  → SSH (TCP 22) depuis 0.0.0.0/0… "
if exo compute security-group show "$SG_NAME" --output-format json 2>/dev/null | \
   python3 -c "
import sys, json
rules = json.load(sys.stdin).get('ingress_rules', [])
for r in rules:
    if r.get('protocol') == 'tcp' and r.get('start_port') == 22 and r.get('end_port') == 22 \
       and r.get('network') in ('0.0.0.0/0', '::/0'):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    echo "déjà présent."
else
    exo compute security-group rule add "$SG_NAME" \
        --protocol tcp \
        --port 22 \
        --network 0.0.0.0/0 > /dev/null
    echo "ajoutée."
fi

# 3. TCP intra-groupe (tous ports)
echo -n "  → TCP all-ports intra-groupe ($SG_NAME)… "
if exo compute security-group show "$SG_NAME" --output-format json 2>/dev/null | \
   python3 -c "
import sys, json
rules = json.load(sys.stdin).get('ingress_rules', [])
sg_name = sys.argv[1]
for r in rules:
    if r.get('protocol') == 'tcp' and r.get('start_port') == 1 and r.get('end_port') == 65535 \
       and sg_name in str(r.get('security_group', '')):
        sys.exit(0)
sys.exit(1)
" "$SG_NAME" 2>/dev/null; then
    echo "déjà présent."
else
    exo compute security-group rule add "$SG_NAME" \
        --protocol tcp \
        --port 1-65535 \
        --security-group "$SG_NAME" > /dev/null
    echo "ajoutée."
fi

# 4. UDP intra-groupe (tous ports — Flannel VXLAN 8472, etc.)
echo -n "  → UDP all-ports intra-groupe ($SG_NAME)… "
if exo compute security-group show "$SG_NAME" --output-format json 2>/dev/null | \
   python3 -c "
import sys, json
rules = json.load(sys.stdin).get('ingress_rules', [])
sg_name = sys.argv[1]
for r in rules:
    if r.get('protocol') == 'udp' and r.get('start_port') == 1 and r.get('end_port') == 65535 \
       and sg_name in str(r.get('security_group', '')):
        sys.exit(0)
sys.exit(1)
" "$SG_NAME" 2>/dev/null; then
    echo "déjà présent."
else
    exo compute security-group rule add "$SG_NAME" \
        --protocol udp \
        --port 1-65535 \
        --security-group "$SG_NAME" > /dev/null
    echo "ajoutée."
fi

# 5. HTTP/HTTPS (TCP 80/443) depuis partout — accès aux services exposés en hostPort
echo -n "  → HTTP (TCP 80) depuis 0.0.0.0/0… "
if exo compute security-group show "$SG_NAME" --output-format json 2>/dev/null | \
   python3 -c "
import sys, json
rules = json.load(sys.stdin).get('ingress_rules', [])
for r in rules:
    if r.get('protocol') == 'tcp' and r.get('start_port') == 80 and r.get('end_port') == 80 \
       and r.get('network') in ('0.0.0.0/0', '::/0'):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    echo "déjà présent."
else
    exo compute security-group rule add "$SG_NAME" \
        --protocol tcp \
        --port 80 \
        --network 0.0.0.0/0 > /dev/null
    echo "ajoutée."
fi

# 6. NodePorts (TCP 30000-32767) depuis partout — accès aux services exposés (Grafana, etc.)
echo -n "  → NodePorts (TCP 30000-32767) depuis 0.0.0.0/0… "
if exo compute security-group show "$SG_NAME" --output-format json 2>/dev/null | \
   python3 -c "
import sys, json
rules = json.load(sys.stdin).get('ingress_rules', [])
for r in rules:
    if r.get('protocol') == 'tcp' and r.get('start_port') == 30000 and r.get('end_port') == 32767 \
       and r.get('network') in ('0.0.0.0/0', '::/0'):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    echo "déjà présent."
else
    exo compute security-group rule add "$SG_NAME" \
        --protocol tcp \
        --port 30000-32767 \
        --network 0.0.0.0/0 > /dev/null
    echo "ajoutée."
fi

# 7. Kubernetes API (TCP 6443) depuis partout — accès kubectl externe pour TP
echo -n "  → Kubernetes API (TCP 6443) depuis 0.0.0.0/0… "
if exo compute security-group show "$SG_NAME" --output-format json 2>/dev/null | \
   python3 -c "
import sys, json
rules = json.load(sys.stdin).get('ingress_rules', [])
for r in rules:
    if r.get('protocol') == 'tcp' and r.get('start_port') == 6443 and r.get('end_port') == 6443 \
       and r.get('network') in ('0.0.0.0/0', '::/0'):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    echo "déjà présent."
else
    exo compute security-group rule add "$SG_NAME" \
        --protocol tcp \
        --port 6443 \
        --network 0.0.0.0/0 > /dev/null
    echo "ajoutée."
fi

echo ""
echo "✅ Security group '$SG_NAME' configuré."
echo ""
echo "Règles actives :"
exo compute security-group show "$SG_NAME"

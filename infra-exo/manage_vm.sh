#!/bin/bash

# Configuration — valeurs par défaut (surchargées par .env si présent)
KEY_NAME="./vm_key"
ZONE="de-fra-1"
TEMPLATE="Linux CentOS Stream 10 64-bit"
INSTANCE_TYPE="standard.medium"  # 2 vCPU / 4 GB — ajuster si besoin (format: FAMILY.SIZE)
SECURITY_GROUP=""                 # optionnel : ex. "tp-k8s" (définir dans .env)
PRIVATE_NETWORK=""                # optionnel : nom du réseau privé Exoscale (définir dans .env)

# Chargement de la configuration locale (.env) si elle existe — après les defaults pour permettre la surcharge
if [ -f .env ]; then
    # shellcheck source=/dev/null
    source .env
fi

# Variables par défaut
COUNT=1
TAGS=""
DELETE_MODE=false
DELETE_ALL=false

# Fonction d'usage
usage() {
    cat << EOF
Usage: $0 --tags "tag1,tag2" [--count N] [--delete] [--all] [--init <path_cle>]

Options:
  --tags, -t   Liste des tags (séparés par des virgules) [Requis sauf si --delete --all]
  --count, -c  Nombre de VMs à créer (défaut: 1)
  --delete, -d Supprimer les VMs basées sur les tags
  --all        Supprimer TOUTES les VMs (requiert --delete)
  --init PATH  Enregistrer le chemin de la clé SSH dans .env et quitter

Clé SSH :
  La clé ./vm_key est générée automatiquement au premier lancement si absente.
  Pour utiliser une clé existante :
    $0 --init /chemin/vers/ma_cle
  La clé privée (vm_key) est ignorée par git — ne jamais la commiter manuellement.

Exemples:
  $0 --tags "tp-k8s" --count 3          # créer 3 VMs
  $0 --tags "tp-k8s" --delete           # supprimer par tag
  $0 --delete --all                     # supprimer toutes les VMs
  $0 --init ~/.ssh/id_ed25519           # utiliser une clé existante
EOF
    exit 1
}

# Parsing des arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --init)
            if [ -z "$2" ]; then echo "❌ Erreur: --init requiert un chemin de clé."; exit 1; fi
            echo "KEY_NAME=\"$2\"" > .env
            echo "✅ Configuration enregistrée dans .env : KEY_NAME=\"$2\""
            exit 0
            ;;
        -t|--tags) TAGS="$2"; shift ;;
        -c|--count) COUNT="$2"; shift ;;
        -d|--delete) DELETE_MODE=true ;;
        --all) DELETE_ALL=true ;;
        -h|--help) usage ;;
        *) echo "Option inconnue: $1"; usage ;;
    esac
    shift
done

# Vérification des outils
if ! command -v exo &> /dev/null; then
    echo "❌ Erreur : exo (Exoscale CLI) n'est pas installé."
    echo "  → https://community.exoscale.com/documentation/tools/exoscale-command-line-interface/"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ Erreur : jq n'est pas installé."
    exit 1
fi

# Vérification des credentials Exoscale (env vars ou config exo)
if [ -z "$EXOSCALE_API_KEY" ] || [ -z "$EXOSCALE_API_SECRET" ]; then
    # Tenter quand même : exo peut utiliser son fichier de config (~/.config/exoscale/exoscale.toml)
    if ! exo config show > /dev/null 2>&1; then
        echo "❌ Erreur : pas de credentials Exoscale."
        echo "  Soit : export EXOSCALE_API_KEY=EXO... && export EXOSCALE_API_SECRET=..."
        echo "  Soit : exo config (profil déjà configuré)"
        exit 1
    fi
fi

# Vérification des tags (sauf suppression totale)
if [ -z "$TAGS" ]; then
    if [ "$DELETE_MODE" = true ] && [ "$DELETE_ALL" = true ]; then
        : # Pas besoin de tags pour tout supprimer
    else
        echo "❌ Erreur : L'argument --tags est obligatoire (sauf avec --delete --all)."
        usage
    fi
fi

# Helper : liste les noms des instances ayant le label <tag>=true dans la zone courante
# (exo list ne retourne pas les labels — on appelle show pour chaque instance)
instances_by_tag() {
    local tag="$1"
    local all_names
    all_names=$(exo compute instance list -z "$ZONE" --output-format json 2>/dev/null | jq -r '.[].name')
    for name in $all_names; do
        local lval
        lval=$(exo compute instance show "$name" -z "$ZONE" --output-format json 2>/dev/null | \
               jq -r --arg t "$tag" '.labels[$t] // empty')
        if [ -n "$lval" ]; then
            echo "$name"
        fi
    done
}

# --- MODE SUPPRESSION ---
if [ "$DELETE_MODE" = true ]; then
    echo "⚠️  Mode suppression activé."

    if [ "$DELETE_ALL" = true ]; then
        echo "🛑 ATTENTION : Vous avez demandé la suppression de TOUTES les VMs (zone: $ZONE)."
        read -p "❓ Êtes-vous sûr de vouloir tout supprimer ? (o/N) : " confirmation
        if [[ "$confirmation" != "o" && "$confirmation" != "O" ]]; then
            echo "❌ Annulé."
            exit 0
        fi

        echo "🔍 Récupération de toutes les VMs..."
        ALL_NAMES=$(exo compute instance list -z "$ZONE" --output-format json 2>/dev/null | jq -r '.[].name')

        if [ -z "$ALL_NAMES" ]; then
            echo "ℹ️  Aucune VM trouvée."
        else
            echo "🗑️  Suppression de toutes les VMs..."
            for name in $ALL_NAMES; do
                exo compute instance delete "$name" -z "$ZONE" --force
            done
        fi
    else
        IFS=',' read -ra TAG_LIST <<< "$TAGS"
        for tag in "${TAG_LIST[@]}"; do
            echo "🗑️  Suppression des VMs avec le tag : $tag..."
            NAMES=$(instances_by_tag "$tag")
            if [ -z "$NAMES" ]; then
                echo "ℹ️  Aucune VM trouvée pour le tag : $tag"
            else
                for name in $NAMES; do
                    exo compute instance delete "$name" -z "$ZONE" --force
                done
            fi
        done
    fi

    echo "✅ Suppression terminée."
    exit 0
fi

# --- MODE CRÉATION ---

# 1. Gestion de la clé SSH locale
if [ -f "$KEY_NAME" ]; then
    echo "ℹ️  La paire de clés existe déjà : $KEY_NAME"
else
    echo "🔑 Génération de la paire de clés SSH ($KEY_NAME)..."
    ssh-keygen -t ed25519 -f "$KEY_NAME" -N "" -C "generated-for-exo"
fi

LOCAL_FP_MD5=$(ssh-keygen -E md5 -lf "${KEY_NAME}.pub" | awk '{print $2}')
LOCAL_FP_MD5_CLEAN=${LOCAL_FP_MD5#"MD5:"}

if [ -z "$LOCAL_FP_MD5_CLEAN" ]; then
    echo "❌ Erreur : Impossible de récupérer le fingerprint de la clé publique locale."
    exit 1
fi
echo "🔑 Fingerprint local (MD5) : $LOCAL_FP_MD5_CLEAN"

# Vérification si la clé existe déjà sur Exoscale (fingerprint MD5 sans préfixe)
SSH_KEY_NAME=""
while read -r name fingerprint; do
    if [ "$fingerprint" = "$LOCAL_FP_MD5_CLEAN" ]; then
        SSH_KEY_NAME="$name"
        echo "✅ Clé trouvée sur Exoscale : $SSH_KEY_NAME"
        break
    fi
done < <(exo compute ssh-key list --output-format json 2>/dev/null | \
         jq -r '.[] | .name + " " + .fingerprint')

# 2. Enregistrement de la clé sur Exoscale si absente
if [ -z "$SSH_KEY_NAME" ]; then
    SSH_KEY_NAME="vm-key-$(date +%s)"
    echo "⬆️  Enregistrement de la clé publique sur Exoscale ($SSH_KEY_NAME)..."
    if ! exo compute ssh-key register "$SSH_KEY_NAME" "${KEY_NAME}.pub"; then
        echo "❌ Erreur lors de l'enregistrement de la clé."
        exit 1
    fi
    echo "✅ Clé enregistrée."
fi

# 3. Construction du label string (format: "tag1=true,tag2=true")
LABEL_STR=""
IFS=',' read -ra TAG_LIST <<< "$TAGS"
for tag in "${TAG_LIST[@]}"; do
    if [ -n "$LABEL_STR" ]; then
        LABEL_STR="${LABEL_STR},${tag}=true"
    else
        LABEL_STR="${tag}=true"
    fi
done

# Security group (optionnel, défini via $SECURITY_GROUP ou .env)
SG_ARGS=()
if [ -n "$SECURITY_GROUP" ]; then
    SG_ARGS+=("--security-group" "$SECURITY_GROUP")
fi

# Réseau privé (optionnel, défini via $PRIVATE_NETWORK ou .env)
PN_ARGS=()
if [ -n "$PRIVATE_NETWORK" ]; then
    PN_ARGS+=("--private-network" "$PRIVATE_NETWORK")
fi

# 4. Boucle de création des VMs
echo "🚀 Démarrage de la création de $COUNT VM(s) avec les tags : $TAGS"

for ((i=1; i<=COUNT; i++)); do
    VM_NAME="vm-$(date +%s)-$i"
    echo "----------------------------------------"
    echo "🛠  Création VM $i/$COUNT : $VM_NAME"

    exo compute instance create "$VM_NAME" \
        -z "$ZONE" \
        --template "$TEMPLATE" \
        --instance-type "$INSTANCE_TYPE" \
        --ssh-key "$SSH_KEY_NAME" \
        --label "$LABEL_STR" \
        "${SG_ARGS[@]}" \
        "${PN_ARGS[@]}"

    if [ $? -ne 0 ]; then
        echo "❌ Erreur lors de la création de $VM_NAME"
        continue
    fi

    # Récupération de l'IP via output-template (plus fiable que le parsing JSON)
    IP=$(exo compute instance show "$VM_NAME" -z "$ZONE" \
         --output-template '{{.IPAddress}}' 2>/dev/null)

    if [ -z "$IP" ] || [ "$IP" = "<nil>" ]; then
        echo "⚠️  VM créée mais IP non récupérée."
        echo "   → exo compute instance show $VM_NAME -z $ZONE"
    else
        echo "✅ Créée avec succès !"
        echo "🌍 IP : $IP"
        echo "💻 Connexion : ssh -i $KEY_NAME root@$IP"
    fi
done

echo "----------------------------------------"
echo "🎉 Opérations terminées."

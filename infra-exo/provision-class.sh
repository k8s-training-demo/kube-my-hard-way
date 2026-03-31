#!/bin/bash
# provision-class.sh — Provisionner les VMs pour une classe entière
# Génère un fichier Markdown avec les IPs par étudiant.

set -e

# ── Configuration (surchargée par .env) ───────────────────────────────────────
KEY_NAME="./vm_key"
ZONE="de-fra-1"
TEMPLATE="Linux CentOS Stream 10 64-bit"
INSTANCE_TYPE="standard.medium"
SECURITY_GROUP=""
PRIVATE_NETWORK=""

if [ -f .env ]; then
    # shellcheck source=/dev/null
    source .env
fi

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

# ── Help ──────────────────────────────────────────────────────────────────────
usage() {
    cat << EOF
${BOLD}Usage:${RESET} $0 [OPTIONS]

${BOLD}Description:${RESET}
  Provisionne des VMs Exoscale pour une classe (N étudiants × M VMs),
  puis génère un fichier Markdown prêt à distribuer avec IPs et commandes SSH.
  Sans options, lance le mode interactif.

${BOLD}Options de provisioning:${RESET}
  --students N       Nombre d'étudiants (défaut: interactif)
  --vms N            Nombre de VMs par étudiant (défaut: 3)
  --prefix PREFIX    Préfixe des tags (défaut: etudiant)
                     Ex: "groupe" → groupe-01, groupe-02…
  --output FILE      Fichier Markdown de sortie (défaut: access-etudiants.md)

${BOLD}Options de suppression:${RESET}
  --delete           Supprimer des VMs (interactif si --student/--all absent)
  --student N        Supprimer uniquement l'étudiant N (ex: --student 3)
  --all              Supprimer toutes les VMs de la classe (label préfixe)

${BOLD}Autres:${RESET}
  --with-ccm         Générer aussi les tokens CCM Exoscale (IAM role + API key par étudiant)
                     Produit : ccm-secret-{prefix}-{N}.yaml + tokens-ccm-{prefix}.md
  -h, --help         Afficher cette aide

${BOLD}Exemples:${RESET}
  # Mode interactif (recommandé)
  $0

  # Mode non-interactif (CI, scripting)
  $0 --students 15 --vms 3

  # Avec préfixe et fichier de sortie custom
  $0 --students 20 --vms 2 --prefix groupe --output tp1-acces.md

  # Suppression interactive (choisir étudiant ou tous)
  $0 --delete --prefix etudiant

  # Supprimer un étudiant précis
  $0 --delete --student 3 --prefix etudiant

  # Supprimer tous les étudiants de la classe
  $0 --delete --all --prefix etudiant

${BOLD}Configuration (.env):${RESET}
  INSTANCE_TYPE      Type d'instance Exoscale (défaut: standard.large)
  SECURITY_GROUP     Security group à attacher (ex: tp-k8s)
  PRIVATE_NETWORK    Réseau privé Exoscale (optionnel)
  KEY_NAME           Chemin vers la clé SSH locale (défaut: ./vm_key)

${BOLD}Clé SSH :${RESET}
  La clé ./vm_key est générée automatiquement au premier lancement si absente.
  Pour utiliser une clé existante, définir dans .env :
    echo 'KEY_NAME="/chemin/vers/ma_cle"' >> .env
  La clé privée (vm_key) est ignorée par git — ne jamais la commiter manuellement.

EOF
    exit 0
}

# ── Parsing des arguments ─────────────────────────────────────────────────────
STUDENTS=""
VMS_PER_STUDENT=""
PREFIX=""
OUTPUT=""
DELETE_MODE=false
DELETE_STUDENT=""   # numéro d'un étudiant précis à supprimer
DELETE_ALL=false
INTERACTIVE=true
WITH_CCM=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --students)   STUDENTS="$2";        INTERACTIVE=false; shift ;;
        --vms)        VMS_PER_STUDENT="$2"; shift ;;
        --prefix)     PREFIX="$2";          shift ;;
        --output)     OUTPUT="$2";          shift ;;
        --delete)     DELETE_MODE=true ;;
        --student)    DELETE_STUDENT="$2";  shift ;;
        --all)        DELETE_ALL=true ;;
        --with-ccm)   WITH_CCM=true ;;
        -h|--help)    usage ;;
        *) echo -e "${RED}❌ Option inconnue: $1${RESET}"; echo ""; usage ;;
    esac
    shift
done

# ── Prérequis ─────────────────────────────────────────────────────────────────
for cmd in exo jq ssh-keygen; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}❌ Commande requise manquante: $cmd${RESET}"
        exit 1
    fi
done

# ── Helpers ───────────────────────────────────────────────────────────────────
confirm() {
    local prompt="$1" answer
    echo -ne "${YELLOW}${prompt}${RESET} (o/N) : "
    read -r answer </dev/tty
    [[ "$answer" == "o" || "$answer" == "O" ]]
}

# Supprime toutes les VMs portant le label <key>=true dans la zone
delete_by_label() {
    local label_key="$1"
    local ALL_NAMES
    ALL_NAMES=$(exo compute instance list -z "$ZONE" --output-format json 2>/dev/null | jq -r '.[].name')

    local found=0
    for vm_name in $ALL_NAMES; do
        local lval
        lval=$(exo compute instance show "$vm_name" -z "$ZONE" --output-format json 2>/dev/null | \
               jq -r --arg k "$label_key" '.labels[$k] // empty')
        if [ -n "$lval" ]; then
            echo -ne "  🗑️  $vm_name… "
            exo compute instance delete "$vm_name" -z "$ZONE" --force
            echo -e "${GREEN}supprimée${RESET}"
            found=$(( found + 1 ))
        fi
    done
    [ "$found" -eq 0 ] && echo -e "  ${YELLOW}ℹ️  Aucune VM trouvée pour le label '${label_key}'${RESET}"
    return 0
}

role_name() {
    local idx="$1" total="$2"
    case $total in
        1) echo "master" ;;
        2) case $idx in 1) echo "master" ;; *) echo "worker1" ;; esac ;;
        3) case $idx in 1) echo "master" ;; 2) echo "worker1" ;; *) echo "worker2" ;; esac ;;
        *) case $idx in 1) echo "master" ;; *) echo "worker$(( idx - 1 ))" ;; esac ;;
    esac
}

# ── Mode interactif ───────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${RESET}"
echo -e "${BOLD}  🎓 Provisioning classe — Exoscale VMs${RESET}"
echo -e "${BOLD}══════════════════════════════════════════${RESET}"
echo ""

if [ "$INTERACTIVE" = true ] && [ "$DELETE_MODE" = false ]; then
    echo -e "${BLUE}ℹ️  Configuration actuelle (.env / défauts) :${RESET}"
    echo -e "   Zone          : ${BOLD}$ZONE${RESET}"
    echo -e "   Instance type : ${BOLD}$INSTANCE_TYPE${RESET}"
    [ -n "$SECURITY_GROUP" ] && echo -e "   Security group: ${BOLD}$SECURITY_GROUP${RESET}"
    [ -n "$PRIVATE_NETWORK" ] && echo -e "   Réseau privé  : ${BOLD}$PRIVATE_NETWORK${RESET}"
    echo ""

    echo -ne "${CYAN}Nombre d'étudiants${RESET} [${BOLD}15${RESET}] : "
    read -r STUDENTS </dev/tty
    STUDENTS="${STUDENTS:-15}"

    echo -ne "${CYAN}VMs par étudiant${RESET} [${BOLD}3${RESET}] : "
    read -r VMS_PER_STUDENT </dev/tty
    VMS_PER_STUDENT="${VMS_PER_STUDENT:-3}"

    echo -ne "${CYAN}Préfixe des tags${RESET} [${BOLD}etudiant${RESET}] : "
    read -r PREFIX </dev/tty
    PREFIX="${PREFIX:-etudiant}"

    echo -ne "${CYAN}Fichier Markdown de sortie${RESET} [${BOLD}access-etudiants.md${RESET}] : "
    read -r OUTPUT </dev/tty
    OUTPUT="${OUTPUT:-access-etudiants.md}"

    echo ""
fi

# Valeurs par défaut pour mode non-interactif
[ -z "$STUDENTS" ]        && STUDENTS=15
[ -z "$VMS_PER_STUDENT" ] && VMS_PER_STUDENT=3
[ -z "$PREFIX" ]          && PREFIX="etudiant"
[ -z "$OUTPUT" ]          && OUTPUT="access-etudiants.md"

TOTAL=$(( STUDENTS * VMS_PER_STUDENT ))

# ── MODE SUPPRESSION ──────────────────────────────────────────────────────────
if [ "$DELETE_MODE" = true ]; then
    [ -z "$PREFIX" ] && PREFIX="etudiant"

    # Mode interactif : demander étudiant précis ou tous
    if [ -z "$DELETE_STUDENT" ] && [ "$DELETE_ALL" = false ]; then
        echo -e "${YELLOW}⚠️  Mode suppression — préfixe : '${BOLD}${PREFIX}${RESET}${YELLOW}'${RESET}"
        echo ""
        echo -e "  ${BOLD}1)${RESET} Supprimer un étudiant précis"
        echo -e "  ${BOLD}2)${RESET} Supprimer tous les étudiants de la classe"
        echo ""
        echo -ne "${CYAN}Choix${RESET} [${BOLD}1${RESET}] : "
        read -r choice </dev/tty
        choice="${choice:-1}"

        if [ "$choice" = "1" ]; then
            echo -ne "${CYAN}Numéro de l'étudiant à supprimer${RESET} : "
            read -r DELETE_STUDENT </dev/tty
        else
            DELETE_ALL=true
        fi
        echo ""
    fi

    if [ "$DELETE_ALL" = true ]; then
        echo -e "${YELLOW}⚠️  Suppression de TOUTES les VMs de la classe '${BOLD}${PREFIX}${RESET}${YELLOW}'${RESET}"
        echo -e "   (label de classe : ${BOLD}${PREFIX}=true${RESET})"
        echo ""
        if ! confirm "❓ Confirmer la suppression de toutes ces VMs ?"; then
            echo -e "${RED}❌ Annulé.${RESET}"; exit 0
        fi
        delete_by_label "$PREFIX"
    else
        # Numéro formaté sur 2 chiffres
        n_fmt=$(printf '%02d' "$DELETE_STUDENT")
        tag="${PREFIX}-${n_fmt}"
        echo -e "${YELLOW}⚠️  Suppression des VMs de l'étudiant ${BOLD}${n_fmt}${RESET}${YELLOW} (label : ${BOLD}${tag}=true${RESET}${YELLOW})${RESET}"
        echo ""
        if ! confirm "❓ Confirmer ?"; then
            echo -e "${RED}❌ Annulé.${RESET}"; exit 0
        fi
        delete_by_label "$tag"
    fi

    echo ""
    echo -e "${GREEN}✅ Suppression terminée.${RESET}"
    exit 0
fi

# ── Confirmation avant création ───────────────────────────────────────────────
echo -e "${BOLD}Récapitulatif :${RESET}"
echo -e "   Étudiants    : ${BOLD}$STUDENTS${RESET}"
echo -e "   VMs/étudiant : ${BOLD}$VMS_PER_STUDENT${RESET}  ($(for v in $(seq 1 "$VMS_PER_STUDENT"); do printf "%s " "$(role_name "$v" "$VMS_PER_STUDENT")"; done))"
echo -e "   Total VMs    : ${BOLD}$TOTAL${RESET}"
echo -e "   Préfixe tags : ${BOLD}${PREFIX}-01 … ${PREFIX}-$(printf '%02d' "$STUDENTS")${RESET}"
echo -e "   Fichier      : ${BOLD}$OUTPUT${RESET}"
echo -e "   Zone         : ${BOLD}$ZONE${RESET}  |  Type : ${BOLD}$INSTANCE_TYPE${RESET}"
[ -n "$SECURITY_GROUP" ]  && echo -e "   Security grp : ${BOLD}$SECURITY_GROUP${RESET}"
[ -n "$PRIVATE_NETWORK" ] && echo -e "   Réseau privé : ${BOLD}$PRIVATE_NETWORK${RESET}"
echo ""

if ! confirm "🚀 Lancer le provisioning ?"; then
    echo -e "${RED}❌ Annulé.${RESET}"; exit 0
fi
echo ""

# ── Gestion clé SSH ───────────────────────────────────────────────────────────
if [ ! -f "$KEY_NAME" ]; then
    echo -e "🔑 Génération de la clé SSH (${KEY_NAME})..."
    ssh-keygen -t ed25519 -f "$KEY_NAME" -N "" -C "generated-for-exo"
fi

LOCAL_FP_MD5=$(ssh-keygen -E md5 -lf "${KEY_NAME}.pub" | awk '{print $2}')
LOCAL_FP_MD5_CLEAN="${LOCAL_FP_MD5#"MD5:"}"

SSH_KEY_NAME=""
while read -r name fingerprint; do
    if [ "$fingerprint" = "$LOCAL_FP_MD5_CLEAN" ]; then
        SSH_KEY_NAME="$name"
        echo -e "✅ Clé SSH Exoscale : ${BOLD}$SSH_KEY_NAME${RESET}"
        break
    fi
done < <(exo compute ssh-key list --output-format json 2>/dev/null | \
         jq -r '.[] | .name + " " + .fingerprint')

if [ -z "$SSH_KEY_NAME" ]; then
    SSH_KEY_NAME="vm-key-$(date +%s)"
    echo -e "⬆️  Enregistrement de la clé sur Exoscale (${SSH_KEY_NAME})..."
    exo compute ssh-key register "$SSH_KEY_NAME" "${KEY_NAME}.pub"
    echo -e "✅ Clé enregistrée."
fi

SG_ARGS=()
[ -n "$SECURITY_GROUP" ]  && SG_ARGS+=("--security-group" "$SECURITY_GROUP")

PN_ARGS=()
[ -n "$PRIVATE_NETWORK" ] && PN_ARGS+=("--private-network" "$PRIVATE_NETWORK")

# ── Helpers d'affichage ───────────────────────────────────────────────────────
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

_build_bar() {
    local current=$1 total=$2 width=36
    local filled=$(( total > 0 ? current * width / total : 0 ))
    local empty=$(( width - filled ))
    local bar="" i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    printf '%s' "$bar"
}

_draw_progress() {
    local pct=$(( TOTAL > 0 ? DONE * 100 / TOTAL : 0 ))
    printf "\033[u  ${BOLD}Progression${RESET} [%s] ${GREEN}${BOLD}%d${RESET}/%d VMs (%d%%)\n\n" \
        "$(_build_bar "$DONE" "$TOTAL")" "$DONE" "$TOTAL" "$pct"
    [ "$VM_LINES" -gt 0 ] && printf "\033[%dB\r" "$VM_LINES"
    return 0
}

_spinner_run() {
    local label="$1"; shift
    local spin_i=0 rc
    "$@" >/dev/null 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r\033[K  ${CYAN}%s${RESET} %s" "${SPINNER_CHARS:$spin_i:1}" "$label"
        spin_i=$(( (spin_i + 1) % ${#SPINNER_CHARS} ))
        sleep 0.1
    done
    wait "$pid"; rc=$?
    printf "\r\033[K"
    return $rc
}

# ── Boucle de création ────────────────────────────────────────────────────────
TMPDIR_DATA=$(mktemp -d)
DONE=0
VM_LINES=0

printf "\r\033[s"
_draw_progress

for n in $(seq -w 1 "$STUDENTS"); do
    tag="${PREFIX}-${n}"
    label_str="${tag}=true,${PREFIX}=true"
    student_file="${TMPDIR_DATA}/${tag}"

    for ((v=1; v<=VMS_PER_STUDENT; v++)); do
        role=$(role_name "$v" "$VMS_PER_STUDENT")
        vm_name="vm-${tag}-${role}"
        DONE=$(( DONE + 1 ))

        _spinner_run "[${DONE}/${TOTAL}] ${vm_name}" \
            exo compute instance create "$vm_name" \
                -z "$ZONE" \
                --template "$TEMPLATE" \
                --instance-type "$INSTANCE_TYPE" \
                --ssh-key "$SSH_KEY_NAME" \
                --label "$label_str" \
                "${SG_ARGS[@]}" \
                "${PN_ARGS[@]}" && create_rc=0 || create_rc=$?

        IP=$(exo compute instance show "$vm_name" -z "$ZONE" \
             --output-template '{{.IPAddress}}' 2>/dev/null)

        if [ $create_rc -ne 0 ]; then
            IP="N/A"
            printf "  ${RED}✗${RESET}  [%d/%d] %-26s ${RED}erreur création${RESET}\n" \
                "$DONE" "$TOTAL" "$vm_name"
        elif [ -z "$IP" ] || [ "$IP" = "<nil>" ]; then
            IP="N/A"
            printf "  ${YELLOW}⚠${RESET}  [%d/%d] %-26s ${YELLOW}IP non récupérée${RESET}\n" \
                "$DONE" "$TOTAL" "$vm_name"
        else
            printf "  ${GREEN}✓${RESET}  [%d/%d] %-26s ${BOLD}%s${RESET}\n" \
                "$DONE" "$TOTAL" "$vm_name" "$IP"
        fi

        VM_LINES=$(( VM_LINES + 1 ))
        echo "${vm_name}|${role}|${IP}" >> "$student_file"
        _draw_progress
    done
done

echo ""

# ── Génération du Markdown ────────────────────────────────────────────────────
echo ""
echo -ne "📝 Génération de ${BOLD}${OUTPUT}${RESET}… "

DATE=$(date '+%d/%m/%Y %H:%M')

cat > "$OUTPUT" << HEADER
# Accès VMs — Kubernetes TD

> Généré le ${DATE} — ${STUDENTS} étudiants × ${VMS_PER_STUDENT} VMs (${TOTAL} VMs total)

**Clé SSH privée :** demander à l'instructeur le fichier \`vm_key\`

Connexion : \`ssh -i vm_key root@<IP>\`

---

HEADER

for n in $(seq -w 1 "$STUDENTS"); do
    tag="${PREFIX}-${n}"
    student_file="${TMPDIR_DATA}/${tag}"

    printf "## Étudiant %s\n\n" "$n" >> "$OUTPUT"
    printf "| Rôle | Nom VM | IP | Connexion SSH |\n" >> "$OUTPUT"
    printf "|------|--------|----|---------------|\n" >> "$OUTPUT"

    while IFS='|' read -r vm_name role ip; do
        printf "| \`%-8s\` | \`%-30s\` | \`%-15s\` | \`ssh -i vm_key root@%s\` |\n" \
            "$role" "$vm_name" "$ip" "$ip" >> "$OUTPUT"
    done < "$student_file"

    printf "\n---\n\n" >> "$OUTPUT"
done

rm -rf "$TMPDIR_DATA"

echo -e "${GREEN}✅ OK${RESET}"

# ── Génération des tokens CCM (optionnel) ────────────────────────────────────
if [ "$WITH_CCM" = "true" ]; then
    echo ""
    echo -ne "🔑 Génération des tokens CCM Exoscale… "
    CCM_SCRIPT="$(dirname "$0")/setup-ccm-token.sh"
    if [ ! -x "$CCM_SCRIPT" ]; then
        echo -e "${RED}❌ setup-ccm-token.sh introuvable ou non exécutable${RESET}"
    else
        CCM_OUT=$("$CCM_SCRIPT" \
            --prefix "$PREFIX" \
            --count "$STUDENTS" \
            --zone "$ZONE" \
            --output "tokens-ccm-${PREFIX}.md" 2>&1) && \
            CCM_DIR=$(echo "$CCM_OUT" | grep "Répertoire" | awk '{print $NF}')
            echo -e "${GREEN}✅ OK${RESET} → ${BOLD}${CCM_DIR}${RESET}" || \
            echo -e "${YELLOW}⚠ Erreur lors de la génération des tokens CCM${RESET}"

        # Ajouter section CCM dans le Markdown principal
        cat >> "$OUTPUT" << CCM_SECTION

---

## Tokens CCM Exoscale (Cloud Controller Manager)

Fichiers secrets à distribuer **individuellement** à chaque étudiant.
Voir le détail dans \`tokens-ccm-${PREFIX}.md\`.

| Étudiant | Fichier secret |
|----------|----------------|
CCM_SECTION
        for n in $(seq -w 1 "$STUDENTS"); do
            echo "| \`${PREFIX}-${n}\` | \`$(dirname "$OUTPUT")/ccm-secret-${PREFIX}-${n}.yaml\` |" >> "$OUTPUT"
        done

        cat >> "$OUTPUT" << CCM_FOOTER

\`\`\`bash
# Sur le cluster de l'étudiant (après réception du fichier secret) :
kubectl apply -f ccm-secret-${PREFIX}-XX.yaml
cd scripts/partie-13-prometheus && ./05-install-ccm.sh
\`\`\`
CCM_FOOTER
    fi
fi

# ── Résumé final ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}🎉 Provisioning terminé !${RESET}"
echo -e "   VMs créées : ${BOLD}$TOTAL${RESET}"
echo -e "   Fichier    : ${BOLD}$OUTPUT${RESET}"
[ "$WITH_CCM" = "true" ] && \
    echo -e "   Secrets CCM: ${BOLD}${CCM_DIR:-/tmp/ccm-secrets-*}${RESET} (hors git)"
echo -e "${BOLD}══════════════════════════════════════════${RESET}"
echo ""
echo -e "💡 Pour supprimer toutes les VMs :"
echo -e "   ${CYAN}$0 --students $STUDENTS --prefix $PREFIX --delete${RESET}"
echo ""

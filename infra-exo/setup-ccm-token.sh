#!/bin/bash
# setup-ccm-token.sh — Créer un IAM role + API key restreint pour le CCM Exoscale
# À exécuter par l'INSTRUCTEUR sur son poste (avec ses credentials Exoscale)
#
# Génère pour chaque étudiant :
#   - Un IAM role "ccm-{prefix}-{N}" avec les permissions minimales CCM
#   - Une API key associée
#   - Un Secret Kubernetes à appliquer sur le cluster étudiant
#   - Un fichier récapitulatif tokens-ccm.md

# --- Configuration ---
PREFIX="etudiant"
STUDENTS=1
ZONE="de-fra-1"
OUTPUT_FILE="tokens-ccm.md"
# Les secrets sont générés dans /tmp pour éviter tout commit accidentel
OUTPUT_DIR=$(mktemp -d /tmp/ccm-secrets-XXXXXX)

if [ -f .env ]; then source .env; fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --prefix)      PREFIX="$2";     shift ;;
        --count)       STUDENTS="$2";   shift ;;
        --zone)        ZONE="$2";       shift ;;
        --output)      OUTPUT_FILE="$2"; shift ;;
        --delete)      DELETE=true ;;
        -h|--help)
            echo "Usage: $0 [--prefix etudiant] [--count 15] [--zone de-fra-1] [--delete]"
            exit 0 ;;
        *) echo "Option inconnue: $1"; exit 1 ;;
    esac
    shift
done

if ! command -v exo &>/dev/null; then
    echo "❌ exo CLI non trouvé"; exit 1
fi

# --- Mode suppression ---
if [ "${DELETE:-false}" = "true" ]; then
    echo "=== Suppression des IAM roles et API keys CCM ==="
    for n in $(seq -w 1 "$STUDENTS"); do
        tag="${PREFIX}-${n}"
        role_name="ccm-${tag}"

        echo -n "  → Suppression API key ${role_name}... "
        KEY_ID=$(exo iam api-key list --output-template '{{range .}}{{if eq .Name "'"${role_name}"'"}}{{.Key}}{{end}}{{end}}' 2>/dev/null || echo "")
        if [ -n "$KEY_ID" ]; then
            exo iam api-key delete "$KEY_ID" --force 2>/dev/null && echo "supprimée." || echo "introuvable."
        else
            echo "déjà absente."
        fi

        echo -n "  → Suppression IAM role ${role_name}... "
        exo iam role delete "$role_name" --force 2>/dev/null && echo "supprimé." || echo "introuvable."
    done
    echo "✓ Nettoyage terminé."
    exit 0
fi

echo "=== Génération des tokens CCM Exoscale ==="
echo "   Prefix    : $PREFIX"
echo "   Étudiants : $STUDENTS"
echo "   Zone      : $ZONE"
echo "   Répertoire: $OUTPUT_DIR"
echo ""

# --- Créer le IAM policy CCM (permissions minimales pour le Cloud Controller Manager) ---
# Le CCM Exoscale a besoin d'accès complet au service compute.
# On utilise "type": "allow" pour éviter les problèmes de noms d'opérations exacts
# (les noms varient selon les versions de l'API Exoscale).
# Le compte est de toute façon limité aux ressources de l'étudiant par son IAM role.
CCM_POLICY=$(cat <<'POLICY'
{
  "default-service-strategy": "deny",
  "services": {
    "compute": {
      "type": "allow"
    }
  }
}
POLICY
)

# Créer un fichier policy temporaire
# --- Initialisation du fichier de sortie ---
OUTPUT_FILE="${OUTPUT_DIR}/$(basename "${OUTPUT_FILE}")"
cat > "$OUTPUT_FILE" <<EOF
# Tokens CCM Exoscale — $(date +%Y-%m-%d)

Fichier généré par \`setup-ccm-token.sh\` pour le TP Kubernetes.
**Confidentiel — à distribuer individuellement à chaque étudiant.**

---

EOF

echo "| Étudiant | IAM Role | API Key | Secret |" >> "$OUTPUT_FILE"
echo "|----------|----------|---------|--------|" >> "$OUTPUT_FILE"

# --- Génération par étudiant ---
for n in $(seq -w 1 "$STUDENTS"); do
    tag="${PREFIX}-${n}"
    role_name="ccm-${tag}"
    secret_name="exoscale-ccm-credentials"
    namespace="kube-system"

    echo -n "  [${n}/${STUDENTS}] IAM role ${role_name}... "

    # Créer le role IAM s'il n'existe pas
    EXISTING_ROLE=$(exo iam role list -O text \
        --output-template '{{range .}}{{if eq .Name "'"${role_name}"'"}}{{.Name}}{{end}}{{end}}' 2>/dev/null || true)

    if [ -z "$EXISTING_ROLE" ]; then
        ROLE_CREATE_OUT=$(echo "$CCM_POLICY" | exo iam role create "$role_name" \
            --policy - \
            -O text --output-template '{{.ID}}' 2>&1)
        ROLE_CREATE_STATUS=$?
        if [ $ROLE_CREATE_STATUS -eq 0 ]; then
            # Extraire uniquement le UUID (le spinner pollue stdout)
            ROLE_ID=$(echo "$ROLE_CREATE_OUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | tail -1)
            echo -n "créé. "
        elif echo "$ROLE_CREATE_OUT" | grep -qi "conflict"; then
            # Le rôle existe déjà (run précédent) — récupérer son ID
            echo -n "conflit (rôle existant, récupération ID)... "
            ROLE_ID=$(exo iam role list -O text \
                --output-template '{{range .}}{{if eq .Name "'"${role_name}"'"}}{{.ID}}{{end}}{{end}}' 2>&1 | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | tail -1)
        else
            echo "❌ Échec role: $ROLE_CREATE_OUT"
            continue
        fi
    else
        ROLE_ID=$(exo iam role list -O text \
            --output-template '{{range .}}{{if eq .Name "'"${role_name}"'"}}{{.ID}}{{end}}{{end}}' 2>&1 | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | tail -1)
        echo -n "existe déjà. "
    fi

    if [ -z "$ROLE_ID" ]; then
        echo "❌ ROLE_ID vide pour $tag"
        continue
    fi

    # Créer l'API key
    echo -n "API key... "
    API_CREDS_RAW=$(exo iam api-key create "$role_name" "$ROLE_ID" \
        -O text --output-template '{{.Key}} {{.Secret}}' 2>&1)
    API_CREDS_STATUS=$?
    # tail -1 : ignore le spinner animé, garde uniquement la dernière ligne (Key Secret)
    API_CREDS=$(echo "$API_CREDS_RAW" | tail -1)
    if [ $API_CREDS_STATUS -ne 0 ]; then
        echo "❌ Échec API key: $API_CREDS_RAW"
        continue
    fi
    API_KEY=$(echo "$API_CREDS" | awk '{print $1}')
    API_SECRET=$(echo "$API_CREDS" | awk '{print $2}')

    if [ -z "$API_KEY" ] || [ -z "$API_SECRET" ]; then
        echo "❌ Échec extraction key/secret: '$API_CREDS'"
        continue
    fi
    echo "générée."

    # Générer le fichier Secret Kubernetes pour cet étudiant
    STUDENT_SECRET_FILE="${OUTPUT_DIR}/ccm-secret-${tag}.yaml"
    cat > "$STUDENT_SECRET_FILE" <<EOF2
# Secret Kubernetes pour le Cloud Controller Manager Exoscale
# Étudiant : ${tag}
# À appliquer sur le cluster : kubectl apply -f ${STUDENT_SECRET_FILE}
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
type: Opaque
stringData:
  api-key: "${API_KEY}"
  api-secret: "${API_SECRET}"
  zone: "${ZONE}"
EOF2

    # Ajouter au fichier récapitulatif
    echo "| \`${tag}\` | \`${role_name}\` | \`${API_KEY}\` | \`${STUDENT_SECRET_FILE}\` |" >> "$OUTPUT_FILE"

    echo "     → Fichier secret : ${STUDENT_SECRET_FILE}"
done

cat >> "$OUTPUT_FILE" <<EOF

---

## Comment utiliser ces tokens

### 1. Transmettre le fichier secret à l'étudiant

\`\`\`bash
# L'étudiant applique le secret sur son cluster
kubectl apply -f ccm-secret-etudiant-01.yaml
\`\`\`

### 2. Installer le CCM Exoscale sur le cluster

\`\`\`bash
# Sur le master de l'étudiant
cd scripts/partie-13-prometheus
./05-install-ccm.sh
\`\`\`

### 3. Vérifier que le Service type:LoadBalancer fonctionne

\`\`\`bash
kubectl get svc kube-prom-grafana -n monitoring
# EXTERNAL-IP doit afficher une IP (NLB créé automatiquement par Exoscale)
\`\`\`
EOF

echo ""
echo "✓ ${STUDENTS} token(s) générés."
echo ""
echo "  Répertoire    : ${OUTPUT_DIR}"
echo "  Récapitulatif : ${OUTPUT_FILE}"
echo "  Secrets       : ${OUTPUT_DIR}/ccm-secret-${PREFIX}-*.yaml"
echo ""
echo "⚠️  Ces fichiers contiennent des clés API — ne jamais les commiter dans git."
echo ""
echo "PROCHAINE ÉTAPE : Distribuer les fichiers ccm-secret-*.yaml aux étudiants"
echo "                  puis lancer 05-install-ccm.sh sur chaque cluster"

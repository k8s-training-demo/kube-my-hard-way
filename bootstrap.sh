#!/bin/bash
# bootstrap.sh — Initialisation du poste instructeur pour le TP Kubernetes / Exoscale
#
# Ce script est à exécuter UNE FOIS après avoir cloné le repo.
# Il installe les outils nécessaires et configure l'environnement local.
#
# Usage :
#   ./bootstrap.sh           # installation complète
#   ./bootstrap.sh --check   # vérification sans installer

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECK_ONLY=false
ERRORS=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --check) CHECK_ONLY=true ;;
        -h|--help)
            echo "Usage: $0 [--check]"
            echo "  --check   Vérifie uniquement, sans installer"
            exit 0 ;;
        *) echo "Option inconnue: $1"; exit 1 ;;
    esac
    shift
done

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "  ${BLUE}→${NC} $1"; }

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Bootstrap — TP Kubernetes / Exoscale                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── 1. Exoscale CLI (exo) ─────────────────────────────────────────────────────
echo "1. Exoscale CLI (exo)"

if command -v exo &>/dev/null; then
    EXO_VERSION=$(exo version 2>/dev/null | head -1 || echo "version inconnue")
    ok "exo installé — $EXO_VERSION"
else
    warn "exo non trouvé"
    if [ "$CHECK_ONLY" = false ]; then
        info "Installation de exo..."
        if [ "$OS" = "Darwin" ]; then
            if command -v brew &>/dev/null; then
                brew install exoscale/tap/exo
                ok "exo installé via Homebrew"
            else
                # Téléchargement direct macOS
                EXO_LATEST=$(curl -s https://api.github.com/repos/exoscale/cli/releases/latest \
                    | grep '"tag_name"' | cut -d'"' -f4)
                EXO_VERSION_NUM="${EXO_LATEST#v}"
                EXO_URL="https://github.com/exoscale/cli/releases/download/${EXO_LATEST}/exo_${EXO_VERSION_NUM}_darwin_all.tar.gz"
                curl -fsSL "$EXO_URL" -o /tmp/exo.tar.gz
                tar -xzf /tmp/exo.tar.gz -C /tmp exo
                sudo mv /tmp/exo /usr/local/bin/exo
                chmod +x /usr/local/bin/exo
                rm /tmp/exo.tar.gz
                ok "exo $EXO_LATEST installé dans /usr/local/bin"
            fi
        elif [ "$OS" = "Linux" ]; then
            ARCH=$(uname -m)
            [ "$ARCH" = "x86_64" ] && ARCH="amd64"
            [ "$ARCH" = "aarch64" ] && ARCH="arm64"
            EXO_LATEST=$(curl -s https://api.github.com/repos/exoscale/cli/releases/latest \
                | grep '"tag_name"' | cut -d'"' -f4)
            EXO_VERSION_NUM="${EXO_LATEST#v}"
            EXO_URL="https://github.com/exoscale/cli/releases/download/${EXO_LATEST}/exo_${EXO_VERSION_NUM}_linux_${ARCH}.tar.gz"
            curl -fsSL "$EXO_URL" -o /tmp/exo.tar.gz
            tar -xzf /tmp/exo.tar.gz -C /tmp exo
            sudo mv /tmp/exo /usr/local/bin/exo
            chmod +x /usr/local/bin/exo
            rm /tmp/exo.tar.gz
            ok "exo $EXO_LATEST installé dans /usr/local/bin"
        else
            fail "OS non supporté pour l'installation automatique — installer exo manuellement"
            info "https://community.exoscale.com/documentation/tools/exoscale-command-line-interface/"
        fi
    else
        fail "exo requis — https://community.exoscale.com/documentation/tools/exoscale-command-line-interface/"
    fi
fi

echo ""

# ── 2. jq ─────────────────────────────────────────────────────────────────────
echo "2. jq (parsing JSON)"

if command -v jq &>/dev/null; then
    ok "jq $(jq --version)"
else
    warn "jq non trouvé"
    if [ "$CHECK_ONLY" = false ]; then
        info "Installation de jq..."
        if [ "$OS" = "Darwin" ] && command -v brew &>/dev/null; then
            brew install jq && ok "jq installé"
        elif [ "$OS" = "Linux" ]; then
            sudo apt-get install -y jq 2>/dev/null || sudo dnf install -y jq 2>/dev/null || fail "Installer jq manuellement"
        else
            fail "Installer jq manuellement : https://jqlang.github.io/jq/"
        fi
    else
        fail "jq requis"
    fi
fi

echo ""

# ── 3. kubectl ────────────────────────────────────────────────────────────────
echo "3. kubectl"

if command -v kubectl &>/dev/null; then
    ok "kubectl $(kubectl version --client --short 2>/dev/null | head -1 || kubectl version --client 2>/dev/null | grep 'Client Version' | awk '{print $3}')"
else
    warn "kubectl non trouvé (optionnel sur ce poste si accès cluster via SSH)"
fi

echo ""

# ── 4. Helm ───────────────────────────────────────────────────────────────────
echo "4. Helm (déploiement kube-prometheus-stack)"

if command -v helm &>/dev/null; then
    ok "helm $(helm version --short 2>/dev/null)"
else
    warn "helm non trouvé (nécessaire uniquement sur les nœuds master)"
fi

echo ""

# ── 5. Git hooks ──────────────────────────────────────────────────────────────
echo "5. Git hooks (protection anti-secrets)"

HOOK_SRC="${REPO_ROOT}/hooks/pre-commit"
HOOK_DST="${REPO_ROOT}/.git/hooks/pre-commit"

if [ ! -f "$HOOK_SRC" ]; then
    fail "hooks/pre-commit introuvable dans le repo"
else
    if [ -f "$HOOK_DST" ] && diff -q "$HOOK_SRC" "$HOOK_DST" &>/dev/null; then
        ok "pre-commit hook déjà installé et à jour"
    else
        if [ "$CHECK_ONLY" = false ]; then
            cp "$HOOK_SRC" "$HOOK_DST"
            chmod +x "$HOOK_DST"
            ok "pre-commit hook installé → .git/hooks/pre-commit"
            info "Bloque les commits contenant des clés API, secrets Kubernetes, clés SSH"
            info "Bypass si nécessaire : git commit --no-verify"
        else
            if [ -f "$HOOK_DST" ]; then
                warn "pre-commit hook présent mais différent de hooks/pre-commit (mettre à jour : ./bootstrap.sh)"
            else
                fail "pre-commit hook non installé — lancer ./bootstrap.sh"
            fi
        fi
    fi
fi

echo ""

# ── 6. Fichier .env ───────────────────────────────────────────────────────────
echo "6. Configuration Exoscale (.env)"

ENV_FILE="${REPO_ROOT}/infra-exo/.env"
ENV_EXAMPLE="${REPO_ROOT}/infra-exo/.env.example"

if [ -f "$ENV_FILE" ]; then
    # Vérifier que les variables clés sont définies
    if grep -q "EXOSCALE_API_KEY=.\+" "$ENV_FILE" 2>/dev/null && \
       grep -q "EXOSCALE_API_SECRET=.\+" "$ENV_FILE" 2>/dev/null; then
        ok ".env présent avec les credentials Exoscale"
    else
        warn ".env présent mais EXOSCALE_API_KEY / EXOSCALE_API_SECRET non définis"
        info "Éditer infra-exo/.env et renseigner les valeurs"
    fi
else
    warn "infra-exo/.env absent"
    if [ "$CHECK_ONLY" = false ]; then
        if [ -f "$ENV_EXAMPLE" ]; then
            cp "$ENV_EXAMPLE" "$ENV_FILE"
            ok ".env créé depuis .env.example"
        else
            cat > "$ENV_FILE" <<'EOF'
# Credentials Exoscale — NE JAMAIS COMMITER CE FICHIER
EXOSCALE_API_KEY=
EXOSCALE_API_SECRET=

# Configuration optionnelle
ZONE=de-fra-1
SECURITY_GROUP=tp-k8s
INSTANCE_TYPE=standard.medium
EOF
            ok ".env créé — renseigner EXOSCALE_API_KEY et EXOSCALE_API_SECRET"
        fi
        info "Éditer : ${ENV_FILE}"
    else
        fail "infra-exo/.env absent — lancer ./bootstrap.sh"
    fi
fi

echo ""

# ── 7. Authentification exo ───────────────────────────────────────────────────
echo "7. Authentification Exoscale"

if command -v exo &>/dev/null; then
    if exo account list &>/dev/null 2>&1; then
        ACCOUNT=$(exo account list 2>/dev/null | grep -v "^NAME" | head -1 | awk '{print $1}')
        ok "exo authentifié${ACCOUNT:+ — compte : $ACCOUNT}"
    else
        warn "exo non authentifié"
        info "Lancer : exo config"
        info "Ou définir EXOSCALE_API_KEY et EXOSCALE_API_SECRET dans infra-exo/.env"
    fi
fi

echo ""

# ── Résumé ────────────────────────────────────────────────────────────────────
echo "══════════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}  Environnement prêt.${NC}"
    echo ""
    echo "  Prochaines étapes :"
    echo "    1. exo config                        # si pas encore authentifié"
    echo "    2. cd infra-exo"
    echo "    3. ./setup-sg.sh                     # créer le security group tp-k8s"
    echo "    4. ./provision-class.sh --count 15   # provisionner les clusters"
else
    echo -e "${RED}  $ERRORS erreur(s) — corriger les points ci-dessus avant de continuer.${NC}"
fi
echo "══════════════════════════════════════════════════════════════"
echo ""

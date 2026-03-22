#!/bin/bash

# Vérifier si un tag a été fourni en argument
if [ -z "$1" ]; then
    echo "❌ Erreur : Aucun tag fourni."
    echo "Usage : $0 <nom_du_tag>"
    exit 1
fi

TAG="$1"
ZONE="${EXOSCALE_ZONE:-de-fra-1}"

if ! command -v jq &> /dev/null; then
    echo "❌ Erreur : jq n'est pas installé."
    exit 1
fi

# Vérification de la connexion (supporte config exo ou env vars)
if ! exo config show > /dev/null 2>&1; then
    echo "❌ Échec de l'authentification avec exo."
    exit 1
fi

echo "✅ Authentification OK."
echo "Recherche des instances avec le tag : '$TAG' (zone: $ZONE)..."

# Récupère tous les noms, puis filtre par label via show
# (exo instance list ne retourne pas les labels dans son JSON)
ALL_NAMES=$(exo compute instance list -z "$ZONE" --output-format json 2>/dev/null | jq -r '.[].name')

FOUND=0
for name in $ALL_NAMES; do
    instance_json=$(exo compute instance show "$name" -z "$ZONE" --output-format json 2>/dev/null)
    lval=$(echo "$instance_json" | jq -r --arg t "$TAG" '.labels[$t] // empty')
    if [ -n "$lval" ]; then
        ip=$(echo "$instance_json" | jq -r '.ip_address // "N/A"')
        state=$(echo "$instance_json" | jq -r '.state // "unknown"')
        printf "%-30s %-18s %s\n" "$name" "$ip" "$state"
        FOUND=$((FOUND + 1))
    fi
done

if [ "$FOUND" -eq 0 ]; then
    echo "ℹ️  Aucune instance trouvée avec le tag '$TAG'."
fi

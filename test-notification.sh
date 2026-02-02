#!/bin/bash
################################################################################
# SCRIPT DE TEST DES NOTIFICATIONS
# Description: Teste l'envoi de notifications via l'endpoint API
# Usage: ./test-notification.sh [API_ENDPOINT]
# Version: 1.0.0
################################################################################

set -e

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
CONFIG_FILE="/opt/patching/config.conf"
API_ENDPOINT="${1:-}"

# Charger la config si aucun argument fourni
if [ -z "$API_ENDPOINT" ] && [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Vérifier que l'endpoint est défini
if [ -z "$API_ENDPOINT" ]; then
    echo -e "${RED}[ERREUR]${NC} Aucun endpoint API fourni"
    echo "Usage: $0 [API_ENDPOINT]"
    echo "Ou configurez API_ENDPOINT dans $CONFIG_FILE"
    exit 1
fi

echo -e "${YELLOW}[INFO]${NC} Test de notification vers: $API_ENDPOINT"
echo ""

# Création du payload de test
json_payload=$(cat <<EOF
{
    "subject": "[TEST] Notification de test - $(hostname)",
    "body": "Ceci est un message de test envoyé depuis le script de patching.\n\nDate: $(date)\nHostname: $(hostname)\nOS: $(lsb_release -d | cut -f2)",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "status": "TEST"
}
EOF
)

echo "Payload JSON:"
echo "-------------"
echo "$json_payload"
echo ""
echo "Envoi de la notification..."
echo ""

# Envoi de la requête
if response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    "$API_ENDPOINT" 2>&1); then

    # Extraire le code HTTP
    http_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | head -n -1)

    echo "Code HTTP: $http_code"
    echo "Réponse: $body"
    echo ""

    # Vérifier le code de réponse
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "${GREEN}[SUCCÈS]${NC} Notification envoyée avec succès!"
        exit 0
    else
        echo -e "${RED}[ERREUR]${NC} Échec de l'envoi (code HTTP: $http_code)"
        exit 1
    fi
else
    echo -e "${RED}[ERREUR]${NC} Impossible de se connecter à l'endpoint"
    echo "Vérifiez:"
    echo "  - L'URL de l'endpoint"
    echo "  - La connectivité réseau"
    echo "  - Les règles de firewall"
    exit 1
fi

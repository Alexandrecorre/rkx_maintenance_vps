#!/bin/bash
################################################################################
# SCRIPT DE VÉRIFICATION DES SERVICES CRITIQUES
# Description: Vérifie que les applications critiques ont bien redémarré
# Usage: Appelé automatiquement après un redémarrage système
# Version: 1.0.0
################################################################################

set -euo pipefail

# Variables
LOG_FILE="/var/log/patching/services-check-$(date +%Y-%m-%d).log"
CONFIG_FILE="/opt/patching/config.conf"
CRITICAL_SERVICES="${CRITICAL_SERVICES:-nginx mysql docker}"
API_ENDPOINT="${API_ENDPOINT:-}"

# Compteurs
TOTAL_SERVICES=0
SERVICES_OK=0
SERVICES_FAILED=0

# Fonction de logging
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Charger la configuration
if [ -f "${CONFIG_FILE}" ]; then
    source "${CONFIG_FILE}"
fi

log "INFO" "=================================================================================="
log "INFO" "VÉRIFICATION DES SERVICES CRITIQUES APRÈS REDÉMARRAGE"
log "INFO" "=================================================================================="

# Informations système
log "INFO" "Hostname: $(hostname)"
log "INFO" "Uptime: $(uptime -p)"
log "INFO" "Boot time: $(who -b | awk '{print $3, $4}')"

# Vérification de chaque service
log "INFO" "Services à vérifier: ${CRITICAL_SERVICES}"

for service in $CRITICAL_SERVICES; do
    ((TOTAL_SERVICES++))

    log "INFO" "Vérification du service: ${service}"

    if systemctl is-active --quiet "${service}"; then
        log "SUCCESS" "${service} - ACTIF"
        ((SERVICES_OK++))

        # Détails du service
        local status=$(systemctl show -p ActiveState,SubState,MainPID "${service}" 2>/dev/null)
        log "INFO" "${service} - ${status}"
    else
        log "ERROR" "${service} - INACTIF ou NON TROUVÉ"
        ((SERVICES_FAILED++))

        # Tenter de redémarrer le service
        log "INFO" "Tentative de redémarrage de ${service}..."
        if systemctl restart "${service}" 2>&1 | tee -a "${LOG_FILE}"; then
            log "SUCCESS" "${service} - Redémarré avec succès"
            ((SERVICES_FAILED--))
            ((SERVICES_OK++))
        else
            log "ERROR" "${service} - Échec du redémarrage"
        fi
    fi
done

# Résumé
log "INFO" "=================================================================================="
log "INFO" "RÉSUMÉ DE LA VÉRIFICATION"
log "INFO" "=================================================================================="
log "INFO" "Total services: ${TOTAL_SERVICES}"
log "INFO" "Services OK: ${SERVICES_OK}"
log "INFO" "Services en échec: ${SERVICES_FAILED}"

# Déterminer le statut global
if [ ${SERVICES_FAILED} -eq 0 ]; then
    STATUS="SUCCÈS"
    log "SUCCESS" "Tous les services critiques sont opérationnels"
    exit_code=0
else
    STATUS="ERREUR"
    log "ERROR" "${SERVICES_FAILED} service(s) critique(s) non opérationnel(s)"
    exit_code=1
fi

# Notification via API
if [ -n "$API_ENDPOINT" ]; then
    log "INFO" "Envoi de notification..."

    json_payload=$(cat <<EOF
{
    "subject": "[${STATUS}] Vérification services après redémarrage - $(hostname)",
    "body": "Services vérifiés: ${TOTAL_SERVICES}\nServices OK: ${SERVICES_OK}\nServices en échec: ${SERVICES_FAILED}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "status": "${STATUS}",
    "details": {
        "total": ${TOTAL_SERVICES},
        "ok": ${SERVICES_OK},
        "failed": ${SERVICES_FAILED}
    }
}
EOF
)

    if curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "${json_payload}" \
        "${API_ENDPOINT}" >> "${LOG_FILE}" 2>&1; then
        log "SUCCESS" "Notification envoyée"
    else
        log "ERROR" "Échec de l'envoi de la notification"
    fi
fi

log "INFO" "Vérification terminée"
exit ${exit_code}

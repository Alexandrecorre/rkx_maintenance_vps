#!/bin/bash
################################################################################
# SCRIPT DE VÉRIFICATION DES SERVICES + DOCKER
# Description: Vérifie services systemd ET conteneurs Docker après redémarrage
# Version: 1.1.0
################################################################################

set -euo pipefail

# Variables
LOG_FILE="/var/log/patching/services-check-$(date +%Y-%m-%d).log"
CONFIG_FILE="/opt/patching/config.conf"
CRITICAL_SERVICES="${CRITICAL_SERVICES:-nginx mysql}"
CRITICAL_CONTAINERS="${CRITICAL_CONTAINERS:-}"
CRITICAL_COMPOSE_PROJECTS="${CRITICAL_COMPOSE_PROJECTS:-}"
API_ENDPOINT="${API_ENDPOINT:-}"

# Compteurs
TOTAL_CHECKS=0
CHECKS_OK=0
CHECKS_FAILED=0

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
log "INFO" "VÉRIFICATION COMPLÈTE APRÈS REDÉMARRAGE (Services + Docker)"
log "INFO" "=================================================================================="

# Informations système
log "INFO" "Hostname: $(hostname)"
log "INFO" "Uptime: $(uptime -p)"
log "INFO" "Boot time: $(who -b | awk '{print $3, $4}')"

################################################################################
# 1. VÉRIFICATION DES SERVICES SYSTEMD
################################################################################

if [ -n "$CRITICAL_SERVICES" ]; then
    log "INFO" "================================================================================"
    log "INFO" "1. VÉRIFICATION DES SERVICES SYSTEMD"
    log "INFO" "================================================================================"
    log "INFO" "Services à vérifier: ${CRITICAL_SERVICES}"

    for service in $CRITICAL_SERVICES; do
        ((TOTAL_CHECKS++))
        log "INFO" "Vérification du service: ${service}"

        if systemctl is-active --quiet "${service}"; then
            log "SUCCESS" "${service} - ACTIF"
            ((CHECKS_OK++))

            # Détails du service
            local status=$(systemctl show -p ActiveState,SubState,MainPID "${service}" 2>/dev/null || echo "N/A")
            log "INFO" "${service} - ${status}"
        else
            log "ERROR" "${service} - INACTIF"
            ((CHECKS_FAILED++))

            # Tentative de redémarrage
            log "INFO" "Tentative de redémarrage de ${service}..."
            if systemctl restart "${service}" 2>&1 | tee -a "${LOG_FILE}"; then
                sleep 3
                if systemctl is-active --quiet "${service}"; then
                    log "SUCCESS" "${service} - Redémarré avec succès"
                    ((CHECKS_FAILED--))
                    ((CHECKS_OK++))
                else
                    log "ERROR" "${service} - Échec du redémarrage"
                fi
            else
                log "ERROR" "${service} - Impossible de redémarrer"
            fi
        fi
    done
fi

################################################################################
# 2. VÉRIFICATION DE DOCKER
################################################################################

log "INFO" "================================================================================"
log "INFO" "2. VÉRIFICATION DE DOCKER"
log "INFO" "================================================================================"

# Vérifier que Docker est installé et actif
if ! command -v docker &> /dev/null; then
    log "WARN" "Docker n'est pas installé, vérifications Docker ignorées"
else
    ((TOTAL_CHECKS++))

    if systemctl is-active --quiet docker; then
        log "SUCCESS" "Service Docker - ACTIF"
        ((CHECKS_OK++))

        # Informations Docker
        log "INFO" "Version Docker: $(docker --version)"
        log "INFO" "Conteneurs en cours: $(docker ps -q | wc -l)"
        log "INFO" "Conteneurs totaux: $(docker ps -aq | wc -l)"
    else
        log "ERROR" "Service Docker - INACTIF"
        ((CHECKS_FAILED++))

        log "INFO" "Tentative de redémarrage de Docker..."
        if systemctl restart docker; then
            sleep 5
            if systemctl is-active --quiet docker; then
                log "SUCCESS" "Docker redémarré avec succès"
                ((CHECKS_FAILED--))
                ((CHECKS_OK++))
            fi
        fi
    fi
fi

################################################################################
# 3. VÉRIFICATION DES CONTENEURS DOCKER
################################################################################

if command -v docker &> /dev/null && systemctl is-active --quiet docker; then

    if [ -n "$CRITICAL_CONTAINERS" ]; then
        log "INFO" "================================================================================"
        log "INFO" "3. VÉRIFICATION DES CONTENEURS DOCKER"
        log "INFO" "================================================================================"
        log "INFO" "Conteneurs critiques: ${CRITICAL_CONTAINERS}"

        for container in $CRITICAL_CONTAINERS; do
            ((TOTAL_CHECKS++))
            log "INFO" "Vérification du conteneur: ${container}"

            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                # Conteneur en cours d'exécution
                local container_status=$(docker inspect --format='{{.State.Status}}' "${container}")
                local container_health=$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || echo "no-healthcheck")

                log "SUCCESS" "${container} - RUNNING (health: ${container_health})"
                ((CHECKS_OK++))

                # Vérifier le health check si disponible
                if [ "$container_health" = "unhealthy" ]; then
                    log "WARN" "${container} - Conteneur en cours mais UNHEALTHY"
                    ((CHECKS_FAILED++))
                    ((CHECKS_OK--))
                fi
            else
                log "ERROR" "${container} - ARRÊTÉ"
                ((CHECKS_FAILED++))

                # Vérifier si le conteneur existe mais est arrêté
                if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
                    log "INFO" "Tentative de redémarrage de ${container}..."
                    if docker start "${container}" 2>&1 | tee -a "${LOG_FILE}"; then
                        sleep 5
                        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                            log "SUCCESS" "${container} - Redémarré avec succès"
                            ((CHECKS_FAILED--))
                            ((CHECKS_OK++))
                        else
                            log "ERROR" "${container} - Échec du redémarrage"
                            docker logs --tail 20 "${container}" 2>&1 | tee -a "${LOG_FILE}"
                        fi
                    fi
                else
                    log "ERROR" "${container} - Conteneur non trouvé"
                fi
            fi
        done
    fi

    ################################################################################
    # 4. VÉRIFICATION DES PROJETS DOCKER COMPOSE
    ################################################################################

    if [ -n "$CRITICAL_COMPOSE_PROJECTS" ]; then
        log "INFO" "================================================================================"
        log "INFO" "4. VÉRIFICATION DES PROJETS DOCKER COMPOSE"
        log "INFO" "================================================================================"

        if ! command -v docker-compose &> /dev/null; then
            log "WARN" "docker-compose n'est pas installé"
        else
            for project_path in $CRITICAL_COMPOSE_PROJECTS; do
                ((TOTAL_CHECKS++))

                local project_name=$(basename "$project_path")
                log "INFO" "Vérification du projet Compose: ${project_name} (${project_path})"

                if [ ! -f "${project_path}/docker-compose.yml" ]; then
                    log "ERROR" "${project_name} - docker-compose.yml non trouvé"
                    ((CHECKS_FAILED++))
                    continue
                fi

                cd "${project_path}"

                # Vérifier l'état des services
                local running_services=$(docker-compose ps --services --filter "status=running" | wc -l)
                local total_services=$(docker-compose ps --services | wc -l)

                log "INFO" "${project_name} - Services: ${running_services}/${total_services} en cours"

                if [ "$running_services" -eq "$total_services" ] && [ "$total_services" -gt 0 ]; then
                    log "SUCCESS" "${project_name} - Tous les services sont actifs"
                    ((CHECKS_OK++))
                else
                    log "ERROR" "${project_name} - Certains services ne sont pas actifs"
                    ((CHECKS_FAILED++))

                    log "INFO" "Tentative de redémarrage du projet ${project_name}..."
                    if docker-compose up -d 2>&1 | tee -a "${LOG_FILE}"; then
                        sleep 10
                        local running_after=$(docker-compose ps --services --filter "status=running" | wc -l)

                        if [ "$running_after" -eq "$total_services" ]; then
                            log "SUCCESS" "${project_name} - Redémarré avec succès"
                            ((CHECKS_FAILED--))
                            ((CHECKS_OK++))
                        else
                            log "ERROR" "${project_name} - Échec du redémarrage complet"
                            docker-compose logs --tail=20 2>&1 | tee -a "${LOG_FILE}"
                        fi
                    fi
                fi
            done
        fi
    fi

    ################################################################################
    # 5. VÉRIFICATION GLOBALE DES CONTENEURS
    ################################################################################

    log "INFO" "================================================================================"
    log "INFO" "5. ÉTAT GLOBAL DES CONTENEURS DOCKER"
    log "INFO" "================================================================================"

    # Liste tous les conteneurs avec restart policy "always"
    local always_restart_containers=$(docker ps -a --filter "restart=always" --format "{{.Names}}" | wc -l)
    local running_always_containers=$(docker ps --filter "restart=always" --format "{{.Names}}" | wc -l)

    log "INFO" "Conteneurs avec restart=always: ${running_always_containers}/${always_restart_containers} actifs"

    # Afficher les conteneurs arrêtés avec restart policy "always"
    local stopped_always=$(docker ps -a --filter "restart=always" --filter "status=exited" --format "{{.Names}}")
    if [ -n "$stopped_always" ]; then
        log "WARN" "Conteneurs arrêtés avec restart=always détectés:"
        echo "$stopped_always" | while read container; do
            log "WARN" "  - ${container}"
            ((TOTAL_CHECKS++))
            ((CHECKS_FAILED++))
        done
    fi
fi

################################################################################
# RÉSUMÉ ET NOTIFICATION
################################################################################

log "INFO" "=================================================================================="
log "INFO" "RÉSUMÉ DE LA VÉRIFICATION"
log "INFO" "=================================================================================="
log "INFO" "Total vérifications: ${TOTAL_CHECKS}"
log "INFO" "Vérifications OK: ${CHECKS_OK}"
log "INFO" "Vérifications en échec: ${CHECKS_FAILED}"

# Déterminer le statut global
if [ ${CHECKS_FAILED} -eq 0 ]; then
    STATUS="SUCCÈS"
    log "SUCCESS" "Tous les services et conteneurs sont opérationnels"
    exit_code=0
elif [ ${CHECKS_FAILED} -lt ${CHECKS_OK} ]; then
    STATUS="AVERTISSEMENT"
    log "WARN" "Certains services/conteneurs ont des problèmes"
    exit_code=10
else
    STATUS="ERREUR"
    log "ERROR" "Plusieurs services/conteneurs critiques non opérationnels"
    exit_code=1
fi

# Notification via API
if [ -n "$API_ENDPOINT" ]; then
    log "INFO" "Envoi de notification..."

    json_payload=$(cat <<EOF
{
    "subject": "[${STATUS}] Vérification services après redémarrage - $(hostname)",
    "body": "Vérifications totales: ${TOTAL_CHECKS}\nOK: ${CHECKS_OK}\nÉchecs: ${CHECKS_FAILED}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "status": "${STATUS}",
    "details": {
        "total": ${TOTAL_CHECKS},
        "ok": ${CHECKS_OK},
        "failed": ${CHECKS_FAILED}
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

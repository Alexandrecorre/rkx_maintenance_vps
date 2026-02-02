#!/bin/bash
################################################################################
# SCRIPT DE PATCHING AUTOMATIQUE VPS UBUNTU
# Description: Effectue la mise à jour système complète avec logging et notifications
# Auteur: Généré automatiquement
# Version: 1.0.0
# Date: 2026-01-26
################################################################################

set -euo pipefail
IFS=$'\n\t'

################################################################################
# 1. VARIABLES DE CONFIGURATION
################################################################################

# Répertoires
SCRIPT_DIR="/opt/patching"
LOG_DIR="/var/log/patching"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Fichier de log avec timestamp
LOG_FILE="${LOG_DIR}/patching-$(date +%Y-%m-%d).log"
REPORT_FILE="${LOG_DIR}/report-$(date +%Y-%m-%d).txt"

# Configuration par défaut (peut être surchargée par config.conf)
LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-90}
ENABLE_REBOOT=${ENABLE_REBOOT:-true}
REBOOT_DELAY=${REBOOT_DELAY:-10}
API_ENDPOINT=${API_ENDPOINT:-""}
DRY_RUN=${DRY_RUN:-false}
MAX_RETRIES=2
RETRY_DELAY=30

# Variables de rapport
PACKAGES_UPDATED=0
ERRORS_COUNT=0
START_TIME=$(date +%s)
STATUS="SUCCÈS"

################################################################################
# 2. FONCTIONS UTILITAIRES
################################################################################

# Fonction de logging
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() {
    log "INFO" "$@"
}

log_warn() {
    log "WARN" "$@"
    ((ERRORS_COUNT++)) || true
}

log_error() {
    log "ERROR" "$@"
    ((ERRORS_COUNT++)) || true
    STATUS="ERREUR"
}

log_success() {
    log "SUCCESS" "$@"
}

# Fonction pour exécuter une commande avec retry
execute_with_retry() {
    local cmd="$1"
    local description="$2"
    local attempt=1
    local max_attempts=$MAX_RETRIES

    log_info "Exécution: ${description}"

    while [ $attempt -le $max_attempts ]; do
        if [ "$DRY_RUN" = true ]; then
            log_info "[DRY-RUN] Simulation: ${cmd}"
            return 0
        fi

        if eval "$cmd" >> "${LOG_FILE}" 2>&1; then
            log_success "${description} - Succès"
            return 0
        else
            local exit_code=$?
            log_warn "${description} - Échec (tentative ${attempt}/${max_attempts}) - Code: ${exit_code}"

            if [ $attempt -lt $max_attempts ]; then
                log_info "Nouvelle tentative dans ${RETRY_DELAY} secondes..."
                sleep $RETRY_DELAY
            fi
            ((attempt++))
        fi
    done

    log_error "${description} - Échec après ${max_attempts} tentatives"
    return 1
}

# Fonction de vérification de l'espace disque
check_disk_space() {
    log_info "Vérification de l'espace disque disponible"

    local available=$(df / | tail -1 | awk '{print $4}')
    local available_gb=$((available / 1024 / 1024))

    log_info "Espace disponible: ${available_gb} GB"

    if [ $available_gb -lt 2 ]; then
        log_error "Espace disque insuffisant (< 2GB). Arrêt du patching."
        return 1
    fi

    return 0
}

# Fonction d'envoi de notification via API
send_notification() {
    local subject="$1"
    local body="$2"

    if [ -z "$API_ENDPOINT" ]; then
        log_warn "Aucun endpoint API configuré pour les notifications"
        return 0
    fi

    log_info "Envoi de notification: ${subject}"

    local json_payload=$(cat <<EOF
{
    "subject": "${subject}",
    "body": "${body}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "hostname": "$(hostname)",
    "status": "${STATUS}"
}
EOF
)

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY-RUN] Notification non envoyée"
        return 0
    fi

    if curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "${json_payload}" \
        "${API_ENDPOINT}" >> "${LOG_FILE}" 2>&1; then
        log_success "Notification envoyée avec succès"
        return 0
    else
        log_error "Échec de l'envoi de la notification"
        return 1
    fi
}

################################################################################
# 3. VALIDATION DE L'ENVIRONNEMENT
################################################################################

validate_environment() {
    log_info "=== VALIDATION DE L'ENVIRONNEMENT ==="

    # Vérification root
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        log_error "Ce script doit être exécuté en tant que root"
        exit 1
    fi

    # Création des répertoires si nécessaire
    if [ ! -d "${LOG_DIR}" ]; then
        log_info "Création du répertoire de logs: ${LOG_DIR}"
        mkdir -p "${LOG_DIR}"
        chmod 755 "${LOG_DIR}"
    fi

    if [ ! -d "${SCRIPT_DIR}" ]; then
        log_info "Création du répertoire de script: ${SCRIPT_DIR}"
        mkdir -p "${SCRIPT_DIR}"
        chmod 755 "${SCRIPT_DIR}"
    fi

    # Chargement du fichier de configuration si existant
    if [ -f "${CONFIG_FILE}" ]; then
        log_info "Chargement de la configuration: ${CONFIG_FILE}"
        source "${CONFIG_FILE}"
    else
        log_warn "Fichier de configuration non trouvé, utilisation des valeurs par défaut"
    fi

    # Vérification de l'espace disque
    check_disk_space || exit 1

    # Vérification de la timezone
    local current_tz=$(timedatectl | grep "Time zone" | awk '{print $3}')
    log_info "Timezone actuelle: ${current_tz}"

    log_success "Validation de l'environnement terminée"
}

################################################################################
# 4. SAUVEGARDE PRÉ-PATCHING
################################################################################

pre_patching_backup() {
    log_info "=== SAUVEGARDE PRÉ-PATCHING ==="

    # Sauvegarde de la liste des paquets installés
    local backup_file="${LOG_DIR}/packages-before-$(date +%Y-%m-%d).txt"

    if [ "$DRY_RUN" = false ]; then
        dpkg -l > "${backup_file}" 2>&1
        log_success "Liste des paquets sauvegardée: ${backup_file}"
    else
        log_info "[DRY-RUN] Sauvegarde de la liste des paquets simulée"
    fi
}

################################################################################
# 5. MISE À JOUR DES PAQUETS
################################################################################

update_packages() {
    log_info "=== MISE À JOUR DES PAQUETS ==="

    # 5.1 - Mise à jour de la liste des paquets
    execute_with_retry \
        "apt-get update" \
        "Rafraîchissement de la liste des paquets" || return 1

    # 5.2 - Vérification des paquets disponibles
    if [ "$DRY_RUN" = false ]; then
        local upgradable=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
        PACKAGES_UPDATED=$upgradable
        log_info "Nombre de paquets à mettre à jour: ${PACKAGES_UPDATED}"
    fi

    # 5.3 - Installation des mises à jour
    if [ "$PACKAGES_UPDATED" -gt 0 ] || [ "$DRY_RUN" = true ]; then
        execute_with_retry \
            "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'" \
            "Installation des mises à jour standard"

        # Mise à jour des paquets de sécurité critiques
        execute_with_retry \
            "DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'" \
            "Installation des mises à jour de sécurité"
    else
        log_info "Aucun paquet à mettre à jour"
    fi

    # 5.4 - Nettoyage des paquets obsolètes
    execute_with_retry \
        "apt-get autoremove -y" \
        "Suppression des paquets obsolètes"

    execute_with_retry \
        "apt-get autoclean -y" \
        "Nettoyage du cache des paquets"

    log_success "Mise à jour des paquets terminée"
}

################################################################################
# 6. GESTION DES DÉPENDANCES
################################################################################

fix_dependencies() {
    log_info "=== VÉRIFICATION DES DÉPENDANCES ==="

    # Vérification et correction des dépendances cassées
    execute_with_retry \
        "apt-get install -f -y" \
        "Correction des dépendances cassées"

    # Vérification de l'état du système de paquets
    if [ "$DRY_RUN" = false ]; then
        if dpkg --audit >> "${LOG_FILE}" 2>&1; then
            log_success "Aucun problème de dépendances détecté"
        else
            log_warn "Des problèmes de dépendances ont été détectés"
            STATUS="AVERTISSEMENT"
        fi
    fi
}

################################################################################
# 7. VÉRIFICATION DU REDÉMARRAGE
################################################################################

check_reboot_required() {
    log_info "=== VÉRIFICATION REDÉMARRAGE REQUIS ==="

    local reboot_needed=false

    # Vérification du fichier de redémarrage requis
    if [ -f /var/run/reboot-required ]; then
        reboot_needed=true
        log_warn "Redémarrage système requis"

        if [ -f /var/run/reboot-required.pkgs ]; then
            log_info "Paquets nécessitant un redémarrage:"
            cat /var/run/reboot-required.pkgs | tee -a "${LOG_FILE}"
        fi
    else
        log_info "Aucun redémarrage système requis"
    fi

    # Gestion du redémarrage
    if [ "$reboot_needed" = true ] && [ "$ENABLE_REBOOT" = true ]; then
        log_warn "Redémarrage programmé dans ${REBOOT_DELAY} minutes"

        if [ "$DRY_RUN" = false ]; then
            shutdown -r +${REBOOT_DELAY} "Redémarrage automatique après patching système" &
            log_info "Commande de redémarrage programmée"
        else
            log_info "[DRY-RUN] Redémarrage simulé"
        fi
    elif [ "$reboot_needed" = true ]; then
        log_warn "Redémarrage requis mais désactivé dans la configuration"
        STATUS="AVERTISSEMENT"
    fi
}

################################################################################
# 8. GÉNÉRATION DU RAPPORT
################################################################################

generate_report() {
    log_info "=== GÉNÉRATION DU RAPPORT ==="

    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local duration_min=$((duration / 60))

    local reboot_status="NON"
    if [ -f /var/run/reboot-required ] && [ "$ENABLE_REBOOT" = true ]; then
        reboot_status="OUI (dans ${REBOOT_DELAY} min)"
    elif [ -f /var/run/reboot-required ]; then
        reboot_status="REQUIS (non programmé)"
    fi

    cat > "${REPORT_FILE}" <<EOF
================================================================================
RAPPORT DE PATCHING AUTOMATIQUE
================================================================================

Serveur: $(hostname)
Date d'exécution: $(date '+%Y-%m-%d %H:%M:%S %Z')
Durée totale: ${duration_min} minutes (${duration} secondes)

RÉSUMÉ
------
Status global: ${STATUS}
Paquets mis à jour: ${PACKAGES_UPDATED}
Erreurs rencontrées: ${ERRORS_COUNT}
Redémarrage programmé: ${reboot_status}

DÉTAILS SYSTÈME
---------------
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
Uptime: $(uptime -p)
Charge système: $(uptime | awk -F'load average:' '{print $2}')

ESPACE DISQUE
-------------
$(df -h / | tail -1)

MÉMOIRE
-------
$(free -h | grep "Mem:")

LOGS COMPLETS
-------------
Voir: ${LOG_FILE}

================================================================================
EOF

    log_info "Rapport généré: ${REPORT_FILE}"

    # Affichage du rapport dans les logs
    cat "${REPORT_FILE}" | tee -a "${LOG_FILE}"
}

################################################################################
# 9. NOTIFICATIONS
################################################################################

send_notifications() {
    log_info "=== ENVOI DES NOTIFICATIONS ==="

    local subject="[${STATUS}] Patching VPS $(hostname) - $(date +%Y-%m-%d)"
    local body=$(cat "${REPORT_FILE}")

    send_notification "${subject}" "${body}"
}

################################################################################
# 10. NETTOYAGE DES ANCIENS LOGS
################################################################################

cleanup_old_logs() {
    log_info "=== NETTOYAGE DES ANCIENS LOGS ==="

    if [ "$DRY_RUN" = false ]; then
        local deleted_count=$(find "${LOG_DIR}" -name "patching-*.log" -type f -mtime +${LOG_RETENTION_DAYS} -delete -print | wc -l)
        local deleted_reports=$(find "${LOG_DIR}" -name "report-*.txt" -type f -mtime +${LOG_RETENTION_DAYS} -delete -print | wc -l)
        local deleted_backups=$(find "${LOG_DIR}" -name "packages-before-*.txt" -type f -mtime +${LOG_RETENTION_DAYS} -delete -print | wc -l)

        local total_deleted=$((deleted_count + deleted_reports + deleted_backups))

        if [ $total_deleted -gt 0 ]; then
            log_info "Fichiers supprimés: ${total_deleted} (logs: ${deleted_count}, rapports: ${deleted_reports}, backups: ${deleted_backups})"
        else
            log_info "Aucun ancien fichier à supprimer"
        fi
    else
        log_info "[DRY-RUN] Nettoyage des logs simulé"
    fi
}

################################################################################
# 11. FONCTION PRINCIPALE
################################################################################

main() {
    # Début du script
    log_info "=================================================================================="
    log_info "DÉBUT DU PATCHING AUTOMATIQUE"
    log_info "=================================================================================="

    if [ "$DRY_RUN" = true ]; then
        log_warn "MODE DRY-RUN ACTIVÉ - Aucune modification ne sera effectuée"
    fi

    # Étapes du patching
    validate_environment
    pre_patching_backup

    if ! update_packages; then
        log_error "Échec de la mise à jour des paquets"
        STATUS="ERREUR"
    fi

    fix_dependencies
    check_reboot_required

    # Rapport et notifications
    generate_report
    send_notifications
    cleanup_old_logs

    # Fin du script
    log_info "=================================================================================="
    log_info "FIN DU PATCHING - STATUS: ${STATUS}"
    log_info "=================================================================================="

    # Code de sortie basé sur le statut
    if [ "$STATUS" = "SUCCÈS" ]; then
        exit 0
    elif [ "$STATUS" = "AVERTISSEMENT" ]; then
        exit 10
    else
        exit 1
    fi
}

################################################################################
# 12. GESTION DES ARGUMENTS
################################################################################

# Aide
show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Script de patching automatique pour VPS Ubuntu

OPTIONS:
    --dry-run           Mode simulation (aucune modification)
    --help              Afficher cette aide
    --version           Afficher la version du script

EXEMPLES:
    $0                  Exécution normale
    $0 --dry-run        Test sans modification

FICHIERS:
    Configuration: ${CONFIG_FILE}
    Logs: ${LOG_DIR}/

EOF
    exit 0
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        --version|-v)
            echo "Version 1.0.0"
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            echo "Utilisez --help pour l'aide"
            exit 1
            ;;
    esac
done

################################################################################
# EXÉCUTION
################################################################################

main

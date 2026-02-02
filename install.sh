#!/bin/bash
################################################################################
# SCRIPT D'INSTALLATION - PATCHING AUTOMATIQUE VPS UBUNTU
# Description: Installation automatique du système de patching
# Version: 1.0.0
################################################################################

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="/opt/patching"
LOG_DIR="/var/log/patching"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fonctions d'affichage
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================================${NC}"
}

# Vérification root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Ce script doit être exécuté en tant que root"
        echo "Utilisez: sudo $0"
        exit 1
    fi
}

# Vérification de l'OS
check_os() {
    print_info "Vérification du système d'exploitation..."

    if [ ! -f /etc/os-release ]; then
        print_error "Impossible de détecter le système d'exploitation"
        exit 1
    fi

    . /etc/os-release

    if [ "$ID" != "ubuntu" ]; then
        print_warning "Ce script est conçu pour Ubuntu, détecté: $ID"
        read -p "Continuer quand même? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    print_success "OS détecté: $PRETTY_NAME"
}

# Installation des dépendances
install_dependencies() {
    print_info "Installation des dépendances..."

    apt-get update -qq
    apt-get install -y curl cron > /dev/null 2>&1

    print_success "Dépendances installées"
}

# Création des répertoires
create_directories() {
    print_info "Création des répertoires..."

    mkdir -p "$SCRIPT_DIR"
    mkdir -p "$LOG_DIR"

    chmod 755 "$SCRIPT_DIR"
    chmod 755 "$LOG_DIR"

    print_success "Répertoires créés: $SCRIPT_DIR, $LOG_DIR"
}

# Installation des fichiers
install_files() {
    print_info "Installation des fichiers..."

    # Script principal
    if [ -f "$CURRENT_DIR/patch-vps.sh" ]; then
        cp "$CURRENT_DIR/patch-vps.sh" "$SCRIPT_DIR/"
        chmod 700 "$SCRIPT_DIR/patch-vps.sh"
        chown root:root "$SCRIPT_DIR/patch-vps.sh"
        print_success "Script principal installé"
    else
        print_error "Fichier patch-vps.sh introuvable dans $CURRENT_DIR"
        exit 1
    fi

    # Fichier de configuration
    if [ -f "$CURRENT_DIR/config.conf" ]; then
        if [ -f "$SCRIPT_DIR/config.conf" ]; then
            print_warning "config.conf existe déjà, création d'une sauvegarde"
            cp "$SCRIPT_DIR/config.conf" "$SCRIPT_DIR/config.conf.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        cp "$CURRENT_DIR/config.conf" "$SCRIPT_DIR/"
        chmod 600 "$SCRIPT_DIR/config.conf"
        chown root:root "$SCRIPT_DIR/config.conf"
        print_success "Fichier de configuration installé"
    else
        print_warning "config.conf introuvable, création d'un fichier par défaut"
        cat > "$SCRIPT_DIR/config.conf" <<EOF
# Configuration par défaut
LOG_RETENTION_DAYS=90
ENABLE_REBOOT=true
REBOOT_DELAY=10
API_ENDPOINT=""
EOF
        chmod 600 "$SCRIPT_DIR/config.conf"
        chown root:root "$SCRIPT_DIR/config.conf"
    fi
}

# Test du script
test_script() {
    print_info "Test du script en mode dry-run..."

    if "$SCRIPT_DIR/patch-vps.sh" --dry-run; then
        print_success "Test du script réussi"
        return 0
    else
        print_error "Test du script échoué"
        return 1
    fi
}

# Configuration du cron
install_cron() {
    print_info "Configuration du cron job..."

    local cron_line="0 2 * * 3 $SCRIPT_DIR/patch-vps.sh >> $LOG_DIR/cron.log 2>&1"

    # Vérifier si le cron existe déjà
    if crontab -l 2>/dev/null | grep -q "$SCRIPT_DIR/patch-vps.sh"; then
        print_warning "Cron job déjà configuré"
        echo "Cron actuel:"
        crontab -l | grep patch-vps.sh
        return 0
    fi

    # Ajouter le cron job
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -

    print_success "Cron job installé"
    echo "Planification: Tous les mercredis à 02h00 UTC"
}

# Affichage de la timezone
show_timezone() {
    print_info "Configuration de la timezone:"
    timedatectl | grep "Time zone" || echo "Timezone non disponible"

    local tz=$(timedatectl | grep "Time zone" | awk '{print $3}')
    if [ "$tz" != "UTC" ]; then
        print_warning "Timezone actuelle: $tz (le cron utilise l'heure locale)"
        print_info "Le script s'exécutera tous les mercredis à 02h00 heure locale"
    else
        print_success "Timezone: UTC (recommandé)"
    fi
}

# Configuration interactive
interactive_config() {
    print_header "CONFIGURATION INTERACTIVE"

    read -p "Voulez-vous configurer les paramètres maintenant? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Configuration ignorée. Vous pouvez éditer $SCRIPT_DIR/config.conf plus tard"
        return 0
    fi

    # API Endpoint
    echo ""
    read -p "Endpoint API pour les notifications (laissez vide pour ignorer): " api_endpoint
    if [ -n "$api_endpoint" ]; then
        sed -i "s|^API_ENDPOINT=.*|API_ENDPOINT=\"$api_endpoint\"|" "$SCRIPT_DIR/config.conf"
        print_success "API endpoint configuré"
    fi

    # Redémarrage automatique
    echo ""
    read -p "Activer le redémarrage automatique après patching? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        sed -i "s/^ENABLE_REBOOT=.*/ENABLE_REBOOT=false/" "$SCRIPT_DIR/config.conf"
        print_success "Redémarrage automatique désactivé"
    else
        print_success "Redémarrage automatique activé"
    fi

    # Services critiques
    echo ""
    read -p "Services critiques à surveiller (ex: nginx mysql, laissez vide pour ignorer): " critical_services
    if [ -n "$critical_services" ]; then
        sed -i "s/^CRITICAL_SERVICES=.*/CRITICAL_SERVICES=\"$critical_services\"/" "$SCRIPT_DIR/config.conf"
        print_success "Services critiques configurés"
    fi

    print_success "Configuration terminée"
}

# Résumé de l'installation
show_summary() {
    print_header "RÉSUMÉ DE L'INSTALLATION"

    echo ""
    echo "Installation terminée avec succès!"
    echo ""
    echo "Fichiers installés:"
    echo "  - Script:        $SCRIPT_DIR/patch-vps.sh"
    echo "  - Configuration: $SCRIPT_DIR/config.conf"
    echo "  - Logs:          $LOG_DIR/"
    echo ""
    echo "Cron configuré:"
    echo "  - Fréquence: Tous les mercredis à 02h00"
    crontab -l | grep patch-vps.sh | sed 's/^/  - /'
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Éditer la configuration: nano $SCRIPT_DIR/config.conf"
    echo "  2. Tester le script:        $SCRIPT_DIR/patch-vps.sh --dry-run"
    echo "  3. Consulter les logs:      tail -f $LOG_DIR/patching-\$(date +%Y-%m-%d).log"
    echo ""
    echo "Pour plus d'informations, consultez le fichier README.md"
    echo ""
}

# Désinstallation
uninstall() {
    print_header "DÉSINSTALLATION DU SCRIPT DE PATCHING"

    read -p "Êtes-vous sûr de vouloir désinstaller? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Désinstallation annulée"
        exit 0
    fi

    print_info "Suppression du cron job..."
    crontab -l 2>/dev/null | grep -v "patch-vps.sh" | crontab - || true

    print_info "Suppression des fichiers..."
    read -p "Supprimer également les logs? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$LOG_DIR"
        print_success "Logs supprimés"
    else
        print_info "Logs conservés dans $LOG_DIR"
    fi

    rm -rf "$SCRIPT_DIR"
    print_success "Désinstallation terminée"
    exit 0
}

# Menu principal
show_menu() {
    print_header "INSTALLATION DU SCRIPT DE PATCHING VPS UBUNTU"
    echo ""
    echo "1) Installation complète (recommandé)"
    echo "2) Installation sans configuration du cron"
    echo "3) Réinstaller uniquement le script"
    echo "4) Tester le script existant"
    echo "5) Désinstaller"
    echo "6) Quitter"
    echo ""
    read -p "Votre choix [1-6]: " choice

    case $choice in
        1)
            check_root
            check_os
            install_dependencies
            create_directories
            install_files
            test_script
            install_cron
            show_timezone
            interactive_config
            show_summary
            ;;
        2)
            check_root
            check_os
            install_dependencies
            create_directories
            install_files
            test_script
            interactive_config
            print_success "Installation terminée (sans cron)"
            print_info "Pour configurer le cron manuellement: crontab -e"
            ;;
        3)
            check_root
            install_files
            test_script
            print_success "Script réinstallé"
            ;;
        4)
            check_root
            if [ -f "$SCRIPT_DIR/patch-vps.sh" ]; then
                "$SCRIPT_DIR/patch-vps.sh" --dry-run
            else
                print_error "Script non trouvé. Installez-le d'abord."
            fi
            ;;
        5)
            check_root
            uninstall
            ;;
        6)
            print_info "Installation annulée"
            exit 0
            ;;
        *)
            print_error "Choix invalide"
            exit 1
            ;;
    esac
}

# Main
main() {
    # Si argument --uninstall
    if [ "$1" = "--uninstall" ]; then
        check_root
        uninstall
    # Si argument --auto (installation automatique sans interaction)
    elif [ "$1" = "--auto" ]; then
        check_root
        check_os
        install_dependencies
        create_directories
        install_files
        test_script
        install_cron
        show_summary
    else
        show_menu
    fi
}

# Exécution
main "$@"

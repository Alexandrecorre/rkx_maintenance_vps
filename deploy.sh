#!/bin/bash
################################################################################
# SCRIPT DE DÉPLOIEMENT DISTANT
# Description: Déploie le système de patching sur un serveur distant via SSH
# Usage: ./deploy.sh user@hostname
# Version: 1.0.0
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo ""
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================================${NC}"
    echo ""
}

# Vérification des arguments
if [ $# -eq 0 ]; then
    print_error "Aucun serveur cible spécifié"
    echo ""
    echo "Usage: $0 user@hostname [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run     Simuler le déploiement sans modifications"
    echo "  --cron        Installer avec cron (par défaut)"
    echo "  --systemd     Installer avec systemd timer"
    echo ""
    echo "Exemples:"
    echo "  $0 root@192.168.1.100"
    echo "  $0 ubuntu@vps.example.com --systemd"
    echo "  $0 admin@server.com --dry-run"
    exit 1
fi

# Variables
SERVER=$1
DRY_RUN=false
USE_SYSTEMD=false
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_TMP_DIR="/tmp/patching-deploy-$$"

# Parse des options
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --systemd)
            USE_SYSTEMD=true
            shift
            ;;
        --cron)
            USE_SYSTEMD=false
            shift
            ;;
        *)
            print_error "Option inconnue: $1"
            exit 1
            ;;
    esac
done

print_header "DÉPLOIEMENT DU SYSTÈME DE PATCHING"

if [ "$DRY_RUN" = true ]; then
    print_warning "MODE DRY-RUN ACTIVÉ - Aucune modification ne sera effectuée"
fi

print_info "Serveur cible: $SERVER"
print_info "Méthode de planification: $([ "$USE_SYSTEMD" = true ] && echo "systemd timer" || echo "cron")"

# Vérification de la connexion SSH
print_info "Vérification de la connexion SSH..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER" "echo 'Connexion réussie'" > /dev/null 2>&1; then
    print_error "Impossible de se connecter à $SERVER"
    print_info "Assurez-vous que:"
    print_info "  - Le serveur est accessible"
    print_info "  - Votre clé SSH est configurée"
    print_info "  - L'utilisateur a les droits sudo"
    exit 1
fi
print_success "Connexion SSH établie"

# Vérification des fichiers requis
print_info "Vérification des fichiers locaux..."
required_files=(
    "patch-vps.sh"
    "config.conf"
    "install.sh"
    "check-services.sh"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$CURRENT_DIR/$file" ]; then
        print_error "Fichier requis manquant: $file"
        exit 1
    fi
done
print_success "Tous les fichiers requis sont présents"

# Création du répertoire temporaire distant
print_info "Création du répertoire temporaire distant..."
if [ "$DRY_RUN" = false ]; then
    ssh "$SERVER" "mkdir -p $REMOTE_TMP_DIR"
fi
print_success "Répertoire temporaire créé: $REMOTE_TMP_DIR"

# Copie des fichiers
print_info "Copie des fichiers vers le serveur..."
files_to_copy=(
    "patch-vps.sh"
    "config.conf"
    "install.sh"
    "check-services.sh"
    "test-notification.sh"
    "README.md"
    "CHEATSHEET.md"
)

if [ "$USE_SYSTEMD" = true ]; then
    files_to_copy+=(
        "patching.service"
        "patching.timer"
        "patching-check.service"
        "SYSTEMD_TIMER.md"
    )
fi

if [ "$DRY_RUN" = false ]; then
    for file in "${files_to_copy[@]}"; do
        if [ -f "$CURRENT_DIR/$file" ]; then
            scp -q "$CURRENT_DIR/$file" "$SERVER:$REMOTE_TMP_DIR/"
            print_success "  ✓ $file"
        fi
    done
else
    print_warning "  [DRY-RUN] Copie des fichiers simulée"
fi

# Installation
print_header "INSTALLATION SUR LE SERVEUR"

if [ "$DRY_RUN" = false ]; then
    # Script d'installation distant
    ssh "$SERVER" "bash -s" <<REMOTE_SCRIPT
set -e

# Couleurs pour SSH
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\${BLUE}[INFO]\${NC} Installation sur $(hostname)..."

# Vérification root
if [ "\$EUID" -ne 0 ]; then
    echo -e "\${RED}[ERROR]\${NC} Les commandes suivantes nécessitent sudo"
    echo "Relancez avec: ssh $SERVER 'sudo bash' < deploy.sh"
    exit 1
fi

# Copie des fichiers
echo -e "\${BLUE}[INFO]\${NC} Création des répertoires..."
mkdir -p /opt/patching
mkdir -p /var/log/patching
chmod 755 /opt/patching
chmod 755 /var/log/patching

echo -e "\${BLUE}[INFO]\${NC} Installation des fichiers..."
cd $REMOTE_TMP_DIR

# Script principal
cp patch-vps.sh /opt/patching/
chmod 700 /opt/patching/patch-vps.sh
chown root:root /opt/patching/patch-vps.sh

# Script de vérification
cp check-services.sh /opt/patching/
chmod 700 /opt/patching/check-services.sh
chown root:root /opt/patching/check-services.sh

# Configuration (ne pas écraser si existe)
if [ -f /opt/patching/config.conf ]; then
    echo -e "\${YELLOW}[WARNING]\${NC} config.conf existe, sauvegarde créée"
    cp /opt/patching/config.conf /opt/patching/config.conf.backup-\$(date +%Y%m%d-%H%M%S)
fi
cp config.conf /opt/patching/
chmod 600 /opt/patching/config.conf
chown root:root /opt/patching/config.conf

# Documentation
[ -f README.md ] && cp README.md /opt/patching/
[ -f CHEATSHEET.md ] && cp CHEATSHEET.md /opt/patching/

# Test du script
echo -e "\${BLUE}[INFO]\${NC} Test du script..."
if /opt/patching/patch-vps.sh --dry-run > /dev/null 2>&1; then
    echo -e "\${GREEN}[SUCCESS]\${NC} Script testé avec succès"
else
    echo -e "\${RED}[ERROR]\${NC} Échec du test du script"
    exit 1
fi

# Installation de la planification
if [ "$USE_SYSTEMD" = true ]; then
    echo -e "\${BLUE}[INFO]\${NC} Installation du systemd timer..."

    cp patching.service /etc/systemd/system/
    cp patching.timer /etc/systemd/system/
    [ -f patching-check.service ] && cp patching-check.service /etc/systemd/system/

    systemctl daemon-reload
    systemctl enable patching.timer
    systemctl start patching.timer

    echo -e "\${GREEN}[SUCCESS]\${NC} Systemd timer installé"
    systemctl list-timers patching.timer
else
    echo -e "\${BLUE}[INFO]\${NC} Installation du cron job..."

    cron_line="0 2 * * 3 /opt/patching/patch-vps.sh >> /var/log/patching/cron.log 2>&1"

    if crontab -l 2>/dev/null | grep -q "patch-vps.sh"; then
        echo -e "\${YELLOW}[WARNING]\${NC} Cron job déjà existant"
    else
        (crontab -l 2>/dev/null; echo "\$cron_line") | crontab -
        echo -e "\${GREEN}[SUCCESS]\${NC} Cron job installé"
    fi
fi

# Nettoyage
echo -e "\${BLUE}[INFO]\${NC} Nettoyage..."
rm -rf $REMOTE_TMP_DIR

echo -e "\${GREEN}[SUCCESS]\${NC} Installation terminée!"
echo ""
echo "Configuration:"
echo "  - Éditer: nano /opt/patching/config.conf"
echo "  - Test: /opt/patching/patch-vps.sh --dry-run"
echo "  - Logs: tail -f /var/log/patching/patching-\$(date +%Y-%m-%d).log"
REMOTE_SCRIPT

    print_success "Installation terminée sur $SERVER"
else
    print_warning "[DRY-RUN] Installation simulée"
fi

# Résumé
print_header "RÉSUMÉ DU DÉPLOIEMENT"

echo "Serveur: $SERVER"
echo "Status: $([ "$DRY_RUN" = true ] && echo "Simulé (dry-run)" || echo "Installé avec succès")"
echo "Planification: $([ "$USE_SYSTEMD" = true ] && echo "systemd timer" || echo "cron")"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo "Prochaines étapes:"
    echo "  1. Se connecter au serveur: ssh $SERVER"
    echo "  2. Éditer la configuration: sudo nano /opt/patching/config.conf"
    echo "  3. Tester le script: sudo /opt/patching/patch-vps.sh --dry-run"
    echo ""
    echo "Commandes utiles:"
    if [ "$USE_SYSTEMD" = true ]; then
        echo "  - Voir le statut: sudo systemctl status patching.timer"
        echo "  - Voir les logs: sudo journalctl -u patching.service -f"
        echo "  - Exécuter maintenant: sudo systemctl start patching.service"
    else
        echo "  - Voir le cron: sudo crontab -l"
        echo "  - Voir les logs: sudo tail -f /var/log/patching/patching-\$(date +%Y-%m-%d).log"
        echo "  - Exécuter maintenant: sudo /opt/patching/patch-vps.sh"
    fi
fi

echo ""
print_success "Déploiement terminé!"

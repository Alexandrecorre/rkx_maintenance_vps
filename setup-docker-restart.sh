#!/bin/bash
################################################################################
# SCRIPT DE CONFIGURATION AUTOMATIQUE DES RESTART POLICIES DOCKER
# Description: Configure tous les conteneurs Docker avec restart=always
# Usage: sudo bash setup-docker-restart.sh
# Version: 1.0.0
################################################################################

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Vérification root
if [ "$EUID" -ne 0 ]; then
    print_error "Ce script doit être exécuté en tant que root"
    exit 1
fi

# Vérification Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker n'est pas installé"
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    print_error "Le service Docker n'est pas actif"
    print_info "Démarrage de Docker..."
    systemctl start docker
fi

print_header "CONFIGURATION DES RESTART POLICIES DOCKER"

# 1. Afficher l'état actuel
print_info "État actuel des conteneurs:"
echo ""
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RestartPolicy}}" | head -20
echo ""

# 2. Compter les conteneurs
total_containers=$(docker ps -aq | wc -l)
running_containers=$(docker ps -q | wc -l)
stopped_containers=$((total_containers - running_containers))

print_info "Total: ${total_containers} conteneurs (${running_containers} en cours, ${stopped_containers} arrêtés)"
echo ""

# 3. Demander confirmation
read -p "Voulez-vous configurer restart=always pour TOUS les conteneurs? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Configuration annulée"
    echo ""
    print_info "Options alternatives:"
    echo "  1. Configurer manuellement: docker update --restart=always NOM_CONTENEUR"
    echo "  2. Pour un seul: docker update --restart=unless-stopped NOM_CONTENEUR"
    echo "  3. Désactiver restart: docker update --restart=no NOM_CONTENEUR"
    exit 0
fi

print_header "APPLICATION DES RESTART POLICIES"

# 4. Configurer restart=always pour tous les conteneurs
updated=0
failed=0

for container_id in $(docker ps -aq); do
    container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/\///')
    current_policy=$(docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' "$container_id")

    print_info "Configuration de: ${container_name} (actuel: ${current_policy})"

    if docker update --restart=always "$container_id" > /dev/null 2>&1; then
        print_success "  ✓ ${container_name} configuré avec restart=always"
        ((updated++))
    else
        print_error "  ✗ Échec pour ${container_name}"
        ((failed++))
    fi
done

echo ""
print_header "RÉSUMÉ"

echo "Conteneurs mis à jour: ${updated}"
echo "Échecs: ${failed}"
echo ""

# 5. Afficher le nouvel état
print_info "Nouvel état des conteneurs:"
echo ""
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RestartPolicy}}" | head -20
echo ""

# 6. Vérifier les conteneurs arrêtés
stopped_always=$(docker ps -a --filter "restart=always" --filter "status=exited" --format "{{.Names}}")
if [ -n "$stopped_always" ]; then
    print_warning "Attention: Certains conteneurs avec restart=always sont arrêtés:"
    echo ""
    echo "$stopped_always"
    echo ""
    read -p "Voulez-vous les démarrer maintenant? (y/N) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$stopped_always" | while read container; do
            print_info "Démarrage de ${container}..."
            if docker start "$container"; then
                print_success "  ✓ ${container} démarré"
            else
                print_error "  ✗ Échec de ${container}"
            fi
        done
    fi
fi

# 7. Configuration recommandée du config.conf
print_header "CONFIGURATION RECOMMANDÉE"

running_containers_names=$(docker ps --format "{{.Names}}" | tr '\n' ' ')

echo "Ajoutez ces conteneurs dans /opt/patching/config.conf:"
echo ""
echo "CRITICAL_CONTAINERS=\"${running_containers_names}\""
echo ""

read -p "Voulez-vous ajouter automatiquement ces conteneurs dans config.conf? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    CONFIG_FILE="/opt/patching/config.conf"

    if [ -f "$CONFIG_FILE" ]; then
        # Sauvegarder l'ancien fichier
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup-$(date +%Y%m%d-%H%M%S)"

        # Supprimer l'ancienne ligne CRITICAL_CONTAINERS si elle existe
        sed -i '/^CRITICAL_CONTAINERS=/d' "$CONFIG_FILE"

        # Ajouter la nouvelle ligne
        echo "CRITICAL_CONTAINERS=\"${running_containers_names}\"" >> "$CONFIG_FILE"

        print_success "Configuration mise à jour dans ${CONFIG_FILE}"
        print_info "Une sauvegarde a été créée"
    else
        print_warning "Fichier config.conf non trouvé à ${CONFIG_FILE}"
    fi
fi

echo ""
print_header "PROCHAINES ÉTAPES"

echo "1. Remplacer check-services.sh par la version Docker:"
echo "   sudo cp check-services-docker.sh /opt/patching/check-services.sh"
echo ""
echo "2. Configurer le service de vérification au boot:"
echo "   sudo systemctl enable patching-check.service"
echo ""
echo "3. Tester:"
echo "   sudo /opt/patching/check-services.sh"
echo ""
echo "4. Tester après un reboot:"
echo "   sudo reboot"
echo ""

print_success "Configuration terminée!"

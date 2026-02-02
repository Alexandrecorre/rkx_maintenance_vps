# Makefile pour le script de patching VPS Ubuntu
# Usage: make <target>

.PHONY: help install test deploy clean lint docker-test validate

# Variables
INSTALL_DIR := /opt/patching
LOG_DIR := /var/log/patching
SERVER ?= root@localhost

# Couleurs pour l'affichage
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help:
	@echo "$(GREEN)Commandes disponibles:$(NC)"
	@echo ""
	@echo "  $(YELLOW)make install$(NC)        - Installer localement le système de patching"
	@echo "  $(YELLOW)make test$(NC)           - Tester le script en mode dry-run"
	@echo "  $(YELLOW)make deploy$(NC)         - Déployer sur un serveur distant (SERVER=user@host)"
	@echo "  $(YELLOW)make clean$(NC)          - Nettoyer les logs locaux"
	@echo "  $(YELLOW)make lint$(NC)           - Vérifier la syntaxe des scripts"
	@echo "  $(YELLOW)make docker-test$(NC)    - Construire et lancer un conteneur de test"
	@echo "  $(YELLOW)make validate$(NC)       - Valider tous les scripts"
	@echo "  $(YELLOW)make uninstall$(NC)      - Désinstaller le système de patching"
	@echo ""
	@echo "Exemples:"
	@echo "  make deploy SERVER=root@192.168.1.100"
	@echo "  make test"

install:
	@echo "$(GREEN)Installation du système de patching...$(NC)"
	@sudo bash install.sh --auto

test:
	@echo "$(GREEN)Test du script en mode dry-run...$(NC)"
	@sudo bash patch-vps.sh --dry-run

deploy:
	@echo "$(GREEN)Déploiement sur $(SERVER)...$(NC)"
	@bash deploy.sh $(SERVER)

clean:
	@echo "$(YELLOW)Nettoyage des logs...$(NC)"
	@sudo rm -rf $(LOG_DIR)/*.log
	@sudo rm -rf $(LOG_DIR)/*.txt
	@echo "$(GREEN)Logs nettoyés$(NC)"

lint:
	@echo "$(GREEN)Vérification de la syntaxe des scripts...$(NC)"
	@bash -n patch-vps.sh && echo "  ✓ patch-vps.sh" || echo "  $(RED)✗ patch-vps.sh$(NC)"
	@bash -n check-services.sh && echo "  ✓ check-services.sh" || echo "  $(RED)✗ check-services.sh$(NC)"
	@bash -n test-notification.sh && echo "  ✓ test-notification.sh" || echo "  $(RED)✗ test-notification.sh$(NC)"
	@bash -n install.sh && echo "  ✓ install.sh" || echo "  $(RED)✗ install.sh$(NC)"
	@bash -n deploy.sh && echo "  ✓ deploy.sh" || echo "  $(RED)✗ deploy.sh$(NC)"
	@echo "$(GREEN)Vérification terminée$(NC)"

validate: lint
	@echo "$(GREEN)Validation complète...$(NC)"
	@if [ -f patch-vps.sh ]; then echo "  ✓ patch-vps.sh existe"; else echo "  $(RED)✗ patch-vps.sh manquant$(NC)"; exit 1; fi
	@if [ -f config.conf ]; then echo "  ✓ config.conf existe"; else echo "  $(RED)✗ config.conf manquant$(NC)"; exit 1; fi
	@if [ -f install.sh ]; then echo "  ✓ install.sh existe"; else echo "  $(RED)✗ install.sh manquant$(NC)"; exit 1; fi
	@if [ -f README.md ]; then echo "  ✓ README.md existe"; else echo "  $(RED)✗ README.md manquant$(NC)"; exit 1; fi
	@echo "$(GREEN)Validation réussie$(NC)"

docker-test:
	@echo "$(GREEN)Construction de l'image Docker de test...$(NC)"
	@docker build -f Dockerfile.test -t patching-test .
	@echo "$(GREEN)Lancement du conteneur...$(NC)"
	@docker run -it --rm patching-test

uninstall:
	@echo "$(RED)Désinstallation du système de patching...$(NC)"
	@sudo bash install.sh --uninstall

check-deps:
	@echo "$(GREEN)Vérification des dépendances...$(NC)"
	@command -v bash >/dev/null 2>&1 && echo "  ✓ bash" || echo "  $(RED)✗ bash manquant$(NC)"
	@command -v curl >/dev/null 2>&1 && echo "  ✓ curl" || echo "  $(YELLOW)✗ curl manquant (optionnel)$(NC)"
	@command -v docker >/dev/null 2>&1 && echo "  ✓ docker" || echo "  $(YELLOW)✗ docker manquant (optionnel)$(NC)"

logs:
	@echo "$(GREEN)Affichage des logs récents...$(NC)"
	@sudo tail -50 $(LOG_DIR)/*.log 2>/dev/null || echo "$(YELLOW)Aucun log trouvé$(NC)"

status:
	@echo "$(GREEN)Statut du système de patching:$(NC)"
	@echo ""
	@echo "Cron:"
	@sudo crontab -l 2>/dev/null | grep patch-vps || echo "  Pas de cron configuré"
	@echo ""
	@echo "Systemd Timer:"
	@sudo systemctl is-active patching.timer 2>/dev/null && echo "  Actif" || echo "  Inactif"
	@echo ""
	@echo "Fichiers:"
	@[ -f $(INSTALL_DIR)/patch-vps.sh ] && echo "  ✓ Script principal installé" || echo "  ✗ Script principal non installé"
	@[ -f $(INSTALL_DIR)/config.conf ] && echo "  ✓ Configuration installée" || echo "  ✗ Configuration non installée"
	@echo ""
	@echo "Logs:"
	@[ -d $(LOG_DIR) ] && echo "  ✓ Répertoire de logs présent" || echo "  ✗ Répertoire de logs absent"
	@sudo ls -lh $(LOG_DIR)/*.log 2>/dev/null | wc -l | xargs echo "  Fichiers de logs:"

.DEFAULT_GOAL := help

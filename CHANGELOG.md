# Changelog

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-26

### Ajouté
- Script principal de patching automatique (`patch-vps.sh`)
  - Mise à jour automatique des paquets système
  - Gestion intelligente des redémarrages avec délai configurable
  - Mécanisme de retry en cas d'échec
  - Mode dry-run pour les tests
  - Journalisation complète avec rotation automatique
  - Génération de rapports détaillés
  - Notifications via API/webhook
  - Vérification de l'espace disque
  - Gestion des dépendances cassées
  - Nettoyage automatique des paquets obsolètes

- Script de vérification des services (`check-services.sh`)
  - Vérification post-redémarrage des services critiques
  - Tentative automatique de redémarrage des services en échec
  - Notifications en cas de problème

- Script de test des notifications (`test-notification.sh`)
  - Test de connectivité vers l'endpoint API
  - Envoi de notifications de test

- Script d'installation interactif (`install.sh`)
  - Menu d'installation avec plusieurs options
  - Vérification des prérequis
  - Installation automatique des dépendances
  - Configuration du cron ou systemd timer
  - Test post-installation
  - Configuration interactive
  - Fonction de désinstallation

- Script de déploiement distant (`deploy.sh`)
  - Déploiement automatisé via SSH
  - Support cron et systemd timer
  - Mode dry-run
  - Vérification de la connexion SSH

- Fichier de configuration (`config.conf`)
  - Paramètres centralisés
  - Configuration de la planification
  - Gestion des notifications
  - Configuration des services critiques

- Support Systemd Timer (alternative à cron)
  - `patching.service`: Service systemd
  - `patching.timer`: Timer systemd
  - `patching-check.service`: Vérification post-redémarrage
  - Documentation complète dans `SYSTEMD_TIMER.md`

- Documentation complète
  - `README.md`: Documentation principale
  - `CHEATSHEET.md`: Guide de référence rapide
  - `SYSTEMD_TIMER.md`: Guide systemd timer
  - `PROJECT_STRUCTURE.md`: Architecture du projet
  - `CHANGELOG.md`: Historique des versions

### Sécurité
- Permissions strictes sur les scripts (700)
- Protection du fichier de configuration (600)
- Vérification des signatures GPG des paquets
- Exécution uniquement en tant que root
- Audit complet dans les logs

### Technique
- Compatibilité Ubuntu 18.04 LTS et supérieur
- Support des deux méthodes de planification (cron et systemd)
- Gestion robuste des erreurs avec retry
- Journalisation structurée avec niveaux (INFO, WARN, ERROR, SUCCESS)
- Code bash avec `set -euo pipefail` pour plus de robustesse
- Validation de l'environnement avant exécution

## [Unreleased]

### Planifié pour les versions futures
- Intégration avec Prometheus pour métriques
- Support de notifications Slack/Discord
- Système de hooks pre/post patching
- Interface web de monitoring
- Support multi-serveurs avec orchestration centrale
- Intégration avec Ansible/Puppet
- Snapshots automatiques avant patching
- Support de rollback automatique en cas d'échec
- Détection des CVE critiques avec priorité
- Support de blacklist/whitelist de paquets
- Fenêtres de maintenance configurables
- Support de proxy APT

---

## Types de changements

- `Ajouté` pour les nouvelles fonctionnalités
- `Modifié` pour les changements dans les fonctionnalités existantes
- `Déprécié` pour les fonctionnalités qui seront retirées
- `Retiré` pour les fonctionnalités retirées
- `Corrigé` pour les corrections de bugs
- `Sécurité` pour les vulnérabilités corrigées

## Format des versions

Le versioning suit le format MAJOR.MINOR.PATCH:
- MAJOR: Changements incompatibles de l'API
- MINOR: Ajout de fonctionnalités rétrocompatibles
- PATCH: Corrections de bugs rétrocompatibles

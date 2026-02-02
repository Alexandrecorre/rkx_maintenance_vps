# Cheatsheet - Script de Patching VPS Ubuntu

Guide de référence rapide pour les commandes courantes.

## Installation

```bash
# Installation complète automatique
sudo bash install.sh --auto

# Installation interactive avec menu
sudo bash install.sh

# Désinstallation
sudo bash install.sh --uninstall
```

## Exécution du script

```bash
# Exécution normale (production)
sudo /opt/patching/patch-vps.sh

# Mode test (dry-run) - aucune modification
sudo /opt/patching/patch-vps.sh --dry-run

# Aide et version
/opt/patching/patch-vps.sh --help
/opt/patching/patch-vps.sh --version
```

## Gestion du Cron

```bash
# Voir les cron jobs actifs
sudo crontab -l

# Éditer le crontab
sudo crontab -e

# Supprimer tous les cron jobs
sudo crontab -r

# Vérifier le service cron
sudo systemctl status cron
sudo systemctl restart cron

# Voir les dernières exécutions du cron
sudo grep CRON /var/log/syslog | tail -20
```

## Consultation des Logs

```bash
# Logs du jour
sudo tail -f /var/log/patching/patching-$(date +%Y-%m-%d).log

# Rapport du jour
sudo cat /var/log/patching/report-$(date +%Y-%m-%d).txt

# Logs d'une date spécifique
sudo cat /var/log/patching/patching-2026-01-26.log

# Tous les logs
sudo ls -lh /var/log/patching/

# Dernières lignes de tous les logs
sudo tail -n 50 /var/log/patching/patching-*.log

# Rechercher des erreurs dans les logs
sudo grep "ERROR" /var/log/patching/patching-*.log

# Logs du cron
sudo tail -f /var/log/patching/cron.log

# Logs système liés au patching
sudo journalctl -u cron | grep patching
```

## Configuration

```bash
# Éditer la configuration
sudo nano /opt/patching/config.conf

# Voir la configuration actuelle
sudo cat /opt/patching/config.conf

# Sauvegarder la configuration
sudo cp /opt/patching/config.conf /opt/patching/config.conf.backup

# Restaurer la configuration
sudo cp /opt/patching/config.conf.backup /opt/patching/config.conf
```

## Gestion du Redémarrage

```bash
# Annuler un redémarrage programmé
sudo shutdown -c

# Programmer un redémarrage manuel
sudo shutdown -r +10 "Redémarrage dans 10 minutes"

# Redémarrer immédiatement
sudo reboot

# Voir si un redémarrage est requis
[ -f /var/run/reboot-required ] && echo "Redémarrage requis" || echo "Pas de redémarrage requis"

# Voir quels paquets nécessitent un redémarrage
cat /var/run/reboot-required.pkgs
```

## Tests et Diagnostic

```bash
# Tester les notifications
sudo bash test-notification.sh

# Ou avec un endpoint spécifique
sudo bash test-notification.sh https://votre-api.com/webhook

# Vérifier les services critiques
sudo bash /opt/patching/check-services.sh

# Vérifier l'espace disque
df -h

# Vérifier la mémoire
free -h

# Vérifier les paquets à mettre à jour
apt list --upgradable

# Simuler une mise à jour
sudo apt-get update && sudo apt-get upgrade -s

# Vérifier l'état du système de paquets
sudo dpkg --audit
sudo apt-get check
```

## Maintenance

```bash
# Nettoyer les logs de plus de 30 jours
sudo find /var/log/patching -name "*.log" -mtime +30 -delete

# Nettoyer tous les logs (ATTENTION)
sudo rm -rf /var/log/patching/*.log

# Vérifier la taille des logs
sudo du -sh /var/log/patching/

# Nettoyer le cache apt
sudo apt-get clean
sudo apt-get autoclean

# Supprimer les paquets obsolètes
sudo apt-get autoremove

# Corriger les dépendances cassées
sudo apt-get install -f
```

## Timezone et Planification

```bash
# Voir la timezone actuelle
timedatectl

# Lister les timezones disponibles
timedatectl list-timezones

# Changer la timezone (exemple: Paris)
sudo timedatectl set-timezone Europe/Paris

# Changer la timezone (exemple: UTC)
sudo timedatectl set-timezone UTC

# Voir l'heure système
date

# Synchroniser l'heure
sudo timedatectl set-ntp true
```

## Désactivation Temporaire

```bash
# Désactiver le patching automatique
sudo crontab -e
# Commenter la ligne avec # devant

# Réactiver le patching
sudo crontab -e
# Décommenter la ligne (supprimer le #)

# Désactiver uniquement le redémarrage
sudo nano /opt/patching/config.conf
# Mettre ENABLE_REBOOT=false
```

## Sécurité et Permissions

```bash
# Vérifier les permissions du script
ls -l /opt/patching/patch-vps.sh
# Devrait être: -rwx------ (700) root:root

# Corriger les permissions si nécessaire
sudo chmod 700 /opt/patching/patch-vps.sh
sudo chmod 600 /opt/patching/config.conf
sudo chown root:root /opt/patching/*

# Auditer les modifications système
sudo cat /var/log/apt/history.log
```

## Rollback et Récupération

```bash
# Voir l'historique des mises à jour apt
sudo cat /var/log/apt/history.log

# Voir la liste des paquets avant le dernier patching
sudo cat /var/log/patching/packages-before-*.txt | tail -1

# Downgrade d'un paquet (exemple: nginx)
sudo apt-cache showpkg nginx
sudo apt-get install nginx=<version>

# Réparer le système de paquets
sudo dpkg --configure -a
sudo apt-get install -f

# Forcer la reconfiguration de tous les paquets
sudo dpkg-reconfigure -a
```

## Monitoring et Alertes

```bash
# Voir les dernières exécutions
sudo grep "DÉBUT DU PATCHING" /var/log/patching/*.log

# Compter les erreurs dans les logs
sudo grep -c "ERROR" /var/log/patching/patching-*.log

# Statistiques des paquets mis à jour
sudo grep "Paquets mis à jour" /var/log/patching/report-*.txt

# Voir tous les redémarrages programmés
sudo grep "Redémarrage programmé" /var/log/patching/*.log
```

## Exemples de Cron Personnalisés

```bash
# Tous les jours à 03h00
0 3 * * * /opt/patching/patch-vps.sh

# Tous les lundis à 01h00
0 1 * * 1 /opt/patching/patch-vps.sh

# Tous les premiers du mois à 02h00
0 2 1 * * /opt/patching/patch-vps.sh

# Tous les dimanches à 04h30
30 4 * * 0 /opt/patching/patch-vps.sh

# Deux fois par semaine (lundi et jeudi à 02h00)
0 2 * * 1,4 /opt/patching/patch-vps.sh
```

## Dépannage Rapide

```bash
# Le script ne s'exécute pas
sudo bash -x /opt/patching/patch-vps.sh --dry-run  # Mode debug

# Permission denied
sudo chmod +x /opt/patching/patch-vps.sh

# Vérifier la syntaxe bash
bash -n /opt/patching/patch-vps.sh

# Le cron ne fonctionne pas
sudo systemctl status cron
sudo systemctl enable cron
sudo systemctl start cron

# Les notifications ne fonctionnent pas
sudo bash test-notification.sh
curl -I https://votre-api.com/webhook  # Tester la connectivité
```

## Variables d'Environnement

```bash
# Exécuter avec des variables personnalisées
sudo DRY_RUN=true /opt/patching/patch-vps.sh
sudo LOG_RETENTION_DAYS=30 /opt/patching/patch-vps.sh
sudo ENABLE_REBOOT=false /opt/patching/patch-vps.sh
```

## Informations Système

```bash
# Version d'Ubuntu
lsb_release -a

# Version du kernel
uname -r

# Uptime
uptime

# Derniers redémarrages
last reboot

# Processus système
top
htop

# Services actifs
systemctl list-units --type=service --state=running
```

---

**Astuce**: Ajoutez ce fichier à vos favoris pour un accès rapide aux commandes!

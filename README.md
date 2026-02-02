# Script de Patching Automatique VPS Ubuntu

## Description

Script automatisé de mise à jour système (patching) pour VPS Ubuntu, exécuté hebdomadairement tous les mercredis matins à 02h00 UTC.

## Fonctionnalités

- ✅ Mise à jour automatique des paquets système
- ✅ Gestion intelligente des redémarrages
- ✅ Journalisation complète avec rotation des logs
- ✅ Notifications via API/webhook
- ✅ Gestion des erreurs avec mécanisme de retry
- ✅ Sauvegarde pré-patching de l'état du système
- ✅ Rapports détaillés d'exécution
- ✅ Mode dry-run pour tester sans modification
- ✅ Configuration flexible via fichier de config

## Prérequis

### Système
- Ubuntu 18.04 LTS ou supérieur
- Accès root ou utilisateur avec privilèges sudo
- Connexion Internet stable

### Packages requis
```bash
# Installation des dépendances
sudo apt-get update
sudo apt-get install -y curl cron
```

## Installation

### 1. Création des répertoires

```bash
# Créer les répertoires nécessaires
sudo mkdir -p /opt/patching
sudo mkdir -p /var/log/patching

# Définir les permissions
sudo chmod 755 /opt/patching
sudo chmod 755 /var/log/patching
```

### 2. Copie des fichiers

```bash
# Copier le script principal
sudo cp patch-vps.sh /opt/patching/
sudo chmod 700 /opt/patching/patch-vps.sh
sudo chown root:root /opt/patching/patch-vps.sh

# Copier le fichier de configuration
sudo cp config.conf /opt/patching/
sudo chmod 600 /opt/patching/config.conf
sudo chown root:root /opt/patching/config.conf
```

### 3. Configuration

Éditer le fichier de configuration selon vos besoins:

```bash
sudo nano /opt/patching/config.conf
```

**Paramètres importants à configurer:**

- `API_ENDPOINT`: URL de votre webhook pour les notifications
- `ENABLE_REBOOT`: Activer/désactiver le redémarrage automatique
- `REBOOT_DELAY`: Délai avant redémarrage (en minutes)
- `CRITICAL_SERVICES`: Services à vérifier après redémarrage

### 4. Test du script

Avant de configurer le cron, testez le script en mode dry-run:

```bash
sudo /opt/patching/patch-vps.sh --dry-run
```

Vérifiez les logs générés:

```bash
sudo tail -f /var/log/patching/patching-$(date +%Y-%m-%d).log
```

### 5. Configuration du Cron

#### Option A: Ajout manuel

```bash
# Éditer le crontab de root
sudo crontab -e

# Ajouter cette ligne (exécution tous les mercredis à 02h00 UTC)
0 2 * * 3 /opt/patching/patch-vps.sh >> /var/log/patching/cron.log 2>&1
```

#### Option B: Script d'installation automatique

Créez un script d'installation:

```bash
#!/bin/bash
# install-cron.sh

CRON_JOB="0 2 * * 3 /opt/patching/patch-vps.sh >> /var/log/patching/cron.log 2>&1"

# Vérifier si le cron existe déjà
if crontab -l 2>/dev/null | grep -q "patch-vps.sh"; then
    echo "Le cron job existe déjà"
    exit 0
fi

# Ajouter le cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "Cron job installé avec succès"
crontab -l | grep patch-vps.sh
```

Exécutez-le:

```bash
sudo bash install-cron.sh
```

### 6. Vérification de la timezone

Le script s'exécute à 02h00 UTC. Vérifiez la timezone de votre serveur:

```bash
timedatectl
```

Si nécessaire, ajustez l'heure dans le cron en fonction de votre timezone locale.

## Utilisation

### Exécution manuelle

```bash
# Exécution normale
sudo /opt/patching/patch-vps.sh

# Mode dry-run (simulation sans modification)
sudo /opt/patching/patch-vps.sh --dry-run

# Afficher l'aide
/opt/patching/patch-vps.sh --help

# Afficher la version
/opt/patching/patch-vps.sh --version
```

### Consultation des logs

```bash
# Logs du jour
sudo tail -f /var/log/patching/patching-$(date +%Y-%m-%d).log

# Rapport du jour
sudo cat /var/log/patching/report-$(date +%Y-%m-%d).txt

# Tous les logs de patching
sudo ls -lh /var/log/patching/

# Logs du cron
sudo tail -f /var/log/patching/cron.log
```

### Vérification du cron

```bash
# Voir les cron jobs actifs
sudo crontab -l

# Vérifier le statut du service cron
sudo systemctl status cron

# Voir les logs système du cron
sudo grep CRON /var/log/syslog | tail -20
```

## Rapports et Notifications

### Format du rapport

Chaque exécution génère un rapport détaillé contenant:

- Date et heure d'exécution
- Nombre de paquets mis à jour
- Erreurs rencontrées
- Status global (SUCCÈS / AVERTISSEMENT / ERREUR)
- Redémarrage programmé (oui/non)
- Informations système (espace disque, mémoire, charge)

### Notifications API

Si configuré, le script envoie une notification JSON à l'endpoint API:

```json
{
    "subject": "[SUCCÈS] Patching VPS hostname - 2026-01-26",
    "body": "... contenu du rapport ...",
    "timestamp": "2026-01-26T02:15:30Z",
    "hostname": "vps-hostname",
    "status": "SUCCÈS"
}
```

## Gestion des erreurs

### Codes de retour

- `0`: Succès complet
- `10`: Avertissement (succès avec réserves)
- `1`: Erreur critique

### Mécanisme de retry

En cas d'échec d'une commande, le script:
1. Attend 30 secondes
2. Relance l'opération une fois
3. Si échec persistant, enregistre l'erreur et notifie

### Gestion de l'espace disque

Le script vérifie l'espace disque disponible avant de commencer:
- Minimum requis: 2 GB libre sur `/`
- Si insuffisant: arrêt du patching et notification

## Maintenance

### Désactiver temporairement le patching

```bash
# Désactiver le cron
sudo crontab -e
# Commenter la ligne avec #

# Ou supprimer le cron
sudo crontab -r
```

### Réactiver le patching

```bash
# Réinstaller le cron
sudo crontab -e
# Décommenter ou ajouter la ligne
```

### Nettoyage manuel des logs

```bash
# Supprimer les logs de plus de 90 jours (effectué automatiquement)
sudo find /var/log/patching -name "*.log" -type f -mtime +90 -delete

# Supprimer tous les logs (ATTENTION: perte de l'historique)
sudo rm -rf /var/log/patching/*
```

### Modifier la fréquence d'exécution

Éditer le crontab et modifier la ligne:

```bash
# Tous les jours à 03h00
0 3 * * * /opt/patching/patch-vps.sh

# Tous les lundis à 01h00
0 1 * * 1 /opt/patching/patch-vps.sh

# Tous les premiers du mois à 02h00
0 2 1 * * /opt/patching/patch-vps.sh
```

## Rollback et récupération

### En cas de problème après patching

1. **Consulter les logs pour identifier le problème:**
   ```bash
   sudo cat /var/log/patching/patching-<date>.log
   ```

2. **Annuler un redémarrage programmé:**
   ```bash
   sudo shutdown -c
   ```

3. **Restaurer un paquet spécifique:**
   ```bash
   # Voir l'historique apt
   sudo cat /var/log/apt/history.log

   # Downgrade d'un paquet (si disponible)
   sudo apt-cache showpkg <package-name>
   sudo apt-get install <package-name>=<version>
   ```

4. **Réparer le système de paquets:**
   ```bash
   sudo apt-get update
   sudo apt-get install -f
   sudo dpkg --configure -a
   ```

### Sauvegarde pré-patching

Le script sauvegarde automatiquement la liste des paquets avant chaque patching:

```bash
# Consulter la sauvegarde
sudo cat /var/log/patching/packages-before-<date>.txt
```

## Sécurité

### Permissions recommandées

```bash
# Script principal
-rwx------ (700) root:root /opt/patching/patch-vps.sh

# Configuration
-rw------- (600) root:root /opt/patching/config.conf

# Répertoire logs
drwxr-xr-x (755) root:root /var/log/patching/
```

### Bonnes pratiques

- ✅ Exécuter uniquement en tant que root
- ✅ Protéger le fichier de configuration (contient les secrets API)
- ✅ Surveiller régulièrement les logs
- ✅ Tester en dry-run avant toute modification
- ✅ Maintenir une sauvegarde du serveur

## Dépannage

### Le cron ne s'exécute pas

```bash
# Vérifier le service cron
sudo systemctl status cron
sudo systemctl restart cron

# Vérifier la syntaxe du crontab
crontab -l

# Vérifier les permissions
ls -l /opt/patching/patch-vps.sh
```

### Erreur "Permission denied"

```bash
# Corriger les permissions
sudo chmod 700 /opt/patching/patch-vps.sh
sudo chown root:root /opt/patching/patch-vps.sh
```

### Les notifications ne sont pas envoyées

1. Vérifier la configuration de `API_ENDPOINT` dans `config.conf`
2. Tester manuellement avec curl:
   ```bash
   curl -X POST -H "Content-Type: application/json" \
        -d '{"test":"message"}' \
        https://votre-api.com/webhook
   ```
3. Vérifier les logs pour les erreurs de connexion

### Espace disque insuffisant

```bash
# Vérifier l'espace disque
df -h

# Nettoyer les anciens logs
sudo find /var/log/patching -name "*.log" -mtime +30 -delete

# Nettoyer le cache apt
sudo apt-get clean
sudo apt-get autoclean
```

## Support et contribution

- **Issues**: Signaler les bugs et demandes de fonctionnalités
- **Documentation**: Ce README est mis à jour régulièrement
- **Logs**: Toujours consulter les logs en cas de problème

## Changelog

### Version 1.0.0 (2026-01-26)
- Version initiale
- Mise à jour automatique des paquets
- Gestion des redémarrages
- Notifications via API
- Mode dry-run
- Journalisation complète

## Licence

Ce script est fourni tel quel, sans garantie.

---

**Auteur**: Généré automatiquement
**Date**: 2026-01-26
**Version**: 1.0.0
#   r k x _ m a i n t e n a n c e _ v p s  
 
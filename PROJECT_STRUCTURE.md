# Structure du Projet - Script de Patching VPS Ubuntu

Ce document décrit l'architecture et l'organisation des fichiers du système de patching automatique.

## 📁 Structure des fichiers

```
rkx_maintenance/
│
├── 📄 spec.txt                    # Spécifications d'origine du projet
├── 📄 README.md                   # Documentation principale
├── 📄 PROJECT_STRUCTURE.md        # Ce fichier (architecture du projet)
├── 📄 CHEATSHEET.md              # Guide de référence rapide
├── 📄 SYSTEMD_TIMER.md           # Guide d'utilisation de systemd timer
│
├── 🔧 Scripts principaux
│   ├── patch-vps.sh              # Script principal de patching
│   ├── check-services.sh         # Vérification des services après redémarrage
│   ├── test-notification.sh      # Test des notifications API
│   ├── install.sh                # Script d'installation interactif
│   └── deploy.sh                 # Script de déploiement distant via SSH
│
├── ⚙️ Configuration
│   └── config.conf               # Fichier de configuration principal
│
├── 🔄 Systemd (alternative à cron)
│   ├── patching.service          # Service systemd pour le patching
│   ├── patching.timer            # Timer systemd (planification)
│   └── patching-check.service    # Service de vérification post-redémarrage
│
└── 📝 Divers
    └── .gitignore                # Fichiers à ignorer par Git

```

## 📋 Description détaillée des fichiers

### Scripts principaux (🔧)

#### `patch-vps.sh`
**Rôle**: Script principal qui effectue toutes les opérations de patching
**Emplacement de déploiement**: `/opt/patching/patch-vps.sh`
**Permissions**: `700 (rwx------) root:root`

**Fonctionnalités**:
- ✅ Validation de l'environnement (root, espace disque, timezone)
- ✅ Mise à jour des paquets apt (update, upgrade, dist-upgrade)
- ✅ Gestion des dépendances cassées
- ✅ Nettoyage des paquets obsolètes
- ✅ Vérification du besoin de redémarrage
- ✅ Gestion du redémarrage automatique avec délai configurable
- ✅ Journalisation complète avec rotation
- ✅ Génération de rapports détaillés
- ✅ Notifications via API/webhook
- ✅ Mécanisme de retry en cas d'échec
- ✅ Mode dry-run pour tests

**Usage**:
```bash
sudo /opt/patching/patch-vps.sh           # Exécution normale
sudo /opt/patching/patch-vps.sh --dry-run # Test sans modification
/opt/patching/patch-vps.sh --help         # Aide
```

---

#### `check-services.sh`
**Rôle**: Vérifie que les services critiques ont bien redémarré après un reboot
**Emplacement de déploiement**: `/opt/patching/check-services.sh`
**Permissions**: `700 (rwx------) root:root`

**Fonctionnalités**:
- ✅ Vérification de l'état des services définis dans config.conf
- ✅ Tentative de redémarrage automatique des services en échec
- ✅ Logging détaillé
- ✅ Notifications en cas d'échec

**Usage**:
```bash
sudo /opt/patching/check-services.sh
```

**Intégration**: Peut être appelé automatiquement via systemd (patching-check.service) après chaque redémarrage.

---

#### `test-notification.sh`
**Rôle**: Teste l'envoi de notifications via l'endpoint API
**Emplacement de déploiement**: `/opt/patching/test-notification.sh`
**Permissions**: `700 (rwx------) root:root`

**Fonctionnalités**:
- ✅ Envoi d'une notification de test
- ✅ Vérification de la connectivité à l'endpoint
- ✅ Affichage du code HTTP et de la réponse

**Usage**:
```bash
sudo bash test-notification.sh                        # Utilise API_ENDPOINT du config
sudo bash test-notification.sh https://api.com/hook   # Avec endpoint spécifique
```

---

#### `install.sh`
**Rôle**: Script d'installation interactive du système de patching
**Emplacement**: Utilisé localement, non déployé

**Fonctionnalités**:
- ✅ Menu interactif avec plusieurs options d'installation
- ✅ Vérification de l'OS et des prérequis
- ✅ Installation des dépendances (curl, cron)
- ✅ Création des répertoires nécessaires
- ✅ Installation des fichiers avec bonnes permissions
- ✅ Configuration du cron ou systemd timer
- ✅ Test du script après installation
- ✅ Configuration interactive des paramètres
- ✅ Fonction de désinstallation

**Usage**:
```bash
sudo bash install.sh                # Menu interactif
sudo bash install.sh --auto         # Installation automatique
sudo bash install.sh --uninstall    # Désinstallation
```

---

#### `deploy.sh`
**Rôle**: Déploie le système de patching sur un serveur distant via SSH
**Emplacement**: Utilisé localement pour le déploiement

**Fonctionnalités**:
- ✅ Déploiement automatisé via SSH
- ✅ Vérification de la connexion SSH
- ✅ Copie de tous les fichiers nécessaires
- ✅ Installation automatique sur le serveur distant
- ✅ Support de cron ou systemd timer
- ✅ Mode dry-run pour tester sans modification

**Usage**:
```bash
./deploy.sh root@192.168.1.100              # Déploiement avec cron
./deploy.sh ubuntu@vps.com --systemd        # Déploiement avec systemd
./deploy.sh admin@server.com --dry-run      # Test de déploiement
```

---

### Configuration (⚙️)

#### `config.conf`
**Rôle**: Fichier de configuration centralisé
**Emplacement de déploiement**: `/opt/patching/config.conf`
**Permissions**: `600 (rw-------) root:root`

**Paramètres configurables**:
```bash
PATCH_HOUR=2                    # Heure d'exécution (format 24h)
PATCH_DAY=3                     # Jour de la semaine (3=mercredi)
LOG_RETENTION_DAYS=90           # Durée de conservation des logs
ENABLE_REBOOT=true              # Activation du redémarrage automatique
REBOOT_DELAY=10                 # Délai avant redémarrage (minutes)
API_ENDPOINT=""                 # URL du webhook pour notifications
CRITICAL_SERVICES="nginx mysql" # Services à surveiller
VERIFY_GPG_SIGNATURES=true      # Vérification des signatures GPG
DEBUG_MODE=false                # Mode debug
```

**Sécurité**: Ce fichier peut contenir des secrets (API keys), il doit être protégé.

---

### Systemd (🔄)

#### `patching.service`
**Rôle**: Définit le service systemd pour le patching
**Emplacement de déploiement**: `/etc/systemd/system/patching.service`

**Contenu clé**:
```ini
[Service]
Type=oneshot
ExecStart=/opt/patching/patch-vps.sh
User=root
```

---

#### `patching.timer`
**Rôle**: Définit la planification avec systemd timer
**Emplacement de déploiement**: `/etc/systemd/system/patching.timer`

**Contenu clé**:
```ini
[Timer]
OnCalendar=Wed *-*-* 02:00:00  # Tous les mercredis à 02h00
Persistent=true                 # Exécuter si manqué
RandomizedDelaySec=300         # Délai aléatoire de 5 min
```

---

#### `patching-check.service`
**Rôle**: Service systemd pour vérifier les services après redémarrage
**Emplacement de déploiement**: `/etc/systemd/system/patching-check.service`

**Contenu clé**:
```ini
[Service]
Type=oneshot
ExecStart=/opt/patching/check-services.sh
```

**Activation**: Ce service s'exécute automatiquement après chaque démarrage.

---

### Documentation (📄)

#### `README.md`
**Rôle**: Documentation principale et complète
**Contenu**:
- Description et fonctionnalités
- Prérequis et installation
- Configuration détaillée
- Utilisation et commandes
- Gestion des erreurs et rollback
- Dépannage
- Sécurité et bonnes pratiques

---

#### `CHEATSHEET.md`
**Rôle**: Guide de référence rapide
**Contenu**:
- Commandes d'installation
- Gestion du cron/systemd
- Consultation des logs
- Tests et diagnostics
- Maintenance courante
- Dépannage rapide

---

#### `SYSTEMD_TIMER.md`
**Rôle**: Guide complet pour utiliser systemd timer au lieu de cron
**Contenu**:
- Avantages de systemd vs cron
- Installation du timer
- Configuration et personnalisation
- Migration depuis cron
- Monitoring et dépannage

---

#### `PROJECT_STRUCTURE.md` (ce fichier)
**Rôle**: Documentation de l'architecture du projet
**Contenu**: Description de tous les fichiers et de leur organisation

---

## 📊 Arborescence de déploiement sur le serveur

Une fois déployé sur le serveur Ubuntu, voici l'arborescence:

```
/opt/patching/                          # Répertoire principal
├── patch-vps.sh                        # Script principal (700)
├── check-services.sh                   # Vérification services (700)
├── config.conf                         # Configuration (600)
├── README.md                           # Documentation
└── CHEATSHEET.md                       # Référence rapide

/var/log/patching/                      # Logs
├── patching-2026-01-26.log            # Logs du jour
├── report-2026-01-26.txt              # Rapport du jour
├── packages-before-2026-01-26.txt     # Backup des paquets
└── cron.log                           # Logs du cron (si utilisé)

/etc/systemd/system/                    # Services systemd (si utilisé)
├── patching.service
├── patching.timer
└── patching-check.service

/etc/cron.d/                            # Cron (alternative)
ou crontab -l                           # Crontab root
```

## 🔄 Flux d'exécution

### 1. Déclenchement (Cron ou Systemd Timer)
```
Mercredi 02h00 UTC
    ↓
Exécution de patch-vps.sh
```

### 2. Validation
```
Vérification root
    ↓
Vérification espace disque
    ↓
Création des répertoires
    ↓
Chargement de la configuration
```

### 3. Patching
```
Sauvegarde liste paquets
    ↓
apt-get update
    ↓
apt-get upgrade -y
    ↓
apt-get dist-upgrade -y
    ↓
apt-get autoremove -y
    ↓
apt-get autoclean -y
    ↓
apt-get install -f
```

### 4. Post-patching
```
Vérification dépendances
    ↓
Vérification redémarrage requis
    ↓
Si requis: shutdown -r +10
```

### 5. Rapport et notification
```
Génération du rapport
    ↓
Envoi notification API
    ↓
Nettoyage logs anciens
```

### 6. Après redémarrage (optionnel)
```
Boot système
    ↓
Exécution check-services.sh (via systemd)
    ↓
Vérification services critiques
    ↓
Notification si échec
```

## 🎯 Cas d'usage

### Cas d'usage 1: Installation initiale
```bash
# Sur votre machine locale
git clone [repo]
cd rkx_maintenance

# Sur le serveur cible (via SSH)
scp -r * root@vps.example.com:/tmp/patching/
ssh root@vps.example.com
cd /tmp/patching
bash install.sh
```

### Cas d'usage 2: Déploiement distant
```bash
# Depuis votre machine locale
./deploy.sh root@vps.example.com --systemd
```

### Cas d'usage 3: Test avant déploiement
```bash
# Sur le serveur
sudo /opt/patching/patch-vps.sh --dry-run
sudo bash test-notification.sh
```

## 🔒 Sécurité

### Permissions critiques
```bash
/opt/patching/patch-vps.sh        → 700 (rwx------) root:root
/opt/patching/check-services.sh   → 700 (rwx------) root:root
/opt/patching/config.conf         → 600 (rw-------) root:root
/opt/patching/                    → 755 (rwxr-xr-x) root:root
/var/log/patching/                → 755 (rwxr-xr-x) root:root
```

### Données sensibles
- `config.conf`: Contient l'API endpoint (peut inclure des tokens)
- Logs: Peuvent contenir des informations système sensibles
- À exclure des backups publics ou repos Git

## 📈 Maintenance et évolution

### Fichiers à personnaliser selon vos besoins
1. `config.conf`: Adaptez les paramètres à votre infrastructure
2. `check-services.sh`: Ajoutez vos services critiques
3. `patching.timer`: Modifiez l'horaire de planification

### Fichiers à ne pas modifier
1. `patch-vps.sh`: Logic principal (sauf bugs)
2. `install.sh`: Script d'installation (sauf bugs)

### Extensions possibles
- Ajouter des hooks pre/post patching
- Intégrer avec des outils de monitoring (Prometheus, Datadog)
- Ajouter des sauvegardes automatiques avant patching
- Intégrer avec un système de gestion de configuration (Ansible, Puppet)

## 📞 Support

Pour toute question ou problème:
1. Consultez README.md
2. Consultez CHEATSHEET.md pour les commandes courantes
3. Vérifiez les logs: `/var/log/patching/`
4. Testez en mode dry-run

---

**Version**: 1.0.0
**Date**: 2026-01-26

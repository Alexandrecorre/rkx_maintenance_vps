# Quick Start - Script de Patching VPS Ubuntu

Guide de démarrage rapide pour installer et utiliser le script de patching automatique en 5 minutes.

## 🚀 Installation rapide (3 minutes)

### Option 1: Installation locale (sur le serveur directement)

```bash
# 1. Se connecter au serveur
ssh root@votre-serveur.com

# 2. Télécharger les fichiers
cd /tmp
# [Copier les fichiers du projet ici]

# 3. Lancer l'installation
sudo bash install.sh --auto

# 4. Configurer l'endpoint API (optionnel)
sudo nano /opt/patching/config.conf
# Modifier: API_ENDPOINT="https://votre-api.com/webhook"

# 5. Tester
sudo /opt/patching/patch-vps.sh --dry-run
```

### Option 2: Déploiement distant (depuis votre machine)

```bash
# 1. Depuis votre machine locale
./deploy.sh root@votre-serveur.com

# 2. Éditer la configuration
ssh root@votre-serveur.com "nano /opt/patching/config.conf"

# 3. Tester
ssh root@votre-serveur.com "/opt/patching/patch-vps.sh --dry-run"
```

## ⚙️ Configuration minimale (2 minutes)

Éditez `/opt/patching/config.conf`:

```bash
# Redémarrage automatique
ENABLE_REBOOT=true              # true = redémarrage auto, false = désactivé
REBOOT_DELAY=10                 # Délai en minutes avant redémarrage

# Notifications
API_ENDPOINT=""                 # URL de votre webhook (laissez vide pour désactiver)

# Services critiques à surveiller après redémarrage
CRITICAL_SERVICES="nginx mysql" # Séparés par des espaces
```

## ✅ Vérification (1 minute)

```bash
# Vérifier que le cron est installé
sudo crontab -l | grep patch-vps

# Voir quand sera la prochaine exécution
# Le script s'exécute tous les mercredis à 02h00 UTC

# Tester le script
sudo /opt/patching/patch-vps.sh --dry-run

# Voir les logs du test
sudo tail -50 /var/log/patching/patching-$(date +%Y-%m-%d).log
```

## 📊 Ce qui se passe automatiquement

Chaque mercredi à 02h00 UTC, le script:

1. ✅ Met à jour la liste des paquets (`apt-get update`)
2. ✅ Installe les mises à jour (`apt-get upgrade`)
3. ✅ Installe les mises à jour de sécurité (`apt-get dist-upgrade`)
4. ✅ Nettoie les paquets obsolètes (`apt-get autoremove`)
5. ✅ Vérifie si un redémarrage est nécessaire
6. ✅ Programme un redémarrage dans 10 minutes si nécessaire
7. ✅ Génère un rapport détaillé
8. ✅ Envoie une notification (si configurée)
9. ✅ Nettoie les logs de plus de 90 jours

## 🔧 Commandes essentielles

```bash
# Exécuter manuellement
sudo /opt/patching/patch-vps.sh

# Tester sans rien modifier
sudo /opt/patching/patch-vps.sh --dry-run

# Voir les logs
sudo tail -f /var/log/patching/patching-$(date +%Y-%m-%d).log

# Voir le dernier rapport
sudo cat /var/log/patching/report-$(date +%Y-%m-%d).txt

# Annuler un redémarrage programmé
sudo shutdown -c

# Éditer la configuration
sudo nano /opt/patching/config.conf
```

## 📧 Configuration des notifications

### Exemple d'endpoint webhook

Le script envoie un POST JSON vers votre endpoint:

```json
{
    "subject": "[SUCCÈS] Patching VPS hostname - 2026-01-26",
    "body": "... rapport complet ...",
    "timestamp": "2026-01-26T02:15:30Z",
    "hostname": "vps-hostname",
    "status": "SUCCÈS"
}
```

### Tester les notifications

```bash
# Éditer config.conf pour ajouter votre endpoint
sudo nano /opt/patching/config.conf

# Tester
sudo bash /opt/patching/test-notification.sh
```

## 🔄 Modifier la planification

### Avec Cron (par défaut)

```bash
# Éditer le crontab
sudo crontab -e

# Format actuel (mercredis à 02h00)
0 2 * * 3 /opt/patching/patch-vps.sh

# Exemples de modifications:
0 3 * * * /opt/patching/patch-vps.sh      # Tous les jours à 03h00
0 1 * * 1 /opt/patching/patch-vps.sh      # Tous les lundis à 01h00
0 2 1 * * /opt/patching/patch-vps.sh      # 1er de chaque mois à 02h00
```

### Avec Systemd Timer (alternative)

Voir le fichier `SYSTEMD_TIMER.md` pour la migration vers systemd.

## 🛑 Désactiver temporairement

```bash
# Désactiver le cron
sudo crontab -e
# Ajouter # devant la ligne

# Ou désactiver uniquement le redémarrage
sudo nano /opt/patching/config.conf
# Mettre: ENABLE_REBOOT=false
```

## 🐛 Dépannage rapide

### Le script ne s'exécute pas
```bash
# Vérifier les permissions
ls -l /opt/patching/patch-vps.sh
# Devrait être: -rwx------ root root

# Corriger si nécessaire
sudo chmod 700 /opt/patching/patch-vps.sh
```

### Les notifications ne fonctionnent pas
```bash
# Tester la connectivité
curl -I https://votre-api.com/webhook

# Tester l'envoi
sudo bash /opt/patching/test-notification.sh
```

### Le cron ne s'exécute pas
```bash
# Vérifier le service cron
sudo systemctl status cron

# Redémarrer si nécessaire
sudo systemctl restart cron

# Voir les logs système
sudo grep CRON /var/log/syslog | tail -20
```

## 📚 Pour aller plus loin

- **Documentation complète**: `README.md`
- **Référence rapide**: `CHEATSHEET.md`
- **Systemd Timer**: `SYSTEMD_TIMER.md`
- **Architecture**: `PROJECT_STRUCTURE.md`

## ⚠️ Important à savoir

1. **Le script s'exécute en tant que root** - Assurez-vous de le protéger
2. **Le redémarrage est automatique** - Configurez REBOOT_DELAY si nécessaire
3. **Les logs sont conservés 90 jours** - Modifiable dans config.conf
4. **L'heure est en UTC** - Adaptez selon votre timezone

## 🎯 Checklist de déploiement

- [ ] Script installé et testé en dry-run
- [ ] Configuration éditée (API_ENDPOINT, CRITICAL_SERVICES)
- [ ] Cron vérifié et actif
- [ ] Notifications testées
- [ ] Timezone vérifiée
- [ ] Permissions validées (700 pour scripts, 600 pour config)
- [ ] Premier test manuel effectué
- [ ] Documentation lue et comprise

## 🆘 Support

En cas de problème:
1. Consultez les logs: `sudo tail -f /var/log/patching/*.log`
2. Testez en dry-run: `sudo /opt/patching/patch-vps.sh --dry-run`
3. Consultez `CHEATSHEET.md` pour les commandes courantes
4. Vérifiez la syntaxe: `bash -n /opt/patching/patch-vps.sh`

---

**Durée totale d'installation et configuration**: ~5 minutes

**Prêt à l'emploi**: Le script s'exécutera automatiquement chaque mercredi matin!

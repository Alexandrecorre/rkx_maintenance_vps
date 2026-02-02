# Utilisation de Systemd Timer (Alternative à Cron)

Ce guide explique comment utiliser **systemd timer** au lieu de cron pour planifier le script de patching. Cette méthode est plus moderne et offre de meilleures fonctionnalités de logging et de gestion.

## Avantages de Systemd Timer vs Cron

✅ **Meilleur logging**: Intégration avec journald
✅ **Dépendances**: Possibilité de définir des dépendances entre services
✅ **Persistance**: Exécution automatique des tâches manquées
✅ **Monitoring**: Commandes systemd pour surveiller l'état
✅ **Randomisation**: Ajout d'un délai aléatoire pour éviter les pics de charge

## Installation

### 1. Copier les fichiers systemd

```bash
# Copier le service
sudo cp patching.service /etc/systemd/system/

# Copier le timer
sudo cp patching.timer /etc/systemd/system/

# Copier le service de vérification post-redémarrage (optionnel)
sudo cp patching-check.service /etc/systemd/system/
sudo cp check-services.sh /opt/patching/
sudo chmod 700 /opt/patching/check-services.sh
```

### 2. Recharger systemd

```bash
sudo systemctl daemon-reload
```

### 3. Activer et démarrer le timer

```bash
# Activer le timer (démarrage automatique au boot)
sudo systemctl enable patching.timer

# Démarrer le timer
sudo systemctl start patching.timer

# Activer le service de vérification post-redémarrage (optionnel)
sudo systemctl enable patching-check.service
```

### 4. Vérifier l'installation

```bash
# Vérifier le statut du timer
sudo systemctl status patching.timer

# Lister tous les timers actifs
sudo systemctl list-timers

# Voir quand sera la prochaine exécution
sudo systemctl list-timers patching.timer
```

## Commandes de gestion

### Statut et monitoring

```bash
# Voir le statut du timer
sudo systemctl status patching.timer

# Voir le statut du service
sudo systemctl status patching.service

# Voir les logs du service
sudo journalctl -u patching.service

# Voir les logs en temps réel
sudo journalctl -u patching.service -f

# Voir les logs depuis le dernier boot
sudo journalctl -u patching.service -b

# Voir les dernières 50 lignes
sudo journalctl -u patching.service -n 50

# Voir les logs d'une période spécifique
sudo journalctl -u patching.service --since "2026-01-20" --until "2026-01-26"
```

### Contrôle du timer

```bash
# Démarrer le timer
sudo systemctl start patching.timer

# Arrêter le timer
sudo systemctl stop patching.timer

# Redémarrer le timer
sudo systemctl restart patching.timer

# Activer (au démarrage)
sudo systemctl enable patching.timer

# Désactiver (au démarrage)
sudo systemctl disable patching.timer

# Recharger la configuration
sudo systemctl daemon-reload
```

### Exécution manuelle

```bash
# Exécuter le service manuellement (sans attendre le timer)
sudo systemctl start patching.service

# Voir les logs de l'exécution en cours
sudo journalctl -u patching.service -f
```

## Configuration du Timer

Le fichier `patching.timer` utilise la syntaxe suivante:

```ini
[Timer]
# Tous les mercredis à 02:00
OnCalendar=Wed *-*-* 02:00:00
```

### Exemples de planification

```ini
# Tous les jours à 03:00
OnCalendar=*-*-* 03:00:00

# Tous les lundis à 01:00
OnCalendar=Mon *-*-* 01:00:00

# Tous les premiers du mois à 02:00
OnCalendar=*-*-01 02:00:00

# Tous les dimanches à 04:30
OnCalendar=Sun *-*-* 04:30:00

# Plusieurs horaires (deux fois par semaine)
OnCalendar=Mon,Thu *-*-* 02:00:00

# Toutes les heures
OnCalendar=*-*-* *:00:00

# Toutes les 4 heures
OnCalendar=*-*-* 00/4:00:00
```

### Tester une expression de calendrier

```bash
# Vérifier quand l'expression sera déclenchée
systemd-analyze calendar "Wed *-*-* 02:00:00"

# Exemple avec une autre expression
systemd-analyze calendar "Mon,Thu *-*-* 02:00:00"
```

## Migration depuis Cron

Si vous utilisez déjà cron, voici comment migrer:

### 1. Sauvegarder le cron actuel

```bash
sudo crontab -l > cron-backup.txt
```

### 2. Supprimer l'entrée cron

```bash
sudo crontab -e
# Supprimer ou commenter la ligne du patching
```

### 3. Installer le systemd timer

```bash
# Suivre les instructions d'installation ci-dessus
sudo systemctl enable --now patching.timer
```

### 4. Vérifier que le timer fonctionne

```bash
sudo systemctl list-timers patching.timer
```

## Personnalisation

### Modifier l'horaire d'exécution

```bash
# Éditer le fichier timer
sudo nano /etc/systemd/system/patching.timer

# Modifier la ligne OnCalendar
OnCalendar=Mon *-*-* 01:00:00

# Recharger systemd
sudo systemctl daemon-reload

# Redémarrer le timer
sudo systemctl restart patching.timer
```

### Ajouter un délai aléatoire

Pour éviter que plusieurs serveurs ne se mettent à jour exactement au même moment:

```ini
[Timer]
OnCalendar=Wed *-*-* 02:00:00
RandomizedDelaySec=1800  # 30 minutes de délai aléatoire
```

### Persistent timer

Pour exécuter le service si l'heure a été manquée (serveur éteint):

```ini
[Timer]
OnCalendar=Wed *-*-* 02:00:00
Persistent=true
```

## Dépannage

### Le timer ne s'exécute pas

```bash
# Vérifier que le timer est actif
sudo systemctl is-active patching.timer

# Vérifier que le timer est enabled
sudo systemctl is-enabled patching.timer

# Voir les erreurs
sudo journalctl -u patching.timer -p err

# Tester manuellement le service
sudo systemctl start patching.service
```

### Voir les prochaines exécutions

```bash
# Afficher tous les timers avec leurs prochaines exécutions
sudo systemctl list-timers --all

# Détails du timer patching
sudo systemctl status patching.timer
```

### Réinitialiser un timer bloqué

```bash
# Arrêter le timer
sudo systemctl stop patching.timer

# Désactiver le timer
sudo systemctl disable patching.timer

# Recharger systemd
sudo systemctl daemon-reload

# Réactiver et redémarrer
sudo systemctl enable patching.timer
sudo systemctl start patching.timer
```

## Monitoring avancé

### Créer des alertes

Vous pouvez créer des alertes en cas d'échec:

```bash
# Éditer le service pour ajouter des actions en cas d'échec
sudo nano /etc/systemd/system/patching.service
```

Ajouter dans la section `[Service]`:

```ini
[Service]
Type=oneshot
ExecStart=/opt/patching/patch-vps.sh
OnFailure=patching-failed.service
```

Créer un service d'alerte:

```bash
sudo nano /etc/systemd/system/patching-failed.service
```

```ini
[Unit]
Description=Alerte d'échec du patching

[Service]
Type=oneshot
ExecStart=/opt/patching/send-alert.sh
```

### Statistiques d'exécution

```bash
# Voir combien de fois le service a été exécuté
sudo systemctl show patching.service -p NRestarts

# Voir le dernier code de sortie
sudo systemctl show patching.service -p ExecMainStatus

# Voir la dernière exécution
sudo systemctl show patching.service -p ExecMainExitTimestamp
```

## Désactivation temporaire

```bash
# Désactiver temporairement le timer
sudo systemctl stop patching.timer

# Réactiver
sudo systemctl start patching.timer
```

## Désinstallation

```bash
# Arrêter et désactiver le timer
sudo systemctl stop patching.timer
sudo systemctl disable patching.timer

# Supprimer les fichiers
sudo rm /etc/systemd/system/patching.timer
sudo rm /etc/systemd/system/patching.service
sudo rm /etc/systemd/system/patching-check.service

# Recharger systemd
sudo systemctl daemon-reload
```

## Comparaison Cron vs Systemd Timer

| Fonctionnalité | Cron | Systemd Timer |
|----------------|------|---------------|
| Logging | Limité (syslog) | Complet (journald) |
| Dépendances | Non | Oui |
| Persistance | Non | Oui |
| Randomisation | Difficile | Intégré |
| Monitoring | Basique | Avancé |
| Configuration | Simple | Plus verbeux |
| Portabilité | Universel | Systemd uniquement |

## Recommandation

**Utilisez systemd timer si:**
- Vous avez Ubuntu 16.04+ (systemd est standard)
- Vous voulez un meilleur logging et monitoring
- Vous avez besoin de gérer des dépendances
- Vous voulez une gestion moderne des services

**Utilisez cron si:**
- Vous préférez la simplicité
- Vous devez supporter des systèmes anciens
- Vous avez déjà une infrastructure cron

---

**Note**: Les deux méthodes (cron et systemd timer) sont valides et fonctionnent bien. Choisissez celle qui correspond le mieux à vos besoins.

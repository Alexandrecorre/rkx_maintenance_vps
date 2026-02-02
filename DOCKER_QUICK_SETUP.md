# Configuration Rapide - Redémarrage Automatique Docker

Guide ultra-rapide pour configurer le redémarrage automatique de vos services Docker après un reboot système.

## 🚀 Installation rapide (5 minutes)

### Étape 1: Configurer les restart policies Docker (2 min)

```bash
# Option A: Automatique pour TOUS les conteneurs
sudo bash setup-docker-restart.sh

# Option B: Manuel pour chaque conteneur
docker update --restart=always mon-conteneur-1
docker update --restart=always mon-conteneur-2
docker update --restart=always mon-conteneur-3

# Option C: Depuis Docker Compose (recommandé)
# Éditer votre docker-compose.yml et ajouter "restart: always" à chaque service
```

### Étape 2: Configurer les conteneurs à surveiller (1 min)

```bash
# Éditer la configuration
sudo nano /opt/patching/config.conf
```

Ajouter vos conteneurs:

```bash
# Services systemd
CRITICAL_SERVICES="docker nginx mysql redis"

# Conteneurs Docker individuels
CRITICAL_CONTAINERS="mon-app mon-db mon-redis"

# Projets Docker Compose
CRITICAL_COMPOSE_PROJECTS="/opt/app1 /opt/monitoring"
```

### Étape 3: Activer le script de vérification (2 min)

```bash
# Remplacer l'ancien script par la version Docker
sudo cp check-services-docker.sh /opt/patching/check-services.sh
sudo chmod 700 /opt/patching/check-services.sh

# Créer le service systemd
sudo nano /etc/systemd/system/patching-check.service
```

Copier:

```ini
[Unit]
Description=Vérification services et Docker après redémarrage
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=/opt/patching/check-services.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
```

Activer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable patching-check.service
```

### Étape 4: Tester

```bash
# Test manuel
sudo /opt/patching/check-services.sh

# Test après reboot
sudo reboot

# Après reboot, vérifier
sudo journalctl -u patching-check.service
sudo cat /var/log/patching/services-check-*.log
```

---

## 📋 Résumé des fichiers créés

| Fichier | Description | Action |
|---------|-------------|--------|
| **check-services-docker.sh** | Script de vérification amélioré | Remplace check-services.sh |
| **setup-docker-restart.sh** | Configure restart policies automatiquement | Exécuter une fois |
| **docker-compose.example.yml** | Exemple de compose avec bonnes pratiques | Adapter à votre app |
| **app-compose.service.example** | Service systemd pour docker-compose | Adapter si besoin |
| **DOCKER_RESTART_GUIDE.md** | Guide complet détaillé | Lire pour comprendre |

---

## ✅ Checklist de configuration

- [ ] Restart policies configurées sur tous les conteneurs
- [ ] config.conf mis à jour avec CRITICAL_CONTAINERS
- [ ] check-services-docker.sh installé
- [ ] patching-check.service activé
- [ ] Test manuel réussi
- [ ] Test après reboot réussi

---

## 🎯 Configurations recommandées par cas d'usage

### Cas 1: Application simple avec quelques conteneurs

**Méthode**: Docker restart policies uniquement

```bash
docker update --restart=always $(docker ps -q)
```

Configuration config.conf:

```bash
CRITICAL_SERVICES="docker"
CRITICAL_CONTAINERS="app-web app-api app-db"
```

### Cas 2: Application Docker Compose

**Méthode**: restart: always dans docker-compose.yml

```yaml
services:
  app:
    image: mon-app:latest
    restart: always
  db:
    image: postgres:15
    restart: always
```

Configuration config.conf:

```bash
CRITICAL_SERVICES="docker"
CRITICAL_COMPOSE_PROJECTS="/opt/mon-app"
```

### Cas 3: Multiples projets avec dépendances

**Méthode**: Systemd services + Docker Compose

1. Créer un service systemd par projet (voir app-compose.service.example)
2. Configurer les dépendances (After=, Requires=)
3. Activer les services

Configuration config.conf:

```bash
CRITICAL_SERVICES="docker app1-compose app2-compose"
CRITICAL_COMPOSE_PROJECTS="/opt/app1 /opt/app2"
```

---

## 🔍 Vérification rapide

```bash
# Voir tous les conteneurs et leurs restart policies
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.RestartPolicy}}"

# Voir les conteneurs qui devraient redémarrer mais sont arrêtés
docker ps -a --filter "restart=always" --filter "status=exited"

# Tester le script de vérification
sudo /opt/patching/check-services.sh

# Voir les logs de la dernière vérification
sudo tail -50 /var/log/patching/services-check-*.log
```

---

## 🆘 Dépannage rapide

### Conteneur ne redémarre pas après reboot

```bash
# Vérifier le restart policy
docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' mon-conteneur

# Si "no", corriger:
docker update --restart=always mon-conteneur
```

### Script de vérification ne détecte pas les conteneurs

```bash
# Vérifier que les noms correspondent exactement
docker ps --format '{{.Names}}'

# Comparer avec config.conf
cat /opt/patching/config.conf | grep CRITICAL_CONTAINERS
```

### Service systemd ne démarre pas

```bash
# Voir les erreurs
sudo systemctl status patching-check.service -l
sudo journalctl -u patching-check.service -xe

# Tester le script manuellement
sudo /opt/patching/check-services.sh
```

---

## 📖 Documentation complète

Pour plus de détails, consultez:
- **DOCKER_RESTART_GUIDE.md** - Guide complet avec toutes les options
- **README.md** - Documentation principale du système de patching

---

**Durée totale**: ~5 minutes
**Complexité**: Faible
**Fiabilité**: Très élevée

Vous êtes prêt ! Vos conteneurs Docker redémarreront automatiquement après chaque reboot système. 🎉

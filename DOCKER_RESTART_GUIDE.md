# Guide - Redémarrage des Services Docker et Applicatifs

Guide complet pour gérer le redémarrage automatique des services Docker et applicatifs après un reboot système.

## 🎯 Stratégie recommandée (Multi-niveaux)

### Niveau 1: Docker Restart Policies (Natif Docker)
### Niveau 2: Systemd Services (Gestion système)
### Niveau 3: Vérification et monitoring (Scripts)
### Niveau 4: Ordre de démarrage (Dépendances)

---

## 📋 Niveau 1: Docker Restart Policies

### Configuration recommandée pour vos conteneurs

```bash
# Restart policy "always" - Le conteneur redémarre toujours
docker run -d --restart=always --name mon-app mon-image

# Restart policy "unless-stopped" - Redémarre sauf si arrêté manuellement
docker run -d --restart=unless-stopped --name mon-app mon-image

# Modifier un conteneur existant
docker update --restart=always mon-conteneur
```

### Avec Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    image: nginx:latest
    restart: always  # ← Toujours redémarrer
    ports:
      - "80:80"

  app:
    image: mon-app:latest
    restart: unless-stopped  # ← Redémarrer sauf si arrêté manuellement
    depends_on:
      - db

  db:
    image: postgres:15
    restart: always
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:  # ← Ajouter un health check
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  db-data:
```

### Appliquer les restart policies à tous vos conteneurs existants

```bash
#!/bin/bash
# Script pour appliquer restart=always à tous les conteneurs

for container in $(docker ps -q); do
    container_name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
    echo "Configuration de restart=always pour: $container_name"
    docker update --restart=always "$container"
done
```

---

## 🔧 Niveau 2: Systemd Services

### Option A: Service Systemd pour Docker Compose

Créez un service systemd pour chaque projet Docker Compose:

```bash
sudo nano /etc/systemd/system/mon-app-compose.service
```

```ini
[Unit]
Description=Mon Application Docker Compose
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mon-app
ExecStartPre=/usr/bin/docker-compose pull --quiet --ignore-pull-failures
ExecStart=/usr/bin/docker-compose up -d --remove-orphans
ExecStop=/usr/bin/docker-compose down
ExecReload=/usr/bin/docker-compose pull --quiet --ignore-pull-failures
ExecReload=/usr/bin/docker-compose up -d --remove-orphans
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
```

Activer le service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mon-app-compose.service
sudo systemctl start mon-app-compose.service
```

### Option B: Service Systemd pour un conteneur Docker simple

```bash
sudo nano /etc/systemd/system/mon-conteneur.service
```

```ini
[Unit]
Description=Mon Conteneur Docker
Requires=docker.service
After=docker.service

[Service]
Type=simple
RemainAfterExit=yes
ExecStartPre=-/usr/bin/docker stop mon-conteneur
ExecStartPre=-/usr/bin/docker rm mon-conteneur
ExecStart=/usr/bin/docker run --rm --name mon-conteneur \
    -p 8080:8080 \
    -v /data:/app/data \
    mon-image:latest
ExecStop=/usr/bin/docker stop mon-conteneur
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

---

## 🔍 Niveau 3: Vérification et Monitoring

### Script de vérification amélioré (déjà fourni)

Le script `check-services-docker.sh` vérifie:
- ✅ Services systemd
- ✅ Service Docker
- ✅ Conteneurs Docker critiques
- ✅ Projets Docker Compose
- ✅ Conteneurs avec restart=always

### Configuration

Éditez `/opt/patching/config.conf`:

```bash
# Services systemd critiques
CRITICAL_SERVICES="nginx mysql redis"

# Conteneurs Docker critiques (noms exacts)
CRITICAL_CONTAINERS="mon-app mon-db mon-redis"

# Projets Docker Compose (chemins absolus)
CRITICAL_COMPOSE_PROJECTS="/opt/app1 /opt/app2"
```

### Intégration avec systemd (vérification automatique au boot)

```bash
sudo nano /etc/systemd/system/patching-check-docker.service
```

```ini
[Unit]
Description=Vérification des services et conteneurs Docker après redémarrage
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=/opt/patching/check-services-docker.sh
RemainAfterExit=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Activer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable patching-check-docker.service
```

---

## ⚙️ Niveau 4: Ordre de démarrage (Gestion des dépendances)

### Avec Docker Compose (depends_on)

```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  app:
    image: mon-app:latest
    restart: always
    depends_on:
      db:
        condition: service_healthy  # Attendre que DB soit healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3

  nginx:
    image: nginx:latest
    restart: always
    depends_on:
      app:
        condition: service_healthy  # Attendre que l'app soit healthy
    ports:
      - "80:80"
```

### Avec Systemd (After/Requires)

```bash
# Service pour la base de données
sudo nano /etc/systemd/system/app-database.service
```

```ini
[Unit]
Description=Application Database
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker-compose -f /opt/app/docker-compose.yml up -d db
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
```

```bash
# Service pour l'application (qui dépend de la DB)
sudo nano /etc/systemd/system/app-backend.service
```

```ini
[Unit]
Description=Application Backend
After=app-database.service
Requires=app-database.service docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/bin/sleep 10
ExecStart=/usr/bin/docker-compose -f /opt/app/docker-compose.yml up -d app
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
```

---

## 🚀 Script d'initialisation global (Recommandé)

Créez un script qui démarre tout dans le bon ordre:

```bash
sudo nano /opt/patching/start-all-services.sh
```

```bash
#!/bin/bash
################################################################################
# SCRIPT DE DÉMARRAGE GLOBAL DES SERVICES ET CONTENEURS
################################################################################

set -euo pipefail

LOG_FILE="/var/log/patching/startup-$(date +%Y-%m-%d).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "===== DÉMARRAGE DES SERVICES ====="

# 1. Attendre que Docker soit prêt
log "Attente de Docker..."
timeout 60 bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'
log "Docker est prêt"

# 2. Démarrer les services systemd dans l'ordre
SYSTEMD_SERVICES="nginx mysql redis"
for service in $SYSTEMD_SERVICES; do
    log "Démarrage de $service..."
    if systemctl start "$service"; then
        log "✓ $service démarré"
    else
        log "✗ Échec de $service"
    fi
    sleep 2
done

# 3. Démarrer les projets Docker Compose dans l'ordre
COMPOSE_PROJECTS="/opt/app1 /opt/app2"
for project in $COMPOSE_PROJECTS; do
    if [ -f "$project/docker-compose.yml" ]; then
        log "Démarrage de $(basename $project)..."
        cd "$project"
        if docker-compose up -d; then
            log "✓ $(basename $project) démarré"
        else
            log "✗ Échec de $(basename $project)"
        fi
        sleep 5
    fi
done

# 4. Démarrer les conteneurs individuels
CONTAINERS="mon-app-special"
for container in $CONTAINERS; do
    if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
        log "Démarrage de $container..."
        if docker start "$container"; then
            log "✓ $container démarré"
        else
            log "✗ Échec de $container"
        fi
        sleep 2
    fi
done

log "===== DÉMARRAGE TERMINÉ ====="

# 5. Attendre que tout soit stable
log "Attente de stabilisation (30s)..."
sleep 30

# 6. Vérification finale
log "Vérification finale..."
/opt/patching/check-services-docker.sh
```

Permissions:

```bash
sudo chmod 700 /opt/patching/start-all-services.sh
```

Service systemd pour ce script:

```bash
sudo nano /etc/systemd/system/startup-all-services.service
```

```ini
[Unit]
Description=Démarrage global de tous les services et conteneurs
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/opt/patching/start-all-services.sh
RemainAfterExit=yes
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
```

Activer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable startup-all-services.service
```

---

## 📊 Tableau comparatif des méthodes

| Méthode | Avantages | Inconvénients | Recommandé pour |
|---------|-----------|---------------|-----------------|
| **Docker restart policies** | Natif, simple, automatique | Pas de contrôle de l'ordre | Tous les conteneurs |
| **Systemd services** | Contrôle total, dépendances | Plus complexe | Applications critiques |
| **Docker Compose depends_on** | Gestion ordre, health checks | Limité au projet | Stacks complètes |
| **Script global** | Flexibilité maximale | Maintenance manuelle | Cas complexes |

---

## ✅ Configuration complète recommandée

### 1. Configuration des conteneurs Docker

```bash
# Appliquer restart=always à tous vos conteneurs
docker update --restart=always $(docker ps -q)
```

### 2. Configuration du fichier config.conf

```bash
sudo nano /opt/patching/config.conf
```

Ajouter:

```bash
# Services systemd critiques
CRITICAL_SERVICES="docker nginx mysql redis"

# Conteneurs Docker critiques
CRITICAL_CONTAINERS="app-web app-api app-worker"

# Projets Docker Compose
CRITICAL_COMPOSE_PROJECTS="/opt/monapp /opt/monitoring"
```

### 3. Remplacer check-services.sh par la version Docker

```bash
sudo cp /opt/patching/check-services.sh /opt/patching/check-services.sh.backup
sudo mv /tmp/check-services-docker.sh /opt/patching/check-services.sh
sudo chmod 700 /opt/patching/check-services.sh
```

### 4. Créer le service de vérification au boot

```bash
sudo nano /etc/systemd/system/patching-check.service
```

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

### 5. Tester

```bash
# Test manuel
sudo /opt/patching/check-services.sh

# Test avec reboot
sudo reboot

# Après reboot, vérifier les logs
sudo journalctl -u patching-check.service
sudo cat /var/log/patching/services-check-*.log
```

---

## 🔥 Cas d'usage courants

### Cas 1: Stack LAMP avec conteneurs

```yaml
# docker-compose.yml
version: '3.8'

services:
  mysql:
    image: mysql:8
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  php-app:
    image: php:8.2-fpm
    restart: always
    depends_on:
      mysql:
        condition: service_healthy
    volumes:
      - ./app:/var/www/html

  nginx:
    image: nginx:latest
    restart: always
    depends_on:
      - php-app
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf

volumes:
  mysql-data:
```

### Cas 2: Application avec dépendances multiples

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready"]
      interval: 5s

  redis:
    image: redis:7
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s

  rabbitmq:
    image: rabbitmq:3-management
    restart: always
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 10s

  backend:
    image: mon-backend:latest
    restart: always
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s

  frontend:
    image: mon-frontend:latest
    restart: always
    depends_on:
      backend:
        condition: service_healthy
    ports:
      - "80:80"
```

---

## 🛠️ Dépannage

### Problème: Conteneurs ne redémarrent pas après reboot

```bash
# Vérifier le restart policy
docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' mon-conteneur

# Corriger
docker update --restart=always mon-conteneur
```

### Problème: Ordre de démarrage incorrect

```bash
# Utiliser depends_on avec health checks dans docker-compose.yml
# Ou créer des services systemd avec After= et Requires=
```

### Problème: Docker n'est pas prêt assez tôt

```bash
# Ajouter un délai dans le service systemd
ExecStartPre=/bin/sleep 30

# Ou attendre que Docker soit ready
ExecStartPre=/bin/bash -c 'until docker info; do sleep 1; done'
```

---

## 📚 Ressources

- [Docker Restart Policies](https://docs.docker.com/config/containers/start-containers-automatically/)
- [Docker Compose depends_on](https://docs.docker.com/compose/compose-file/05-services/#depends_on)
- [Systemd Services](https://www.freedesktop.org/software/systemd/man/systemd.service.html)

---

**Recommandation finale**: Utilisez une combinaison de **Docker restart policies** (niveau 1) + **Script de vérification** (niveau 3) pour une fiabilité maximale avec une simplicité de maintenance.

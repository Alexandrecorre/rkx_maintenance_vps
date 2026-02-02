# Index des Fichiers - Script de Patching VPS Ubuntu

Guide de navigation pour tous les fichiers du projet.

## 📖 Par où commencer ?

### Pour démarrer rapidement (5 minutes)
👉 **[QUICK_START.md](QUICK_START.md)** - Guide de démarrage rapide

### Pour une installation complète
👉 **[README.md](README.md)** - Documentation principale complète

### Pour des commandes rapides
👉 **[CHEATSHEET.md](CHEATSHEET.md)** - Référence des commandes courantes

---

## 📂 Liste complète des fichiers

### 🚀 Commencer ici
| Fichier | Description | Utilité |
|---------|-------------|---------|
| **QUICK_START.md** | Guide de démarrage rapide (5 min) | ⭐ Commencez ici pour une installation rapide |
| **README.md** | Documentation complète | ⭐ Documentation principale détaillée |
| **INDEX.md** | Ce fichier - Navigation du projet | 📍 Vous êtes ici |

### 🔧 Scripts principaux
| Fichier | Description | Permissions | Utilisation |
|---------|-------------|-------------|-------------|
| **patch-vps.sh** | Script principal de patching | 700 | Script qui effectue les mises à jour |
| **check-services.sh** | Vérification services critiques | 700 | Vérifie les services après redémarrage |
| **test-notification.sh** | Test des notifications API | 700 | Teste l'envoi de notifications |
| **install.sh** | Installation interactive | 755 | Installe le système complet |
| **deploy.sh** | Déploiement distant SSH | 755 | Déploie sur un serveur distant |

### ⚙️ Configuration
| Fichier | Description | Permissions | Contenu |
|---------|-------------|-------------|---------|
| **config.conf** | Configuration principale | 600 | Paramètres, API endpoint, services |

### 📚 Documentation
| Fichier | Description | Contenu |
|---------|-------------|---------|
| **README.md** | Documentation principale | Installation, configuration, utilisation complète |
| **QUICK_START.md** | Guide rapide | Installation en 5 minutes |
| **CHEATSHEET.md** | Référence rapide | Commandes courantes et exemples |
| **SYSTEMD_TIMER.md** | Guide systemd timer | Alternative à cron avec systemd |
| **PROJECT_STRUCTURE.md** | Architecture du projet | Structure des fichiers et flux d'exécution |
| **CHANGELOG.md** | Historique des versions | Versions et modifications |
| **INDEX.md** | Ce fichier | Navigation du projet |

### 🔄 Systemd (alternative à cron)
| Fichier | Description | Emplacement |
|---------|-------------|-------------|
| **patching.service** | Service systemd | `/etc/systemd/system/` |
| **patching.timer** | Timer systemd | `/etc/systemd/system/` |
| **patching-check.service** | Vérification post-boot | `/etc/systemd/system/` |

### 🐳 Test et développement
| Fichier | Description | Utilisation |
|---------|-------------|-------------|
| **Dockerfile.test** | Image Docker de test | Tests locaux en conteneur |
| **Makefile** | Automatisation des tâches | Commandes make (test, deploy, etc.) |

### 📋 Autres
| Fichier | Description | Utilité |
|---------|-------------|---------|
| **spec.txt** | Spécifications originales | Document de référence initial |
| **LICENSE** | Licence MIT | Termes d'utilisation |
| **.gitignore** | Fichiers Git à ignorer | Configuration Git |

---

## 🎯 Fichiers par cas d'usage

### Je veux installer le système
1. **QUICK_START.md** - Pour une installation rapide
2. **install.sh** - Script d'installation
3. **config.conf** - Configuration à éditer

### Je veux comprendre le système
1. **README.md** - Documentation complète
2. **PROJECT_STRUCTURE.md** - Architecture
3. **spec.txt** - Spécifications originales

### Je veux utiliser le système
1. **CHEATSHEET.md** - Commandes courantes
2. **patch-vps.sh** - Script principal
3. **config.conf** - Configuration

### Je veux déployer sur un serveur
1. **deploy.sh** - Déploiement distant
2. **install.sh** - Installation automatique
3. **README.md** - Instructions détaillées

### Je veux utiliser systemd au lieu de cron
1. **SYSTEMD_TIMER.md** - Guide complet
2. **patching.service** - Service systemd
3. **patching.timer** - Timer systemd

### Je veux tester localement
1. **Dockerfile.test** - Image Docker
2. **Makefile** - Commandes de test
3. **test-notification.sh** - Test des notifications

### Je veux des références rapides
1. **CHEATSHEET.md** - Commandes courantes
2. **QUICK_START.md** - Démarrage rapide
3. **INDEX.md** - Ce fichier

---

## 📊 Taille et organisation

```
Total: 19 fichiers

Documentation:  7 fichiers (README, guides, changelog)
Scripts:        5 fichiers (patch, install, deploy, check, test)
Configuration:  1 fichier  (config.conf)
Systemd:        3 fichiers (service, timer, check)
Dev/Test:       2 fichiers (Dockerfile, Makefile)
Autres:         1 fichier  (LICENSE, .gitignore, spec)
```

---

## 🔍 Recherche rapide

### Rechercher une fonctionnalité

| Je cherche... | Fichier à consulter |
|---------------|---------------------|
| Installation rapide | QUICK_START.md |
| Commande pour voir les logs | CHEATSHEET.md |
| Configuration de l'API endpoint | README.md, config.conf |
| Planification avec systemd | SYSTEMD_TIMER.md |
| Déploiement distant | README.md (section déploiement), deploy.sh |
| Gestion des erreurs | README.md (section dépannage) |
| Structure des logs | PROJECT_STRUCTURE.md |
| Permissions des fichiers | README.md, PROJECT_STRUCTURE.md |
| Tests en local | Dockerfile.test, Makefile |
| Notifications | README.md, test-notification.sh |

### Rechercher par mot-clé

| Mot-clé | Fichiers pertinents |
|---------|---------------------|
| cron | README.md, CHEATSHEET.md, install.sh |
| systemd | SYSTEMD_TIMER.md, patching.service, patching.timer |
| notification | README.md, config.conf, test-notification.sh |
| redémarrage | README.md, config.conf, patch-vps.sh |
| logs | CHEATSHEET.md, PROJECT_STRUCTURE.md |
| services | check-services.sh, config.conf |
| test | QUICK_START.md, Dockerfile.test, Makefile |
| deploy | deploy.sh, README.md |

---

## 📈 Niveau de priorité de lecture

### ⭐⭐⭐ Priorité HAUTE (à lire en premier)
1. **QUICK_START.md** - Pour démarrer rapidement
2. **README.md** - Documentation essentielle
3. **config.conf** - Configuration à personnaliser

### ⭐⭐ Priorité MOYENNE (utile au quotidien)
4. **CHEATSHEET.md** - Référence des commandes
5. **PROJECT_STRUCTURE.md** - Comprendre l'architecture
6. **patch-vps.sh** - Script principal (pour comprendre le code)

### ⭐ Priorité BASSE (optionnel, selon besoins)
7. **SYSTEMD_TIMER.md** - Si vous préférez systemd à cron
8. **Dockerfile.test** - Si vous voulez tester en local
9. **deploy.sh** - Si vous déployez à distance
10. **CHANGELOG.md** - Historique des versions

---

## 🗺️ Chemin d'apprentissage suggéré

### Niveau 1: Débutant (30 minutes)
1. Lire **QUICK_START.md** (5 min)
2. Installer avec **install.sh** (10 min)
3. Tester avec `--dry-run` (5 min)
4. Consulter **CHEATSHEET.md** (10 min)

### Niveau 2: Intermédiaire (1 heure)
1. Lire **README.md** complet (30 min)
2. Comprendre **PROJECT_STRUCTURE.md** (15 min)
3. Personnaliser **config.conf** (10 min)
4. Analyser les logs d'un test (5 min)

### Niveau 3: Avancé (2 heures)
1. Lire le code de **patch-vps.sh** (45 min)
2. Explorer **SYSTEMD_TIMER.md** (30 min)
3. Tester avec **Dockerfile.test** (30 min)
4. Déployer avec **deploy.sh** (15 min)

---

## 💡 Conseils

- **Nouveau sur le projet ?** → Commencez par **QUICK_START.md**
- **Besoin d'aide rapide ?** → Consultez **CHEATSHEET.md**
- **Problème technique ?** → Section dépannage dans **README.md**
- **Installation personnalisée ?** → Lisez **README.md** complet
- **Préférez systemd ?** → Lisez **SYSTEMD_TIMER.md**
- **Déploiement à distance ?** → Utilisez **deploy.sh**

---

## 📞 Support

- **Documentation principale**: README.md
- **Questions fréquentes**: Sections dépannage dans README.md et CHEATSHEET.md
- **Architecture**: PROJECT_STRUCTURE.md
- **Versions**: CHANGELOG.md

---

**Dernière mise à jour**: 2026-01-26
**Version**: 1.0.0

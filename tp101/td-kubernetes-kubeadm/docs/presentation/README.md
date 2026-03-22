# 🎯 Présentation des Slides - TD Kubernetes

Ce dossier contient tout le nécessaire pour lancer un serveur de présentation interactif des slides du cours Kubernetes.

## 🚀 Démarrage rapide

### Prérequis

- Docker installé et démarré
- Docker Compose (généralement inclus avec Docker Desktop)

### Lancement en 1 commande

```bash
cd docs/presentation
./run-presentation.sh
```

Puis ouvrez votre navigateur sur: **http://localhost:8080/slides-instructeur.md**

## 📋 Commandes disponibles

Le script `run-presentation.sh` offre plusieurs commandes:

```bash
# Démarrer le serveur de présentation
./run-presentation.sh start

# Arrêter le serveur
./run-presentation.sh stop

# Redémarrer le serveur
./run-presentation.sh restart

# Voir les logs en temps réel
./run-presentation.sh logs

# Vérifier le statut du conteneur
./run-presentation.sh status

# Reconstruire complètement le conteneur
./run-presentation.sh rebuild

# Exporter les slides en PDF
./run-presentation.sh export-pdf

# Exporter les slides en HTML
./run-presentation.sh export-html

# Exporter les slides en PPTX
./run-presentation.sh export-pptx

# Afficher l'aide
./run-presentation.sh help
```

## 🎨 Utilisation du mode présentation

### Accès web

Une fois le serveur démarré, accédez à:
- **Slides instructeur:** http://localhost:8080/slides-instructeur.md

### Navigation dans les slides

Dans votre navigateur, utilisez:
- **Flèches ← →** ou **clic** pour naviguer
- **F11** pour le mode plein écran
- **Esc** pour quitter le plein écran

### Mode présentateur

Pour afficher les notes et le chronomètre (si configuré):
- Appuyez sur **`P`** dans la présentation

## 📦 Export des slides

### Export PDF

Pour générer un PDF des slides:

```bash
./run-presentation.sh export-pdf
```

Le fichier sera créé dans: `docs/slides-instructeur.pdf`

### Export HTML

Pour générer une page HTML autonome:

```bash
./run-presentation.sh export-html
```

Le fichier sera créé dans: `docs/slides-instructeur.html`

### Export PowerPoint

Pour générer un fichier PPTX:

```bash
./run-presentation.sh export-pptx
```

Le fichier sera créé dans: `docs/slides-instructeur.pptx`

## 🛠️ Configuration avancée

### Changer le port

Si le port 8080 est déjà utilisé, modifiez le fichier `docker-compose.yml`:

```yaml
ports:
  - "3000:8080"  # Changez 3000 par le port de votre choix
```

Puis redémarrez:

```bash
./run-presentation.sh restart
```

### Utiliser Docker directement

Si vous préférez utiliser Docker sans le script:

```bash
# Build l'image
docker build -t kubernetes-slides .

# Run le conteneur
docker run -d \
  --name kubernetes-slides \
  -p 8080:8080 \
  -v $(pwd)/../:/slides:ro \
  kubernetes-slides

# Arrêter le conteneur
docker stop kubernetes-slides

# Supprimer le conteneur
docker rm kubernetes-slides
```

### Utiliser Docker Compose directement

```bash
# Démarrer
docker compose up -d

# Arrêter
docker compose down

# Voir les logs
docker compose logs -f
```

## 📁 Structure des fichiers

```
docs/presentation/
├── Dockerfile              # Image Docker avec Marp CLI
├── docker-compose.yml      # Configuration Docker Compose
├── run-presentation.sh     # Script de gestion simplifié
└── README.md              # Ce fichier
```

## 🔧 Troubleshooting

### Le serveur ne démarre pas

**Problème:** Docker n'est pas installé
```bash
# Vérifiez l'installation
docker --version
docker-compose --version
```

**Problème:** Docker n'est pas démarré
```bash
# Sur macOS/Windows: démarrez Docker Desktop
# Sur Linux:
sudo systemctl start docker
```

**Problème:** Port 8080 déjà utilisé
```bash
# Identifiez le processus
lsof -i :8080  # macOS/Linux
netstat -ano | findstr :8080  # Windows

# Changez le port dans docker-compose.yml
```

### Les slides ne s'affichent pas correctement

**Problème:** Cache du navigateur
```
Appuyez sur Ctrl+Shift+R (ou Cmd+Shift+R sur macOS) pour rafraîchir
```

**Problème:** Le fichier markdown n'est pas trouvé
```bash
# Vérifiez que le fichier existe
ls -la ../slides-instructeur.md

# Vérifiez les volumes Docker
docker inspect kubernetes-slides | grep -A 10 Mounts
```

### Les exports ne fonctionnent pas

**Problème:** Chromium manquant pour l'export PDF/PPTX
```bash
# Reconstruisez l'image avec les dépendances
./run-presentation.sh rebuild
```

## 🎓 Personnalisation des slides

### Modifier le contenu

Les slides sont dans le fichier: `docs/slides-instructeur.md`

Après modification, le serveur détecte automatiquement les changements. Rafraîchissez simplement votre navigateur.

### Modifier le thème

Dans le fichier markdown, modifiez l'en-tête:

```markdown
---
marp: true
theme: default  # ou: gaia, uncover
paginate: true
style: |
  /* Votre CSS personnalisé ici */
---
```

Thèmes disponibles:
- **default** - Thème classique et sobre
- **gaia** - Thème moderne et coloré
- **uncover** - Thème minimaliste

## 📚 Ressources

### Documentation Marp

- [Marp Official Site](https://marp.app/)
- [Marp CLI](https://github.com/marp-team/marp-cli)
- [Marpit Markdown](https://marpit.marp.app/markdown)

### Syntaxe Markdown spéciale

```markdown
<!-- _class: lead -->
# Slide avec style spécial

---

<!-- _paginate: false -->
# Slide sans numéro de page

---

![bg](image.jpg)
# Slide avec image de fond

---

![bg right:40%](image.jpg)
# Texte à gauche, image à droite
```

## 🤝 Support

Si vous rencontrez des problèmes:

1. Vérifiez les logs: `./run-presentation.sh logs`
2. Vérifiez le statut: `./run-presentation.sh status`
3. Essayez de reconstruire: `./run-presentation.sh rebuild`
4. Consultez la documentation Marp: https://marp.app/

## 📄 Licence

Ce matériel pédagogique est fourni à des fins éducatives.

---

**Bon cours !** 🎉

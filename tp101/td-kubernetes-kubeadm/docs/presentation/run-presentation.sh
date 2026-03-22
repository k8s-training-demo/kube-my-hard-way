#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "  Kubernetes TD - Presentation Server"
echo "=========================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé!"
    echo "Veuillez installer Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker n'est pas démarré!"
    echo "Veuillez démarrer Docker et réessayer."
    exit 1
fi

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "❌ Docker Compose n'est pas installé!"
    echo "Veuillez installer Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

cd "$SCRIPT_DIR"

# Parse command line arguments
ACTION="${1:-start}"

case "$ACTION" in
    start|up)
        echo "🚀 Démarrage du serveur de présentation..."
        echo ""

        # Use docker compose (v2) or docker-compose (v1)
        if docker compose version &> /dev/null; then
            docker compose up -d --build
        else
            docker-compose up -d --build
        fi

        echo ""
        echo "✅ Serveur démarré!"
        echo ""
        echo "📊 Accédez aux slides sur:"
        echo "   👉 http://localhost:8080/slides-instructeur.md"
        echo ""
        echo "📝 Commandes utiles:"
        echo "   • Arrêter:     ./run-presentation.sh stop"
        echo "   • Redémarrer:  ./run-presentation.sh restart"
        echo "   • Logs:        ./run-presentation.sh logs"
        echo "   • Statut:      ./run-presentation.sh status"
        echo ""
        ;;

    stop|down)
        echo "🛑 Arrêt du serveur de présentation..."
        if docker compose version &> /dev/null; then
            docker compose down
        else
            docker-compose down
        fi
        echo "✅ Serveur arrêté!"
        ;;

    restart)
        echo "🔄 Redémarrage du serveur..."
        if docker compose version &> /dev/null; then
            docker compose restart
        else
            docker-compose restart
        fi
        echo "✅ Serveur redémarré!"
        echo "📊 http://localhost:8080/slides-instructeur.md"
        ;;

    logs)
        echo "📋 Affichage des logs (Ctrl+C pour quitter)..."
        echo ""
        if docker compose version &> /dev/null; then
            docker compose logs -f
        else
            docker-compose logs -f
        fi
        ;;

    status)
        echo "📊 Statut du conteneur:"
        echo ""
        docker ps -a --filter name=kubernetes-slides --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        ;;

    recreate)
        echo "♻️  Recréation du conteneur (slides à jour)..."
        if docker compose version &> /dev/null; then
            docker compose down
            docker compose up -d
        else
            docker-compose down
            docker-compose up -d
        fi
        echo "✅ Conteneur recréé!"
        echo "📊 http://localhost:8080/slides-instructeur.md"
        ;;

    rebuild)
        echo "🔨 Reconstruction de l'image et du conteneur..."
        if docker compose version &> /dev/null; then
            docker compose down
            docker compose build --no-cache
            docker compose up -d
        else
            docker-compose down
            docker-compose build --no-cache
            docker-compose up -d
        fi
        echo "✅ Conteneur reconstruit et démarré!"
        echo "📊 http://localhost:8080/slides-instructeur.md"
        ;;

    export-pdf)
        echo "📄 Export des slides en PDF..."
        if docker compose version &> /dev/null; then
            docker compose run --rm marp-server marp ../slides-instructeur.md --pdf --output ../slides-instructeur.pdf
        else
            docker-compose run --rm marp-server marp ../slides-instructeur.md --pdf --output ../slides-instructeur.pdf
        fi
        echo "✅ PDF généré: docs/slides-instructeur.pdf"
        ;;

    export-html)
        echo "📄 Export des slides en HTML..."
        if docker compose version &> /dev/null; then
            docker compose run --rm marp-server marp ../slides-instructeur.md --html --output ../slides-instructeur.html
        else
            docker-compose run --rm marp-server marp ../slides-instructeur.md --html --output ../slides-instructeur.html
        fi
        echo "✅ HTML généré: docs/slides-instructeur.html"
        ;;

    export-pptx)
        echo "📄 Export des slides en PPTX..."
        if docker compose version &> /dev/null; then
            docker compose run --rm marp-server marp ../slides-instructeur.md --pptx --output ../slides-instructeur.pptx
        else
            docker-compose run --rm marp-server marp ../slides-instructeur.md --pptx --output ../slides-instructeur.pptx
        fi
        echo "✅ PPTX généré: docs/slides-instructeur.pptx"
        ;;

    help|--help|-h)
        echo "Usage: ./run-presentation.sh [COMMAND]"
        echo ""
        echo "Commandes disponibles:"
        echo "  start, up        Démarrer le serveur de présentation (défaut)"
        echo "  stop, down       Arrêter le serveur"
        echo "  restart          Redémarrer le serveur (process, rapide)"
        echo "  recreate         Recréer le conteneur sans rebuild (slides pas à jour)"
        echo "  logs             Afficher les logs en temps réel"
        echo "  status           Afficher le statut du conteneur"
        echo "  rebuild          Reconstruire l'image Docker complète (lent)"
        echo "  export-pdf       Exporter les slides en PDF"
        echo "  export-html      Exporter les slides en HTML"
        echo "  export-pptx      Exporter les slides en PPTX"
        echo "  help             Afficher cette aide"
        echo ""
        ;;

    *)
        echo "❌ Commande inconnue: $ACTION"
        echo "Utilisez './run-presentation.sh help' pour voir les commandes disponibles"
        exit 1
        ;;
esac

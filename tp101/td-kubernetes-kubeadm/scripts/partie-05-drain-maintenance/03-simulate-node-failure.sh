#!/bin/bash
# Partie 5 - Simulation de panne de nœud et récupération
# À exécuter sur le nœud MASTER

set -e

echo "=== Simulation de panne de nœud ==="
echo ""

echo "1. Déploiement d'une application de test:"
kubectl create deployment app-resilience --image=nginx:alpine --replicas=6

echo ""
echo "   Attente du déploiement..."
kubectl wait --for=condition=available deployment/app-resilience --timeout=60s

echo ""
echo "2. Distribution des pods sur les nœuds:"
kubectl get pods -l app=app-resilience -o wide
echo ""
read -rp "   ↵  Notez la distribution des pods sur les nœuds. Appuyez sur Entrée..."

echo ""
echo "3. Sélection d'un worker pour simuler la panne:"
WORKER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' | head -1)
echo "   Nœud cible: $WORKER_NODE"

echo ""
echo "4. Nombre de pods sur ce nœud:"
PODS_ON_NODE=$(kubectl get pods -l app=app-resilience -o wide --field-selector spec.nodeName=$WORKER_NODE --no-headers | wc -l)
echo "   Pods sur $WORKER_NODE: $PODS_ON_NODE"

echo ""
echo "5. Simulation de la panne (arrêt de kubelet sur le worker):"
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ⚠️  ACTION REQUISE SUR LE NŒUD WORKER — PAS SUR LE MASTER  ⚠️  ║"
echo "║                                                                  ║"
echo "║  Connectez-vous sur $WORKER_NODE et exécutez :              ║"
echo "║                                                                  ║"
echo "║      sudo systemctl stop kubelet                                 ║"
echo "║                                                                  ║"
echo "║  Ne lancez PAS cette commande ici (master) !                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
read -p "Appuyez sur Entrée après avoir arrêté kubelet sur $WORKER_NODE..."

echo ""
echo "6. Observation du nœud (devient NotReady après ~40s) :"
for i in {1..5}; do
    echo "   Tentative $i/5 :"
    kubectl get nodes
    sleep 10
done
echo ""
read -rp "   ↵  Le nœud est NotReady. Les pods sont encore 'Running' — l'API ne sait pas encore. Appuyez sur Entrée..."

echo ""
echo "7. État des pods après la panne:"
kubectl get pods -l app=app-resilience -o wide
echo "   Note: Les pods sur le nœud en panne passent en 'Unknown' puis 'Terminating'"
echo ""
read -rp "   ↵  Observez le statut Unknown/Terminating. Appuyez sur Entrée pour attendre l'éviction..."

echo ""
echo "8. Après ~5 minutes, Kubernetes évince les pods et les recrée sur les nœuds sains..."
echo "   Attente de 1 minute pour observer le début de la transition..."
sleep 60

kubectl get pods -l app=app-resilience -o wide
echo ""
read -rp "   ↵  De nouveaux pods ont été créés sur les nœuds sains. Appuyez sur Entrée..."

echo ""
echo "9. Récupération: Redémarrage de kubelet sur le worker"
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ⚠️  ACTION REQUISE SUR LE NŒUD WORKER — PAS SUR LE MASTER  ⚠️  ║"
echo "║                                                                  ║"
echo "║  Connectez-vous sur $WORKER_NODE et exécutez :              ║"
echo "║                                                                  ║"
echo "║      sudo systemctl start kubelet                                ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
read -p "Appuyez sur Entrée après avoir redémarré kubelet sur $WORKER_NODE..."

echo ""
echo "10. Observation de la récupération du nœud:"
for i in {1..5}; do
    echo "   Tentative $i/5:"
    kubectl get nodes
    sleep 10
done
echo ""
read -rp "   ↵  Le nœud est de nouveau Ready. Les anciens pods reviennent-ils ? Appuyez sur Entrée..."

echo ""
echo "11. État final des pods:"
kubectl get pods -l app=app-resilience -o wide
echo ""
read -rp "   ↵  Les pods ne reviennent PAS sur worker1 — ils ont été remplacés définitivement. Appuyez sur Entrée..."

echo ""
echo "Nettoyage..."
kubectl delete deployment app-resilience

echo ""
echo "✓ Simulation de panne terminée!"
echo ""
echo "OBSERVATIONS CLÉS:"
echo "- Kubernetes détecte les nœuds NotReady après ~40s (node-monitor-grace-period)"
echo "- Les pods sont marqués Terminating après ~5min (pod-eviction-timeout)"
echo "- Les nouveaux pods sont automatiquement créés sur des nœuds sains"
echo "- La résilience dépend de la haute disponibilité (replicas > 1)"
echo ""
echo "ALTERNATIVES pour une panne planifiée:"
echo "- Utiliser 'kubectl drain' pour évacuer proprement les pods AVANT la maintenance"
echo "- Utiliser 'kubectl cordon' pour empêcher de nouveaux pods (sans évacuer les existants)"

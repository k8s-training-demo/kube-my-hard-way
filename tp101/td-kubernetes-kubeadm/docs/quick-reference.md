# Quick Reference - Commandes Kubernetes

Guide de référence rapide pour les commandes utilisées pendant le TD.

## Commandes kubectl essentielles

### Gestion des nœuds

```bash
# Lister les nœuds
kubectl get nodes
kubectl get nodes -o wide

# Détails d'un nœud
kubectl describe node <node-name>

# Taints sur un nœud
kubectl describe node <node-name> | grep Taints

# Cordoner un nœud (empêcher scheduling)
kubectl cordon <node-name>

# Décordoner un nœud
kubectl uncordon <node-name>

# Drainer un nœud (évacuer les pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

### Gestion des pods

```bash
# Lister les pods
kubectl get pods
kubectl get pods -o wide
kubectl get pods --all-namespaces
kubectl get pods -n <namespace>

# Détails d'un pod
kubectl describe pod <pod-name>
kubectl describe pod <pod-name> -n <namespace>

# Logs d'un pod
kubectl logs <pod-name>
kubectl logs <pod-name> -f  # Follow
kubectl logs <pod-name> --previous  # Container précédent
kubectl logs <pod-name> -c <container-name>  # Container spécifique

# Exécuter une commande dans un pod
kubectl exec <pod-name> -- <command>
kubectl exec <pod-name> -it -- sh  # Shell interactif

# Supprimer un pod
kubectl delete pod <pod-name>
kubectl delete pod <pod-name> --force --grace-period=0  # Force
```

### Déploiements et services

```bash
# Créer un déploiement
kubectl create deployment <name> --image=<image>

# Scaler un déploiement
kubectl scale deployment <name> --replicas=<n>

# Exposer un déploiement
kubectl expose deployment <name> --port=<port> --type=<ClusterIP|NodePort|LoadBalancer>

# Lister les déploiements
kubectl get deployments
kubectl get deploy -o wide

# Lister les services
kubectl get services
kubectl get svc -o wide
```

### Informations système

```bash
# Version du cluster
kubectl version --short

# Info du cluster
kubectl cluster-info

# Composants du control plane
kubectl get componentstatuses  # Déprécié
kubectl get --raw='/readyz?verbose'  # Nouveau

# Événements
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Ressources du cluster
kubectl top nodes  # Nécessite metrics-server
kubectl top pods --all-namespaces
```

### Manifests YAML

```bash
# Appliquer un manifest
kubectl apply -f <file.yaml>
kubectl apply -f <directory>/

# Créer depuis un manifest
kubectl create -f <file.yaml>

# Supprimer depuis un manifest
kubectl delete -f <file.yaml>

# Voir la définition d'une ressource
kubectl get pod <name> -o yaml
kubectl get pod <name> -o json
```

### Namespaces

```bash
# Lister les namespaces
kubectl get namespaces
kubectl get ns

# Créer un namespace
kubectl create namespace <name>

# Supprimer un namespace
kubectl delete namespace <name>

# Utiliser un namespace par défaut
kubectl config set-context --current --namespace=<name>
```

### Debugging

```bash
# Describe (détails + événements)
kubectl describe <resource> <name>

# Logs
kubectl logs <pod-name> --tail=50
kubectl logs <pod-name> --since=1h

# Pod de debug
kubectl run debug --image=busybox --rm -it -- sh
kubectl run debug --image=nicolaka/netshoot --rm -it -- bash

# Port-forward
kubectl port-forward <pod-name> <local-port>:<pod-port>

# Copier des fichiers
kubectl cp <pod-name>:<path> <local-path>
kubectl cp <local-path> <pod-name>:<path>
```

## Commandes kubeadm

### Installation et initialisation

```bash
# Initialiser le control plane
sudo kubeadm init --pod-network-cidr=<cidr> --apiserver-advertise-address=<ip>

# Générer la commande de jonction
kubeadm token create --print-join-command

# Joindre un worker
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Reset du nœud
sudo kubeadm reset
```

### Gestion des tokens

```bash
# Lister les tokens
kubeadm token list

# Créer un nouveau token
kubeadm token create
kubeadm token create --ttl 24h

# Supprimer un token
kubeadm token delete <token>
```

### Upgrade

```bash
# Voir le plan d'upgrade
sudo kubeadm upgrade plan

# Appliquer l'upgrade (sur le master)
sudo kubeadm upgrade apply v<version>

# Upgrade de la config node (sur les workers)
sudo kubeadm upgrade node
```

### Certificats

```bash
# Vérifier l'expiration des certificats
kubeadm certs check-expiration

# Renouveler tous les certificats
sudo kubeadm certs renew all

# Renouveler un certificat spécifique
sudo kubeadm certs renew apiserver
```

## Commandes système (kubelet)

```bash
# Status de kubelet
sudo systemctl status kubelet

# Démarrer/Arrêter kubelet
sudo systemctl start kubelet
sudo systemctl stop kubelet
sudo systemctl restart kubelet

# Activer kubelet au démarrage
sudo systemctl enable kubelet

# Logs de kubelet
sudo journalctl -u kubelet
sudo journalctl -u kubelet -f  # Follow
sudo journalctl -u kubelet -n 100  # 100 dernières lignes
sudo journalctl -u kubelet --since "5 min ago"

# Configuration kubelet
sudo cat /var/lib/kubelet/config.yaml

# Recharger la configuration systemd
sudo systemctl daemon-reload
```

## Commandes réseau

### Vérifications générales

```bash
# Interfaces réseau
ip addr show
ip link show

# Routes
ip route
ip route show

# Tables de routage
route -n

# Règles iptables
sudo iptables -L -n -v
sudo iptables -t nat -L -n -v

# Connectivité
ping <ip>
traceroute <ip>
telnet <ip> <port>
nc -zv <ip> <port>
```

### CNI spécifique

```bash
# Flannel
kubectl get pods -n kube-flannel
kubectl logs -n kube-flannel <pod-name>
ip addr show flannel.1

# Calico
kubectl get pods -n kube-system -l k8s-app=calico-node
kubectl logs -n kube-system <calico-node-pod>
kubectl exec -n kube-system <calico-node-pod> -- calicoctl node status
```

### Test de connectivité

```bash
# DNS depuis un pod
kubectl run test --image=busybox --rm -it -- nslookup kubernetes.default

# Ping depuis un pod
kubectl run test --image=busybox --rm -it -- ping 8.8.8.8

# Curl depuis un pod
kubectl run test --image=curlimages/curl --rm -it -- curl http://<service-ip>

# Test complet avec netshoot
kubectl run netshoot --image=nicolaka/netshoot --rm -it -- bash
# Dans le pod:
# - nslookup kubernetes.default
# - ping <pod-ip>
# - curl http://<service-ip>
# - traceroute <ip>
```

## Commandes dnf (paquets Kubernetes) - CentOS 10

```bash
# Mettre à jour la liste des paquets
sudo dnf check-update

# Installer un paquet
sudo dnf install -y <package> --disableexcludes=kubernetes

# Installer une version spécifique
sudo dnf install -y kubeadm-1.34.0 --disableexcludes=kubernetes

# Voir les versions disponibles
dnf list --showduplicates kubeadm
dnf list --showduplicates kubelet
dnf list --showduplicates kubectl

# Verrouiller une version (empêcher upgrade automatique)
# D'abord installer le plugin versionlock si nécessaire
sudo dnf install -y 'dnf-command(versionlock)'
sudo dnf versionlock add kubeadm kubelet kubectl

# Voir les paquets verrouillés
sudo dnf versionlock list

# Déverrouiller
sudo dnf versionlock delete kubeadm kubelet kubectl
```

## Commandes containerd

```bash
# Status de containerd
sudo systemctl status containerd

# Redémarrer containerd
sudo systemctl restart containerd

# Configuration containerd
sudo cat /etc/containerd/config.toml

# Lister les conteneurs (avec crictl)
sudo crictl ps
sudo crictl ps -a

# Lister les images
sudo crictl images

# Logs d'un conteneur
sudo crictl logs <container-id>
```

## Patterns utiles

### Filtrage et formatage

```bash
# Sélection par label
kubectl get pods -l app=nginx
kubectl get pods -l 'environment in (production, staging)'

# Sélection par field
kubectl get pods --field-selector status.phase=Running
kubectl get pods --field-selector spec.nodeName=worker1

# Colonnes personnalisées
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Format JSON avec jq
kubectl get nodes -o json | jq '.items[].metadata.name'
kubectl get nodes -o json | jq -r '.items[] | "\(.metadata.name): \(.status.conditions[-1].type)"'

# Tri
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get events --sort-by=.lastTimestamp
```

### Boucles bash utiles

```bash
# Exécuter une commande sur tous les nœuds
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $node ==="
  kubectl describe node $node | grep -A 5 "Taints:"
done

# Vérifier tous les pods d'un namespace
for pod in $(kubectl get pods -n kube-system -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $pod ==="
  kubectl get pod $pod -n kube-system -o jsonpath='{.status.phase}'
  echo ""
done

# Drainer tous les workers
for node in $(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name'); do
  kubectl drain $node --ignore-daemonsets --delete-emptydir-data
done
```

### Watches et monitoring

```bash
# Watch continu
kubectl get pods --watch
kubectl get pods -w

# Watch avec interval personnalisé
watch -n 1 kubectl get pods

# Suivre les événements
kubectl get events -w

# Suivre les logs de plusieurs pods
kubectl logs -l app=nginx -f --max-log-requests=10
```

## Raccourcis et alias

```bash
# Alias recommandés (à ajouter dans ~/.bashrc)
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kgs='kubectl get svc'
alias kd='kubectl describe'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kdel='kubectl delete'

# Avec completion
source <(kubectl completion bash)
complete -F __start_kubectl k
```

## Variables d'environnement utiles

```bash
# Namespace par défaut pour kubectl
export NAMESPACE=<namespace>

# Kubeconfig
export KUBECONFIG=$HOME/.kube/config

# Editor pour kubectl edit
export KUBE_EDITOR=vim
```

## Snippets YAML courants

### Pod simple

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
  - name: container
    image: nginx:alpine
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: container
        image: nginx:alpine
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myservice
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### Toleration

```yaml
tolerations:
- key: "key"
  operator: "Equal"
  value: "value"
  effect: "NoSchedule"
```

### PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: mypdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

---

**Tip:** Bookmark cette page dans votre navigateur ou imprimez-la pour l'avoir sous la main pendant le TD !

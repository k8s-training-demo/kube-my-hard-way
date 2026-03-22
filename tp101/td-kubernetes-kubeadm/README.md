# TD Kubernetes avec kubeadm

Matériel complet de TD pour l'installation, la configuration et la maintenance d'un cluster Kubernetes avec kubeadm.

## Vue d'ensemble

Ce TD pratique couvre l'ensemble du cycle de vie d'un cluster Kubernetes, de l'installation à la mise à jour, en passant par la configuration avancée et les opérations de maintenance.

**Durée:** 2h45
**Niveau:** Avancé
**Prérequis:** Notions de Docker, concepts Kubernetes de base

### Ce que vous allez apprendre

- Installation et configuration d'un cluster Kubernetes multi-nœuds avec kubeadm
- Configuration système (kubelet, static pods)
- Mécanismes de scheduling avancés (taints, tolerations)
- Migration de CNI (Container Network Interface)
- Opérations de maintenance (drain, cordon)
- Mise à jour d'un cluster en production

## Structure du projet

```
td-kubernetes-kubeadm/
├── scripts/
│   ├── partie1-installation/          # Installation du cluster de base
│   ├── partie2-kubelet-static-pods/   # Configuration kubelet et static pods
│   ├── partie3-taints-tolerations/    # Scheduling avec taints
│   ├── partie4-migration-cni/         # Migration Flannel → Calico
│   ├── partie5-drain-maintenance/     # Maintenance des nœuds
│   └── partie6-upgrade/               # Mise à jour du cluster
├── configs/
│   ├── kubelet/                       # Configurations kubelet
│   ├── static-pods/                   # Manifests de static pods
│   ├── network/                       # Configs réseau
│   └── workloads/                     # Applications de test
├── validation/
│   ├── validate-all.sh               # Validation complète du TD
│   └── validate-partie.sh            # Validation par partie
├── docs/
│   ├── exercices-etudiants.md        # Guide pour les étudiants
│   └── guide-instructeur.md          # Guide pour l'instructeur
└── README.md                          # Ce fichier
```

## Démarrage rapide

### Pour les étudiants

1. Clonez ce dépôt sur le nœud master :
   ```bash
   git clone <repo-url> td-kubernetes-kubeadm
   cd td-kubernetes-kubeadm
   ```

2. Suivez le guide des exercices :
   ```bash
   cat docs/exercices-etudiants.md
   # ou ouvrez dans un navigateur/éditeur markdown
   ```

3. Exécutez les scripts partie par partie selon les instructions

4. Validez chaque partie :
   ```bash
   cd validation
   ./validate-partie.sh <numero-partie>
   ```

### Pour les instructeurs

1. Lisez le guide instructeur complet :
   ```bash
   cat docs/guide-instructeur.md
   ```

2. Préparez l'infrastructure (voir section Infrastructure)

3. Testez l'intégralité du TD avant la session

4. Référez-vous au guide pendant le TD pour les points d'attention

## Infrastructure requise

### Matériel

**Option 1: Machines virtuelles locales**
```
Master:  2 CPU, 4 GB RAM, 20 GB disque
Worker1: 2 CPU, 2 GB RAM, 20 GB disque
Worker2: 2 CPU, 2 GB RAM, 20 GB disque
```

**Option 2: Cloud (AWS, GCP, Azure)**
```
Master:  t3.medium (AWS) ou équivalent
Workers: t3.small (AWS) ou équivalent
```

### Logiciel

- OS: CentOS Stream 10 (recommandé)
- Accès root ou sudo
- Connexion Internet (pour téléchargement des images)
- Connectivité réseau entre tous les nœuds

### Versions Kubernetes

Ce TD est testé avec :
- Kubernetes 1.28.x (installation initiale)
- Upgrade vers 1.29.x (partie 6)

Ajustez les versions dans les scripts selon vos besoins.

## Contenu détaillé du TD

### Partie 1 - Installation du cluster (35 min)

- Installation de containerd, kubeadm, kubelet, kubectl
- Initialisation du control plane
- Jonction des workers au cluster
- Installation du CNI Flannel
- Vérification complète du cluster

**Scripts:**
- `01-prereqs.sh` - Prérequis sur tous les nœuds
- `02-init-control-plane.sh` - Initialisation du master
- `03-join-workers.sh` - Jonction des workers
- `04-install-flannel.sh` - Installation du CNI
- `05-verify-cluster.sh` - Vérification

### Partie 2 - Configuration kubelet et static pods (30 min)

- Anatomie de la configuration kubelet
- Modification des paramètres kubelet
- Création d'un static pod de monitoring
- Comportement spécifique des static pods

**Scripts:**
- `01-modify-kubelet-config.sh` - Modification config
- `02-deploy-static-pod.sh` - Déploiement static pod
- `03-test-static-pod-behavior.sh` - Tests de comportement

**Fichiers de config:**
- `configs/kubelet/kubelet-config-custom.yaml`
- `configs/static-pods/disk-monitor.yaml`

### Partie 3 - Taints, tolerations et scheduling (20 min)

- Exploration des taints par défaut du master
- Ajout de taints personnalisés
- Tolerations dans les pods
- Observation du comportement de scheduling

**Scripts:**
- `01-explore-default-taints.sh` - Exploration
- `02-add-custom-taints.sh` - Ajout de taints
- `03-observe-scheduling.sh` - Tests de scheduling

**Manifests de test:**
- `configs/workloads/pod-no-toleration.yaml`
- `configs/workloads/pod-with-toleration.yaml`
- `configs/workloads/pod-tolerate-all.yaml`

### Partie 4 - Migration CNI: Flannel vers Calico (25 min)

- Sauvegarde de l'état du cluster
- Drain progressif des nœuds
- Suppression propre de Flannel
- Installation de Calico
- Validation de la connectivité réseau

**Scripts:**
- `01-backup-cluster-state.sh` - Backup
- `02-drain-nodes.sh` - Drain des workers
- `03-remove-flannel.sh` - Suppression Flannel
- `04-install-calico.sh` - Installation Calico
- `05-uncordon-and-validate.sh` - Remise en service et tests

### Partie 5 - Drain et maintenance de nœuds (20 min)

- Drain avec PodDisruptionBudget
- Gestion des DaemonSets lors du drain
- Simulation de panne de nœud et récupération

**Scripts:**
- `01-drain-with-pdb.sh` - Test avec PDB
- `02-drain-with-daemonsets.sh` - Test avec DaemonSets
- `03-simulate-node-failure.sh` - Simulation de panne

**Manifests:**
- `configs/workloads/deployment-with-pdb.yaml`
- `configs/workloads/test-daemonset.yaml`

### Partie 6 - Mise à jour du cluster (25 min)

- Vérification des versions actuelles
- Upgrade du control plane
- Upgrade kubelet/kubectl sur le master
- Upgrade des workers (un par un)
- Validation post-upgrade

**Scripts:**
- `01-check-versions.sh` - Vérification versions
- `02-upgrade-control-plane.sh` - Upgrade control plane
- `03-upgrade-master-kubelet.sh` - Upgrade master kubelet
- `04-upgrade-worker.sh` - Upgrade workers (multi-étapes)
- `05-validate-upgrade.sh` - Validation complète

## Validation

### Validation par partie

Après chaque partie, validez votre travail :

```bash
cd validation
./validate-partie.sh <numero-partie>
```

Exemples :
```bash
./validate-partie.sh 1  # Valider l'installation du cluster
./validate-partie.sh 4  # Valider la migration CNI
```

### Validation complète

À la fin du TD, exécutez la validation complète :

```bash
./validate-all.sh
```

Ce script vérifie :
- État de tous les nœuds
- Fonctionnement du CNI
- Connectivité réseau
- DNS
- Versions après upgrade

## Troubleshooting

### Cluster ne démarre pas

```bash
# Vérifier kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 100

# Vérifier les certificats
sudo ls -la /etc/kubernetes/pki/

# Vérifier la connectivité
ping <master-ip>
curl -k https://<master-ip>:6443
```

### Problèmes réseau

```bash
# Vérifier le CNI
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel  # ou kube-system pour Calico

# Tester la connectivité
kubectl run test --image=busybox --rm -it -- ping 8.8.8.8

# Vérifier DNS
kubectl run test --image=busybox --rm -it -- nslookup kubernetes.default
```

### Worker ne rejoint pas le cluster

```bash
# Régénérer le token de jonction
kubeadm token create --print-join-command

# Vérifier les logs du join
sudo journalctl -u kubelet -f

# Reset et réessayer
sudo kubeadm reset
# Puis rejoindre à nouveau
```

### Pods ne démarrent pas

```bash
# Voir les événements
kubectl describe pod <pod-name>
kubectl get events --sort-by='.lastTimestamp'

# Vérifier les ressources
kubectl describe node <node-name>
kubectl top nodes  # Nécessite metrics-server
```

## FAQ

### Puis-je utiliser une autre distribution Linux ?

Oui, mais les scripts sont optimisés pour CentOS Stream 10 / RHEL 9+. Pour Ubuntu/Debian, adaptez :
- `dnf` → `apt-get`
- `dnf versionlock` → `apt-mark hold`
- `firewall-cmd` → `ufw` ou `iptables`
- Chemins de configuration potentiellement différents

### Puis-je sauter des parties ?

Oui et non :
- Parties 1 et 2 sont obligatoires (base du cluster)
- Partie 3 peut être rapidement parcourue si temps limité
- Partie 4 (migration CNI) peut être skippée si vous restez sur Flannel
- Parties 5 et 6 sont indépendantes l'une de l'autre

### Combien de temps pour refaire le TD ?

- Première fois (apprentissage) : 2h45 - 3h30
- Avec expérience : 1h30 - 2h
- Pour démo rapide : 45min (parties 1, 2 et shortcuts)

### Peut-on faire le TD avec 2 nœuds seulement (1 master + 1 worker) ?

Oui, mais certains aspects (distribution des pods, drain) seront moins visibles. Le minimum est 1 master + 1 worker.

### Comment réinitialiser complètement le cluster ?

Sur chaque nœud :
```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube/config
sudo rm -rf /etc/kubernetes/
```

Puis recommencez à la Partie 1.

## Ressources additionnelles

### Documentation officielle

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [kubelet Configuration](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)
- [CNI Specification](https://github.com/containernetworking/cni)

### CNI

- [Flannel](https://github.com/flannel-io/flannel)
- [Calico](https://docs.tigera.io/calico/latest/about/)
- [Comparison of CNI plugins](https://www.cncf.io/blog/2020/02/13/a-comparison-of-kubernetes-cni-providers-flannel-calico-canal-and-weave/)

### Certification

Ce TD couvre plusieurs topics du [Certified Kubernetes Administrator (CKA)](https://www.cncf.io/certification/cka/) :
- Cluster Architecture, Installation & Configuration (25%)
- Workloads & Scheduling (15%)
- Services & Networking (20%)

### Outils recommandés

- [k9s](https://k9scli.io/) - Interface terminal interactive pour Kubernetes
- [kubectx/kubens](https://github.com/ahmetb/kubectx) - Switch rapide de contexte
- [stern](https://github.com/stern/stern) - Multi-pod logs
- [kube-ps1](https://github.com/jonmosco/kube-ps1) - Contexte k8s dans le prompt

## Contribution

### Reporter un problème

Si vous trouvez un bug ou avez une suggestion :
1. Vérifiez qu'il n'existe pas déjà dans les issues
2. Créez une issue avec un titre descriptif
3. Incluez les détails de votre environnement

### Proposer une amélioration

Les pull requests sont bienvenues ! Assurez-vous de :
1. Tester vos modifications sur un cluster propre
2. Mettre à jour la documentation si nécessaire
3. Suivre le style des scripts existants

## Licence

Ce matériel pédagogique est fourni à des fins éducatives.

## Auteur

Créé pour le cours de Kubernetes avancé.

## Remerciements

- La communauté Kubernetes pour l'excellente documentation
- Les mainteneurs de Flannel et Calico
- Tous les contributeurs qui ont testé et amélioré ce TD

---

Pour commencer le TD, consultez [`docs/exercices-etudiants.md`](docs/exercices-etudiants.md)

Pour l'enseigner, consultez [`docs/guide-instructeur.md`](docs/guide-instructeur.md)

**Bon TD !**

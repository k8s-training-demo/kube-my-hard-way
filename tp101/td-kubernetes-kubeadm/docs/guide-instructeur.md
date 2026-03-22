# Guide Instructeur - TD Kubernetes avec kubeadm

**Durée totale:** 2h45 (compressible à 2h30 avec étudiants autonomes)
**Niveau:** Avancé
**Prérequis étudiants:** Notions de Docker, concepts Kubernetes de base

---

## Vue d'ensemble du TD

Ce TD couvre l'installation complète et la maintenance d'un cluster Kubernetes en utilisant kubeadm. Il est conçu pour être pratique et proche des situations réelles de production.

### Objectifs pédagogiques

1. **Compréhension de l'architecture** Kubernetes (control plane, workers, CNI)
2. **Maîtrise de kubeadm** pour les opérations d'administration
3. **Configuration système** (kubelet, static pods)
4. **Mécanismes de scheduling** (taints, tolerations)
5. **Opérations réseau** (CNI, migration)
6. **Maintenance en production** (drain, upgrade)

### Points forts du TD

- Scripts automatisés mais commentés pour la compréhension
- Validation à chaque étape
- Situations réalistes (migration CNI, panne de nœud)
- Balance entre théorie et pratique

---

## Préparation du TD

### Infrastructure requise

#### Option 1: Machines virtuelles locales (VirtualBox, VMware)
```
Master:  2 CPU, 4 GB RAM, 20 GB disque
Worker1: 2 CPU, 2 GB RAM, 20 GB disque
Worker2: 2 CPU, 2 GB RAM, 20 GB disque

OS: CentOS Stream 10
```

#### Option 2: Cloud (AWS, GCP, Azure)
```
Master:  t3.medium ou équivalent
Workers: t3.small ou équivalent
```

#### Option 3: Vagrant (pour déploiement rapide)
Fournissez un Vagrantfile prêt à l'emploi.

#### Option 4: Exoscale (utilisé en cours à Montpellier)

```
Instance type : standard.medium (2 vCPU / 4 GB RAM)
Zone          : de-fra-1
Template      : Linux CentOS Stream 10 64-bit
```

Scripts de provisioning dans `infra-exo/`. **Ordre à respecter impérativement :**

```bash
# 1. Créer le security group avec les bonnes règles
cd infra-exo
./setup-sg.sh

# 2. Provisionner les VMs (attache le SG automatiquement via .env)
./provision-class.sh
```

**Pourquoi cet ordre ?**
`provision-class.sh` attache le SG aux VMs mais ne le crée pas. Si le SG n'existe pas ou n'a pas les règles intra-groupe, les nœuds rejoignent le cluster mais restent `NotReady` : Flannel ne peut pas établir ses tunnels VXLAN (UDP 8472) entre les nœuds.

C'est un bon exemple pédagogique à montrer aux étudiants : les nœuds affichent `NotReady` juste après `kubeadm join` (avant l'installation du CNI), ce qui est **normal**. Si les nœuds restent `NotReady` après l'installation de Flannel, c'est le SG qui bloque.

**Règles requises dans le SG `tp-k8s` :**
| Protocole | Ports    | Source    | Usage                          |
|-----------|----------|-----------|--------------------------------|
| TCP       | 22       | 0.0.0.0/0 | SSH depuis l'extérieur         |
| TCP       | 1-65535  | tp-k8s    | Trafic Kubernetes inter-nœuds  |
| UDP       | 1-65535  | tp-k8s    | Flannel VXLAN (UDP 8472), etc. |

**Désactiver firewalld sur chaque nœud** (les règles Exoscale suffisent) :
```bash
systemctl stop firewalld && systemctl disable firewalld
```

### Distribution du matériel

Avant le TD, assurez-vous que les étudiants ont :
1. Accès SSH aux 3 machines
2. Le dossier `td-kubernetes-kubeadm` cloné sur le master
3. Connexion Internet fonctionnelle
4. Droits sudo sur toutes les machines

### Test préalable

Testez l'intégralité du TD 1-2 jours avant pour identifier d'éventuels problèmes :
- Versions des paquets disponibles
- Vitesse de téléchargement
- Problèmes réseau spécifiques

---

## Déroulement détaillé

### Introduction (5 min)

**Présentation:**
- Objectifs du TD
- Architecture finale
- Répartition temporelle
- Importance de la validation à chaque étape

**Points à souligner:**
- Kubernetes est un système distribué complexe
- L'ordre des opérations est crucial
- La sauvegarde est primordiale en production
- Les erreurs sont des opportunités d'apprentissage

---

## Partie 1 - Installation du cluster (35 min)

### Timeline suggérée
- Installation prérequis: 15 min
- Init control plane: 5 min
- Join workers: 5 min
- Install CNI: 5 min
- Vérification: 5 min

### Points d'attention

#### 1.1 Installation des prérequis

**Problèmes fréquents:**

1. **Swap non désactivé correctement**
   ```bash
   # Vérification
   free -h
   # Si swap actif, kubeadm refusera de démarrer
   ```

2. **Modules kernel non chargés**
   ```bash
   # Vérification
   lsmod | grep overlay
   lsmod | grep br_netfilter
   ```

3. **Problèmes de dépôts Kubernetes**
   ```bash
   # Si les dépôts ne répondent pas, utiliser un miroir local
   # ou préparer les .rpm en avance
   ```

**Questions attendues des étudiants:**

Q: "Pourquoi désactiver le swap ?"
R: Kubernetes nécessite un contrôle précis de la mémoire pour le scheduling. Le swap peut introduire des performances imprévisibles et compliquer l'accounting des ressources.

Q: "Quelle est la différence entre containerd et Docker ?"
R: containerd est le runtime de conteneurs, Docker est un ensemble d'outils incluant containerd. Kubernetes utilise directement containerd via CRI (Container Runtime Interface).

#### 1.2 Initialisation du control plane

**Point critique:** La commande `kubeadm join` affichée à la fin

**Solution de secours:**
```bash
# Si les étudiants perdent la commande
kubeadm token create --print-join-command

# Liste des tokens actifs
kubeadm token list
```

**Vérifications importantes:**
```bash
# Les pods du control plane doivent être Running
kubectl get pods -n kube-system

# Points à vérifier:
# - kube-apiserver
# - kube-controller-manager
# - kube-scheduler
# - etcd
```

#### 1.3 Jonction des workers

**Problème fréquent:** Erreur de connexion au master

```bash
# Vérifier la connectivité
ping <master-ip>

# Vérifier que l'API server est accessible
curl -k https://<master-ip>:6443

# Vérifier les certificats
sudo ls -la /etc/kubernetes/pki/
```

#### 1.4 Installation de Flannel

**Pourquoi Flannel en premier ?**
- Simple et rapide à installer
- Parfait pour l'apprentissage
- Permet de voir l'effet d'une migration CNI

**Vérifications:**
```bash
# Un pod flannel par nœud (DaemonSet)
kubectl get pods -n kube-flannel -o wide

# Interfaces réseau créées
ip addr show flannel.1
```

#### 1.5 Validation

**Temps de stabilisation:** 2-3 minutes après installation CNI

Si des étudiants sont bloqués, utilisez:
```bash
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

---

## Partie 2 - Configuration Kubelet et Static Pods (30 min)

### Timeline suggérée
- Anatomie config: 5 min
- Modification: 10 min
- Static pod: 10 min
- Test comportement: 5 min

### Points d'attention

#### 2.1 Configuration kubelet

**Concepts clés à expliquer:**
- La kubelet est l'agent node-level
- Configuration en YAML (pas de CLI pour la plupart des paramètres)
- Rechargement nécessaire après modification

**Questions attendues:**

Q: "Quelle est la différence entre /var/lib/kubelet/config.yaml et les flags de kubelet ?"
R: Le fichier YAML contient la configuration structurée (préféré), les flags CLI sont pour des overrides rapides. Le fichier est plus maintenable.

#### 2.2 Static pods

**Démonstration recommandée:**

1. Montrer que le static pod apparaît dans kubectl mais avec un nom suffixé
2. Tenter de supprimer via kubectl → recréation immédiate
3. Supprimer le manifest → suppression effective

**Point pédagogique important:**
Les composants du control plane (apiserver, scheduler, etc.) sont des static pods ! C'est pourquoi le cluster peut démarrer avant même que kubectl fonctionne.

```bash
# Montrer les static pods du control plane
sudo ls -la /etc/kubernetes/manifests/
```

**Exercice bonus (si temps):**
Demander aux étudiants de créer leur propre static pod personnalisé.

---

## Partie 3 - Taints et Tolerations (20 min)

### Timeline suggérée
- Exploration: 5 min
- Ajout taints: 5 min
- Observation scheduling: 10 min

### Points d'attention

#### Concepts clés

**Taint effects:**
- `NoSchedule`: N'affecte pas les pods existants
- `PreferNoSchedule`: Soft constraint
- `NoExecute`: Éviction des pods existants

**Démonstration recommandée:**

Montrer la différence entre NoSchedule et NoExecute en direct:

```bash
# Déployer une app
kubectl create deployment demo --image=nginx --replicas=5

# Taint NoSchedule
kubectl taint nodes worker1 test=true:NoSchedule
# Les pods existants restent

# Taint NoExecute
kubectl taint nodes worker1 test=true:NoExecute
# Les pods sont immédiatement évacués
```

**Questions attendues:**

Q: "Pourquoi ne pas toujours utiliser NoExecute ?"
R: NoExecute est plus agressif et peut causer des interruptions de service. NoSchedule est suffisant pour la maintenance planifiée.

Q: "Comment fonctionne l'operator 'Exists' dans les tolerations ?"
R: C'est un wildcard qui tolère n'importe quelle valeur pour la clé spécifiée, ou toutes les clés si aucune n'est spécifiée.

---

## Partie 4 - Migration CNI (25 min)

### Timeline suggérée
- Backup: 3 min
- Drain: 5 min
- Suppression Flannel: 5 min
- Installation Calico: 7 min
- Validation: 5 min

### Points d'attention

**⚠️ PARTIE LA PLUS CRITIQUE DU TD**

Cette partie simule une opération de production complexe. Soyez particulièrement attentif.

#### 4.1 Pourquoi migrer ?

**Expliquez les différences Flannel vs Calico:**

| Feature | Flannel | Calico |
|---------|---------|--------|
| Complexité | Simple | Avancé |
| Network Policy | ❌ | ✅ |
| Routing | Overlay (VXLAN) | BGP + Overlay |
| Performance | Bonne | Excellente |
| Features | Basique | NetworkPolicy, encryption, etc. |

#### 4.2 Drain progressif

**Point pédagogique:** Pourquoi drainer ?
- Évacuation propre des pods
- Évite les interruptions de connexion
- Respecte les PDB

**Problème potentiel:** Drain bloqué par des pods sans controller

```bash
# Identifier les pods "orphelins"
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.ownerReferences == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Forcer si nécessaire (après vérification)
kubectl drain <node> --force --delete-emptydir-data
```

#### 4.3 Suppression de Flannel

**Points critiques:**

1. **Ne PAS redémarrer kubelet entre suppression Flannel et installation Calico**
   - Les pods perdront leur connectivité
   - Le nœud deviendra NotReady

2. **Nettoyage complet des interfaces**
   ```bash
   # Vérifier que flannel.1 est bien supprimé
   ip link show
   ```

3. **Nettoyage iptables**
   ```bash
   # Vérifier les règles
   sudo iptables -L -n -v
   sudo iptables -t nat -L -n -v
   ```

#### 4.4 Installation de Calico

**Point d'attention:** Le téléchargement peut prendre du temps

**Préparation recommandée:** Avoir les manifests en local

**Vérifications essentielles:**
```bash
# Tous les pods calico-node doivent être Running
kubectl get pods -n kube-system -l k8s-app=calico-node

# Vérifier les logs pour erreurs
kubectl logs -n kube-system -l k8s-app=calico-node --tail=50
```

#### 4.5 Validation

**Tests complets obligatoires:**
1. Connectivité inter-pods
2. DNS fonctionnel
3. Services fonctionnels
4. Connectivité externe

Si un test échoue, ne pas passer à la suite !

**Debug connectivité:**
```bash
# Vérifier les routes Calico
kubectl exec -n kube-system <calico-node-pod> -- ip route

# Vérifier les interfaces
kubectl exec -n kube-system <calico-node-pod> -- ip addr

# Vérifier BGP (si applicable)
kubectl exec -n kube-system <calico-node-pod> -- calicoctl node status
```

---

## Partie 5 - Drain et Maintenance (20 min)

### Timeline suggérée
- PDB: 7 min
- DaemonSets: 7 min
- Simulation panne: 6 min

### Points d'attention

#### 5.1 PodDisruptionBudget

**Concept clé:** Protection de la disponibilité

**Démonstration recommandée:**

1. Montrer un drain qui respecte le PDB (lent mais sûr)
2. Montrer un drain qui violerait le PDB (échec)

**Questions attendues:**

Q: "Que se passe-t-il si le PDB est trop restrictif ?"
R: Le drain peut échouer ou prendre très longtemps. Il faut équilibrer disponibilité et maintenabilité.

Q: "MinAvailable vs MaxUnavailable ?"
R: Deux façons d'exprimer la même contrainte. minAvailable=3 équivaut à maxUnavailable=replicas-3.

#### 5.2 DaemonSets

**Point pédagogique:** Les DaemonSets sont spéciaux

Expliquez pourquoi :
- CNI (Calico, Flannel) → Réseau node-level
- Monitoring (node-exporter) → Métriques par nœud
- Logging (fluentd) → Collecte locale des logs

**Démo:** Tentative de drain sans `--ignore-daemonsets`

#### 5.3 Simulation de panne

**⚠️ Attention:** Cette section est interactive

**Préparation:**
- Avoir un accès SSH séparé au worker
- Expliquer la procédure avant de commencer

**Points d'observation:**
1. Délai de détection (~40s)
2. Transition vers NotReady
3. Marquage des pods en Terminating (~5 min)
4. Recréation sur nœuds sains

**Question attendue:**

Q: "Comment réduire le délai de détection ?"
R: Configurer `node-monitor-grace-period` et `pod-eviction-timeout` dans kube-controller-manager. Attention : trop court = false positives.

---

## Partie 6 - Upgrade du Cluster (25 min)

### Timeline suggérée
- Check versions: 3 min
- Upgrade control plane: 7 min
- Upgrade master kubelet: 5 min
- Upgrade workers: 8 min (4 min × 2)
- Validation: 2 min

### Points d'attention

#### Concepts de version Kubernetes

**Expliquez la structure de version:** `v1.28.3`
- Major: Changements majeurs (rare)
- Minor: Features, API changes (tous les ~4 mois)
- Patch: Bugfixes, security patches

**Politique de support:** N, N-1, N-2

**Ordre d'upgrade obligatoire:**
1. etcd (si externe)
2. Control plane
3. Workers
4. Addons (CNI, etc.)

#### 6.2 Upgrade control plane

**Point critique:** `kubeadm upgrade plan`

Insistez pour que les étudiants lisent attentivement le plan !

**Informations dans le plan:**
- Versions actuelles
- Versions disponibles
- Composants à upgrader
- Commande exacte à exécuter

**Problème potentiel:** Version non disponible dans les dépôts

```bash
# Solution de secours - Lister les versions disponibles
dnf list --showduplicates kubeadm | head -20

# Choisir une version disponible
sudo dnf install -y kubeadm-1.35.0 --disableexcludes=kubernetes
```

#### 6.3 Upgrade kubelet

**Point pédagogique:** Pourquoi kubelet séparément ?

- Kubelet tourne sur chaque nœud
- Nécessite un redémarrage local
- Drain requis pour éviter les interruptions

#### 6.4 Upgrade workers

**Procédure par worker:** Drain → Upgrade → Uncordon

**Ordre recommandé:**
- Un worker à la fois
- Valider entre chaque worker

**Si temps limité:** Upgrader un seul worker en démo

**Exercice autonome:** Demander aux étudiants d'upgrader le second worker seuls

#### 6.5 Validation post-upgrade

**Checklist complète:**
```
✓ Tous les nœuds Ready
✓ Versions cohérentes
✓ Pods système Running
✓ Nouveau déploiement fonctionne
✓ DNS fonctionne
✓ Services fonctionnent
```

---

## Réponses aux Questions de Synthèse

### 1. Architecture du Control Plane

**Réponse attendue:**

- **API Server:** Point d'entrée unique, validation, authentification
- **Scheduler:** Placement des pods sur les nœuds
- **Controller Manager:** Boucles de contrôle (ReplicaSet, Node, etc.)
- **etcd:** Base de données distribuée, état du cluster

**Point bonus:** Communication via API server uniquement (sauf kubelet → API server)

### 2. CNI Overlay vs Avancé

**Réponse attendue:**

- **Overlay (Flannel):** Encapsulation VXLAN, simple, léger surcoût performance
- **BGP (Calico):** Routage natif, meilleures perfs, plus complexe
- **Hybride (Calico):** Peut faire les deux

### 3. Static Pods pour Control Plane

**Réponse attendue:**

- Bootstrap problem: kubelet peut démarrer avant l'API server
- Haute disponibilité: si API server crashe, kubelet le redémarre
- Simplicité: pas de dépendance à un orchestrateur externe

### 4. Taints pour GPU

**Réponse attendue:**

```bash
# Tainter les nœuds GPU
kubectl taint nodes gpu-node-1 gpu=true:NoSchedule

# Pods GPU avec toleration
tolerations:
- key: gpu
  operator: Equal
  value: "true"
  effect: NoSchedule

# + nodeSelector ou nodeAffinity pour forcer placement
```

### 5. Drain vs Cordon

**Réponse attendue:**

- **Cordon:** Empêche nouveaux pods, garde les existants
- **Drain:** Cordon + évacuation des pods existants

**Cas d'usage:**
- Cordon: Tests, observation
- Drain: Maintenance, upgrade

### 6. Ordre Upgrade

**Réponse attendue:**

- Rétrocompatibilité: kubelet N peut parler à API server N+1
- Mais API server N+1 peut utiliser features incompatibles avec kubelet N-2
- Donc: Control plane first

### 7. HA du Master

**Réponse attendue:**

**Limitations:**
- Single point of failure
- Pas de maintenance sans downtime
- Pas de scaling

**Solutions:**
- Multiple masters (3 ou 5)
- LoadBalancer devant API servers
- etcd cluster (3 ou 5 membres)
- HA proxy pour kubeconfig

---

## Troubleshooting Avancé

### Problèmes réseau persistants

```bash
# Check complet réseau
kubectl run debug --image=nicolaka/netshoot --rm -it -- bash

# Dans le pod:
# - DNS
nslookup kubernetes.default
# - Connectivité
ping <autre-pod-ip>
# - Routing
ip route
traceroute <service-ip>
```

### Problèmes de certificats

```bash
# Vérifier expiration
kubeadm certs check-expiration

# Renouveler
kubeadm certs renew all
sudo systemctl restart kubelet
```

### etcd corruption

```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save snapshot.db

# Restore
ETCDCTL_API=3 etcdctl snapshot restore snapshot.db
```

---

## Variantes et Extensions du TD

### Si les étudiants vont vite

1. **NetworkPolicy:** Ajouter des règles Calico
2. **Ingress:** Installer nginx-ingress
3. **Monitoring:** Installer Prometheus via Helm
4. **Multi-master:** Ajouter un second control plane

### Si les étudiants sont lents

1. **Combiner parties 5 et 6** (drain déjà pratiqué en partie 4)
2. **Skiper la migration CNI** (rester sur Flannel)
3. **Simplifier l'upgrade** (seulement control plane)

### Pour un TD plus long (4h)

1. Ajouter **Persistent Storage** (Local PV, NFS)
2. Ajouter **Helm** et déploiement d'apps complexes
3. Ajouter **Backup/Restore** complet (Velero)
4. Ajouter **RBAC** et sécurité avancée

---

## Checklist Instructeur

### Avant le TD

- [ ] Infrastructure prête et testée
- [ ] Tous les scripts fonctionnent
- [ ] Versions des paquets disponibles
- [ ] Backup de l'environnement de démo
- [ ] Support visuel préparé (schémas architecture)

### Pendant le TD

- [ ] Surveiller la progression générale
- [ ] Identifier les étudiants en difficulté
- [ ] Valider chaque partie avant de passer à la suivante
- [ ] Encourager les questions
- [ ] Partager l'écran pour les démonstrations

### Après le TD

- [ ] Collecter les feedbacks
- [ ] Noter les problèmes rencontrés
- [ ] Mettre à jour les scripts si nécessaire
- [ ] Préparer les corrections des questions de synthèse

---

## Ressources pour l'Instructeur

### Documentation de référence

- [kubeadm Documentation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [kubelet Configuration](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [CKA Exam Curriculum](https://github.com/cncf/curriculum) - Similitudes avec le TD

### Outils utiles

```bash
# k9s - Interface terminal interactive
brew install k9s  # ou dnf install k9s

# kubectx/kubens - Switch contexte rapidement
brew install kubectx

# stern - Logs multi-pods
brew install stern
```

### Scripts de démo supplémentaires

Préparez des démos visuelles :
- Scaling horizontal d'une app
- Rolling update
- Self-healing (kill de pods)
- Resource limits en action

---

## Annexe: Commandes Utiles

```bash
# === Debugging général ===
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
kubectl describe node <node-name>
kubectl top nodes  # Nécessite metrics-server

# === Logs ===
sudo journalctl -u kubelet -f
kubectl logs -n kube-system <pod> --previous  # Logs du container précédent

# === Réseau ===
kubectl get pods -o wide --all-namespaces
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ip route

# === Certificats ===
kubeadm certs check-expiration
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout

# === etcd ===
kubectl exec -n kube-system etcd-master -- etcdctl member list
kubectl exec -n kube-system etcd-master -- etcdctl endpoint health

# === Performance ===
kubectl top pods --all-namespaces
kubectl top nodes
```

---

**Bon TD et n'hésitez pas à adapter selon votre contexte !**

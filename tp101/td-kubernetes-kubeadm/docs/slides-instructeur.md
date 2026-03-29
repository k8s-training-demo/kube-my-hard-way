---
marp: true
theme: default
paginate: true
style: |
  section {
    font-size: 20px;
    padding: 30px 50px;
  }
  h1 {
    color: #326CE5;
    margin-bottom: 0.3em;
  }
  h2 {
    color: #326CE5;
    margin-bottom: 0.3em;
  }
  h3 {
    margin-bottom: 0.2em;
    margin-top: 0.4em;
  }
  p, ul, ol, pre, table {
    margin-top: 0.3em;
    margin-bottom: 0.3em;
  }
  li {
    margin-bottom: 0.1em;
  }
  pre {
    font-size: 0.85em;
  }
  /* Style pour slides avec diagramme pleine page */
  section.diagram {
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    padding-top: 40px;
  }
  section.diagram h2 {
    position: relative;
    z-index: 10;
    background: rgba(255,255,255,0.9);
    padding: 10px 20px;
    border-radius: 8px;
    margin-bottom: 0;
  }
  /* Style pour le menu de navigation */
  section.toc ul {
    columns: 2;
    font-size: 20px;
  }
  section.toc a {
    color: #326CE5;
    text-decoration: none;
  }
  section.toc a:hover {
    text-decoration: underline;
  }
---

<!-- _class: lead -->

# TD Kubernetes avec kubeadm
## Guide de formation pour instructeurs

**Durée:** 2h45 (compressible à 2h30)
**Niveau:** Avancé
**Prérequis:** Docker, concepts Kubernetes de base

---

## Vue d'ensemble du TD

### Objectifs pédagogiques

1. **Compréhension de l'architecture** Kubernetes
2. **Maîtrise de kubeadm** pour l'administration
3. **Configuration système** (kubelet, static pods)
4. **Mécanismes de scheduling** (taints, tolerations)
5. **Opérations réseau** (CNI, migration)
6. **Maintenance en production** (drain, upgrade)

---

## Points forts du TD

✅ Scripts automatisés mais commentés
✅ Validation à chaque étape
✅ Situations réalistes (migration CNI, panne de nœud)
✅ Balance entre théorie et pratique
✅ Proche des situations de production

---

## Infrastructure requise

### Option 1: VMs locales (VirtualBox, VMware)
```
Master:  2 CPU, 4 GB RAM, 20 GB disque
Worker1: 2 CPU, 2 GB RAM, 20 GB disque  — OS: CentOS Stream 10
Worker2: 2 CPU, 2 GB RAM, 20 GB disque
```

### Option 2: Cloud — VMs Exoscale (kubeadm manuel)
```
Zone: de-fra-1  |  Type: standard.large (2 vCPU / 8 GB)
Template: Linux CentOS Stream 10 64-bit
Réseau: public seul  OU  public + réseau privé Exoscale
```

### Option 3: SKS Exoscale (Kubernetes managé)
```
exo compute sks create tp-k8s --zone de-fra-1 \
  --version 1.30 --node-pools workers,2
```
→ Control plane géré par Exoscale, nœuds uniquement à configurer

---

## Préparation - Checklist avant le TD

- Infrastructure prête et testée
- Tous les scripts fonctionnent
- Versions des paquets disponibles
- Backup de l'environnement de démo
- Support visuel préparé
- Connexion Internet vérifiée
- Accès SSH pour tous les étudiants

---

<!-- _class: toc -->

## 🗺️ Plan du TD — ~5h30

<style scoped>table { font-size: 14px; } th, td { padding: 3px 10px; }</style>

| # | Contenu | ⏱️ | |
|---|---------|---:|---|
| [0](#7) | 👋 Introduction & Objectifs | 5 min | [→](#7) |
| [1](#9) | 🔧 Installation cluster kubeadm | 35 min | [→](#9) |
| [2](#44) | ⚙️ Kubelet & Static Pods | 30 min | [→](#44) |
| [3](#86) | 🏷️ Taints & Tolerations | 30 min | [→](#86) |
| [4](#115) | 🌐 Migration CNI | 25 min | [→](#115) |
| [5](#126) | 🔩 Drain & Maintenance | 20 min | [→](#126) |
| [6](#141) | 🗄️ etcd & etcdctl | 25 min | [→](#141) |
| [7](#149) | ⬆️ Upgrade cluster | 25 min | [→](#149) |
| [8](#158) | 🛡️ RuntimeClass & gVisor | 25 min | [→](#158) |
| [9](#173) | 📦 cgroups | 20 min | [→](#173) |
| [10](#183) | 🏗️ HA Control Plane — Théorie | 15 min | [→](#183) |
| [11](#187) | 🔀 Réseau public vs privé | 10 min | [→](#187) |
| [12](#198) | ☁️ SKS Exoscale | 15 min | [→](#198) |
| [13](#205) | 📊 Observabilité — kube-prometheus-stack | 30 min | [→](#205) |
| [★](#247) | 🏆 HA Control Plane *(bonus pratique)* | 30 min | [→](#247) |

---

# Partie 0
## Introduction (5 min)

---

## Points à souligner

- Kubernetes est un **système distribué complexe**
- L'**ordre des opérations est crucial**
- La **sauvegarde est primordiale** en production
- Les **erreurs sont des opportunités** d'apprentissage
- Valider à chaque étape avant de continuer

### Architecture finale

```
┌─────────────┐
│   Master    │ ← Control Plane
└─────────────┘
      │
  ┌───┴───┐
┌─▼─┐   ┌─▼─┐
│W1 │   │W2 │ ← Workers
└───┘   └───┘
```

---

<!-- _class: lead -->

# Partie 1
## Installation du cluster (35 min)

---

## Partie 1 - Timeline suggérée

- Installation prérequis: **15 min**
- Init control plane: **5 min**
- Join workers: **5 min**
- Install CNI: **5 min**
- Vérification: **5 min**

---

## 1.1 - Prérequis système

### 📝 EXERCICE ÉLÈVE
**Script à exécuter sur TOUS les nœuds:**
```bash
cd scripts/partie-01-installation

# Option explicite (recommandée si hostname générique)
./01-prereqs.sh --role master   # sur le control plane
./01-prereqs.sh --role worker   # sur les workers

# Autodetect via hostname (hostname contient "master" ou "control")
./01-prereqs.sh
```

> 💡 L'autodetect installe `kubectl` uniquement sur le master.

**Questions à poser:**
1. Pourquoi désactiver le swap ?
2. Rôle de containerd ?
3. Différence kubeadm/kubelet/kubectl ?

---

## 1.1 - Prérequis système (suite)

### Problèmes fréquents

**Swap non désactivé**
```bash
free -h  # Vérification
# Si swap actif, kubeadm refusera de démarrer
```

**Modules kernel non chargés**
```bash
lsmod | grep overlay
lsmod | grep br_netfilter
```

---

## 1.1b - Prérequis CentOS 10 détaillés

### Installation containerd sur CentOS 10

```bash
# 1. Ajouter le repo Docker (contient containerd)
sudo dnf config-manager --add-repo \
  https://download.docker.com/linux/centos/docker-ce.repo

# 2. Installer containerd
sudo dnf install -y containerd.io

# 3. Générer la configuration par défaut
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

---

## `containerd config default` — pas portable entre distros

### La commande inspecte l'environnement au moment de l'exécution

```bash
# Sur CentOS 10 (systemd, cgroup v2)
containerd config default | grep -E "SystemdCgroup|snapshotter"
#   SystemdCgroup = false       ← cgroupfs par défaut même sur systemd !
#   snapshotter = "overlayfs"

# Sur Alpine (OpenRC, cgroup v1 possible)
containerd config default | grep -E "SystemdCgroup|snapshotter"
#   SystemdCgroup = false       ← identique
#   snapshotter = "overlayfs"
```

### Ce qui change réellement selon la distro

| Paramètre | CentOS 10 | Alpine | Ubuntu 24.04 |
|-----------|-----------|--------|--------------|
| `SystemdCgroup` (défaut) | false | false | false |
| cgroup version hôte | **v2** | v1 ou v2 | **v2** |
| Init system | systemd | OpenRC | systemd |
| Ajustement requis | `true` | non | `true` |

> `config default` donne **les mêmes valeurs partout** — c'est la config universelle minimale, pas la config optimale pour ton OS

---

## Règle : toujours générer sur la cible finale

### Ne jamais copier une config.toml d'une autre machine

```
❌ À ne pas faire
──────────────────────────────────────────────────────
Copier config.toml depuis un tuto, une VM de test,
ou un autre OS → valeurs inadaptées, bugs silencieux

✅ Procédure correcte
──────────────────────────────────────────────────────
1. Installer containerd sur la machine CIBLE
2. containerd config default > /etc/containerd/config.toml
3. Ajuster SystemdCgroup selon l'init system de CETTE machine
4. Redémarrer containerd sur CETTE machine
```

### Pourquoi les bugs sont silencieux

- containerd démarre sans erreur avec une config incorrecte
- Les pods démarrent… jusqu'à la pression mémoire
- L'OOM killer se comporte différemment → crash imprévisibles
- `kubeadm init` peut passer → problèmes appraissent en production

> La config containerd est **locale** : générée sur place, ajustée sur place

---

## Configuration containerd - SystemdCgroup

### ⚠️ IMPORTANT: Activer SystemdCgroup

```bash
# Activer systemd cgroup driver (OBLIGATOIRE pour kubeadm)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

# Redémarrer containerd
sudo systemctl restart containerd
```

### Pourquoi SystemdCgroup = true ?

| Aspect | Explication |
|--------|-------------|
| **Cohérence** | CentOS 10 utilise systemd comme init. Le cgroup driver doit correspondre |
| **kubelet** | Par défaut, kubelet utilise systemd cgroup driver depuis K8s 1.22+ |
| **Stabilité** | Si containerd et kubelet utilisent des drivers différents → instabilité |
| **OOM Killer** | systemd gère mieux les limites mémoire et l'OOM killer |

---

## Configuration containerd - Explication détaillée

### Pourquoi cette configuration est critique ?

```
┌──────────────────────────────────────────────────────────┐
│                      SYSTEMD (PID 1)                      │
│                         ↓                                 │
│              Gestion des cgroups v2                       │
│                    ↓           ↓                          │
│            ┌───────┴───┐ ┌────┴────┐                     │
│            │  kubelet  │ │containerd│                     │
│            │ (systemd) │ │(systemd) │ ← Doivent utiliser  │
│            └───────────┘ └──────────┘   le même driver!   │
└──────────────────────────────────────────────────────────┘
```

**Si drivers différents:**
- Conflits de gestion mémoire
- Pods qui ne démarrent pas
- Métriques incorrectes
- Comportement OOM imprévisible

---

## Pourquoi cgroupfs par défaut ?

### containerd est agnostique de l'init system

```
┌─────────────────────────────────────────────────────────────────┐
│              Environnements cibles de containerd                │
├─────────────────────────────────────────────────────────────────┤
│   • Linux avec systemd (RHEL, Ubuntu, Debian modernes)          │
│   • Linux avec OpenRC (Alpine, Gentoo)                          │
│   • Linux avec runit (Void Linux)                               │
│   • Linux minimal sans init (Docker-in-Docker)                  │
│   • WSL2 (pas de vrai init)                                     │
│   • Embedded Linux                                              │
└─────────────────────────────────────────────────────────────────┘
```

**Dénominateur commun:** `/sys/fs/cgroup` (kernel Linux)

→ **cgroupfs** = choix par défaut le plus portable

---

## Distributions et configurations cgroup

| Distribution | Init system | containerd défaut | Recommandé K8s |
|-------------|-------------|-------------------|----------------|
| RHEL/CentOS 8+ | systemd | cgroupfs | **systemd** |
| Ubuntu 20.04+ | systemd | cgroupfs | **systemd** |
| Debian 11+ | systemd | cgroupfs | **systemd** |
| Fedora | systemd | cgroupfs | **systemd** |
| Alpine | OpenRC | cgroupfs | cgroupfs ✓ |
| Flatcar | systemd | systemd | systemd ✓ |
| Talos | custom | systemd | systemd ✓ |
| k3s/RKE2 | systemd | systemd | systemd ✓ |

Les distros K8s spécialisées préconfigure `SystemdCgroup = true`

---

## Le cas Alpine (sans systemd)

### Alpine utilise OpenRC, pas systemd

```bash
# Sur Alpine, cgroupfs est le bon choix !
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = false  # Correct pour Alpine
```

**Si `SystemdCgroup = true` sur Alpine:**
- containerd cherche systemd via D-Bus
- D-Bus n'existe pas → **crash**

---

## Philosophie containerd

### Pourquoi pas de détection automatique ?

```
Philosophie containerd:
───────────────────────
"Je suis un runtime bas niveau. Je ne fais pas de magie.
 L'administrateur sait mieux que moi dans quel environnement
 je tourne. Configuration explicite > détection implicite."
```

**Raisons techniques:**
- **Prévisibilité** — Comportement identique partout
- **Containers imbriqués** — systemd présent mais non fonctionnel
- **Transition cgroups v1 → v2** — Détection aurait été instable

---

## kubeadm vérifie la cohérence

### L'installateur Kubernetes force la bonne config

```bash
kubeadm init
# [preflight] Running pre-flight checks
# [preflight] Detected cgroup driver: systemd
# [preflight] Checking container runtime cgroup driver...
# ERROR: container runtime cgroup driver "cgroupfs"
#        != kubelet cgroup driver "systemd"
```

**kubeadm échoue** si configuration incohérente → force l'admin à corriger

---

## Résumé pratique - Cgroup driver

### Quelle configuration selon ton environnement ?

```
Distro avec systemd (CentOS, Ubuntu, Debian, RHEL) ?
────────────────────────────────────────────────────
  → SystemdCgroup = true  (OBLIGATOIRE)

k3s, RKE2, Talos, Flatcar ?
───────────────────────────
  → Déjà configuré, rien à faire

Alpine ou système sans systemd ?
────────────────────────────────
  → SystemdCgroup = false (le défaut est correct)
```

containerd choisit le mode universel → **l'intégrateur fait le dernier pas**

---

## cgroup v1 → v2 : chronologie du support containerd

### Les bornes à retenir

| Jalon | Version | Date |
|-------|---------|------|
| containerd supporte cgroup v1 | toutes (dès l'origine) | — |
| containerd supporte cgroup v2 | **1.4+** | août 2020 |
| Avant 1.4 sur Fedora 31+ | kernel cmdline `systemd.unified_cgroup_hierarchy=0` requis | — |
| Dernière version supportant v1 | **1.7.x** | — |
| containerd 2.0+ | **cgroup v2 uniquement** | 2024 |

### Conséquence pour Kubernetes

- K8s **1.35** = dernier K8s acceptant cgroup v1 (avec containerd 1.7)
- K8s **1.36+** exige containerd 2.0 → cgroup v2 obligatoire
- CentOS Stream 10 : cgroup v2 par défaut ✓ → on est alignés

---

## Matrice containerd × Kubernetes × cgroup

| Kubernetes | containerd min | containerd max | cgroup v1 | cgroup v2 |
|-----------|---------------|---------------|-----------|-----------|
| 1.24–1.25 | 1.5 | 1.6.x | ✓ | ✓ (depuis 1.4) |
| 1.26–1.27 | 1.6 | 1.7.x | ✓ | ✓ |
| 1.28–1.33 | 1.6 | 1.7.x / 2.0 | ✓ (1.6/1.7) | ✓ |
| 1.34 | 1.7 ⚠️ déprécié | 2.x | ✓ (1.7 seul) | ✓ |
| **1.35** | 1.7 (dernier) | 2.x | ✓ **(dernier K8s)** | ✓ |
| **1.36+** | **2.0 minimum** | 2.x | ✗ supprimé | ✓ uniquement |

> **Ce TD** : K8s 1.34/1.35 + containerd 2.x → cgroup v2 uniquement, on est dans la trajectoire moderne

---

## Prérequis réseau CentOS 10 - Modules kernel

```bash
# Charger les modules nécessaires
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

### Pourquoi ces modules ?

- **overlay**: Système de fichiers pour les layers des containers
- **br_netfilter**: Permet à iptables de voir le trafic bridgé

---

## Prérequis réseau CentOS 10 - Sysctl

```bash
# Paramètres sysctl pour le routage
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

### Pourquoi ip_forward ?

Routage des paquets entre interfaces réseau (requis par CNI)

---

## Désactivation du swap sur CentOS 10

```bash
# Désactiver le swap immédiatement
sudo swapoff -a

# Désactiver le swap au boot (commenter la ligne swap dans fstab)
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

### Pourquoi désactiver le swap ?

| Raison | Explication |
|--------|-------------|
| **Scheduling** | Kubernetes doit connaître la RAM réelle disponible |
| **Performance** | Le swap introduit des latences imprévisibles |
| **Limites** | Les limits de mémoire des pods deviennent imprécises |
| **OOM** | Le comportement OOM devient non-déterministe |

**Note:** Depuis K8s 1.28+, le swap peut être activé avec configuration spécifique (voir section swap)

---

## Firewall CentOS 10 - Master

### Ports requis sur le Control Plane

```bash
sudo firewall-cmd --permanent --add-port=6443/tcp   # API Server
sudo firewall-cmd --permanent --add-port=2379-2380/tcp # etcd
sudo firewall-cmd --permanent --add-port=10250/tcp  # kubelet API
sudo firewall-cmd --permanent --add-port=10259/tcp  # kube-scheduler
sudo firewall-cmd --permanent --add-port=10257/tcp  # kube-controller-manager
sudo firewall-cmd --reload
```

---

## Firewall CentOS 10 - Workers

### Ports requis sur les Workers

```bash
sudo firewall-cmd --permanent --add-port=10250/tcp  # kubelet API
sudo firewall-cmd --permanent --add-port=10256/tcp  # kube-proxy
sudo firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort
sudo firewall-cmd --reload
```

---

## SELinux sur CentOS 10 - Mode Permissive

### Recommandé pour ce TD

```bash
# Temporaire (jusqu'au reboot)
sudo setenforce 0

# Permanent
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' \
  /etc/selinux/config
```

### Pourquoi mode permissive pour le TD ?

- Simplifie le troubleshooting
- Évite les problèmes de permissions complexes

---

## SELinux en production — pourquoi c'est transparent

### `container-selinux` — déjà là, automatiquement

- Fournit les **policies SELinux pour les containers** : confine les processus avec le type `container_t`
- Restreint l'accès aux fichiers host, aux devices et au réseau depuis l'intérieur du container
- Sur CentOS Stream 10 + repo Docker : **installé automatiquement** comme dépendance de `containerd.io`
- Depuis **K8s 1.27** : feature gate `SELinuxMount` (GA en 1.30) → labels SELinux appliqués correctement sur les volumes montés, sans hack
- Résultat : en mode `enforcing`, les containers sont confinés **sans configuration supplémentaire**

```bash
# Vérifier que container-selinux est présent
rpm -q container-selinux

# Confirmer que les containers tournent bien avec le bon type
ps -eZ | grep containerd
```

> ℹ️ Le mode `permissive` de ce TD n'est là que pour simplifier le troubleshooting — pas une nécessité technique.

---

## Installation kubeadm - Repo Kubernetes

### Configuration du repo sur CentOS 10

```bash
# Ajouter le repo officiel Kubernetes
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```

---

## Installation kubeadm - Composants

### Installation et activation

```bash
# Installer kubeadm, kubelet et kubectl
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Activer kubelet au démarrage
sudo systemctl enable --now kubelet
```

### Verrouillage des versions

```bash
# Verrouiller pour éviter mises à jour accidentelles
sudo dnf install -y 'dnf-command(versionlock)'
sudo dnf versionlock add kubelet kubeadm kubectl
```

---

## Récapitulatif prérequis CentOS 10

### Checklist complète

| Étape | Commande de vérification |
|-------|-------------------------|
| Swap désactivé | `free -h` (Swap = 0) |
| Modules kernel | `lsmod \| grep br_netfilter` |
| containerd | `systemctl status containerd` |
| SystemdCgroup | `grep SystemdCgroup /etc/containerd/config.toml` |
| Firewall | `firewall-cmd --list-ports` |
| SELinux | `getenforce` (Permissive) |
| kubeadm | `kubeadm version` |

---

## Questions attendues - Prérequis (1/2)

**Q: Pourquoi désactiver le swap ?**
> R: Kubernetes nécessite un contrôle précis de la mémoire pour le scheduling. Le swap introduit des performances imprévisibles.

**Q: Différence entre containerd et Docker ?**
> R: containerd est le runtime de conteneurs (CRI), Docker est un ensemble d'outils incluant containerd. Kubernetes utilise directement containerd via CRI.

---

## Questions attendues - Prérequis (2/2)

**Q: Pourquoi `SystemdCgroup = true` ?**
> R: CentOS 10 utilise systemd comme gestionnaire de cgroups v2. Le kubelet utilise aussi systemd par défaut. Si drivers différents → conflits mémoire et pods qui crashent.

**Q: Pourquoi SELinux en mode permissive ?**
> R: Pour simplifier le TD. En production, SELinux doit rester en enforcing.

---

## 1.2 - Initialisation du control plane

### 📝 EXERCICE ÉLÈVE
**Script à exécuter sur le MASTER uniquement:**
```bash
./02-init-control-plane.sh
```

**⚠️ IMPORTANT:** Faire sauvegarder la commande `kubeadm join` !

### Point critique
**La commande `kubeadm join` affichée à la fin !**

### Solution de secours
```bash
# Si les étudiants perdent la commande
kubeadm token create --print-join-command

# Liste des tokens actifs
kubeadm token list
```

---

## Vérifications control plane

```bash
kubectl get pods -n kube-system

# Points à vérifier (doivent être Running):
# - kube-apiserver
# - kube-controller-manager
# - kube-scheduler
# - etcd
```

---

## 1.3 - Jonction des workers

### 📝 EXERCICE ÉLÈVE
**Script à exécuter sur chaque WORKER:**
```bash
./03-join-workers.sh
```

**Saisir la commande `kubeadm join` obtenue précédemment**

### Problème fréquent
Erreur de connexion au master

```bash
# Vérifier la connectivité
ping <master-ip>

# Vérifier que l'API server est accessible
curl -k https://<master-ip>:6443

# Vérifier les certificats
sudo ls -la /etc/kubernetes/pki/
```

---

## 1.4 - Installation de Flannel

### 📝 EXERCICE ÉLÈVE
**Script à exécuter sur le MASTER:**
```bash
./04-install-flannel.sh
```

**Attendre que tous les pods Flannel soient Running**

### Pourquoi Flannel en premier ?

- Simple et rapide à installer
- Parfait pour l'apprentissage
- Permet de voir l'effet d'une migration CNI

---

## 1.4 - Flannel - Vérifications

### Vérifications post-installation

```bash
# Un pod flannel par nœud (DaemonSet)
kubectl get pods -n kube-flannel -o wide

# Interfaces réseau créées
ip addr show flannel.1
```

**Attendu:** Un pod par nœud en status `Running`

---

## 1.5 - Validation

### 📝 EXERCICE ÉLÈVE
**Script à exécuter sur le MASTER:**
```bash
./05-verify-cluster.sh
```

**Validation:**
```bash
cd ../../validation
./validate-partie.sh 1
```

**Temps de stabilisation:** 2-3 minutes après installation CNI

Si des étudiants sont bloqués:
```bash
kubectl get events --all-namespaces \
  --sort-by='.lastTimestamp'
```

---

<!-- _class: lead -->

# Partie 2
## Kubelet et Static Pods (30 min)

---

## Le kubelet — L'agent node de Kubernetes

### En une phrase

> Le kubelet est l'agent qui tourne sur chaque node et qui s'assure que les containers décrits dans les PodSpecs tournent effectivement sur ce node.

---

## Kubelet - Position dans l'architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CONTROL PLANE                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ API Server  │  │ Scheduler   │  │ Controller Manager      │  │
│  └──────┬──────┘  └─────────────┘  └─────────────────────────┘  │
└─────────┼───────────────────────────────────────────────────────┘
          │ HTTPS (watch, status updates)
┌─────────┼───────────────────────────────────────────────────────┐
│         ▼                        NODE                           │
│  ┌─────────────┐                                                │
│  │   KUBELET   │ ◄─── L'agent principal du node                 │
│  └──────┬──────┘                                                │
│         ├──────────────┬──────────────┬──────────────┐          │
│         ▼              ▼              ▼              ▼          │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐     │
│  │containerd │  │ cAdvisor  │  │  CSI      │  │  CNI      │     │
│  │ (CRI)     │  │ (metrics) │  │ (storage) │  │ (network) │     │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Kubelet - Boucle de réconciliation

### Compare état désiré vs état actuel

```
┌──────────────────────────────────────────────────────────────┐
│                    BOUCLE DE RÉCONCILIATION                  │
│                                                              │
│   ┌─────────────┐         ┌─────────────┐                    │
│   │ État désiré │         │ État actuel │                    │
│   │ (API Server)│         │ (sur le node)│                   │
│   └──────┬──────┘         └──────┬──────┘                    │
│          └───────────┬───────────┘                           │
│                      ▼                                       │
│              ┌───────────────┐                               │
│              │   Différence? │                               │
│              └───────┬───────┘                               │
│          ┌───────────┴───────────┐                           │
│          ▼                       ▼                           │
│   Pod manquant?           Pod en trop?                       │
│   → Créer le pod          → Supprimer le pod                 │
│                                                              │
│   Container crashé?       Config changée?                    │
│   → Redémarrer            → Recréer le container             │
└──────────────────────────────────────────────────────────────┘
```

---

## Kubelet - Cycle de vie des containers

```
kubelet reçoit PodSpec
        │
        ▼
┌───────────────────┐
│ Préparer le pod   │
│ • Créer cgroups   │
│ • Monter volumes  │
│ • Configurer net  │
└────────┬──────────┘
         ▼
┌───────────────────┐
│ Init containers   │  ← Exécutés séquentiellement
└────────┬──────────┘
         ▼
┌───────────────────┐
│ App containers    │  ← Démarrés en parallèle
│ + postStart hooks │
└────────┬──────────┘
         ▼
┌───────────────────┐
│ Probes actives    │
│ • startup/liveness│
│ • readiness       │
└───────────────────┘
```

---

## Kubelet - Ce qu'il remonte à l'API Server

### NodeStatus

```yaml
conditions:
  - type: Ready           # Le node peut accepter des pods
  - type: MemoryPressure  # Mémoire insuffisante
  - type: DiskPressure    # Disque plein
  - type: PIDPressure     # Trop de processus

capacity:
  cpu: "8"
  memory: "32Gi"
  pods: "110"

allocatable:              # Capacity - reserved
  cpu: "7.5"
  memory: "30Gi"
```

---

## Kubelet - PodStatus remonté

### Ce que kubectl get pods affiche

```yaml
status:
  phase: Running          # Pending/Running/Failed/Succeeded
  conditions:
    - type: PodScheduled
    - type: Initialized
    - type: ContainersReady
    - type: Ready
  containerStatuses:
    - name: nginx
      ready: true
      restartCount: 0
      state:
        running:
          startedAt: "2024-01-15T10:00:00Z"
```

---

## Kubelet - Interface CRI

### CRI (Container Runtime Interface)

Communication kubelet ↔ runtime:

```
kubelet ──► CRI ──► containerd
              │
              ├─ RunPodSandbox()
              ├─ CreateContainer()
              └─ StartContainer()
```

Point d'extension: permet d'utiliser containerd, CRI-O, etc.

---

## Kubelet - CRI : détail des appels

| Appel | Rôle |
|-------|------|
| `RunPodSandbox()` | Crée le **pause container** + namespaces Linux (net, pid, ipc, uts) — la "coquille" vide du pod |
| `CreateContainer()` | Instancie un conteneur applicatif dans le sandbox (pull image, config) |
| `StartContainer()` | Démarre le conteneur (point d'entrée du process) |
| `StopContainer()` | Envoie SIGTERM puis SIGKILL après grace period |
| `RemovePodSandbox()` | Détruit le sandbox et tous ses conteneurs |

Le **pause container** (`registry.k8s.io/pause`) tient les namespaces en vie — si un conteneur applicatif crashe et redémarre, il réutilise les mêmes namespaces réseau/PID.

---

## Kubelet - Interfaces CNI et CSI

### CNI (Container Network Interface)

```
kubelet ──► CNI plugin (Calico, Flannel...)
              ├─ ADD: Configure réseau pour nouveau pod
              └─ DEL: Nettoie quand le pod meurt
```

### CSI (Container Storage Interface)

```
kubelet ──► CSI driver
              ├─ NodeStageVolume()   # Attache au node
              └─ NodePublishVolume() # Monte dans le pod
```

---

## Kubelet - Fonctions gérées directement

| Fonction | Description |
|----------|-------------|
| **Probes** | Exécute liveness/readiness/startup |
| **Ressources** | Applique requests/limits via cgroups |
| **Logs** | Capture stdout/stderr des containers |
| **Exec/Attach** | Permet `kubectl exec` et `kubectl attach` |
| **Port-forward** | Permet `kubectl port-forward` |
| **Éviction** | Tue des pods si le node manque de ressources |
| **Image GC** | Nettoie les images non utilisées |
| **Container GC** | Nettoie les containers morts |

---

## Static Pods - Le problème de l'œuf et la poule

### Comment démarrer l'API Server sans API Server ?

```
/etc/kubernetes/manifests/
├── etcd.yaml
├── kube-apiserver.yaml
├── kube-controller-manager.yaml
└── kube-scheduler.yaml
```

**Le kubelet watch ce dossier et démarre les pods SANS passer par l'API !**

---

## Static Pods - Flux de démarrage

```
┌─────────────────────────────────────────────────────────┐
│                    STATIC PODS                          │
│                                                         │
│   kubelet démarre                                       │
│        │                                                │
│        ▼                                                │
│   Watch /etc/kubernetes/manifests/                      │
│        │                                                │
│        ▼                                                │
│   Trouve kube-apiserver.yaml                            │
│        │                                                │
│        ▼                                                │
│   Démarre le container (sans API Server!)               │
│        │                                                │
│        ▼                                                │
│   API Server devient disponible                         │
│        │                                                │
│        ▼                                                │
│   kubelet crée un "mirror pod" dans l'API               │
│   (pour visibilité: kubectl get pods le voit)           │
└─────────────────────────────────────────────────────────┘
```

---

## Kubelet - Configuration importante

```yaml
# /var/lib/kubelet/config.yaml

cgroupDriver: systemd          # DOIT matcher containerd !
containerRuntimeEndpoint: unix:///run/containerd/containerd.sock

# Ressources réservées pour le système
kubeReserved:
  cpu: "500m"
  memory: "1Gi"
systemReserved:
  cpu: "500m"
  memory: "1Gi"

# Seuils d'éviction (tue des pods si dépassés)
evictionHard:
  memory.available: "100Mi"
  nodefs.available: "10%"
  imagefs.available: "15%"

# Limites
maxPods: 110
podsPerCore: 10
```

---

## Kubelet - Debugging

```bash
# Logs en temps réel
journalctl -u kubelet -f

# État du node vu par kubelet
kubectl describe node <node-name>

# Vérifier que kubelet répond
curl -k https://localhost:10250/healthz

# Pods sur ce node spécifique
kubectl get pods -A --field-selector spec.nodeName=<node-name>

# Voir les événements du node
kubectl get events --field-selector involvedObject.name=<node-name>
```

---

## Kubelet - Exemple complet PodSpec

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exemple-complet
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:           # Minimum garanti (scheduling)
        cpu: "250m"
        memory: "128Mi"
      limits:             # Maximum autorisé (cgroups)
        cpu: "500m"
        memory: "256Mi"
    livenessProbe:        # kubelet redémarre si échec
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 5
    readinessProbe:       # kubelet retire du Service si échec
      httpGet:
        path: /ready
        port: 8080
```

---

## Kubelet - En résumé

### Le "contremaître" de chaque node

```
┌─────────────────────────────────────────────────────────┐
│                      KUBELET                            │
│                                                         │
│  • Reçoit les ordres du control plane (API Server)      │
│  • Coordonne les outils locaux:                         │
│    - Runtime (containerd)                               │
│    - Réseau (CNI)                                       │
│    - Stockage (CSI)                                     │
│  • Surveille que tout tourne (probes)                   │
│  • Remonte les problèmes (status, events)               │
│                                                         │
│  Sans kubelet, un node N'EXISTE PAS pour Kubernetes     │
└─────────────────────────────────────────────────────────┘
```

---

## Kubelet au-delà des containers

### CRI : deux implémentations, deux niveaux OCI

```
┌─────────────────────────────────────────────────────────────────┐
│                          KUBELET                                │
│                    ↓ parle CRI (gRPC)                           │
├──────────────────────────┬──────────────────────────────────────┤
│  containerd              │  CRI-O                               │
│  (CRI via plugin)        │  (CRI natif, conçu pour K8s)         │
│  ↓ appelle runtimes OCI  │  ↓ appelle runtimes OCI              │
├────────┬────────┬────────┼────────┬────────┬────────────────────┤
│  runc  │  kata  │ runsc  │  runc  │  kata  │  runsc             │
│        │(microVM│(gVisor)│        │(microVM│ (gVisor)           │
└────────┴────────┴────────┴────────┴────────┴────────────────────┘
```

**Couche 1 — implémentent CRI :** `containerd` (plugin), `CRI-O` (natif)
**Couche 2 — runtimes OCI :** `runc`, `kata-runtime`, `runsc` (gVisor)

---

## KubeVirt — VM dans Kubernetes, sans toucher à CRI

```
┌──────────────────────────────────────────────────────────────────┐
│                    KUBERNETES API                                 │
│   kubectl apply VirtualMachine (CRD KubeVirt)                    │
│                        ↓                                         │
│             virt-controller (operator)                           │
│                        ↓ crée un Pod normal                      │
├──────────────────────────────────────────────────────────────────┤
│  kubelet → CRI → containerd → runc → Pod "virt-launcher"         │
│                                          ↓ (dans le container)   │
│                                     libvirt / QEMU               │
│                                          ↓ (KVM)                 │
│                                     Vraie VM (OS invité complet) │
└──────────────────────────────────────────────────────────────────┘
```

KubeVirt ne touche **ni kubelet, ni CRI, ni les runtimes OCI**

---

## KubeVirt — Gérer des VMs, c'est une autre approche

### Containers vs VMs dans Kubernetes

| | Containers (runc/kata) | KubeVirt |
|---|---|---|
| Unité schedulée | Pod | Pod (`virt-launcher`) |
| Isolation | namespaces/cgroups (ou microVM kata) | QEMU + KVM |
| OS invité | Non (shared kernel) | Oui (kernel complet) |
| Niveau d'extension | OCI runtime | Kubernetes CRD + Operator |
| kubelet modifié ? | **Non** | **Non** |

> On ne remplace pas le runtime : on encapsule QEMU dans un pod

---

## KubeVirt — Kubelet a-t-il encore du sens ?

### Oui — et à deux niveaux

**1. Le nœud n'est pas 100% VMs**
- Pods système toujours présents : CNI, CSI, kube-proxy, monitoring, etc.
- Rien n'empêche containers ET VMs sur le même worker

**2. Kubelet gère le pod `virt-launcher` lui-même**
- Liveness/readiness probes sur la VM
- Resource limits CPU/RAM → éviction si pression mémoire
- Scheduling, QoS class, PodDisruptionBudget

**Ce que KubeVirt ajoute *au-dessus* de kubelet :**
- Live migration entre nœuds (coordonné par `virt-controller`)
- Snapshots, disques persistants (CDI)
- API `VirtualMachine` / `VMI` pour le cycle de vie VM

> Kubelet gère le pod qui **contient** la VM.
> KubeVirt gère ce qui est **à l'intérieur** — QEMU, migration, disques.

---

## CRI - Les différents runtimes

### 1. Containers classiques (runc)

```
PodSpec → kubelet → containerd → runc → container Linux
                                        (namespaces + cgroups)
```

### 2. Kata Containers (microVMs)

```
PodSpec → kubelet → containerd → kata-runtime → QEMU/Firecracker
                                                (vraie VM légère)
```

### 3. gVisor (sandbox userspace)

```
PodSpec → kubelet → containerd → runsc → gVisor kernel
```

### 4. WebAssembly (WASM)

```
PodSpec → kubelet → containerd → runwasi → wasmtime/spin
```

---

## Container classique vs Kata Container

```
┌─────────────────────────────────────────────────────────────────┐
│                     NODE (bare metal/VM)                        │
│                                                                 │
│   Container classique          Kata Container                   │
│   ┌─────────────────┐          ┌─────────────────────────────┐  │
│   │ App             │          │  microVM                    │  │
│   │ ─────────────── │          │  ┌─────────────────────────┐│  │
│   │ Shared kernel   │          │  │ App                     ││  │
│   │ (host kernel)   │          │  │ ───────────────────     ││  │
│   └─────────────────┘          │  │ Guest kernel (dédié)    ││  │
│                                │  └─────────────────────────┘│  │
│                                └─────────────────────────────┘  │
│                                                                 │
│   Isolation: namespaces        Isolation: hyperviseur           │
│   Rapide, léger                Plus lent, plus isolé            │
└─────────────────────────────────────────────────────────────────┘
```

---

## RuntimeClass - Choisir le runtime

### Définir les runtimes disponibles

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata      # Config containerd
---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: wasm
handler: spin
```

---

## RuntimeClass - Utilisation dans un Pod

### Spécifier le runtime pour un workload

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-workload
spec:
  runtimeClassName: kata  # ← Ce pod dans une microVM !
  containers:
  - name: app
    image: my-app:latest
```

Le scheduler trouve un node avec ce runtime disponible

---

## KubeVirt - VMs complètes dans K8s

### Gérer de vraies VMs comme des pods

```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: my-windows-vm
spec:
  running: true
  template:
    spec:
      domain:
        resources:
          requests:
            memory: 4Gi
            cpu: 2
      volumes:
      - name: root
        containerDisk:
          image: kubevirt/windows:2019
```

---

## KubeVirt - Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          KUBELET                                │
│                             │                                   │
│                             ▼                                   │
│                    ┌─────────────────┐                          │
│                    │       CRI       │                          │
│                    └────────┬────────┘                          │
└─────────────────────────────┼───────────────────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │   containerd    │
                    └────────┬────────┘
                              ▼
                    ┌─────────────────┐
                    │   virt-handler  │  ← Agent KubeVirt
                    └────────┬────────┘
                              ▼
                    ┌─────────────────┐
                    │   libvirt/QEMU  │  ← VM complète
                    │  Windows/Linux  │
                    └─────────────────┘
```

---

## Comparaison des runtimes

| Solution | Isolation | Overhead | Cas d'usage |
|----------|-----------|----------|-------------|
| **runc** | Namespaces | Minimal | Workloads standards |
| **gVisor** | Kernel userspace | Faible | Multi-tenant, code non fiable |
| **Kata** | microVM | Moyen | Sécurité, compliance |
| **KubeVirt** | VM complète | Élevé | Legacy, Windows, drivers |
| **WASM** | Sandbox WASM | Très faible | Edge, serverless |

---

## Cas d'usage concrets

| Cas d'usage | Runtime | Bénéfice |
|-------------|---------|----------|
| Multi-tenant hostile | Kata | Isolation VM par tenant |
| Legacy Windows | KubeVirt | VMs complètes |
| Edge / IoT | WASM | Démarrage en ms |
| PCI-DSS / Healthcare | Kata | Isolation certifiable |

```yaml
# Exemple: isolation multi-tenant
runtimeClassName: kata  # → VM dédiée par pod
```

---

## CRI - L'abstraction puissante

### kubelet ne sait pas ce qu'est un "container"

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  kubelet parle CRI, point final.                        │
│                                                         │
│  Tout ce qui répond à cette interface peut être         │
│  schedulé comme un "pod" :                              │
│                                                         │
│  • Container Linux classique                            │
│  • microVM (Kata, Firecracker)                          │
│  • VM complète (KubeVirt)                               │
│  • Module WebAssembly                                   │
│  • Sandbox gVisor                                       │
│                                                         │
│  L'abstraction est PUISSANTE.                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Partie 2 - Timeline suggérée

- Anatomie config: **5 min**
- Modification: **10 min**
- Static pod: **10 min**
- Test comportement: **5 min**

---

## 2.1 - Configuration kubelet

### 📝 EXERCICE ÉLÈVE
**Sur n'importe quel nœud:**
```bash
sudo cat /var/lib/kubelet/config.yaml
```

**Questions à poser:**
1. Où sont les clés d'authentification ?
2. Valeur de `maxPods` ?
3. Chemin des static pods ?

---

## 2.1 - Kubelet - Décryptage config.yaml

| Paramètre | Rôle |
|-----------|------|
| `cgroupDriver: systemd` | Doit matcher containerd — sinon nœuds instables |
| `containerRuntimeEndpoint` | Socket Unix vers containerd |
| `kubeReserved` | CPU/RAM réservés pour kubelet, kube-proxy, containerd |
| `systemReserved` | CPU/RAM réservés pour l'OS (systemd, sshd…) |
| `evictionHard` | Seuils sous lesquels kubelet tue des pods pour récupérer des ressources |
| `maxPods` | Limite absolue de pods sur le nœud (défaut kubeadm : 110) |
| `podsPerCore` | Limite relative : effectif = `min(maxPods, podsPerCore × cores)` |

**Ressources allouables au scheduler :**
```
Allocatable = Capacité nœud − kubeReserved − systemReserved − evictionHard
```

**Réponses exercice :**
1. **Clés d'authentification** → `/etc/kubernetes/pki/ca.crt` (CA), `/var/lib/kubelet/pki/kubelet.crt` (cert servant), `/etc/kubernetes/kubelet.conf` (kubeconfig client)
2. **maxPods** → `110` (défaut kubeadm)
3. **Static pods** → `/etc/kubernetes/manifests/` (champ `staticPodPath`)

---

## 2.1 - Kubelet - Concepts clés

### Points importants

- Kubelet = **agent node-level**
- Configuration en **YAML** (recommandé vs flags CLI)
- **Rechargement nécessaire** après modification

**Fichier principal:** `/var/lib/kubelet/config.yaml`

---

## Question attendue - Kubelet

**Q: Différence entre config.yaml et les flags kubelet ?**
> R: Le fichier YAML contient la configuration structurée (préféré), les flags CLI sont pour des overrides rapides. Le fichier est plus maintenable.

---

## 2.2 - Modification kubelet config

### 📝 EXERCICE ÉLÈVE
**Script sur n'importe quel nœud:**
```bash
cd scripts/partie-02-kubelet-static-pods
./01-modify-kubelet-config.sh
```

**Vérification:**
```bash
sudo journalctl -u kubelet -n 50 | grep -i max
```

---

## 2.3 - Static pods

![bg right:40% fit](diagrams/static-pods.png)

### 📝 EXERCICE ÉLÈVE
**Sur un WORKER:**
```bash
./02-deploy-static-pod.sh
```

**Sur le MASTER, vérifier:**
```bash
kubectl get pods -n kube-system | grep disk-monitor
kubectl logs -n kube-system disk-monitor-<nom-du-nœud>
```

---

## 2.3 - Static pods (suite)

### Démonstration recommandée

1. Le static pod apparaît dans kubectl avec **nom suffixé**
2. Tenter de supprimer via kubectl → **recréation immédiate**
3. Supprimer le manifest → **suppression effective**

### Point pédagogique important

**Les composants du control plane sont des static pods !**

```bash
sudo ls -la /etc/kubernetes/manifests/
```

---

## 2.4 - Test comportement

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
./03-test-static-pod-behavior.sh
```

**Questions à poser:**
1. Que se passe-t-il si on supprime via kubectl ?
2. Comment supprimer définitivement ?
3. Avantage pour les composants control plane ?

**Validation:**
```bash
cd ../../validation
./validate-partie.sh 2
```

---

## Exercice bonus (si temps)

Demander aux étudiants de créer leur propre static pod personnalisé

**Répertoire:** `/etc/kubernetes/manifests/`

---

<!-- _class: lead -->

# Partie 3
## Taints et Tolerations (30 min)

---

## Partie 3 - Timeline suggérée

- Theorie Taints/Tolerations: **15 min**
- Exploration: **5 min**
- Ajout taints + observation: **10 min**

---

## Taints & Tolerations - C'est quoi ?

### Analogie simple : Le videur de boite de nuit

```
┌─────────────────────────────────────────────────────────┐
│                      NODE                               │
│                                                         │
│   TAINT = "Panneau a l'entree"                         │
│   ┌─────────────────────────────┐                      │
│   │  🚫 INTERDIT AUX PODS       │                      │
│   │     SANS TOLERATION         │                      │
│   └─────────────────────────────┘                      │
│                                                         │
│   TOLERATION = "Badge VIP du Pod"                      │
│   ┌─────────────────────────────┐                      │
│   │  ✅ J'ai le droit d'entrer  │                      │
│   └─────────────────────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

**Taint** = Le node **repousse** les pods
**Toleration** = Le pod **tolere** le taint (peut entrer)

---

## Direction du controle - Concept cle

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│    nodeSelector / Affinity        Taints/Tolerations    │
│    ────────────────────────       ──────────────────    │
│                                                          │
│         POD ──────────> NODE      NODE ──────────> POD  │
│                                                          │
│    "Je VEUX aller sur             "Je REFUSE les pods   │
│     ce node"                       sans badge"          │
│                                                          │
│    Le Pod CHOISIT                 Le Node EXCLUT        │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Combinaison recommandee:** Taint + nodeSelector pour controle complet

---

## Syntaxe d'un Taint

```bash
kubectl taint nodes <node-name> <key>=<value>:<effect>
```

### Exemples concrets :
```bash
# Marquer un node pour maintenance
kubectl taint nodes worker1 maintenance=true:NoSchedule

# Node dedie GPU
kubectl taint nodes gpu-node-1 gpu=nvidia:NoSchedule

# Node en panne (evacuation urgente)
kubectl taint nodes worker2 node.kubernetes.io/unreachable:NoExecute
```

### Retirer un taint (ajouter `-` a la fin) :
```bash
kubectl taint nodes worker1 maintenance=true:NoSchedule-
```

---

## Les 3 Effects - Vue d'ensemble

| Effect | Pods existants | Nouveaux pods |
|--------|----------------|---------------|
| `NoSchedule` | ✅ Restent | ❌ Bloques |
| `PreferNoSchedule` | ✅ Restent | ⚠️ Evites si possible |
| `NoExecute` | ❌ **Evacues** | ❌ Bloques |

---

## Les 3 Effects - Diagramme

![fit](diagrams/taints-tolerations.png)

---

## Effect 1: NoSchedule (le plus courant)

<div style="display:flex;align-items:flex-start;gap:30px;margin-top:10px">
<div style="flex:1;border:2px solid #43a047;border-radius:8px;padding:12px;background:#e8f5e9">
<div style="font-weight:bold;color:#2e7d32;margin-bottom:8px">AVANT le taint — Worker1</div>
<div style="display:flex;gap:8px;margin-bottom:8px">
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod A</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod B</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod C</div>
<div style="background:#fff9c4;border:1px dashed #f9a825;border-radius:4px;padding:6px 12px;color:#e65100">Pod D (libre)</div>
</div>
</div>
<div style="font-size:32px;align-self:center">➜</div>
<div style="flex:1;border:2px solid #e53935;border-radius:8px;padding:12px;background:#ffebee">
<div style="font-weight:bold;color:#b71c1c;margin-bottom:4px">APRÈS — Worker1</div>
<div style="background:#ffcdd2;border-radius:4px;padding:4px 8px;margin-bottom:8px;color:#c62828;font-size:13px">🔴 Taint: NoSchedule</div>
<div style="display:flex;gap:8px;margin-bottom:8px">
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod A ✅</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod B ✅</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod C ✅</div>
</div>
<div style="background:#ffcdd2;border:1px dashed #e53935;border-radius:4px;padding:6px 12px;color:#b71c1c;display:inline-block">Pod D ❌ REFUSÉ</div>
</div>
</div>

📌 Cas d'usage : maintenance planifiée, réserver un nœud GPU

---

## Effect 2: PreferNoSchedule (soft)

<div style="text-align:center;margin-top:10px">
<div style="display:inline-block;background:#e3f2fd;border:2px solid #1565c0;border-radius:8px;padding:10px 30px;color:#0d47a1;font-weight:bold;margin-bottom:16px">⚙️ Scheduler — Où placer Pod X ?</div>
</div>
<div style="display:flex;gap:20px;margin-top:8px">
<div style="flex:1;border:2px solid #43a047;border-radius:8px;padding:14px;background:#e8f5e9;text-align:center">
<div style="font-weight:bold;color:#2e7d32;margin-bottom:8px">Worker1</div>
<div style="font-size:22px;margin-bottom:6px">✅</div>
<div style="background:#c8e6c9;border-radius:4px;padding:4px;color:#1b5e20;font-weight:bold">Score : 100</div>
<div style="color:#388e3c;font-size:13px;margin-top:6px">Prioritaire</div>
</div>
<div style="flex:1;border:2px solid #f9a825;border-radius:8px;padding:14px;background:#fff8e1;text-align:center">
<div style="font-weight:bold;color:#e65100;margin-bottom:4px">Worker2</div>
<div style="background:#ffe0b2;border-radius:4px;padding:4px;color:#bf360c;font-size:13px;margin-bottom:6px">⚠️ Taint: PreferNoSchedule</div>
<div style="background:#ffcc80;border-radius:4px;padding:4px;color:#e65100;font-weight:bold">Score : 50</div>
<div style="color:#e65100;font-size:13px;margin-top:6px">Évité si possible</div>
</div>
<div style="flex:1;border:2px solid #43a047;border-radius:8px;padding:14px;background:#e8f5e9;text-align:center">
<div style="font-weight:bold;color:#2e7d32;margin-bottom:8px">Worker3</div>
<div style="font-size:22px;margin-bottom:6px">✅</div>
<div style="background:#c8e6c9;border-radius:4px;padding:4px;color:#1b5e20;font-weight:bold">Score : 100</div>
<div style="color:#388e3c;font-size:13px;margin-top:6px">Prioritaire</div>
</div>
</div>

📌 Worker2 utilisé seulement si Worker1 et Worker3 sont saturés

---

## Effect 3: NoExecute (agressif!)

<div style="display:flex;align-items:flex-start;gap:20px;margin-top:10px">
<div style="flex:1;border:2px solid #43a047;border-radius:8px;padding:12px;background:#e8f5e9">
<div style="font-weight:bold;color:#2e7d32;margin-bottom:8px">AVANT — Worker1</div>
<div style="display:flex;gap:8px">
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod A</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod B</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod C</div>
</div>
</div>
<div style="text-align:center;align-self:center">
<div style="font-size:28px">➜</div>
<div style="color:#c62828;font-weight:bold;font-size:13px">ÉVACUATION<br>IMMÉDIATE</div>
</div>
<div style="flex:1;border:2px solid #e53935;border-radius:8px;padding:12px;background:#ffebee">
<div style="font-weight:bold;color:#b71c1c;margin-bottom:4px">APRÈS — Worker1</div>
<div style="background:#ffcdd2;border-radius:4px;padding:4px 8px;margin-bottom:8px;color:#c62828;font-size:13px">🔴 Taint: NoExecute</div>
<div style="color:#b71c1c;font-style:italic;text-align:center;padding:10px">(VIDE)</div>
</div>
<div style="font-size:28px;align-self:center">➜</div>
<div style="flex:1;border:2px solid #43a047;border-radius:8px;padding:12px;background:#e8f5e9">
<div style="font-weight:bold;color:#2e7d32;margin-bottom:8px">Worker2 — Reschedule</div>
<div style="display:flex;gap:8px">
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod A ✅</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod B ✅</div>
<div style="background:#a5d6a7;border:1px solid #43a047;border-radius:4px;padding:6px 12px;color:#1b5e20">Pod C ✅</div>
</div>
</div>
</div>

⚠️ Peut causer des interruptions de service — à utiliser avec précaution

---

## Syntaxe d'une Toleration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mon-pod
spec:
  tolerations:
  - key: "gpu"              # Cle du taint
    operator: "Equal"       # Equal ou Exists
    value: "nvidia"         # Valeur (si Equal)
    effect: "NoSchedule"    # Meme effect que le taint
  containers:
  - name: app
    image: nvidia/cuda:latest
```

---

## Toleration - Correspondance

**Les champs doivent correspondre exactement :**

| Taint sur Node | Toleration sur Pod | Match? |
|----------------|-------------------|--------|
| `gpu=nvidia:NoSchedule` | `key:gpu, value:nvidia, effect:NoSchedule` | ✅ OUI |
| `gpu=nvidia:NoSchedule` | `key:gpu, value:amd, effect:NoSchedule` | ❌ NON (value) |
| `gpu=nvidia:NoSchedule` | `key:gpu, effect:NoExecute` | ❌ NON (effect) |
| `gpu=nvidia:NoSchedule` | `key:cpu, value:nvidia, effect:NoSchedule` | ❌ NON (key) |

**Regle:** key + value + effect doivent tous correspondre

---

## Operator: Equal vs Exists

### **Equal** - Correspondance exacte
```yaml
tolerations:
- key: "gpu"
  operator: "Equal"      # value DOIT matcher
  value: "nvidia"
  effect: "NoSchedule"
```
→ Tolere UNIQUEMENT `gpu=nvidia:NoSchedule`

### **Exists** - Wildcard sur la valeur
```yaml
tolerations:
- key: "gpu"
  operator: "Exists"     # Pas de value!
  effect: "NoSchedule"
```
→ Tolere `gpu=nvidia`, `gpu=amd`, `gpu=intel`...

---

## Wildcard total - Tolerer TOUT

```yaml
tolerations:
- operator: "Exists"     # Pas de key!
```

**⚠️ Tolere TOUS les taints du cluster!**

### C'est ce qu'ont les pods systeme:
```bash
$ kubectl get pod kube-apiserver -n kube-system -o yaml | grep -A5 tolerations
tolerations:
- operator: Exists    # Tolere tout!
```

→ C'est pourquoi ils peuvent tourner sur le master malgre le taint

---

## tolerationSeconds - Delai avant eviction

```yaml
tolerations:
- key: "node.kubernetes.io/unreachable"
  operator: "Exists"
  effect: "NoExecute"
  tolerationSeconds: 300    # 5 minutes
```

```
  Node devient unreachable
           │
           ▼
  ┌─────────────────────────────────────────┐
  │  Pod reste sur le node pendant 300s    │
  │  (en esperant que le node revienne)    │
  └─────────────────────────────────────────┘
           │ 300 secondes passees...
           ▼
  ┌─────────────────────────────────────────┐
  │  Pod evacue vers un autre node         │
  └─────────────────────────────────────────┘
```

**Utile pour:** Tolerer les micro-coupures reseau

---

## Taints par defaut du Master

```bash
$ kubectl describe node master | grep Taints
Taints:  node-role.kubernetes.io/control-plane:NoSchedule
```

### Pourquoi les pods systeme tournent sur le master ?

Ils ont une toleration wildcard:
```yaml
tolerations:
- operator: "Exists"    # Tolere TOUT!
```

### Permettre les workloads sur le master (lab/dev) :
```bash
kubectl taint nodes master \
  node-role.kubernetes.io/control-plane:NoSchedule-
```

---

## 4.1 - Explorer les taints

### 📝 EXERCICE ELEVE
**Script sur le MASTER:**
```bash
cd scripts/partie-03-taints-tolerations
./01-explore-default-taints.sh
```

**Questions a poser:**
1. Quelle taint est sur le master ?
2. Pourquoi les pods systeme tournent sur le master malgre le taint ?
3. Regardez la toleration de kube-apiserver

---

## 4.2 - Ajout de taints et observation

### 📝 EXERCICE ELEVE
**Script sur le MASTER:**
```bash
./02-add-custom-taints.sh
```

**Observer:**
- Pods existants avec NoSchedule
- Nouveaux pods refuses
- Evacuation avec NoExecute

---

## Demo live recommandee

```bash
# 1. Deployer une app
kubectl create deployment demo --image=nginx --replicas=5
kubectl get pods -o wide

# 2. Taint NoSchedule sur worker1
kubectl taint nodes worker1 test=true:NoSchedule

# 3. Scaler pour voir l'effet
kubectl scale deployment demo --replicas=8
kubectl get pods -o wide
# Nouveaux pods sur worker2 uniquement!

# 4. Taint NoExecute (attention!)
kubectl taint nodes worker1 test=true:NoExecute
kubectl get pods -o wide -w
# Pods evacues immediatement!

# 5. Cleanup
kubectl taint nodes worker1 test=true:NoExecute-
kubectl delete deployment demo
```

---

## Cas d'usage reels

| Scenario | Taint | Effect |
|----------|-------|--------|
| **Nodes GPU** | `gpu=nvidia` | `NoSchedule` |
| **Nodes SSD** | `storage=ssd` | `NoSchedule` |
| **Maintenance planifiee** | `maintenance=true` | `NoSchedule` |
| **Node en panne** | `unreachable` | `NoExecute` |
| **Multi-tenancy** | `team=alpha` | `NoSchedule` |
| **Nodes spot/preemptible** | `preemptible=true` | `NoSchedule` |

---

## Exemple complet: Nodes GPU dedies

```bash
# 1. Tainter les nodes GPU
kubectl taint nodes gpu-node-1 gpu=nvidia:NoSchedule
kubectl label nodes gpu-node-1 gpu=true
```

```yaml
# 2. Pod ML avec toleration + nodeSelector
apiVersion: v1
kind: Pod
metadata:
  name: ml-training
spec:
  tolerations:
  - key: "gpu"
    operator: "Equal"
    value: "nvidia"
    effect: "NoSchedule"
  nodeSelector:           # IMPORTANT: sinon le pod peut
    gpu: "true"           # aller sur n'importe quel node!
  containers:
  - name: training
    image: tensorflow/tensorflow:latest-gpu
```

---

## Questions frequentes - Taints

**Q: Pourquoi ne pas toujours utiliser NoExecute ?**
> R: NoExecute est **agressif** et cause des interruptions. NoSchedule suffit pour la maintenance planifiee.

**Q: Comment fonctionne l'operator 'Exists' ?**
> R: C'est un **wildcard**. Sans value = tolere toutes les valeurs. Sans key = tolere TOUT.

**Q: Taint seul vs Taint + nodeSelector ?**
> R: Taint **repousse** les autres pods. Mais le pod avec toleration peut aller **n'importe ou**. Ajoutez nodeSelector pour **forcer** le placement.

**Q: Comment voir les taints d'un node ?**
> R: `kubectl describe node <name> | grep Taints`

---

## Stratégies de Placement - Vue d'ensemble

| Mécanisme | Direction | Usage |
|-----------|-----------|-------|
| **nodeSelector** | Pod → Node | Simple, labels exacts |
| **Node Affinity** | Pod → Node | Avancé, expressions |
| **Taints/Tolerations** | Node → Pod | Exclusion de nodes |
| **Pod Affinity** | Pod → Pod | Co-localisation |
| **Pod Anti-Affinity** | Pod ↔ Pod | Séparation |
| **TopologySpread** | Pod → Zones | Distribution uniforme |

---

## Node Affinity - Concept

**Évolution de nodeSelector avec plus de flexibilité**

```yaml
apiVersion: v1
kind: Pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:  # Hard
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: ["eu-west-1a", "eu-west-1b"]
      preferredDuringSchedulingIgnoredDuringExecution:  # Soft
      - weight: 80
        preference:
          matchExpressions:
          - key: node-type
            operator: In
            values: ["high-memory"]
```

---

## Node Affinity - Opérateurs

| Opérateur | Description | Exemple |
|-----------|-------------|---------|
| `In` | Valeur dans liste | `zone In [a, b]` |
| `NotIn` | Valeur hors liste | `env NotIn [prod]` |
| `Exists` | Label existe | `gpu Exists` |
| `DoesNotExist` | Label absent | `spot DoesNotExist` |
| `Gt` | Supérieur à | `cpu-cores Gt 4` |
| `Lt` | Inférieur à | `memory Lt 32` |

---

## Pod Affinity - Co-localisation

**Scenario: Web App sur le meme node que Redis (latence minimale)**

```
┌─────────────────────────────────────────────────────┐
│                    Worker1                          │
│  ┌─────────────┐       ┌─────────────┐             │
│  │   Redis     │◄──────│   Web App   │             │
│  │ app: redis  │       │ affinity:   │             │
│  └─────────────┘       │  app=redis  │             │
│                        └─────────────┘             │
│                                                     │
│         Communication locale = latence ~0          │
└─────────────────────────────────────────────────────┘
```

```yaml
# Web App veut etre sur le meme node que Redis
apiVersion: v1
kind: Pod
metadata:
  name: web-app
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: redis       # Cherche pods avec app=redis
        topologyKey: kubernetes.io/hostname  # Meme node
  containers:
  - name: web
    image: nginx
```

---

## Pod Anti-Affinity - Séparation

**Répartir les pods pour haute disponibilité**

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: web
            topologyKey: kubernetes.io/hostname
# Chaque replica sur un node différent
```

**Cas d'usage:** Zookeeper, etcd, bases de données répliquées

---

## TopologySpreadConstraints - Distribution

**Répartition uniforme sur zones/nodes (K8s 1.19+ GA)**

```yaml
apiVersion: v1
kind: Pod
spec:
  topologySpreadConstraints:
  - maxSkew: 1                    # Écart max entre zones
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule  # ou ScheduleAnyway
    labelSelector:
      matchLabels:
        app: web
```

| Zone A | Zone B | Zone C | maxSkew=1 |
|--------|--------|--------|-----------|
| 3 pods | 2 pods | 2 pods | ✅ OK |
| 4 pods | 2 pods | 1 pod  | ❌ Violation |

---

## Stratégies de Placement - Récapitulatif

```
┌─────────────────────────────────────────────────────┐
│                    Scheduler                         │
├─────────────────────────────────────────────────────┤
│  1. Filtering (élimination)                         │
│     └─ Taints, Node Affinity (required)             │
│                                                      │
│  2. Scoring (préférence)                            │
│     └─ Node Affinity (preferred), weights           │
│                                                      │
│  3. Binding                                          │
│     └─ Pod assigné au node avec meilleur score     │
└─────────────────────────────────────────────────────┘
```

---

<!-- _class: lead -->

# Partie 4
## Migration CNI (25 min)

⚠️ **PARTIE LA PLUS CRITIQUE DU TD**

---

## Partie 4 - Timeline suggérée

- Backup: **3 min**
- Drain: **5 min**
- Retrait Flannel: **5 min**
- Installation Calico: **7 min**
- Validation: **5 min**

---

## Pourquoi migrer de Flannel vers Calico ?

| Feature | Flannel | Calico |
|---------|---------|--------|
| Complexité | Simple | Avancé |
| Network Policy | ❌ | ✅ |
| Routing | Overlay (VXLAN) | BGP + Overlay |
| Performance | Bonne | Excellente |
| Features | Basique | NetworkPolicy, encryption, etc. |

---

## Modèle OSI — où se situent IPIP et VXLAN

<div style="display:flex;flex-direction:column;gap:4px;font-size:0.82em;margin-top:6px">
  <div style="background:#f3e8ff;border-radius:6px;padding:7px 16px;border-left:5px solid #9333ea"><strong>L7 · Application</strong> &nbsp;·&nbsp; HTTP, gRPC, données du pod</div>
  <div style="background:#ede9fe;border-radius:6px;padding:7px 16px;border-left:5px solid #7c3aed;opacity:0.7"><strong>L6 · Présentation</strong> &nbsp;·&nbsp; <em>théorique — fondu dans L7 en TCP/IP (TLS, encodage)</em></div>
  <div style="background:#ede9fe;border-radius:6px;padding:7px 16px;border-left:5px solid #7c3aed;opacity:0.7"><strong>L5 · Session</strong> &nbsp;·&nbsp; <em>théorique — fondu dans L7 en TCP/IP (sessions HTTP, WebSocket)</em></div>
  <div style="text-align:center;color:#888;font-size:0.8em">▼</div>
  <div style="background:#bbf7d0;border-radius:6px;padding:7px 16px;border-left:5px solid #16a34a"><strong>L4 · Transport</strong> &nbsp;·&nbsp; TCP (proto 6) · UDP (proto 17) &nbsp;·&nbsp; <em>ports src / dst</em> &nbsp;← <strong>Security Groups filtrent ici</strong></div>
  <div style="text-align:center;color:#888;font-size:0.8em">▼</div>
  <div style="background:#fef08a;border-radius:6px;padding:7px 16px;border-left:5px solid #ca8a04"><strong>L3 · Réseau</strong> &nbsp;·&nbsp; IP · adresses src/dst · champ <strong>Protocol</strong> (1 octet) &nbsp;·&nbsp; <em>proto 4 = IPIP · proto 17 = UDP</em></div>
  <div style="text-align:center;color:#888;font-size:0.8em">▼</div>
  <div style="background:#e0f2fe;border-radius:6px;padding:7px 16px;border-left:5px solid #0284c7"><strong>L2 · Liaison</strong> &nbsp;·&nbsp; Ethernet · adresses MAC</div>
  <div style="text-align:center;color:#888;font-size:0.8em">▼</div>
  <div style="background:#f1f5f9;border-radius:6px;padding:7px 16px;border-left:5px solid #94a3b8"><strong>L1 · Physique</strong> &nbsp;·&nbsp; câble · fibre · switch virtuel</div>
</div>

> L5/L6 existent dans le modèle OSI théorique (1984) mais **n'ont pas d'équivalent en TCP/IP** — on parle uniquement de L3/L4/L7 en pratique. IPIP : L3→L3, pas de L4 → drop SG.

---

## IPIP — couches OSI du paquet encapsulé

<div style="font-size:0.82em">

<div style="background:#fee2e2;border-radius:6px;padding:8px 14px;margin:4px 0;border-left:4px solid #dc2626">
<strong>L3 outer</strong> · IP · src=<code>NodeA</code> dst=<code>NodeB</code> · <strong>Protocol = 4</strong> ← pas de L4, pas de port
</div>
<div style="background:#fecaca;border-radius:6px;padding:8px 14px;margin:4px 0 4px 30px;border-left:4px solid #ef4444">
<strong>L3 inner</strong> · IP · src=<code>10.244.0.5</code> (PodA) dst=<code>10.244.1.8</code> (PodB) · Protocol = 6
</div>
<div style="background:#fee2e2;border-radius:6px;padding:8px 14px;margin:4px 0 4px 60px;border-left:4px solid #f87171">
<strong>L4 inner</strong> · TCP · src=<code>54321</code> dst=<code>80</code>
</div>
<div style="background:#fef2f2;border-radius:6px;padding:8px 14px;margin:4px 0 4px 90px;border-left:4px solid #fca5a5">
<strong>L7 inner</strong> · HTTP GET /
</div>

</div>

<br/>

<div style="display:flex;align-items:center;gap:12px;font-size:0.85em;margin-top:8px">
  <div style="background:#fee2e2;border:2px solid #dc2626;border-radius:8px;padding:8px 14px;text-align:center"><strong>Paquet IPIP</strong><br/>proto=4</div>
  <div style="font-size:1.4em;color:#888">→</div>
  <div style="background:#fef9c3;border:2px solid #ca8a04;border-radius:8px;padding:8px 14px;text-align:center"><strong>Security Group</strong><br/>cherche L4…</div>
  <div style="font-size:1.4em;color:#888">→</div>
  <div style="background:#fee2e2;border:2px solid #dc2626;border-radius:8px;padding:8px 14px;text-align:center">pas de port ❌<br/><strong>DROP silencieux</strong><br/><small>au hyperviseur</small></div>
</div>

---

## VXLAN — couches OSI du paquet encapsulé

<div style="font-size:0.82em">

<div style="background:#dcfce7;border-radius:6px;padding:8px 14px;margin:4px 0;border-left:4px solid #16a34a">
<strong>L3 outer</strong> · IP · src=<code>NodeA</code> dst=<code>NodeB</code> · Protocol = 17 (UDP)
</div>
<div style="background:#bbf7d0;border-radius:6px;padding:8px 14px;margin:4px 0 4px 30px;border-left:4px solid #22c55e">
<strong>L4 outer</strong> · UDP · src=<code>ephémère</code> dst=<strong><code>4789</code></strong> ← filtrable par SG ✅
</div>
<div style="background:#f0fdf4;border-radius:6px;padding:8px 14px;margin:4px 0 4px 60px;border-left:4px solid #86efac">
<strong>VXLAN header</strong> · VNI (Virtual Network Identifier)
</div>
<div style="background:#dcfce7;border-radius:6px;padding:8px 14px;margin:4px 0 4px 90px;border-left:4px solid #4ade80">
<strong>L2 inner</strong> · Ethernet · MAC PodA → MAC PodB
</div>
<div style="background:#f0fdf4;border-radius:6px;padding:8px 14px;margin:4px 0 4px 90px;border-left:4px solid #86efac">
<strong>L3 inner</strong> · IP · <code>10.244.0.5</code> → <code>10.244.1.8</code> &nbsp;|&nbsp; <strong>L4</strong> · TCP :80 &nbsp;|&nbsp; <strong>L7</strong> · HTTP
</div>

</div>

<br/>

> Calico par défaut = IPIP (bare-metal). Sur Exoscale → `vxlanMode: Always` dans le manifest.

---

## 5.1 - Backup

![bg right:40% fit](diagrams/cni-migration.png)

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
cd scripts/partie-04-migration-cni
./01-backup-state.sh
```

---

## 5.2 - Drain progressif

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
./02-drain-nodes.sh
```

Observer l'évacuation progressive des pods

### Pourquoi drainer ?

✅ Évacuation propre des pods
✅ Évite les interruptions de connexion
✅ Respecte les PodDisruptionBudgets

### Problème potentiel
Drain bloqué par des pods sans controller

```bash
kubectl drain <node> --force --delete-emptydir-data
```

---

## 5.3 - Retrait de Flannel ⚠️ ordre impératif

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER puis sur chaque NŒUD:**
```bash
./03-remove-flannel.sh master   # depuis le master
sudo ./03-remove-flannel.sh node  # sur chaque nœud
```

### Pourquoi en deux temps ?

- **`master`** : supprime les ressources Kubernetes (DaemonSet, ConfigMap…)
- **`node`** : nettoie les interfaces réseau (`flannel.1`) et les règles iptables locales

### ⛔ Ne PAS redémarrer kubelet avant d'avoir installé Calico
Kubelet sans CNI = nœud `NotReady`, tous les pods perdent leur connectivité

---

## 5.4 - Installation de Calico

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
./04-install-calico.sh
```

⚠️ Le téléchargement peut prendre du temps — le script configure automatiquement le mode **VXLAN**

### Ensuite — redémarrer kubelet sur **chaque nœud**
```bash
sudo systemctl start kubelet
```
> ⛔ Ne faire cette étape qu'**après** que Calico soit Ready

---

<style scoped>
h2 { margin-bottom: 4px; }
pre { font-size: 13px; margin-top: 6px; }
</style>

## IPIP vs VXLAN — encapsulation et cloud firewalls

<svg width="1100" height="235" viewBox="0 0 1100 235" xmlns="http://www.w3.org/2000/svg" font-family="sans-serif">
<defs>
  <marker id="arrgray" markerWidth="7" markerHeight="6" refX="6" refY="3" orient="auto"><path d="M0,0 L7,3 L0,6 Z" fill="#6b7280"/></marker>
  <marker id="arrgreen" markerWidth="7" markerHeight="6" refX="6" refY="3" orient="auto"><path d="M0,0 L7,3 L0,6 Z" fill="#16a34a"/></marker>
</defs>
<text x="44" y="34" text-anchor="middle" fill="#dc2626" font-size="14" font-weight="bold">❌ IPIP</text>
<text x="44" y="50" text-anchor="middle" fill="#dc2626" font-size="11">IP proto 4</text>
<rect x="84" y="12" width="88" height="64" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="128" y="31" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">Node A</text>
<text x="128" y="47" text-anchor="middle" fill="#1d4ed8" font-size="10">10.0.0.1</text>
<text x="128" y="62" text-anchor="middle" fill="#0369a1" font-size="10">pod 10.244.0.1</text>
<line x1="174" y1="44" x2="192" y2="44" stroke="#6b7280" stroke-width="1.5" marker-end="url(#arrgray)"/>
<rect x="195" y="12" width="500" height="64" rx="6" fill="#fecaca" stroke="#dc2626" stroke-width="2"/>
<text x="445" y="29" text-anchor="middle" fill="#7f1d1d" font-size="11" font-weight="bold">IP outer — src 10.0.0.1 → dst 10.0.0.2 | protocol: 4 (IP-in-IP)</text>
<rect x="207" y="34" width="476" height="35" rx="4" fill="#fee2e2" stroke="#ef4444" stroke-width="1.5"/>
<text x="445" y="50" text-anchor="middle" fill="#991b1b" font-size="11" font-weight="bold">IP inner — 10.244.0.1 (pod A) → 10.244.1.1 (pod B)</text>
<text x="445" y="63" text-anchor="middle" fill="#b91c1c" font-size="10">payload</text>
<line x1="697" y1="44" x2="715" y2="44" stroke="#6b7280" stroke-width="1.5" marker-end="url(#arrgray)"/>
<rect x="718" y="12" width="148" height="64" rx="8" fill="#fca5a5" stroke="#dc2626" stroke-width="2.5"/>
<text x="792" y="32" text-anchor="middle" fill="#7f1d1d" font-size="12" font-weight="bold">🔥 Security</text>
<text x="792" y="48" text-anchor="middle" fill="#7f1d1d" font-size="12" font-weight="bold">Group</text>
<text x="792" y="67" text-anchor="middle" fill="#dc2626" font-size="12" font-weight="bold">proto 4 → DROP</text>
<line x1="868" y1="44" x2="882" y2="44" stroke="#dc2626" stroke-width="1.5" stroke-dasharray="5,3"/>
<rect x="884" y="12" width="88" height="64" rx="8" fill="#f3f4f6" stroke="#d1d5db" stroke-width="1.5"/>
<text x="928" y="31" text-anchor="middle" fill="#9ca3af" font-size="13" font-weight="bold">Node B</text>
<text x="928" y="47" text-anchor="middle" fill="#9ca3af" font-size="10">injoignable</text>
<text x="928" y="63" text-anchor="middle" fill="#ef4444" font-size="11" font-weight="bold">calico 0/1 ✗</text>
<text x="540" y="93" text-anchor="middle" fill="#dc2626" font-size="11" font-style="italic">Security group bloque IP protocol 4 → tunnel Calico ne s'établit pas → calico-node reste 0/1</text>
<line x1="20" y1="104" x2="1080" y2="104" stroke="#e5e7eb" stroke-width="1.5" stroke-dasharray="8,4"/>
<text x="44" y="132" text-anchor="middle" fill="#16a34a" font-size="14" font-weight="bold">✅ VXLAN</text>
<text x="44" y="148" text-anchor="middle" fill="#16a34a" font-size="11">UDP 4789</text>
<rect x="84" y="113" width="88" height="98" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="128" y="133" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">Node A</text>
<text x="128" y="150" text-anchor="middle" fill="#1d4ed8" font-size="10">10.0.0.1</text>
<text x="128" y="166" text-anchor="middle" fill="#0369a1" font-size="10">pod 10.244.0.1</text>
<line x1="174" y1="162" x2="192" y2="162" stroke="#6b7280" stroke-width="1.5" marker-end="url(#arrgray)"/>
<rect x="195" y="113" width="500" height="98" rx="6" fill="#bbf7d0" stroke="#16a34a" stroke-width="2"/>
<text x="445" y="129" text-anchor="middle" fill="#14532d" font-size="11" font-weight="bold">IP outer — src: 10.0.0.1 → dst: 10.0.0.2</text>
<rect x="207" y="134" width="476" height="71" rx="4" fill="#d1fae5" stroke="#22c55e" stroke-width="1.5"/>
<text x="445" y="149" text-anchor="middle" fill="#166534" font-size="11" font-weight="bold">UDP header — port: 4789</text>
<rect x="219" y="154" width="452" height="45" rx="4" fill="#ecfdf5" stroke="#34d399" stroke-width="1.5"/>
<text x="445" y="168" text-anchor="middle" fill="#166534" font-size="11">VXLAN header (VNI)</text>
<rect x="231" y="172" width="428" height="22" rx="3" fill="#f0fdf4" stroke="#6ee7b7" stroke-width="1.5"/>
<text x="445" y="187" text-anchor="middle" fill="#14532d" font-size="11">IP inner — 10.244.0.1 (pod A) → 10.244.1.1 (pod B) + payload</text>
<line x1="697" y1="162" x2="715" y2="162" stroke="#6b7280" stroke-width="1.5" marker-end="url(#arrgray)"/>
<rect x="718" y="113" width="148" height="98" rx="8" fill="#bbf7d0" stroke="#16a34a" stroke-width="2.5"/>
<text x="792" y="148" text-anchor="middle" fill="#14532d" font-size="12" font-weight="bold">🔥 Security</text>
<text x="792" y="165" text-anchor="middle" fill="#14532d" font-size="12" font-weight="bold">Group</text>
<text x="792" y="194" text-anchor="middle" fill="#16a34a" font-size="12" font-weight="bold">UDP 4789 → ALLOW</text>
<line x1="868" y1="162" x2="882" y2="162" stroke="#16a34a" stroke-width="2" marker-end="url(#arrgreen)"/>
<rect x="884" y="113" width="88" height="98" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="1.5"/>
<text x="928" y="133" text-anchor="middle" fill="#14532d" font-size="13" font-weight="bold">Node B</text>
<text x="928" y="150" text-anchor="middle" fill="#166534" font-size="10">10.0.0.2</text>
<text x="928" y="166" text-anchor="middle" fill="#0369a1" font-size="10">pod 10.244.1.1</text>
<text x="928" y="200" text-anchor="middle" fill="#16a34a" font-size="12" font-weight="bold">calico 1/1 ✓</text>
<text x="540" y="226" text-anchor="middle" fill="#16a34a" font-size="11" font-style="italic">UDP est autorisé par défaut → tunnel VXLAN établi → calico-node passe Ready 1/1</text>
</svg>

```bash
# Patch manuel si calico-node restent 0/1 (IPIP installé sans VXLAN) :
kubectl patch ippools default-ipv4-ippool --type=merge \
  -p '{"spec": {"ipipMode": "Never", "vxlanMode": "Always"}}'
kubectl rollout restart daemonset/calico-node -n kube-system
```

---

## 5.5 - Uncordon et validation

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
./05-uncordon-and-validate.sh
cd ../../validation && ./validate-partie.sh 4
```

### Tests obligatoires

- Nœuds de nouveau `Ready` et `Schedulable`
- Connectivité inter-pods
- DNS fonctionnel
- Services fonctionnels

⚠️ **Si un test échoue, ne pas passer à la suite !**

---

<!-- _class: lead -->

# Partie 5
## Drain et Maintenance (20 min)

---

## Partie 5 - Timeline suggérée

- PodDisruptionBudget: **7 min**
- DaemonSets: **7 min**
- Simulation panne: **6 min**

---

![bg fit](diagrams/pod-disruption-budget.png)

---

## PodDisruptionBudget - Concept

**Protection de la disponibilité pendant opérations volontaires**

| Opération | Volontaire ? | Respecte PDB ? |
|-----------|-------------|----------------|
| `kubectl drain` | Oui | ✅ Oui |
| `kubectl delete pod` | Oui | ✅ Oui |
| Node crash | Non | ❌ Non |
| OOM Kill | Non | ❌ Non |

---

## Drain + PDB — ce qui se passe étape par étape

<div style="font-size:0.78em">

<!-- État initial -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:90px;font-weight:bold;color:#6b7280">① Initial</div>
  <div style="display:flex;gap:3px">
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">A<br/><small>w1</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">B<br/><small>w1</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">C<br/><small>w1</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">D<br/><small>w2</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">E<br/><small>w2</small></div>
  </div>
  <div style="color:#16a34a;font-size:0.85em">PDB minAvailable=3 · 5/5 dispo · <strong>2 disruptions autorisées</strong></div>
</div>

<!-- kubectl drain -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:90px;font-weight:bold;color:#6b7280">② drain<br/>worker1</div>
  <div style="background:#fef9c3;border:2px solid #ca8a04;border-radius:5px;padding:3px 8px;font-size:0.85em"><code>kubectl drain worker1</code><br/>cordon + éviction</div>
  <div style="font-size:1.2em">→</div>
  <div style="display:flex;gap:3px">
    <div style="background:#fee2e2;border:2px dashed #dc2626;border-radius:5px;padding:3px 7px;color:#dc2626">A<br/><small>évincé</small></div>
    <div style="background:#fee2e2;border:2px dashed #dc2626;border-radius:5px;padding:3px 7px;color:#dc2626">B<br/><small>évincé</small></div>
    <div style="background:#ffedd5;border:2px dashed #ea580c;border-radius:5px;padding:3px 7px;color:#ea580c">C<br/><small>bloqué ⏸</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">D<br/><small>w2</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">E<br/><small>w2</small></div>
  </div>
  <div style="color:#ca8a04;font-size:0.85em">A+B évincés (2 dispo) → 3ème éviction bloquée tant que A'/B' pas Ready</div>
</div>

<!-- reschedulé -->
<div style="display:flex;align-items:flex-start;gap:8px;margin-bottom:6px">
  <div style="width:90px;font-weight:bold;color:#6b7280;padding-top:4px">③ reschedule<br/>A' B' → Ready</div>
  <div style="display:flex;flex-direction:column;gap:4px">
    <div style="display:flex;gap:3px;align-items:center">
      <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 7px">A'<br/><small>w2 ✅</small></div>
      <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 7px">B'<br/><small>w2 ✅</small></div>
      <div style="background:#fee2e2;border:2px dashed #dc2626;border-radius:5px;padding:3px 7px;color:#dc2626">C<br/><small>évincé</small></div>
      <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">D<br/><small>w2</small></div>
      <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">E<br/><small>w2</small></div>
    </div>
    <div style="background:#f0f9ff;border-left:3px solid #0284c7;padding:4px 8px;border-radius:3px;color:#0369a1;font-size:0.82em">
      Le drain vide <strong>tous</strong> les pods de worker1 — C doit partir aussi car il est sur worker1 ·
      Le PDB contrôle le <strong>rythme</strong> : il attend que A' et B' soient <strong>Ready</strong> avant d'autoriser l'éviction de C ·
      Sans PDB, A, B et C auraient été évincés simultanément → risque de tomber sous minAvailable
    </div>
  </div>
</div>

<!-- final -->
<div style="display:flex;align-items:center;gap:8px">
  <div style="width:90px;font-weight:bold;color:#6b7280">④ Final</div>
  <div style="display:flex;gap:3px">
    <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 7px">A'<br/><small>w2</small></div>
    <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 7px">B'<br/><small>w2</small></div>
    <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 7px">C'<br/><small>w2</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">D<br/><small>w2</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 7px">E<br/><small>w2</small></div>
    <div style="background:#f1f5f9;border:2px dashed #94a3b8;border-radius:5px;padding:3px 7px;color:#94a3b8">w1<br/><small>cordonné</small></div>
  </div>
  <div style="color:#16a34a;font-size:0.85em">5/5 Running · worker1 vide · prêt pour maintenance</div>
</div>

</div>

---

## PodDisruptionBudget - Configuration

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2          # OU maxUnavailable: 1
  selector:
    matchLabels:
      app: my-app
---
# Équivalent avec pourcentage
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  maxUnavailable: 25%      # Sur 4 replicas = 1 pod max
  selector:
    matchLabels:
      app: my-app
```

---

## PodDisruptionBudget - En pratique

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
cd scripts/partie-05-drain-maintenance
./01-test-pdb.sh
```

**Démonstration:**
1. Drain qui **respecte le PDB** (éviction séquentielle)
2. Drain qui **violerait le PDB** (bloqué, attente)

```bash
# Voir le status du PDB
kubectl get pdb app-pdb -o wide
# ALLOWED DISRUPTIONS montre combien de pods peuvent être évincés
```

---

## PodDisruptionBudget - Bonnes pratiques

| Situation | Recommandation |
|-----------|----------------|
| App stateless 3+ replicas | `maxUnavailable: 1` |
| App stateful (DB) | `minAvailable: 51%` (quorum) |
| Batch jobs | Pas de PDB nécessaire |
| Single replica | ⚠️ PDB bloquera tout drain! |

**Piège courant:** `minAvailable: 1` avec 1 replica = drain impossible

---

## 5.2 - DaemonSets

![bg right:40% fit](diagrams/node-drain-process.png)

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
./02-drain-daemonsets.sh
```

Observer l'erreur, puis avec `--ignore-daemonsets`

---

## 5.2 - DaemonSets (suite)

### Point pédagogique
Les DaemonSets sont spéciaux

### Pourquoi ?

**CNI** (Calico, Flannel) → Réseau node-level
**Monitoring** (node-exporter) → Métriques par nœud
**Logging** (fluentd) → Collecte locale des logs

**Démo:** Tentative de drain sans `--ignore-daemonsets`

Le drain échoue car les DaemonSets doivent rester sur le nœud

---

## Drain + DaemonSet — ce qui se passe

<div style="font-size:0.8em">

<!-- Initial -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:100px;font-weight:bold;color:#6b7280">① Initial</div>
  <div style="display:flex;gap:6px;align-items:flex-end">
    <div style="display:flex;flex-direction:column;gap:3px;align-items:center">
      <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">App A<br/><small>w1</small></div>
      <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 8px">DS-w1<br/><small>DaemonSet</small></div>
    </div>
    <div style="display:flex;flex-direction:column;gap:3px;align-items:center">
      <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">App B<br/><small>w2</small></div>
      <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 8px">DS-w2<br/><small>DaemonSet</small></div>
    </div>
  </div>
  <div style="color:#6b7280;font-size:0.85em">1 pod DaemonSet par nœud — obligatoire</div>
</div>

<!-- Sans flag -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:100px;font-weight:bold;color:#6b7280">② drain<br/><small>sans flag</small></div>
  <div style="background:#fee2e2;border:2px solid #dc2626;border-radius:5px;padding:4px 10px;font-size:0.85em">
    <code>kubectl drain worker1</code><br/>❌ <strong>ERREUR</strong> : cannot delete DaemonSet-managed Pods
  </div>
  <div style="background:#fef9c3;border-left:3px solid #ca8a04;padding:4px 8px;border-radius:3px;font-size:0.82em;color:#92400e">
    Le drain refuse de supprimer DS-w1 car le DaemonSet le recréerait immédiatement → boucle infinie
  </div>
</div>

<!-- Avec flag -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:100px;font-weight:bold;color:#6b7280">③ drain<br/><small>--ignore-daemonsets</small></div>
  <div style="display:flex;gap:6px;align-items:flex-end">
    <div style="display:flex;flex-direction:column;gap:3px;align-items:center">
      <div style="background:#fee2e2;border:2px dashed #dc2626;border-radius:5px;padding:3px 8px;color:#dc2626">App A<br/><small>évincé</small></div>
      <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 8px">DS-w1<br/><small>ignoré ✅</small></div>
    </div>
    <div style="display:flex;flex-direction:column;gap:3px;align-items:center">
      <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">App B<br/><small>w2</small></div>
      <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 8px">DS-w2<br/><small>DaemonSet</small></div>
    </div>
    <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 8px">App A'<br/><small>w2</small></div>
  </div>
  <div style="color:#0284c7;font-size:0.85em">App A reschedulée · DS-w1 reste en place — il est node-level</div>
</div>

</div>

> Le pod DaemonSet **reste sur le nœud drainé** — c'est voulu : il fournit un service au niveau du nœud (réseau, logs, monitoring) qui ne peut pas migrer.

---

## 5.3 - Simulation de panne

### 📝 EXERCICE ÉLÈVE
```bash
./03-simulate-node-failure.sh
cd ../../validation && ./validate-partie.sh 5
```

⚠️ **Section interactive**

### Points d'observation

| Étape | Délai |
|-------|-------|
| Détection NotReady | ~40s |
| Pods Terminating | ~5 min |
| Recréation pods | Après éviction |

---

## Simulation de panne — timeline Kubernetes

<div style="font-size:0.8em">

<!-- Initial -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:110px;font-weight:bold;color:#6b7280">① t=0<br/>Panne kubelet</div>
  <div style="display:flex;gap:4px">
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 1<br/><small>w1</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 2<br/><small>w1</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 3<br/><small>w2</small></div>
  </div>
  <div style="background:#fee2e2;border:2px dashed #dc2626;border-radius:5px;padding:3px 10px;color:#dc2626">worker1<br/><small>kubelet arrêté</small></div>
  <div style="color:#6b7280;font-size:0.82em">Les pods semblent Running — l'API ne sait pas encore</div>
</div>

<!-- t=40s -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:110px;font-weight:bold;color:#6b7280">② t≈40s<br/>NotReady</div>
  <div style="display:flex;gap:4px">
    <div style="background:#ffedd5;border:2px dashed #ea580c;border-radius:5px;padding:3px 8px;color:#ea580c">Pod 1<br/><small>Unknown</small></div>
    <div style="background:#ffedd5;border:2px dashed #ea580c;border-radius:5px;padding:3px 8px;color:#ea580c">Pod 2<br/><small>Unknown</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 3<br/><small>w2</small></div>
  </div>
  <div style="background:#fef9c3;border-left:3px solid #ca8a04;padding:4px 8px;border-radius:3px;font-size:0.82em;color:#92400e">
    <code>node-monitor-grace-period=40s</code> · node-controller marque worker1 <strong>NotReady</strong>
  </div>
</div>

<!-- t=5min -->
<div style="display:flex;align-items:center;gap:8px;margin-bottom:6px">
  <div style="width:110px;font-weight:bold;color:#6b7280">③ t≈5min<br/>Eviction</div>
  <div style="display:flex;gap:4px">
    <div style="background:#fee2e2;border:2px dashed #dc2626;border-radius:5px;padding:3px 8px;color:#dc2626">Pod 1<br/><small>Terminating</small></div>
    <div style="background:#fee2e2;border:2px dashed #dc2626;border-radius:5px;padding:3px 8px;color:#dc2626">Pod 2<br/><small>Terminating</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 3<br/><small>w2</small></div>
    <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 8px">Pod 1'<br/><small>w2 🆕</small></div>
    <div style="background:#e0f2fe;border:2px solid #0284c7;border-radius:5px;padding:3px 8px">Pod 2'<br/><small>w2 🆕</small></div>
  </div>
  <div style="color:#dc2626;font-size:0.82em"><code>pod-eviction-timeout=5min</code> · pods recréés sur nœuds sains</div>
</div>

<!-- récupération -->
<div style="display:flex;align-items:center;gap:8px">
  <div style="width:110px;font-weight:bold;color:#6b7280">④ Récupération<br/>kubelet restart</div>
  <div style="display:flex;gap:4px">
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 1'<br/><small>w2</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 2'<br/><small>w2</small></div>
    <div style="background:#dcfce7;border:2px solid #16a34a;border-radius:5px;padding:3px 8px">Pod 3<br/><small>w2</small></div>
    <div style="background:#f1f5f9;border:2px solid #94a3b8;border-radius:5px;padding:3px 8px;color:#6b7280">worker1<br/><small>Ready (vide)</small></div>
  </div>
  <div style="color:#16a34a;font-size:0.82em">worker1 revient Ready · anciens pods <strong>ne reviennent pas</strong> (déjà remplacés)</div>
</div>

</div>

---

## Question - Délai de détection

**Q: Comment réduire le délai de détection ?**
> R: Configurer `node-monitor-grace-period` et `pod-eviction-timeout` dans kube-controller-manager.
>
> ⚠️ Attention: trop court = false positives

---

<!-- _class: lead -->

# Partie 6
## etcd & etcdctl — La source de vérité du cluster

---

## etcd — rôle dans Kubernetes

### L'unique source de vérité

```
┌─────────────────────────────────────────────────────────────┐
│                      CONTROL PLANE                          │
│                                                             │
│  kubectl → API Server → etcd  ← tout l'état du cluster     │
│                ↑                                            │
│  scheduler, controller-manager lisent/écrivent via API      │
└─────────────────────────────────────────────────────────────┘
```

**Ce qu'etcd stocke :**
- Tous les objets Kubernetes (Pods, Services, ConfigMaps…)
- L'état désiré ET l'état observé
- Les secrets (chiffrés at rest depuis K8s 1.13+)

> Perte d'etcd = perte du cluster. C'est le seul composant **stateful**.

---

## etcd dans kubeadm — stacked vs external

### Stacked (défaut kubeadm)

```
┌─────────── Master node ───────────┐
│  API Server                       │
│  scheduler / controller-manager   │
│  etcd  ← tourne sur le même nœud  │
└───────────────────────────────────┘
```

### External (production multi-master)

```
Master nodes          etcd cluster
┌──────────┐         ┌─────┐ ┌─────┐ ┌─────┐
│ API Srvr │────────►│etcd │ │etcd │ │etcd │
└──────────┘         └─────┘ └─────┘ └─────┘
                      3 ou 5 membres (quorum)
```

| | Stacked | External |
|---|---|---|
| Simplicité | ✓ | Plus complexe |
| HA réelle | Partielle | ✓ |
| Ce TD | **✓ stacked** | — |

---

## etcdctl — setup et authentification

### Variables d'environnement obligatoires

```bash
# API v3 obligatoire (v2 = legacy)
export ETCDCTL_API=3

# Certificats TLS (kubeadm stacked)
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

# Endpoint local
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
```

### Vérifier que tout fonctionne

```bash
etcdctl endpoint health
# 127.0.0.1:2379 is healthy: committed revision: 42156
```

⚠️ Sans `ETCDCTL_API=3` → erreurs cryptiques ou réponses vides

---

## etcdctl — commandes essentielles

### Santé du cluster

```bash
etcdctl endpoint status --write-out=table
# ENDPOINT             ID    VERSION  DB SIZE  IS LEADER
# 127.0.0.1:2379  abc123  3.5.12   8.2 MB   true

etcdctl member list --write-out=table
# ID     STATUS   NAME     PEER ADDRS             IS LEARNER
# abc123 started  master   https://10.0.0.1:2380  false
```

### Inspection des données

```bash
# Lister toutes les clés (namespace Kubernetes)
etcdctl get / --prefix --keys-only | head -20

# Lire un objet spécifique
etcdctl get /registry/pods/default/mon-pod
```

> L'API Server est une façade : tout ce que kubectl retourne vient d'etcd

---

## Backup etcd — snapshot avant upgrade

### Procédure obligatoire avant tout upgrade

```bash
# 1. Créer le répertoire de backup
sudo mkdir -p /var/backup/etcd

# 2. Snapshot
sudo ETCDCTL_API=3 etcdctl snapshot save /var/backup/etcd/snapshot-$(date +%Y%m%d-%H%M).db \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  --endpoints=https://127.0.0.1:2379

# 3. Vérifier le snapshot
sudo ETCDCTL_API=3 etcdctl snapshot status /var/backup/etcd/snapshot-*.db \
  --write-out=table
```

**Output attendu :**
```
HASH       REVISION  TOTAL KEYS  TOTAL SIZE
a1b2c3d4   42156     1247        8.2 MB
```

---

## Restauration depuis un snapshot

### Scénario : cluster cassé, etcd corrompu

```bash
# 1. Arrêter l'API server (pod statique → déplacer le manifest)
sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# 2. Restaurer le snapshot
sudo ETCDCTL_API=3 etcdctl snapshot restore /var/backup/etcd/snapshot.db \
  --data-dir=/var/lib/etcd-restored \
  --name=master \
  --initial-cluster=master=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380

# 3. Pointer etcd vers le nouveau data-dir
# Modifier /tmp/etcd.yaml : --data-dir=/var/lib/etcd-restored

# 4. Remettre le manifest → etcd redémarre
sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/
```

⚠️ La restauration **revert l'état complet** — tous les objets créés après le snapshot sont perdus

---

## etcdctl — points instructeur

### Pièges fréquents

| Piège | Symptôme | Fix |
|-------|----------|-----|
| `ETCDCTL_API` non défini | `Error: unknown command` | `export ETCDCTL_API=3` |
| Mauvais certificat | `x509: certificate signed by unknown authority` | Vérifier les 3 chemins PKI |
| etcd pod stacked | `connection refused` pendant restore | Déplacer le manifest d'abord |
| data-dir existant | `member already exists` | Supprimer `/var/lib/etcd` avant restore |

### Quand utiliser etcdctl en TD ?

- **Avant l'upgrade** (Partie 6) → snapshot obligatoire
- **Curiosité pédagogique** → `get / --prefix --keys-only` pour voir l'état brut
- **Scénario de panne** → restauration (optionnel si temps)

---

<!-- _class: lead -->

# Partie 7
## Upgrade du Cluster (25 min)

---

## Partie 7 - Timeline suggérée

- Check versions: **3 min**
- Upgrade control plane: **7 min**
- Upgrade master kubelet: **5 min**
- Upgrade workers: **8 min** (4 min × 2)
- Validation: **2 min**

---

## Concepts de version Kubernetes

### Structure: `v1.28.3`

- **Major:** Changements majeurs (rare)
- **Minor:** Features, API changes (~4 mois)
- **Patch:** Bugfixes, security patches

### Politique de support
**N, N-1, N-2**

---

## 6.1 - Check versions

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
cd scripts/partie-06-upgrade
./01-check-versions.sh
```

---

## Ordre d'upgrade obligatoire

1. **etcd** (si externe)
2. **Control plane**
3. **Workers**
4. **Addons** (CNI, etc.)

⚠️ Ordre crucial pour la compatibilité !

---

## 6.2 - Upgrade control plane

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
./02-upgrade-control-plane.sh
```

### Point critique
`kubeadm upgrade plan`

**Insistez pour que les étudiants lisent attentivement le plan !**

### Informations dans le plan

- Versions actuelles
- Versions disponibles
- Composants à upgrader
- Commande exacte à exécuter

---

## 6.3 - Upgrade kubelet master

### 📝 EXERCICE ÉLÈVE
**Script sur le MASTER:**
```bash
./03-upgrade-master-kubelet.sh
```

### Point pédagogique
**Pourquoi kubelet séparément ?**

- Kubelet tourne sur **chaque nœud**
- Nécessite un **redémarrage local**
- **Drain requis** pour éviter les interruptions

---

## 6.4 - Upgrade workers

### 📝 EXERCICE ÉLÈVE
**Script sur chaque WORKER:**
```bash
./04-upgrade-worker.sh
```

### Procédure par worker
**Drain → Upgrade → Uncordon**

### Ordre recommandé

- Un worker à la fois
- Valider entre chaque worker

**Si temps limité:** Upgrader un seul worker en démo

---

## 6.5 - Validation post-upgrade

### 📝 EXERCICE ÉLÈVE
```bash
./05-verify-upgrade.sh
cd ../../validation && ./validate-partie.sh 6
```

### Checklist

- Nœuds Ready + Versions cohérentes
- Pods système Running
- Nouveau déploiement OK
- DNS + Services fonctionnels

---

<!-- _class: lead -->

# Partie 8
## RuntimeClass & gVisor (25 min)

---

## Partie 8 - Timeline suggérée

- Install gVisor sur les nœuds: **7 min**
- Création RuntimeClass: **3 min**
- Test d'isolation: **5 min**
- Déploiement avec RuntimeClass: **5 min**
- Comparaison de performance: **5 min**

---

## Le problème — isolation des containers

- `runc` partage le **kernel hôte** avec tous les containers
- CVE kernel = **tous les containers exposés**
- Attaque kernel: escalade de privilèges possible

<svg width="760" height="185" viewBox="0 0 760 185" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<defs>
<marker id="p8a1" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#6b7280"/></marker>
<marker id="p8a2" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#ef4444"/></marker>
<marker id="p8a3" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#16a34a"/></marker>
</defs>
<text x="150" y="16" text-anchor="middle" font-size="14" font-weight="bold" fill="#dc2626">runc (défaut)</text>
<rect x="15" y="24" width="120" height="40" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="75" y="49" text-anchor="middle" fill="#1d4ed8" font-weight="bold">Container A</text>
<rect x="155" y="24" width="120" height="40" rx="5" fill="#fee2e2" stroke="#ef4444" stroke-width="1.5"/>
<text x="215" y="42" text-anchor="middle" fill="#b91c1c" font-weight="bold">Container B</text>
<text x="215" y="57" text-anchor="middle" fill="#b91c1c" font-size="11">⚠ compromis</text>
<line x1="75" y1="64" x2="75" y2="100" stroke="#6b7280" stroke-width="1.5" marker-end="url(#p8a1)"/>
<line x1="215" y1="64" x2="215" y2="100" stroke="#ef4444" stroke-width="2" marker-end="url(#p8a2)"/>
<rect x="15" y="103" width="260" height="38" rx="5" fill="#fef3c7" stroke="#f59e0b" stroke-width="2"/>
<text x="145" y="120" text-anchor="middle" fill="#78350f" font-weight="bold">Kernel Linux hôte</text>
<text x="145" y="135" text-anchor="middle" fill="#78350f" font-size="11">partagé par tous les containers</text>
<text x="145" y="158" text-anchor="middle" font-size="12" fill="#dc2626">⚡ CVE kernel → tous les containers exposés</text>
<line x1="310" y1="10" x2="310" y2="175" stroke="#d1d5db" stroke-width="1" stroke-dasharray="5,3"/>
<text x="450" y="16" text-anchor="middle" font-size="14" font-weight="bold" fill="#16a34a">gVisor</text>
<rect x="325" y="24" width="110" height="35" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="380" y="46" text-anchor="middle" fill="#1d4ed8" font-weight="bold">Container A</text>
<rect x="455" y="24" width="110" height="35" rx="5" fill="#fee2e2" stroke="#ef4444" stroke-width="1.5"/>
<text x="510" y="40" text-anchor="middle" fill="#b91c1c" font-weight="bold">Container B</text>
<text x="510" y="53" text-anchor="middle" fill="#b91c1c" font-size="11">⚠ compromis</text>
<line x1="380" y1="59" x2="380" y2="76" stroke="#6b7280" stroke-width="1.5" marker-end="url(#p8a1)"/>
<line x1="510" y1="59" x2="510" y2="76" stroke="#ef4444" stroke-width="1.5" marker-end="url(#p8a2)"/>
<rect x="325" y="78" width="110" height="30" rx="5" fill="#dcfce7" stroke="#16a34a" stroke-width="1.5"/>
<text x="380" y="98" text-anchor="middle" fill="#166534">🛡 Sentry A</text>
<rect x="455" y="78" width="110" height="30" rx="5" fill="#dcfce7" stroke="#16a34a" stroke-width="1.5"/>
<text x="510" y="98" text-anchor="middle" fill="#166534">🛡 Sentry B</text>
<line x1="380" y1="108" x2="380" y2="127" stroke="#16a34a" stroke-width="1.5" marker-end="url(#p8a3)"/>
<line x1="510" y1="108" x2="510" y2="127" stroke="#16a34a" stroke-width="1.5" marker-end="url(#p8a3)"/>
<rect x="325" y="129" width="240" height="33" rx="5" fill="#fef3c7" stroke="#f59e0b" stroke-width="1.5"/>
<text x="445" y="147" text-anchor="middle" fill="#78350f" font-weight="bold">Kernel hôte</text>
<text x="445" y="158" text-anchor="middle" fill="#78350f" font-size="11">syscalls filtrés (limités)</text>
<text x="445" y="180" text-anchor="middle" font-size="12" fill="#16a34a">✓ B compromis reste isolé dans son Sentry</text>
</svg>

**Solution: interposer un kernel par container**

---

## gVisor — kernel en espace utilisateur

- Intercepte les **syscalls** avant le kernel hôte
- ~70% des syscalls Linux implémentés
- Composant clé: **Sentry** (kernel en Go/userspace)

<svg width="740" height="80" viewBox="0 0 740 80" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<defs><marker id="p8a4" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#6b7280"/></marker></defs>
<rect x="5" y="20" width="80" height="38" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="45" y="44" text-anchor="middle" fill="#1d4ed8" font-weight="bold">App</text>
<line x1="85" y1="39" x2="148" y2="39" stroke="#6b7280" stroke-width="1.5" marker-end="url(#p8a4)"/>
<text x="117" y="32" text-anchor="middle" fill="#6b7280" font-size="11">syscall</text>
<text x="117" y="55" text-anchor="middle" fill="#6b7280" font-size="11">(tous)</text>
<rect x="151" y="10" width="175" height="58" rx="5" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
<text x="238" y="36" text-anchor="middle" fill="#166534" font-weight="bold">gVisor Sentry</text>
<text x="238" y="53" text-anchor="middle" fill="#166534" font-size="11">kernel userspace (Go)</text>
<line x1="326" y1="39" x2="395" y2="39" stroke="#6b7280" stroke-width="1.5" marker-end="url(#p8a4)"/>
<text x="361" y="32" text-anchor="middle" fill="#6b7280" font-size="11">syscalls</text>
<text x="361" y="55" text-anchor="middle" fill="#6b7280" font-size="11">filtrés</text>
<rect x="398" y="20" width="155" height="38" rx="5" fill="#fef3c7" stroke="#f59e0b" stroke-width="1.5"/>
<text x="475" y="44" text-anchor="middle" fill="#78350f" font-weight="bold">Kernel hôte</text>
<text x="45" y="74" text-anchor="middle" fill="#9ca3af" font-size="10">userspace</text>
<text x="238" y="74" text-anchor="middle" fill="#9ca3af" font-size="10">userspace (intercept)</text>
<text x="475" y="74" text-anchor="middle" fill="#9ca3af" font-size="10">kernelspace</text>
<text x="590" y="35" fill="#6b7280" font-size="12">~70% syscalls</text>
<text x="590" y="52" fill="#6b7280" font-size="12">implémentés</text>
</svg>

- Isolation forte: même si le Sentry est compromis, surface réduite
- Surcoût: ~2-3× (I/O, fork/exec)

---

## Installation de gVisor

Deux binaires requis sur chaque nœud:
- `runsc` — le runtime gVisor
- `containerd-shim-runsc-v1` — shim containerd

Config containerd via drop-in (ne pas modifier `config.toml`):
```toml
# /etc/containerd/conf.d/gvisor.toml
[plugins.'io.containerd.cri.v1.runtime']
  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
    runtime_type = 'io.containerd.runsc.v1'
    [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc.options]
      TypeUrl = 'io.containerd.runsc.v1.options'
```

⚠️ Plugin v2: `io.containerd.cri.v1.runtime` (pas `grpc.v1.cri`)

---

## containerd 2.x — le plugin CRI a changé de nom

### containerd 1.x vs 2.x : deux chemins incompatibles

```toml
# containerd 1.x  (< 2.0)
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"

# containerd 2.x  (ce TD)
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
  runtime_type = 'io.containerd.runsc.v1'
```

### Pourquoi ce renommage ?

- En 1.x, le CRI était un **plugin gRPC parmi d'autres** → `grpc.v1.cri`
- En 2.x, le CRI est **natif** dans containerd → `cri.v1.runtime`
- Le préfixe `grpc` disparaît : CRI n'est plus un greffon, c'est le cœur

### Piège fréquent

Copier une config gVisor/kata depuis internet → souvent écrite pour 1.x
→ containerd 2.x **ignore silencieusement** la section mal nommée
→ le runtime n'apparaît pas, sans message d'erreur explicite

---

## Exercice 8.1 — Install gVisor

### 📝 EXERCICE ÉLÈVE — Sur TOUS les nœuds

```bash
cd scripts/partie-07-runtimeclass
./01-install-gvisor.sh
```

### Points d'attention instructeur

- KVM disponible sur Exoscale: `platform = 'kvm'` dans `/etc/containerd/runsc.toml`
- Sans KVM: `platform = 'systrap'` (ptrace-based, plus lent)
- Vérifier: `sudo runsc --version`
- Vérifier containerd restart OK: `systemctl status containerd`

---

## RuntimeClass — Le lien K8s ↔ containerd

<svg width="740" height="68" viewBox="0 0 740 68" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<defs><marker id="p8a5" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#6b7280"/></marker></defs>
<rect x="5" y="13" width="155" height="42" rx="5" fill="#ede9fe" stroke="#7c3aed" stroke-width="1.5"/>
<text x="82" y="31" text-anchor="middle" fill="#5b21b6" font-weight="bold">Pod spec</text>
<text x="82" y="47" text-anchor="middle" fill="#5b21b6" font-size="11">runtimeClassName: gvisor</text>
<line x1="160" y1="34" x2="200" y2="34" stroke="#6b7280" stroke-width="1.5" marker-end="url(#p8a5)"/>
<rect x="203" y="10" width="165" height="48" rx="5" fill="#dcfce7" stroke="#16a34a" stroke-width="1.5"/>
<text x="285" y="30" text-anchor="middle" fill="#166534" font-weight="bold">RuntimeClass</text>
<text x="285" y="47" text-anchor="middle" fill="#166534" font-size="11">gvisor → handler: runsc</text>
<line x1="368" y1="34" x2="408" y2="34" stroke="#6b7280" stroke-width="1.5" marker-end="url(#p8a5)"/>
<rect x="411" y="13" width="120" height="42" rx="5" fill="#f3f4f6" stroke="#6b7280" stroke-width="1.5"/>
<text x="471" y="39" text-anchor="middle" fill="#374151" font-weight="bold">containerd</text>
<line x1="531" y1="34" x2="571" y2="34" stroke="#6b7280" stroke-width="1.5" marker-end="url(#p8a5)"/>
<rect x="574" y="13" width="155" height="42" rx="5" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
<text x="651" y="31" text-anchor="middle" fill="#166534" font-weight="bold">runsc</text>
<text x="651" y="47" text-anchor="middle" fill="#166534" font-size="11">gVisor runtime</text>
<text x="285" y="64" text-anchor="middle" fill="#9ca3af" font-size="10">objet Kubernetes</text>
</svg>

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeClassification:
    tolerations:
    - effect: NoSchedule
      key: sandbox
      operator: Equal
      value: gvisor
```

Le `handler` doit correspondre au nom dans la config containerd.

---

## Exercice 8.2 — Création RuntimeClass

### 📝 EXERCICE ÉLÈVE — Sur le MASTER

```bash
./02-create-runtimeclass.sh
```

### Vérification

```bash
kubectl get runtimeclass
kubectl describe runtimeclass gvisor
```

---

## Démonstration de l'isolation

Comparaison `runc` vs `gVisor` depuis un container:

| Commande | runc | gVisor |
|----------|------|--------|
| `uname -r` | Kernel hôte (ex: 5.14.x) | 4.4.0 (Sentry) |
| `dmesg` | Logs kernel hôte | Logs Sentry isolés |
| `/proc/version` | Linux hôte | gVisor version |

**Point pédagogique:** le kernel "4.4.0" est celui du Sentry gVisor — pas le kernel hôte. L'app voit un kernel virtuel.

---

## Exercice 8.3 — Test isolation

### 📝 EXERCICE ÉLÈVE

```bash
./03-test-isolation.sh
```

### Points pédagogiques

- Comparer `uname -r` dans un pod runc vs pod gVisor
- Le kernel "4.4.0" = Sentry gVisor (pas une vraie version)
- `dmesg` dans le pod gVisor: logs isolés, pas ceux de l'hôte
- Essayer d'écrire dans `/proc` → permission refusée

---

## Utilisation dans un Deployment

Ajouter `runtimeClassName` dans le podSpec:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-securisee
  namespace: sandbox
spec:
  template:
    spec:
      runtimeClassName: gvisor
      containers:
      - name: app
        image: nginx:alpine
```

**Bonne pratique:** namespace dédié pour workloads sensibles (CI/CD, multi-tenant)

---

## Exercices 8.4 & 8.5

### 📝 EXERCICE ÉLÈVE

**8.4 — Déploiement avec RuntimeClass:**
```bash
./04-deploy-with-runtimeclass.sh
```

**8.5 — Comparaison de performance:**
```bash
./05-performance-comparison.sh
```

**Résultats attendus:** overhead visible sur I/O et fork/exec, transparent pour workloads CPU.

---

## Performance — Overhead gVisor

| Workload | runc | gVisor | Overhead |
|----------|------|--------|----------|
| I/O séquentiel | 1× | ~3× | +200% |
| fork/exec | 1× | ~2.5× | +150% |
| Requêtes DNS | 1× | ~1.3× | +30% |

**Règle:** gVisor pour l'isolation, pas pour les I/O intensifs.

---

## Quand utiliser gVisor

### Cas d'usage adaptés
- Pipelines CI/CD (code utilisateur non fiable)
- Plateformes multi-tenant (isolation entre clients)
- Workloads traitant des données sensibles
- Preview/sandbox d'applications

### Quand éviter
- Workloads I/O-intensifs (bases de données, logs)
- Applications temps-réel (latence critique)
- Workloads nécessitant des syscalls non supportés

---

<!-- _class: lead -->

# Partie 9
## cgroups — le moteur des containers (20 min)

---

## Partie 9 - Timeline suggérée

- Qu'est-ce qu'un cgroup : **5 min**
- Démo nerdctl + Docker : **5 min**
- Manipulation manuelle + code C : **5 min**
- cgroups dans Kubernetes (QoS) : **5 min**

---

## Qu'est-ce qu'un cgroup ?

- **Linux Control Groups** — mécanisme noyau depuis kernel 2.6.24 (2008)
- Organise les processus en groupes hiérarchiques
- Contrôle et limite : **CPU** · **mémoire** · **I/O disque** · **réseau** · **devices**
- Implémenté comme un **pseudo-filesystem** : `/sys/fs/cgroup/`
- **cgroup v1** (2008) : hiérarchies séparées par subsystem (`/cpu/`, `/memory/`, `/blkio/`)
- **cgroup v2** (kernel 4.5, 2016) : hiérarchie unifiée, standard actuel

> Un container = un processus Linux + **namespaces** (isolation) + **cgroups** (limitation)

---

## Le filesystem cgroup v2

```bash
# Détecter la version
stat -fc %T /sys/fs/cgroup
# → cgroup2fs (v2)  /  tmpfs (v1)

# Contrôleurs disponibles
cat /sys/fs/cgroup/cgroup.controllers
# cpu cpuset io memory pids hugetlb

# Arborescence (CentOS Stream 10)
ls /sys/fs/cgroup/system.slice/
# containerd.service/  sshd.service/  kubelet.service/ ...

# Fichiers de contrôle d'un service
ls /sys/fs/cgroup/system.slice/containerd.service/
# cgroup.procs  cpu.max  memory.max  memory.current  ...
```

---

## Container → cgroup avec nerdctl

```bash
# Lancer un container avec limites
nerdctl run -d --name demo --cpus 0.5 --memory 128m nginx:alpine

# PID du processus principal
PID=$(nerdctl inspect -f '{{.State.Pid}}' demo)

# Trouver le cgroup (v2 : entrée "0::")
CGPATH=$(awk -F: '/^0:/{print $3}' /proc/$PID/cgroup)

# Lire les limites appliquées
cat /sys/fs/cgroup${CGPATH}/memory.max
# → 134217728   (= 128 MiB)

cat /sys/fs/cgroup${CGPATH}/cpu.max
# → 50000 100000   (50 000 µs sur 100 000 µs = 50% d'un CPU)

cat /sys/fs/cgroup${CGPATH}/memory.current
# → consommation réelle en bytes
```

---

## Container → cgroup avec Docker

```bash
docker run -d --name demo2 --cpus 0.5 --memory 128m nginx:alpine

CID=$(docker inspect -f '{{.Id}}' demo2)

# Docker v2 : scopes systemd dans system.slice
cat /sys/fs/cgroup/system.slice/docker-${CID}.scope/memory.max
# → 134217728

cat /sys/fs/cgroup/system.slice/docker-${CID}.scope/cpu.max
# → 50000 100000

# Vue synthétique
docker stats demo2 --no-stream
# NAME    CPU %   MEM USAGE / LIMIT
# demo2   0.01%   3.5MiB / 128MiB
```

> containerd (nerdctl) et Docker écrivent dans le **même** filesystem cgroup — même kernel, même enforcement

---

## Manipuler les cgroups à la main

```bash
# Activer les contrôleurs dans la racine
echo "+memory +cpu" > /sys/fs/cgroup/cgroup.subtree_control

# Créer un cgroup dédié
mkdir /sys/fs/cgroup/demo-manual

# Limiter la mémoire à 64 MiB
echo $((64 * 1024 * 1024)) > /sys/fs/cgroup/demo-manual/memory.max

# Limiter le CPU à 25%  (250 ms sur 1 s)
echo "250000 1000000" > /sys/fs/cgroup/demo-manual/cpu.max

# Placer le shell courant dans ce cgroup
echo $$ > /sys/fs/cgroup/demo-manual/cgroup.procs

# Provoquer un OOM kill (dépasse 64 MiB)
stress --vm 1 --vm-bytes 200M   # → Killed

# Sortir + nettoyer
echo $$ > /sys/fs/cgroup/cgroup.procs
rmdir /sys/fs/cgroup/demo-manual
```

---

## Code C — isoler un processus dans un cgroup

```c
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <fcntl.h>
#define CG "/sys/fs/cgroup/demo_c"

static void cg_write(const char *file, const char *val) {
    char path[256];
    snprintf(path, sizeof(path), CG "/%s", file);
    int fd = open(path, O_WRONLY);
    write(fd, val, strlen(val));  close(fd);
}
int main(void) {
    mkdir(CG, 0755);
    cg_write("memory.max", "67108864");    /* 64 MiB */
    cg_write("cpu.max",    "250000 1000000"); /* 25% */
    pid_t pid = fork();
    if (pid == 0) {
        char buf[32];
        snprintf(buf, sizeof(buf), "%d", getpid());
        cg_write("cgroup.procs", buf);   /* rejoindre le cgroup */
        for (volatile long i = 0; i < 2000000000L; i++); /* CPU loop */
        return 0;
    }
    waitpid(pid, NULL, 0);
    rmdir(CG);
}
```

```bash
gcc -O0 -o cg_demo cg_demo.c && sudo ./cg_demo
# Observer : top → le fils est limité à ~25% CPU
```

> C'est exactement ce que font **runc** (via containerd) et **crun** pour chaque container

---

## cgroups dans Kubernetes — QoS classes

kubelet organise les pods dans `/sys/fs/cgroup/kubepods/` selon la **QoS class** :

| QoS class | Condition | Path cgroup | Priorité OOM |
|-----------|-----------|-------------|--------------|
| **Guaranteed** | requests == limits (tous) | `kubepods/pod<uid>/` | Dernière victime |
| **Burstable** | au moins un request défini | `kubepods/burstable/pod<uid>/` | Selon usage |
| **BestEffort** | aucun request/limit | `kubepods/besteffort/pod<uid>/` | Premier tué |

```bash
# Sur un nœud worker : inspecter le cgroup d'un container
crictl inspect <cid> | jq -r '.info.runtimeSpec.linux.cgroupsPath'
# → /kubepods/burstable/pod<uid>/<cid>

# Vérifier les limites effectives
cat /sys/fs/cgroup/kubepods/burstable/pod<uid>/memory.max
```

---

## Résumé — du YAML au noyau

```
Pod spec (YAML)          kubelet              noyau Linux
─────────────────   ──────────────────   ──────────────────────
resources:          crée le cgroup       /sys/fs/cgroup/
  requests:         écrit les limites      kubepods/burstable/
    memory: 128Mi   memory.max              pod<uid>/
    cpu: 500m       cpu.max                   memory.max = 128M
  limits:                                     cpu.max = 50000
    memory: 256Mi   ← enforcement →      OOM kill si dépassement
    cpu: 1          kernel throttle CPU   throttle si > quota
```

- `requests` = ce que kubelet **réserve** sur le nœud (scheduling)
- `limits` = ce que le **noyau enforced** via cgroup (runtime)
- Sans limits → BestEffort → premier tué en cas de pression mémoire

---

<!-- _class: lead -->

# Partie 10
## HA Control Plane — Théorie (15 min)

---

## Multi-master : comment ça marche ?

> *On ne le fait pas dans ce TD — sauf si temps disponible (cf. Partie Bonus)*

**Méthode normale — `--upload-certs` (recommandée)**

À l'init, `--upload-certs` chiffre les certificats PKI et les stocke dans un Secret `kubeadm-certs` (namespace `kube-system`). Ce Secret expire automatiquement après **2 heures**.

```bash
# Sur master1 — à l'init du cluster
kubeadm init \
  --control-plane-endpoint="<lb>:6443" \
  --upload-certs
# La sortie affiche --certificate-key <key> — à conserver pour le join
```

```bash
# Sur master2 — le flag --control-plane distingue un master d'un worker
# kubeadm télécharge et déchiffre les certs depuis le Secret automatiquement
kubeadm join <lb>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <key>
```

---

## Multi-master — fallback : copie manuelle des certs

**Si `--upload-certs` oublié ou Secret expiré (2h)**

```bash
# Régénérer la clé sans relancer kubeadm init :
kubeadm init phase upload-certs --upload-certs
# → affiche un nouveau --certificate-key valable 2h
```

```bash
# Ou copie manuelle des 6 fichiers PKI master1 → master2
for f in ca.crt ca.key sa.pub sa.key front-proxy-ca.crt front-proxy-ca.key; do
  scp /etc/kubernetes/pki/$f root@master2:/etc/kubernetes/pki/
done
scp /etc/kubernetes/pki/etcd/ca.{crt,key} root@master2:/etc/kubernetes/pki/etcd/
kubeadm join <lb>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> --control-plane
```

**Dans les deux cas :** kubeadm installe `kube-apiserver`, `kube-scheduler`, `kube-controller-manager` et ajoute ce nœud comme membre etcd.

---

## Peut-on promouvoir un worker en master ?

> *Question fréquente : "j'ai 1 master + 2 workers, puis-je transformer les workers ?"*

**Non, kubeadm n'a pas de commande de promotion.** Deux blocages :

**1. Le certificat API server est figé à l'init**
- Sans `--control-plane-endpoint`, le cert ne couvre que l'IP du master d'origine → reset obligatoire

**2. Si `--control-plane-endpoint` était présent**, on peut faire un "reset + rejoin" :
```bash
kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data
kubeadm reset && rm -rf /etc/kubernetes /var/lib/etcd
kubeadm join <lb>:6443 --token ... --control-plane --certificate-key <key>
```

**La décision HA doit être prise au `kubeadm init`.** Après, c'est un reset, pas une promotion.

---

<!-- _class: lead -->

# Partie 11
## Réseau public vs privé (10 min)

---

## Partie 11 - Timeline suggérée

- Architecture sans réseau privé — risques: **4 min**
- Architecture avec réseau privé — isolation: **4 min**
- Quand choisir: **2 min**

---

## Architecture sans réseau privé — les risques

<svg width="1100" height="300" viewBox="0 0 880 240" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<rect x="10" y="15" width="260" height="140" rx="10" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="140" y="38" text-anchor="middle" fill="#1e40af" font-size="15" font-weight="bold">Master</text>
<text x="140" y="57" text-anchor="middle" fill="#dc2626" font-size="12">185.42.17.3 (IP publique)</text>
<rect x="20" y="68" width="100" height="28" rx="5" fill="#bfdbfe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="70" y="87" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">API :6443</text>
<text x="130" y="88" text-anchor="middle" fill="#16a34a" font-size="18">↔</text>
<rect x="140" y="68" width="118" height="28" rx="5" fill="#bfdbfe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="199" y="87" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">etcd :2379</text>
<line x1="20" y1="100" x2="258" y2="100" stroke="#16a34a" stroke-width="1.5"/>
<line x1="20" y1="96" x2="20" y2="100" stroke="#16a34a" stroke-width="1.5"/>
<line x1="258" y1="96" x2="258" y2="100" stroke="#16a34a" stroke-width="1.5"/>
<text x="139" y="117" text-anchor="middle" fill="#15803d" font-size="12">loopback 127.0.0.1 ✓  —  reste local au master</text>
<rect x="305" y="15" width="185" height="115" rx="10" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="397" y="42" text-anchor="middle" fill="#1e40af" font-size="15" font-weight="bold">Worker 1</text>
<text x="397" y="61" text-anchor="middle" fill="#dc2626" font-size="13">185.42.17.8 (pub)</text>
<text x="397" y="83" text-anchor="middle" fill="#6b7280" font-size="13">kubelet</text>
<text x="397" y="103" text-anchor="middle" fill="#6b7280" font-size="13">pods / CNI</text>
<rect x="520" y="15" width="185" height="115" rx="10" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="612" y="42" text-anchor="middle" fill="#1e40af" font-size="15" font-weight="bold">Worker 2</text>
<text x="612" y="61" text-anchor="middle" fill="#dc2626" font-size="13">185.42.17.15 (pub)</text>
<text x="612" y="83" text-anchor="middle" fill="#6b7280" font-size="13">kubelet</text>
<text x="612" y="103" text-anchor="middle" fill="#6b7280" font-size="13">pods / CNI</text>
<line x1="140" y1="155" x2="140" y2="175" stroke="#ef4444" stroke-width="2"/>
<line x1="397" y1="130" x2="397" y2="175" stroke="#ef4444" stroke-width="2"/>
<line x1="612" y1="130" x2="612" y2="175" stroke="#ef4444" stroke-width="2"/>
<rect x="10" y="175" width="720" height="58" rx="8" fill="#fee2e2" stroke="#ef4444" stroke-width="2.5"/>
<text x="370" y="199" text-anchor="middle" fill="#dc2626" font-size="14" font-weight="bold">⚠ Bus IP publique — kubelet→API  et  CNI pod-to-pod</text>
<text x="370" y="220" text-anchor="middle" fill="#b91c1c" font-size="12">trafic inter-nœuds exposé sur internet · ports 6443 + 10250 accessibles</text>
</svg>

- **etcd ↔ API server** : loopback `127.0.0.1` — reste local sur le master ✓
- **kubelet → API server** : IP publique du master ⚠
- **CNI pod-to-pod** : IP publique des workers ⚠

---

## Architecture avec réseau privé — isolation

<svg width="1100" height="300" viewBox="0 0 880 240" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<rect x="10" y="15" width="260" height="140" rx="10" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="140" y="38" text-anchor="middle" fill="#1e40af" font-size="15" font-weight="bold">Master</text>
<text x="140" y="54" text-anchor="middle" fill="#6b7280" font-size="11">pub: 185.42.17.3</text>
<text x="140" y="68" text-anchor="middle" fill="#15803d" font-size="11">priv: 10.0.0.1</text>
<rect x="20" y="78" width="100" height="28" rx="5" fill="#bfdbfe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="70" y="97" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">API :6443</text>
<text x="130" y="98" text-anchor="middle" fill="#16a34a" font-size="18">↔</text>
<rect x="140" y="78" width="118" height="28" rx="5" fill="#bfdbfe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="199" y="97" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">etcd :2379</text>
<line x1="20" y1="110" x2="258" y2="110" stroke="#16a34a" stroke-width="1.5"/>
<line x1="20" y1="106" x2="20" y2="110" stroke="#16a34a" stroke-width="1.5"/>
<line x1="258" y1="106" x2="258" y2="110" stroke="#16a34a" stroke-width="1.5"/>
<text x="139" y="127" text-anchor="middle" fill="#15803d" font-size="12">loopback 127.0.0.1 ✓  —  reste local au master</text>
<rect x="305" y="15" width="185" height="115" rx="10" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="397" y="42" text-anchor="middle" fill="#1e40af" font-size="15" font-weight="bold">Worker 1</text>
<text x="397" y="61" text-anchor="middle" fill="#15803d" font-size="13">priv: 10.0.0.2</text>
<text x="397" y="83" text-anchor="middle" fill="#6b7280" font-size="13">kubelet</text>
<text x="397" y="103" text-anchor="middle" fill="#6b7280" font-size="13">pods / CNI</text>
<rect x="520" y="15" width="185" height="115" rx="10" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="612" y="42" text-anchor="middle" fill="#1e40af" font-size="15" font-weight="bold">Worker 2</text>
<text x="612" y="61" text-anchor="middle" fill="#15803d" font-size="13">priv: 10.0.0.3</text>
<text x="612" y="83" text-anchor="middle" fill="#6b7280" font-size="13">kubelet</text>
<text x="612" y="103" text-anchor="middle" fill="#6b7280" font-size="13">pods / CNI</text>
<line x1="140" y1="155" x2="140" y2="175" stroke="#16a34a" stroke-width="2"/>
<line x1="397" y1="130" x2="397" y2="175" stroke="#16a34a" stroke-width="2"/>
<line x1="612" y1="130" x2="612" y2="175" stroke="#16a34a" stroke-width="2"/>
<rect x="10" y="175" width="720" height="58" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2.5"/>
<text x="370" y="199" text-anchor="middle" fill="#15803d" font-size="14" font-weight="bold">✓ Bus réseau privé 10.0.0.0/24 — kubelet→API  et  CNI pod-to-pod</text>
<text x="370" y="220" text-anchor="middle" fill="#166534" font-size="12">non routable depuis internet · IP publique = SSH uniquement</text>
</svg>

- **etcd ↔ API server** : loopback — inchangé ✓
- **kubelet → API server** : IP privée `10.0.0.x` — non accessible depuis internet ✓
- **CNI pod-to-pod** : IP privée — non routable depuis internet ✓

---

## Quand choisir quelle architecture réseau

### Réseau public seul
- Acceptable pour: labs éphémères, démos isolées
- Mitigation: security group strict, firewalld

### Réseau privé + public
- Recommandé pour: tout environnement de formation réel
- Configurer `PRIVATE_NETWORK` dans `infra-exo/.env`

---

## Un LB DIY — ce que ça implique vraiment

<svg width="1100" height="320" viewBox="0 0 900 260" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<rect x="340" y="8" width="220" height="36" rx="8" fill="#fde68a" stroke="#d97706" stroke-width="2"/>
<text x="450" y="31" text-anchor="middle" fill="#92400e" font-size="14" font-weight="bold">VIP  185.42.17.100  (Keepalived)</text>
<line x1="400" y1="44" x2="144" y2="65" stroke="#d97706" stroke-width="1.5"/>
<line x1="450" y1="44" x2="450" y2="65" stroke="#d97706" stroke-width="1.5"/>
<line x1="500" y1="44" x2="756" y2="65" stroke="#d97706" stroke-width="1.5"/>
<rect x="10" y="65" width="268" height="155" rx="10" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="144" y="89" text-anchor="middle" fill="#1e40af" font-size="15" font-weight="bold">Node LB-1</text>
<text x="144" y="107" text-anchor="middle" fill="#1e40af" font-size="13">MASTER</text>
<line x1="20" y1="114" x2="268" y2="114" stroke="#93c5fd" stroke-width="1"/>
<text x="144" y="132" text-anchor="middle" fill="#374151" font-size="13">HAProxy :6443 → masters</text>
<text x="144" y="152" text-anchor="middle" fill="#374151" font-size="13">Keepalived VRRP MASTER</text>
<text x="144" y="174" text-anchor="middle" fill="#15803d" font-size="13" font-weight="bold">★ détient la VIP</text>
<text x="144" y="193" text-anchor="middle" fill="#15803d" font-size="12">trafic entrant actif</text>
<rect x="316" y="65" width="268" height="155" rx="10" fill="#f8fafc" stroke="#94a3b8" stroke-width="1.5"/>
<text x="450" y="89" text-anchor="middle" fill="#475569" font-size="15" font-weight="bold">Node LB-2</text>
<text x="450" y="107" text-anchor="middle" fill="#475569" font-size="13">BACKUP</text>
<line x1="326" y1="114" x2="574" y2="114" stroke="#cbd5e1" stroke-width="1"/>
<text x="450" y="132" text-anchor="middle" fill="#64748b" font-size="13">HAProxy :6443 → masters</text>
<text x="450" y="152" text-anchor="middle" fill="#64748b" font-size="13">Keepalived VRRP BACKUP</text>
<text x="450" y="174" text-anchor="middle" fill="#6b7280" font-size="12">prêt à reprendre la VIP</text>
<text x="450" y="193" text-anchor="middle" fill="#6b7280" font-size="12">si LB-1 tombe</text>
<rect x="622" y="65" width="268" height="155" rx="10" fill="#f8fafc" stroke="#94a3b8" stroke-width="1.5"/>
<text x="756" y="89" text-anchor="middle" fill="#475569" font-size="15" font-weight="bold">Node LB-3</text>
<text x="756" y="107" text-anchor="middle" fill="#475569" font-size="13">BACKUP</text>
<line x1="632" y1="114" x2="880" y2="114" stroke="#cbd5e1" stroke-width="1"/>
<text x="756" y="132" text-anchor="middle" fill="#64748b" font-size="13">HAProxy :6443 → masters</text>
<text x="756" y="152" text-anchor="middle" fill="#64748b" font-size="13">Keepalived VRRP BACKUP</text>
<text x="756" y="174" text-anchor="middle" fill="#6b7280" font-size="12">prêt à reprendre la VIP</text>
<text x="756" y="193" text-anchor="middle" fill="#6b7280" font-size="12">si LB-1 tombe</text>
<line x1="278" y1="148" x2="316" y2="148" stroke="#d97706" stroke-width="2" stroke-dasharray="4,2"/>
<text x="297" y="141" text-anchor="middle" fill="#d97706" font-size="12">VRRP</text>
<line x1="584" y1="148" x2="622" y2="148" stroke="#d97706" stroke-width="2" stroke-dasharray="4,2"/>
<text x="603" y="141" text-anchor="middle" fill="#d97706" font-size="12">VRRP</text>
<rect x="10" y="230" width="880" height="26" rx="6" fill="#fff7ed" stroke="#f97316" stroke-width="1.5"/>
<text x="450" y="247" text-anchor="middle" fill="#c2410c" font-size="12">⚠ 3 VMs supplémentaires · config HAProxy + Keepalived · monitoring VRRP · failover régulièrement testé</text>
</svg>

> Tout ça pour remplacer **une ligne** `exo compute load-balancer create` — et c'est sans compter les mises à jour, la supervision et les certificats TLS

---

## Dream architecture — security groups dédiés

<svg width="1100" height="373" viewBox="0 0 900 305" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<rect x="300" y="5" width="300" height="28" rx="7" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1.5"/>
<text x="450" y="24" text-anchor="middle" fill="#475569" font-size="13" font-weight="bold">Internet — kubectl / admin</text>
<line x1="450" y1="33" x2="450" y2="48" stroke="#d97706" stroke-width="2"/>
<text x="470" y="45" fill="#92400e" font-size="12">HTTPS :6443</text>
<rect x="235" y="48" width="430" height="42" rx="8" fill="#fef3c7" stroke="#d97706" stroke-width="2"/>
<text x="450" y="68" text-anchor="middle" fill="#92400e" font-size="14" font-weight="bold">Exoscale NLB</text>
<text x="450" y="84" text-anchor="middle" fill="#d97706" font-size="12">185.42.17.100  —  seule IP publique</text>
<line x1="450" y1="90" x2="450" y2="114" stroke="#d97706" stroke-width="2"/>
<text x="470" y="108" fill="#92400e" font-size="12">forward :6443</text>
<rect x="15" y="114" width="870" height="101" rx="8" fill="#faf5ff" stroke="#7c3aed" stroke-width="2" stroke-dasharray="6,3"/>
<text x="25" y="130" fill="#7c3aed" font-size="13" font-weight="bold">sg-masters</text>
<rect x="25" y="135" width="200" height="70" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="125" y="157" text-anchor="middle" fill="#1e40af" font-size="14" font-weight="bold">Master 1</text>
<text x="125" y="175" text-anchor="middle" fill="#1e40af" font-size="13">10.0.0.1</text>
<text x="125" y="192" text-anchor="middle" fill="#6b7280" font-size="12">API Server + etcd</text>
<line x1="225" y1="170" x2="285" y2="170" stroke="#7c3aed" stroke-width="1.5" stroke-dasharray="3,2"/>
<text x="255" y="163" text-anchor="middle" fill="#7c3aed" font-size="11">etcd :2380</text>
<rect x="285" y="135" width="200" height="70" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="385" y="157" text-anchor="middle" fill="#1e40af" font-size="14" font-weight="bold">Master 2</text>
<text x="385" y="175" text-anchor="middle" fill="#1e40af" font-size="13">10.0.0.2</text>
<text x="385" y="192" text-anchor="middle" fill="#6b7280" font-size="12">API Server + etcd</text>
<text x="510" y="148" fill="#7c3aed" font-size="12">IN :6443  ←  NLB + sg-workers</text>
<text x="510" y="168" fill="#7c3aed" font-size="12">IN :2379-2380  ←  sg-masters seul</text>
<text x="510" y="188" fill="#7c3aed" font-size="12">OUT : tout autorisé</text>
<line x1="450" y1="215" x2="450" y2="232" stroke="#16a34a" stroke-width="2"/>
<text x="470" y="228" fill="#166534" font-size="12">kubelet :10250</text>
<rect x="15" y="232" width="870" height="68" rx="8" fill="#f0fdf4" stroke="#16a34a" stroke-width="2" stroke-dasharray="6,3"/>
<text x="25" y="248" fill="#166534" font-size="13" font-weight="bold">sg-workers</text>
<rect x="25" y="252" width="200" height="42" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="125" y="270" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">Worker 1</text>
<text x="125" y="286" text-anchor="middle" fill="#6b7280" font-size="12">10.0.1.1  (pas d'IP pub)</text>
<line x1="225" y1="273" x2="285" y2="273" stroke="#16a34a" stroke-width="1.5" stroke-dasharray="3,2"/>
<text x="255" y="267" text-anchor="middle" fill="#166534" font-size="11">CNI</text>
<rect x="285" y="252" width="200" height="42" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="385" y="270" text-anchor="middle" fill="#1e40af" font-size="13" font-weight="bold">Worker 2</text>
<text x="385" y="286" text-anchor="middle" fill="#6b7280" font-size="12">10.0.1.2  (pas d'IP pub)</text>
<text x="510" y="268" fill="#166534" font-size="12">IN :10250  ←  sg-masters</text>
<text x="510" y="287" fill="#166534" font-size="12">CNI  ←  sg-workers (intra-zone)</text>
</svg>

- **Exoscale NLB** : service managé L4, seul composant exposé — pas un HAProxy custom
- Ce NLB est **exclusivement pour le kube-apiserver** (port `:6443`) — il ne sert pas à exposer des services HTTP applicatifs
- `sg-masters` : ports etcd/API ouverts uniquement entre pairs ou depuis NLB
- `sg-workers` : aucune IP publique, kubelet joignable uniquement par `sg-masters`

---

## NLB Exoscale — filtrage IP (defense in depth)

<svg width="1100" height="376" viewBox="0 0 760 260" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<defs>
  <marker id="fa" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#16a34a"/></marker>
  <marker id="ra" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#dc2626"/></marker>
  <marker id="oa" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#d97706"/></marker>
</defs>
<rect x="30" y="8" width="155" height="38" rx="6" fill="#dcfce7" stroke="#16a34a" stroke-width="1.5"/>
<text x="107" y="24" text-anchor="middle" fill="#166534" font-weight="bold" font-size="10">✓ VPN bureau</text>
<text x="107" y="38" text-anchor="middle" fill="#166534" font-size="9">203.0.113.0/24</text>
<rect x="210" y="8" width="155" height="38" rx="6" fill="#fee2e2" stroke="#dc2626" stroke-width="1.5"/>
<text x="287" y="24" text-anchor="middle" fill="#991b1b" font-weight="bold" font-size="10">✗ Internet inconnu</text>
<text x="287" y="38" text-anchor="middle" fill="#991b1b" font-size="9">45.x.x.x / bots / scanners</text>
<rect x="390" y="8" width="155" height="38" rx="6" fill="#dcfce7" stroke="#16a34a" stroke-width="1.5"/>
<text x="467" y="24" text-anchor="middle" fill="#166534" font-weight="bold" font-size="10">✓ CI/CD runner</text>
<text x="467" y="38" text-anchor="middle" fill="#166534" font-size="9">198.51.100.12/32</text>
<line x1="107" y1="46" x2="200" y2="68" stroke="#16a34a" stroke-width="1.5" marker-end="url(#fa)"/>
<line x1="287" y1="46" x2="270" y2="68" stroke="#dc2626" stroke-width="1.5" stroke-dasharray="4,2" marker-end="url(#ra)"/>
<line x1="467" y1="46" x2="340" y2="68" stroke="#16a34a" stroke-width="1.5" marker-end="url(#fa)"/>
<rect x="130" y="68" width="370" height="48" rx="8" fill="#fef3c7" stroke="#d97706" stroke-width="2"/>
<text x="315" y="86" text-anchor="middle" fill="#92400e" font-weight="bold" font-size="12">Exoscale NLB  ·  185.42.17.100</text>
<text x="315" y="101" text-anchor="middle" fill="#d97706" font-size="10">ACL CIDR : allowed_sources = [203.0.113.0/24, 198.51.100.12/32]</text>
<text x="271" y="63" text-anchor="middle" fill="#dc2626" font-size="12" font-weight="bold">✗</text>
<rect x="505" y="74" width="90" height="18" rx="4" fill="#d97706"/>
<text x="550" y="87" text-anchor="middle" fill="white" font-size="9" font-weight="bold">Couche 1 : NLB</text>
<line x1="315" y1="116" x2="315" y2="136" stroke="#d97706" stroke-width="2" marker-end="url(#oa)"/>
<text x="395" y="130" fill="#92400e" font-size="9">185.42.17.100 → masters</text>
<rect x="130" y="136" width="370" height="48" rx="8" fill="#faf5ff" stroke="#7c3aed" stroke-width="2" stroke-dasharray="5,3"/>
<text x="315" y="154" text-anchor="middle" fill="#7c3aed" font-weight="bold" font-size="12">sg-masters</text>
<text x="315" y="170" text-anchor="middle" fill="#7c3aed" font-size="10">IN :6443 source = 185.42.17.100/32 (IP NLB uniquement)</text>
<rect x="505" y="142" width="100" height="18" rx="4" fill="#7c3aed"/>
<text x="555" y="155" text-anchor="middle" fill="white" font-size="9" font-weight="bold">Couche 2 : SG</text>
<line x1="315" y1="184" x2="315" y2="200" stroke="#16a34a" stroke-width="2" marker-end="url(#fa)"/>
<rect x="215" y="200" width="200" height="32" rx="6" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="315" y="221" text-anchor="middle" fill="#1e40af" font-weight="bold" font-size="12">API Server (masters)</text>
<rect x="30" y="240" width="700" height="16" rx="4" fill="#f8fafc" stroke="#e2e8f0" stroke-width="1"/>
<text x="380" y="252" text-anchor="middle" fill="#64748b" font-size="9">Defense in depth : NLB bloque par IP source · SG bloque si paquet arriverait autrement (ex: réseau interne compromis)</text>
</svg>

```bash
# Configurer les ACL CIDR sur le service NLB (exo CLI)
exo compute load-balancer service update my-nlb my-svc \
  --healthcheck-mode tcp \
  --allowed-ips 203.0.113.0/24,198.51.100.12/32
```

---

## Service type LoadBalancer — le problème sur kubeadm

### Sur un cluster kubeadm bare metal

```bash
kubectl expose deploy mon-app --type=LoadBalancer --port=80
kubectl get svc mon-app
# NAME      TYPE           CLUSTER-IP    EXTERNAL-IP   PORT
# mon-app   LoadBalancer   10.96.0.42    <pending>     80/TCP
```

`<pending>` indéfiniment — kubeadm n'a pas de cloud provider pour provisionner un LB

### Pourquoi ?

- `Service type:LoadBalancer` délègue au **cloud-controller-manager**
- Sur kubeadm DIY : aucun cloud-ccm configuré → l'EXTERNAL-IP ne sera jamais assignée
- Sur SKS : le cloud-ccm Exoscale provisionne **automatiquement** un NLB Exoscale

**Solutions sur kubeadm :** MetalLB · kube-vip · NodePort + LB externe

---

## LoadBalancer apps — 3 approches

<svg width="1100" height="376" viewBox="0 0 760 260" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<defs>
  <marker id="lba" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#6b7280"/></marker>
  <marker id="lbg" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#16a34a"/></marker>
  <marker id="lbo" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#d97706"/></marker>
</defs>
<text x="127" y="16" text-anchor="middle" fill="#374151" font-weight="bold" font-size="11">① MetalLB (kubeadm)</text>
<text x="380" y="16" text-anchor="middle" fill="#374151" font-weight="bold" font-size="11">② NLB Exoscale (SKS)</text>
<text x="633" y="16" text-anchor="middle" fill="#374151" font-weight="bold" font-size="11">③ Ingress Controller</text>
<line x1="253" y1="8" x2="253" y2="250" stroke="#e5e7eb" stroke-width="1"/>
<line x1="506" y1="8" x2="506" y2="250" stroke="#e5e7eb" stroke-width="1"/>
<rect x="70" y="24" width="115" height="22" rx="4" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1"/>
<text x="127" y="39" text-anchor="middle" fill="#475569" font-size="10">Client</text>
<line x1="127" y1="46" x2="127" y2="58" stroke="#6b7280" stroke-width="1.5" marker-end="url(#lba)"/>
<rect x="52" y="58" width="150" height="28" rx="5" fill="#fef3c7" stroke="#d97706" stroke-width="1.5"/>
<text x="127" y="72" text-anchor="middle" fill="#92400e" font-weight="bold" font-size="10">MetalLB VIP</text>
<text x="127" y="82" text-anchor="middle" fill="#d97706" font-size="8">L2 (ARP) ou BGP</text>
<line x1="127" y1="86" x2="127" y2="98" stroke="#d97706" stroke-width="1.5" marker-end="url(#lbo)"/>
<rect x="62" y="98" width="130" height="20" rx="4" fill="#e0e7ff" stroke="#6366f1" stroke-width="1"/>
<text x="127" y="112" text-anchor="middle" fill="#4338ca" font-size="9">kube-proxy</text>
<line x1="95" y1="118" x2="82" y2="130" stroke="#6b7280" stroke-width="1.5" marker-end="url(#lba)"/>
<line x1="158" y1="118" x2="172" y2="130" stroke="#6b7280" stroke-width="1.5" marker-end="url(#lba)"/>
<rect x="44" y="130" width="62" height="20" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1"/>
<text x="75" y="144" text-anchor="middle" fill="#1e40af" font-size="9">Pod A</text>
<rect x="148" y="130" width="62" height="20" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1"/>
<text x="179" y="144" text-anchor="middle" fill="#1e40af" font-size="9">Pod B</text>
<text x="127" y="168" text-anchor="middle" fill="#15803d" font-size="8">✓ kubeadm bare metal</text>
<text x="127" y="178" text-anchor="middle" fill="#dc2626" font-size="8">✗ SKS (cloud-ccm actif)</text>
<text x="127" y="190" text-anchor="middle" fill="#6b7280" font-size="8">1 IP par Service</text>
<rect x="323" y="24" width="115" height="22" rx="4" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1"/>
<text x="380" y="39" text-anchor="middle" fill="#475569" font-size="10">Client</text>
<line x1="380" y1="46" x2="380" y2="58" stroke="#6b7280" stroke-width="1.5" marker-end="url(#lba)"/>
<rect x="305" y="58" width="150" height="28" rx="5" fill="#fef3c7" stroke="#d97706" stroke-width="2"/>
<text x="380" y="72" text-anchor="middle" fill="#92400e" font-weight="bold" font-size="10">Exoscale NLB</text>
<text x="380" y="82" text-anchor="middle" fill="#d97706" font-size="8">provisionné par cloud-ccm</text>
<line x1="380" y1="86" x2="380" y2="98" stroke="#d97706" stroke-width="1.5" marker-end="url(#lbo)"/>
<rect x="305" y="98" width="150" height="20" rx="4" fill="#e0e7ff" stroke="#6366f1" stroke-width="1"/>
<text x="380" y="112" text-anchor="middle" fill="#4338ca" font-size="9">NodePort sur workers</text>
<line x1="348" y1="118" x2="335" y2="130" stroke="#6b7280" stroke-width="1.5" marker-end="url(#lba)"/>
<line x1="412" y1="118" x2="425" y2="130" stroke="#6b7280" stroke-width="1.5" marker-end="url(#lba)"/>
<rect x="297" y="130" width="62" height="20" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1"/>
<text x="328" y="144" text-anchor="middle" fill="#1e40af" font-size="9">Pod A</text>
<rect x="401" y="130" width="62" height="20" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1"/>
<text x="432" y="144" text-anchor="middle" fill="#1e40af" font-size="9">Pod B</text>
<text x="380" y="168" text-anchor="middle" fill="#15803d" font-size="8">✓ SKS (automatique)</text>
<text x="380" y="178" text-anchor="middle" fill="#dc2626" font-size="8">✗ kubeadm (pending)</text>
<text x="380" y="190" text-anchor="middle" fill="#6b7280" font-size="8">1 NLB par Service = coûteux</text>
<rect x="576" y="24" width="115" height="22" rx="4" fill="#f1f5f9" stroke="#94a3b8" stroke-width="1"/>
<text x="633" y="39" text-anchor="middle" fill="#475569" font-size="10">Client</text>
<line x1="633" y1="46" x2="633" y2="58" stroke="#6b7280" stroke-width="1.5" marker-end="url(#lba)"/>
<rect x="558" y="58" width="150" height="22" rx="4" fill="#fef3c7" stroke="#d97706" stroke-width="1.5"/>
<text x="633" y="73" text-anchor="middle" fill="#92400e" font-size="9">1 LB ou NodePort</text>
<line x1="633" y1="80" x2="633" y2="92" stroke="#d97706" stroke-width="1.5" marker-end="url(#lbo)"/>
<rect x="553" y="92" width="160" height="28" rx="5" fill="#f0fdf4" stroke="#16a34a" stroke-width="2"/>
<text x="633" y="106" text-anchor="middle" fill="#166534" font-weight="bold" font-size="10">Ingress Controller</text>
<text x="633" y="117" text-anchor="middle" fill="#16a34a" font-size="8">nginx · traefik · HAProxy</text>
<line x1="585" y1="120" x2="560" y2="132" stroke="#16a34a" stroke-width="1.5" marker-end="url(#lbg)"/>
<line x1="633" y1="120" x2="633" y2="132" stroke="#16a34a" stroke-width="1.5" marker-end="url(#lbg)"/>
<line x1="681" y1="120" x2="706" y2="132" stroke="#16a34a" stroke-width="1.5" marker-end="url(#lbg)"/>
<rect x="518" y="132" width="60" height="20" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1"/>
<text x="548" y="146" text-anchor="middle" fill="#1e40af" font-size="8">app-a</text>
<rect x="603" y="132" width="60" height="20" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1"/>
<text x="633" y="146" text-anchor="middle" fill="#1e40af" font-size="8">app-b</text>
<rect x="688" y="132" width="60" height="20" rx="4" fill="#dbeafe" stroke="#3b82f6" stroke-width="1"/>
<text x="718" y="146" text-anchor="middle" fill="#1e40af" font-size="8">app-c</text>
<text x="633" y="168" text-anchor="middle" fill="#15803d" font-size="8">✓ kubeadm ET SKS</text>
<text x="633" y="178" text-anchor="middle" fill="#15803d" font-size="8">✓ recommandé en prod</text>
<text x="633" y="190" text-anchor="middle" fill="#6b7280" font-size="8">1 IP pour N apps (L7)</text>
<line x1="8" y1="220" x2="752" y2="220" stroke="#e5e7eb" stroke-width="1"/>
<text x="127" y="236" text-anchor="middle" fill="#374151" font-size="9" font-weight="bold">L4 · 1 IP / service</text>
<text x="380" y="236" text-anchor="middle" fill="#374151" font-size="9" font-weight="bold">L4 · 1 NLB / service</text>
<text x="633" y="236" text-anchor="middle" fill="#374151" font-size="9" font-weight="bold">L7 · 1 IP pour tout</text>
</svg>

---

## LoadBalancer apps — récapitulatif

| Approche | Niveau | kubeadm | SKS | Cas d'usage |
|----------|--------|---------|-----|-------------|
| **MetalLB** | L4 | ✓ | ✗ | bare metal, 1 IP/service |
| **Service LB (cloud-ccm)** | L4 | ✗ | ✓ | service TCP non-HTTP |
| **Ingress (nginx/traefik)** | L7 | ✓ | ✓ | apps HTTP/S en prod |
| **Gateway API** | L7+ | ✓ | ✓ | successeur Ingress, nouveaux clusters |

> **Règle pratique :** Ingress ou Gateway API pour tout ce qui est HTTP/S.
> Service LoadBalancer uniquement pour les services TCP bruts (BDD exposée, MQTT, etc.)

---

<!-- _class: lead -->

# Partie 12
## SKS Exoscale — Kubernetes managé (15 min)

---

## Partie 12 - Timeline suggérée

- Présentation SKS vs kubeadm: **4 min**
- Démo live SKS: **7 min**
- Cluster hybride SKS + on-prem: **4 min**

---

## SKS Exoscale — Kubernetes managé

Exoscale **SKS** (Scalable Kubernetes Service): control plane géré, nœuds Exoscale.

| Composant | kubeadm (TD) | SKS Exoscale |
|-----------|-------------|--------------|
| etcd | Vous le gérez | Managé |
| API Server | Vous le gérez | Managé |
| Upgrade CP | Manuel | Un clic / API |
| Nœuds | VMs complètes | Node pools |
| Réseau privé | Optionnel `.env` | Intégré |

**Création en une commande:**
```bash
exo compute sks create tp-k8s \
  --zone de-fra-1 --version 1.30 \
  --node-pools workers,2
```

---

## Démo SKS — Instructeur

### Étapes démo live (7 min)

```bash
# 1. Créer le cluster SKS
exo compute sks create tp-k8s --zone de-fra-1 \
  --version 1.30 --node-pools workers,2

# 2. Récupérer le kubeconfig
exo compute sks kubeconfig tp-k8s admin \
  --zone de-fra-1 > ~/.kube/config-sks

# 3. Vérifier
KUBECONFIG=~/.kube/config-sks kubectl get nodes
```

### Ce que les étudiants observent
- Cluster prêt en ~3 min (vs ~30 min avec kubeadm)
- Control plane invisible — abstrait
- `kubectl get nodes` ne montre que les workers

---

## SKS vs kubeadm — Comparaison pédagogique

| Critère | kubeadm (TD) | SKS (managé) |
|---------|-------------|--------------|
| Compréhension interne | ✓ Totale | ✗ Boîte noire |
| Temps de setup | ~30 min | ~3 min |
| Accès etcd | Oui | Non |
| Static pods CP | Visible | Caché |
| Coût opérationnel | Élevé | Faible |
| Cas d'usage prod | Petites équipes | Équipes DevOps |

**Point pédagogique:** le TD kubeadm vous donne la compréhension interne nécessaire pour opérer SKS intelligemment.

---

## SKS — mono-zone : la limite à connaître

### SKS est strictement mono-zone

```
exo compute sks create tp-k8s --zone de-fra-1 ...
                                       ↑
                               une seule zone
```

- Le control plane SKS tourne dans une zone Exoscale (`de-fra-1`, `ch-gva-2`, etc.)
- Les node pools sont liés à cette même zone
- **Pas de workers dans une autre zone** dans le même cluster SKS
- Si la zone tombe → cluster indisponible

### Comparaison avec les autres providers

| Provider | Multi-zone natif |
|----------|-----------------|
| GKE / EKS / AKS | ✓ nœuds sur plusieurs AZ dans un cluster |
| **SKS Exoscale** | ✗ mono-zone par design |
| kubeadm DIY | ✓ possible si VMs dans plusieurs zones |

### Stratégie HA sur Exoscale

- Plusieurs clusters SKS dans des zones différentes + outil multi-cluster (Liqo, Submariner)
- Ou kubeadm multi-zone avec VMs Exoscale réparties manuellement

---

## Cluster hybride SKS + kubeadm on-prem ?

### Non — pas nativement possible

SKS ne permet pas de joindre des nœuds extérieurs à son control plane :

| Obstacle | Raison |
|----------|--------|
| Tokens kubeadm join | Non exposés par SKS |
| CA privée du control plane | Gérée par Exoscale, inaccessible |
| Node pools SKS | Exclusivement des instances Exoscale |
| API server | Non configuré pour accepter des kubelets externes |

### Alternatives pour du vrai hybride

- **Liqo** — peering de clusters, partage de capacité entre K8s distincts
- **Submariner** — connectivité réseau cross-cluster (pod CIDR routable entre clusters)
- **Skupper** — service mesh multi-cluster via proxy, sans VPN

> L'hybride en production = **deux clusters séparés** reliés par un outil multi-cluster,
> pas un seul cluster avec des nœuds sur deux infrastructures

---

<!-- _class: lead -->

# Partie 13
## Observabilité du cluster — kube-prometheus-stack (30 min)

---

## Partie 13 - Timeline suggérée

- Architecture de la stack et composants : **5 min**
- Installation Helm + vérification : **10 min**
- Dashboards en ConfigMap : **10 min**
- Alertes et values production : **5 min**

---

## Pourquoi observer le cluster ?

| Couche | Quoi mesurer | Composant |
|--------|-------------|-----------|
| **Nodes** | CPU, RAM, disque, réseau | `node-exporter` (DaemonSet) |
| **Control plane** | API latence, etcd leader, scheduler queue | métriques internes |
| **Workloads** | pods running/pending, replicas, PVCs | `kube-state-metrics` |
| **Containers** | CPU/RAM par container, restarts | `cAdvisor` (intégré kubelet) |

- Ce chapitre = **observabilité infra du cluster**
- Pas de tracing applicatif (OpenTelemetry = formation séparée)
- Stack : **kube-prometheus-stack** — chart Helm tout-en-un officiel

---

## Architecture kube-prometheus-stack

<svg width="1100" height="290" viewBox="0 0 900 240" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true" font-family="sans-serif">
<rect x="10" y="10" width="230" height="220" rx="8" fill="#f8fafc" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5,3"/>
<text x="125" y="28" text-anchor="middle" fill="#475569" font-size="13" font-weight="bold">Sources de métriques</text>
<rect x="20" y="35" width="210" height="26" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="125" y="53" text-anchor="middle" fill="#1e40af" font-size="12">node-exporter (DaemonSet)</text>
<rect x="20" y="68" width="210" height="26" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="125" y="86" text-anchor="middle" fill="#1e40af" font-size="12">kube-state-metrics</text>
<rect x="20" y="101" width="210" height="26" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="125" y="119" text-anchor="middle" fill="#1e40af" font-size="12">kubelet /metrics/cadvisor</text>
<rect x="20" y="134" width="210" height="26" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="125" y="152" text-anchor="middle" fill="#1e40af" font-size="12">API server · etcd · scheduler</text>
<rect x="20" y="167" width="210" height="26" rx="5" fill="#dbeafe" stroke="#3b82f6" stroke-width="1.5"/>
<text x="125" y="185" text-anchor="middle" fill="#1e40af" font-size="12">controller-manager</text>
<line x1="240" y1="120" x2="310" y2="120" stroke="#7c3aed" stroke-width="2"/>
<text x="275" y="113" text-anchor="middle" fill="#7c3aed" font-size="11">scrape</text>
<rect x="310" y="60" width="200" height="120" rx="8" fill="#faf5ff" stroke="#7c3aed" stroke-width="2"/>
<text x="410" y="83" text-anchor="middle" fill="#7c3aed" font-size="13" font-weight="bold">Prometheus</text>
<text x="410" y="102" text-anchor="middle" fill="#7c3aed" font-size="12">stockage TSDB</text>
<text x="410" y="121" text-anchor="middle" fill="#6b7280" font-size="11">rétention : 7d (défaut)</text>
<line x1="330" y1="135" x2="490" y2="135" stroke="#c4b5fd" stroke-width="1"/>
<text x="410" y="152" text-anchor="middle" fill="#7c3aed" font-size="11">Operator + CRDs</text>
<text x="410" y="168" text-anchor="middle" fill="#7c3aed" font-size="11">ServiceMonitor · PrometheusRule</text>
<line x1="510" y1="90" x2="570" y2="70" stroke="#d97706" stroke-width="2"/>
<line x1="510" y1="120" x2="570" y2="120" stroke="#16a34a" stroke-width="2"/>
<line x1="510" y1="150" x2="570" y2="165" stroke="#dc2626" stroke-width="2"/>
<rect x="570" y="45" width="160" height="50" rx="8" fill="#fef3c7" stroke="#d97706" stroke-width="2"/>
<text x="650" y="68" text-anchor="middle" fill="#92400e" font-size="13" font-weight="bold">Grafana</text>
<text x="650" y="85" text-anchor="middle" fill="#d97706" font-size="12">dashboards</text>
<rect x="570" y="105" width="160" height="50" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
<text x="650" y="128" text-anchor="middle" fill="#15803d" font-size="13" font-weight="bold">Alertmanager</text>
<text x="650" y="145" text-anchor="middle" fill="#166534" font-size="12">routing alertes</text>
<rect x="570" y="160" width="160" height="50" rx="8" fill="#fee2e2" stroke="#dc2626" stroke-width="1.5"/>
<text x="650" y="183" text-anchor="middle" fill="#dc2626" font-size="12" font-weight="bold">Prom. Operator</text>
<text x="650" y="200" text-anchor="middle" fill="#dc2626" font-size="11">CRD manager</text>
<text x="450" y="230" text-anchor="middle" fill="#6b7280" font-size="11">namespace : monitoring</text>
</svg>

---

## Installation — Helm

```bash
# Ajouter le repo Prometheus Community
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

# Installer la stack complète dans le namespace monitoring
helm install kube-prom \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=7d \
  --version 65.1.1    # version stable en 2025
```

- Installe en une commande : Prometheus, Grafana, Alertmanager,
  node-exporter, kube-state-metrics, Prometheus Operator
- CRDs créés automatiquement : `ServiceMonitor`, `PrometheusRule`, `Alertmanager`

---

## Vérification de l'installation

```bash
kubectl get pods -n monitoring
# NAME                                           READY   STATUS
# alertmanager-kube-prom-alertmanager-0          2/2     Running
# kube-prom-grafana-7d9b8f6c4-xyz               3/3     Running
# kube-prom-kube-state-metrics-...              1/1     Running
# kube-prom-operator-...                         1/1     Running
# kube-prom-prometheus-node-exporter-<node>      1/1     Running  ×N
# prometheus-kube-prom-prometheus-0             2/2     Running

# Accès Grafana (admin / admin)
kubectl port-forward svc/kube-prom-grafana 3000:80 -n monitoring

# Accès Prometheus UI
kubectl port-forward svc/kube-prom-kube-prometheus-stack-prometheus \
  9090 -n monitoring
```

---

## Dashboards inclus par défaut

| Dashboard Grafana | Ce qu'il montre |
|-------------------|-----------------|
| Kubernetes / Compute Resources / Cluster | CPU + RAM global |
| Kubernetes / Compute Resources / Namespace | Par namespace |
| Node Exporter / Nodes | CPU, RAM, disque, réseau OS |
| Kubernetes / Networking / Cluster | Bande passante pods |
| etcd | Latence, transactions, DB size, leader |
| Kubernetes / API server | Requêtes/s, latence, error budget |

> Ces dashboards sont gérés en **ConfigMaps** dans le namespace `monitoring`
> ```bash
> kubectl get configmap -n monitoring -l grafana_dashboard=1
> ```

---

## Ajouter un dashboard — ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dashboard-nodes-overview
  namespace: monitoring
  labels:
    grafana_dashboard: "1"     # sidecar Grafana détecte ce label
data:
  nodes-overview.json: |
    {
      "title": "Cluster — Nodes Overview",
      "uid": "nodes-overview-v1",
      "panels": [
        {
          "title": "CPU Usage par nœud",
          "type": "timeseries",
          "targets": [{
            "expr": "1 - avg(rate(node_cpu_seconds_total{mode='idle'}[5m])) by (instance)"
          }]
        }
      ]
    }
```

- Le sidecar `grafana-sc-dashboard` scanne les ConfigMaps en continu
- Rechargement automatique — pas de redémarrage Grafana nécessaire

---

## ConfigMap — PromQL essentiels pour les nodes

```yaml
# Dans la section panels du dashboard JSON
panels:
  - title: "CPU Usage"
    expr: >
      1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))
      by (instance)

  - title: "Mémoire utilisée"
    expr: >
      1 - node_memory_MemAvailable_bytes
          / node_memory_MemTotal_bytes

  - title: "Disque utilisé"
    expr: >
      1 - node_filesystem_avail_bytes{fstype!="tmpfs"}
          / node_filesystem_size_bytes

  - title: "Pods running par nœud"
    expr: kubelet_running_pods

  - title: "Container restarts (1h)"
    expr: >
      increase(kube_pod_container_status_restarts_total[1h]) > 0
```

---

## ConfigMap — PromQL control plane

```yaml
# API server
- title: "API server — latence p99"
  expr: >
    histogram_quantile(0.99,
      rate(apiserver_request_duration_seconds_bucket
           {verb!="WATCH"}[5m]))

# etcd
- title: "etcd — leader changes"
  expr: increase(etcd_server_leader_changes_seen_total[1h])

- title: "etcd — fsync latency p99"
  expr: >
    histogram_quantile(0.99,
      rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))

# Scheduler
- title: "Pods en attente de scheduling"
  expr: scheduler_pending_pods

# Controller Manager
- title: "Work queue depth"
  expr: max(workqueue_depth) by (name)
```

---

## Alertes pré-configurées (~150 règles)

```bash
kubectl get prometheusrules -n monitoring
# NAME                                      AGE
# kube-prom-alertmanager.rules              10m
# kube-prom-etcd                            10m
# kube-prom-kubernetes-resources            10m
# kube-prom-node-exporter                   10m
# ...
```

| Alerte | Condition | Sévérité |
|--------|-----------|----------|
| `KubeNodeNotReady` | nœud non prêt > 15 min | critical |
| `KubePodCrashLooping` | CrashLoopBackOff | warning |
| `NodeFilesystemSpaceFillingUp` | disque > 80% | warning |
| `etcdMembersDown` | membre etcd down | critical |
| `CPUThrottlingHigh` | throttling > 25% | warning |

```bash
kubectl port-forward svc/kube-prom-alertmanager 9093 -n monitoring
```

---

## Values Helm — configuration production

```yaml
# values-production.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: fast
          resources:
            requests:
              storage: 50Gi
    resources:
      requests: { cpu: 500m, memory: 2Gi }
      limits:   { cpu: 2,    memory: 4Gi }

grafana:
  persistence: { enabled: true, size: 5Gi }
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard    # label ConfigMap à surveiller

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 2Gi
```

```bash
helm upgrade kube-prom prometheus-community/kube-prometheus-stack \
  -n monitoring -f values-production.yaml
```

---

<!-- _class: lead -->

# Questions de Synthèse
## Réponses attendues

---

## Q1: Architecture du Control Plane

### Réponse attendue

- **API Server:** Point d'entrée unique, validation, authentification
- **Scheduler:** Placement des pods sur les nœuds
- **Controller Manager:** Boucles de contrôle (ReplicaSet, Node, etc.)
- **etcd:** Base de données distribuée, état du cluster

**Point bonus:** Communication via API server uniquement

---

## Q2: CNI Overlay vs Avancé

### Réponse attendue

- **Overlay (Flannel):**
  - Encapsulation VXLAN
  - Simple
  - Léger surcoût performance

- **BGP (Calico):**
  - Routage natif
  - Meilleures performances
  - Plus complexe

---

## Q3: Static Pods pour Control Plane

### Réponse attendue

- **Bootstrap problem:** kubelet démarre avant l'API server
- **Haute disponibilité:** si API server crashe, kubelet le redémarre
- **Simplicité:** pas de dépendance à un orchestrateur externe

---

## Q4: Taints pour nœuds GPU

### Réponse attendue

```bash
# Tainter les nœuds GPU
kubectl taint nodes gpu-node-1 gpu=true:NoSchedule

# Pods GPU avec toleration
tolerations:
- key: gpu
  operator: Equal
  value: "true"
  effect: NoSchedule

# + nodeSelector ou nodeAffinity
```

---

## Q5: Drain vs Cordon

### Réponse attendue

- **Cordon:** Empêche nouveaux pods, garde les existants
- **Drain:** Cordon + évacuation des pods existants

### Cas d'usage

- **Cordon:** Tests, observation
- **Drain:** Maintenance, upgrade

---

## Q6: Ordre Upgrade

### Réponse attendue

- **Rétrocompatibilité:** kubelet N peut parler à API server N+1
- **Mais:** API server N+1 peut utiliser features incompatibles avec kubelet N-2
- **Donc:** Control plane first

---

## Q7: HA du Master

### Limitations actuelles

- Single point of failure
- Pas de maintenance sans downtime
- Pas de scaling

### Solutions

- Multiple masters (3 ou 5)
- LoadBalancer devant API servers
- etcd cluster (3 ou 5 membres)
- HA proxy pour kubeconfig

---

## Q8: RuntimeClass — Quand choisir quel runtime

### Réponse attendue

| Critère | runc | gVisor |
|---------|------|--------|
| Isolation | Kernel hôte partagé | Kernel virtuel par pod |
| Performance I/O | Natif | ~2-3× overhead |
| Code non fiable | Risqué | Recommandé |
| Bases de données | OK | Déconseillé |

- **runc** par défaut pour la majorité des workloads
- **gVisor** quand l'isolation prime sur la performance

---

## Q9: Réseau privé & SKS — Architecture cible

### Réponse attendue

| Scenario | Architecture recommandée |
|----------|------------------------|
| Lab éphémère (cours) | VMs public + security group |
| Formation persistante | VMs + réseau privé Exoscale |
| Prod petite équipe | SKS + réseau privé intégré |
| Apprentissage K8s | kubeadm (visibilité totale) |

- **Réseau privé** isole etcd/kubelet de l'exposition internet
- **SKS** sacrifie la visibilité interne pour la simplicité opérationnelle
- En prod: les deux ne sont pas exclusifs (SKS avec private network)

---

<!-- _class: lead -->

# Troubleshooting
## Commandes utiles

---

## Debugging général

```bash
# Événements récents
kubectl get events --all-namespaces \
  --sort-by='.lastTimestamp'

# État d'un nœud
kubectl describe node <node-name>

# Métriques (nécessite metrics-server)
kubectl top nodes
```

---

## Logs

```bash
# Logs kubelet
sudo journalctl -u kubelet -f

# Logs d'un pod (container précédent)
kubectl logs -n kube-system <pod> --previous
```

---

## Réseau

```bash
# Pods avec IPs
kubectl get pods -o wide --all-namespaces

# Debug depuis un pod
kubectl exec <pod> -- ip addr
kubectl exec <pod> -- ip route
```

---

## Certificats

```bash
# Vérifier expiration
kubeadm certs check-expiration

# Détails d'un certificat
openssl x509 -in /etc/kubernetes/pki/apiserver.crt \
  -text -noout
```

---

<!-- _class: lead -->

# Variantes du TD
## Adaptations possibles

---

## Si les étudiants vont vite

1. **NetworkPolicy:** Ajouter des règles Calico
2. **Ingress:** Installer nginx-ingress
3. **Monitoring:** Installer Prometheus via Helm
4. **Multi-master:** Ajouter un second control plane

---

## Si les étudiants sont lents

1. **Combiner parties 5 et 6** (drain déjà pratiqué)
2. **Skiper la migration CNI** (rester sur Flannel)
3. **Simplifier l'upgrade** (seulement control plane)

---

## Pour un TD plus long (4h)

1. **Persistent Storage** (Local PV, NFS)
2. **Helm** et déploiement d'apps complexes
3. **Backup/Restore** complet (Velero)
4. **RBAC** et sécurité avancée

---

<!-- _class: lead -->

# Checklist finale
## Pendant et après le TD

---

## Pendant le TD

- Surveiller la progression générale
- Identifier les étudiants en difficulté
- Valider chaque partie avant de continuer
- Encourager les questions
- Partager l'écran pour les démonstrations

---

## Après le TD

- Collecter les feedbacks
- Noter les problèmes rencontrés
- Mettre à jour les scripts si nécessaire
- Préparer les corrections des questions

---

<!-- _class: lead -->

# Ressources
## Documentation et outils

---

## Documentation de référence

- [kubeadm Documentation](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [kubelet Configuration](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [CKA Exam Curriculum](https://github.com/cncf/curriculum)

---

## Outils recommandés

```bash
# k9s - Interface terminal interactive
brew install k9s

# kubectx/kubens - Switch contexte
brew install kubectx

# stern - Logs multi-pods
brew install stern
```

---

<!-- _class: lead -->

# Questions ?

**Bon TD et n'hésitez pas à adapter selon votre contexte !**

---

<!-- _class: lead -->

# Annexe
## Quick Reference

---

## Commandes essentielles

```bash
# État du cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Debugging
kubectl describe <resource> <name>
kubectl logs <pod>
kubectl exec -it <pod> -- /bin/bash

# Maintenance
kubectl drain <node> --ignore-daemonsets
kubectl uncordon <node>
kubectl cordon <node>
```

---

## Fichiers importants

```
/etc/kubernetes/manifests/       # Static pods
/var/lib/kubelet/config.yaml     # Config kubelet
/etc/cni/net.d/                  # Config CNI
/etc/kubernetes/pki/             # Certificats
```

---

## Ports importants

| Port | Service |
|------|---------|
| 6443 | API Server |
| 2379-2380 | etcd |
| 10250 | kubelet API |
| 10251 | kube-scheduler |
| 10252 | kube-controller-manager |

---

<!-- _class: lead -->

**Contact et ressources dans le README**

------

<!-- _class: lead -->

# Partie Bonus
## HA Control Plane — 3 nœuds maîtres

---

## Bonus HA — Contexte et objectif

> *Dernier exercice avant suppression du cluster — pas une pratique de prod*

**Situation de départ :** 1 master + 2 workers, initialisé **sans** `--control-plane-endpoint`

**Ce qu'on va faire :**
- Réinitialiser le master **avec** `--control-plane-endpoint` et `--upload-certs`
- Réinitialiser chaque worker et le rejoindre en tant que **control plane**
- Retirer les taints `NoSchedule` pour que chaque nœud cumule les deux rôles

**Pourquoi ce n'est pas de la prod :**
- L'endpoint pointe sur l'IP du master → ce nœud reste un SPOF
- En prod : LB devant les 3 API servers, etcd séparé sur disques rapides
- Ici : on démontre le mécanisme, pas l'architecture cible

**Ce qu'on apprend :**
- La décision HA doit être prise **au `kubeadm init`** — pas rétroactivement
- kubeadm ne "promeut" pas — il reset + rejoint
- etcd passe de 1 à 3 membres → quorum réel

---

## Bonus HA — Séquence d'exécution

| Étape | Script | Nœud |
|-------|--------|------|
| 1 | `00-reinit-master.sh` | **master** |
| 2 | `scp /tmp/ha-join-info.sh root@<worker-ip>:/tmp/` | master → workers |
| 3 | `01-promote-worker.sh` | **worker1** |
| 4 | `01-promote-worker.sh` | **worker2** |
| 5 | `02-allow-scheduling.sh` | **master** |
| 6 | `03-validate-ha.sh` | **master** |

**⚠️ Ordre impératif** : le master doit être réinitialisé avant les workers. Le `ha-join-info.sh` doit être copié **avant** de reset les workers (le scp utilise l'ancien réseau).

---

## Bonus HA — Script 00 : réinitialisation master

**`./00-reinit-master.sh`** — sur le master

Ce que fait le script :
1. Draine les workers (`kubectl drain`)
2. `kubeadm reset -f` + nettoyage iptables
3. `kubeadm init --control-plane-endpoint=<master-ip>:6443 --upload-certs`
4. Réinstalle Calico (VXLAN)
5. Génère `/tmp/ha-join-info.sh` avec token, hash et certificate-key

```bash
# Contenu de /tmp/ha-join-info.sh généré automatiquement
MASTER_IP="10.0.0.10"
JOIN_TOKEN="abcdef.0123456789abcdef"
DISCOVERY_HASH="sha256:abc123..."
CERTIFICATE_KEY="def456..."
```

**Point instructeur :** le `--certificate-key` expire après **2h**. Si les workers rejoignent après ce délai, relancer `kubeadm init phase upload-certs --upload-certs` sur le master.

---

## Bonus HA — Script 01 : promotion des workers

**`./01-promote-worker.sh`** — sur chaque worker (après copie de `ha-join-info.sh`)

```bash
# Sur le master : copier le fichier vers chaque worker
scp /tmp/ha-join-info.sh root@<worker1-ip>:/tmp/
scp /tmp/ha-join-info.sh root@<worker2-ip>:/tmp/
```

Ce que fait le script sur chaque worker :
1. `kubeadm reset -f` + nettoyage
2. `kubeadm join --control-plane --certificate-key` (lit `ha-join-info.sh`)
3. Configure `~/.kube/config` → kubectl disponible sur le worker devenu master

**Ce qui se passe dans etcd :**

```
Avant  : 1 membre  → leader unique, pas de tolérance aux pannes
Après  : 3 membres → quorum à 2, tolère la perte d'1 nœud
```

---

## Bonus HA — Scripts 02 et 03

**`./02-allow-scheduling.sh`** — retire le taint `NoSchedule` des control planes

```bash
# Équivalent manuel
kubectl taint node master  node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint node worker1 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint node worker2 node-role.kubernetes.io/control-plane:NoSchedule-
```

Sans ce retrait, les pods applicatifs ne s'y scheduleraient pas — seuls les pods système (DaemonSets avec toleration) y tournent.

---

**`./03-validate-ha.sh`** — validation complète

- Tous les nœuds `Ready` + rôle `control-plane`
- `etcdctl member list` → 3 membres started
- DaemonSet de test schedulé sur les 3 nœuds
- Nettoyage automatique du pod de test


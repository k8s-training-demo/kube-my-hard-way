# Partie 6 — Upgrade du cluster Kubernetes (1.34 → 1.35)

## Ce qu'on fait ici

Un cluster Kubernetes ne se met jamais à jour tout seul. Chaque composant doit être
upgradé dans un ordre précis, nœud par nœud, pour éviter les interruptions de service.

Cette partie couvre l'upgrade complet d'un cluster kubeadm de la version 1.34 vers 1.35.

### Pourquoi cet ordre est obligatoire

```
etcd → kube-apiserver / controller-manager / scheduler → kubelet master → kubelet workers → addons
```

- **etcd d'abord** (si externe) : le control plane en dépend, il faut qu'il soit compatible.
- **Control plane avant les workers** : kubeadm interdit d'upgrader un worker vers une version
  supérieure à celle du control plane.
- **kubelet séparément** : kubelet tourne en tant que service systemd sur chaque nœud.
  `kubeadm upgrade apply` ne le touche pas — il faut l'upgrader et le redémarrer manuellement.
- **Un worker à la fois** : on vide (drain) le nœud avant de l'upgrader pour maintenir la
  disponibilité des applications.

### Politique de version

Kubernetes suit le schéma `v<major>.<minor>.<patch>`. Les upgrades de version mineure
sont **obligatoirement incrémentiels** : on ne peut pas sauter de 1.33 à 1.35 directement.
Un cluster supporte les versions N, N-1, N-2 entre control plane et kubelets.

---

## Scripts et ordre d'exécution

### Vue d'ensemble

```
[MASTER]  01-check-versions.sh          ← état initial, dépôts disponibles
[MASTER]  02-upgrade-control-plane.sh   ← kubeadm + composants control plane
[MASTER]  03-upgrade-master-kubelet.sh  ← kubelet/kubectl du master
[MASTER + WORKER]  04-upgrade-worker.sh ← un worker à la fois (3 étapes)
[MASTER]  05-validate-upgrade.sh        ← vérification complète du cluster
```

---

### 01-check-versions.sh — État initial et disponibilité des versions

**Où :** master
**Commande :**
```bash
./01-check-versions.sh
```

**Ce que ça fait :**
- Affiche les versions actuelles de kubeadm, kubectl, kubelet et de l'API server
- Liste les nœuds et leur version kubelet (`kubectl get nodes -o wide`)
- Vérifie la santé du cluster
- Liste les versions de kubeadm disponibles dans les dépôts DNF

**Ce qu'il faut regarder :**
La colonne `VERSION` de `kubectl get nodes` — tous les nœuds doivent être à 1.34.x avant
de commencer. Si certains sont déjà à 1.35, l'upgrade a été partiellement appliqué.

---

### 02-upgrade-control-plane.sh — Upgrade du control plane

**Où :** master
**Commande :**
```bash
./02-upgrade-control-plane.sh
```

**Ce que ça fait, étape par étape :**

1. **Met à jour le dépôt DNF** vers `pkgs.k8s.io/stable:/v1.35/` — les paquets sont
   organisés par version mineure, il faut pointer le bon repo.

2. **Upgrade kubeadm** vers 1.35.0 — kubeadm est le seul outil qui sait orchestrer
   l'upgrade des composants du control plane. Il doit être upgradé en premier.

3. **`kubeadm upgrade plan`** (dry-run) — affiche ce qui sera upgradé et vers quelle
   version. **Lire attentivement : kubeadm indique la version exacte de la commande
   à lancer** (ex: `kubeadm upgrade apply v1.35.3`, pas forcément celle du script).

4. **`kubeadm upgrade apply`** — met à jour les static pods du control plane :
   kube-apiserver, kube-controller-manager, kube-scheduler, etcd (si géré par kubeadm),
   CoreDNS, kube-proxy. Ces composants tournent comme des pods dans `/etc/kubernetes/manifests/`.

5. **Correction kubeadm-flags.env** (workaround bug 1.35.0) — kubeadm 1.35.0 réécrit
   `/var/lib/kubelet/kubeadm-flags.env` vide pendant l'upgrade, puis échoue à le relire
   dans la phase post-upgrade. Le script corrige le fichier et redémarre kubelet.

**Après ce script :** le control plane est à 1.35, mais `kubectl get nodes` montrera
encore les kubelets à 1.34.x — c'est normal, ils sont upgradés séparément.

---

### 03-upgrade-master-kubelet.sh — Upgrade kubelet/kubectl sur le master

**Où :** master
**Commande :**
```bash
./03-upgrade-master-kubelet.sh
```

**Ce que ça fait :**

1. **Drain du master** — évacue les pods vers les workers avant la maintenance.
   Le master peut héberger des pods si les taints ont été retirés (ce qui est le cas
   dans ce TD). `--ignore-daemonsets` laisse les DaemonSets (CNI, monitoring) en place.

2. **Upgrade kubelet + kubectl** — on déverrouille les paquets (versionlock),
   on installe la version cible, on reverrouille.

3. **`systemctl daemon-reload && systemctl restart kubelet`** — systemd doit relire
   la configuration du service avant de redémarrer. Sans `daemon-reload`, systemd
   pourrait utiliser l'ancienne définition de service.

4. **Attente de l'API server** — kubelet héberge l'API server (static pod). Après
   le redémarrage de kubelet, l'API server redémarre aussi — on attend qu'il réponde.

5. **Uncordon du master** — remet le nœud en service.

**Après ce script :** `kubectl get nodes` montrera le master à 1.35.x, les workers
encore à 1.34.x.

---

### 04-upgrade-worker.sh — Upgrade d'un worker (3 étapes, 2 machines)

Ce script gère une séquence qui se joue sur deux machines dans cet ordre :

```
MASTER                          WORKER
  │                               │
  ├─ master-drain <worker>        │   ← vide le nœud (API Kubernetes)
  │                               │
  │                ┌──────────────┤
  │                │ worker-upgrade   ← upgrade local (paquets + kubelet)
  │                └──────────────┤
  │                               │
  ├─ master-uncordon <worker>     │   ← remet en service (API Kubernetes)
```

**Pourquoi sur deux machines ?**
Le drain et l'uncordon passent par l'API Kubernetes — seul le master (ou une machine
avec kubeconfig admin) peut les exécuter. L'upgrade des paquets et le redémarrage
de kubelet sont locaux au nœud worker.

#### Étape 1 — Sur le master : drain

```bash
# Lister les workers disponibles
./04-upgrade-worker.sh

# Drainer un worker
./04-upgrade-worker.sh drain vm-etudiant-1-worker1
```

Le drain :
- Marque le nœud `SchedulingDisabled` (cordon) — plus aucun nouveau pod ne s'y planifie
- Évacue les pods existants vers d'autres nœuds (respecte les PodDisruptionBudgets)
- `--ignore-daemonsets` : les DaemonSets restent (CNI, kube-proxy — nécessaires au nœud)
- `--delete-emptydir-data` : supprime les volumes emptyDir (temporaires par définition)
- `--timeout=120s` : évite un blocage infini si un pod refuse de s'arrêter

#### Étape 2 — Sur le worker en SSH : upgrade

```bash
ssh -i vm_key root@<ip-du-worker>
sudo ./04-upgrade-worker.sh upgrade
```

Sur le worker :
1. Met à jour le dépôt DNF vers v1.35
2. Upgrade kubeadm (nécessaire pour `kubeadm upgrade node`)
3. **`kubeadm upgrade node`** — resynchronise la config kubelet locale avec le control
   plane (met à jour `kubelet.conf` et le certificat client du kubelet). Sur un worker,
   cette commande ne touche pas les composants du control plane.
4. Upgrade kubelet + kubectl, redémarre kubelet

#### Étape 3 — Sur le master : uncordon

```bash
./04-upgrade-worker.sh uncordon vm-etudiant-1-worker1
```

Remet le nœud en service : le scheduler peut de nouveau y placer des pods.

**Répéter les 3 étapes pour chaque worker.**

---

### 05-validate-upgrade.sh — Validation complète

**Où :** master
**Commande :**
```bash
./05-validate-upgrade.sh
```

**Ce que ça vérifie :**
- Tous les nœuds sont `Ready` et à la version 1.35.x
- Tous les pods système (`kube-system`) sont `Running`
- Santé de l'API server (`/readyz`)
- Déploiement d'un nginx de test sur 3 replicas → vérifie le scheduling
- Résolution DNS depuis un pod (`nslookup kubernetes.default`)
- Appel HTTP vers un ClusterIP → vérifie kube-proxy et le réseau

---

## Problèmes connus

### `error reading kubelet env file: no flags found`

**Symptôme :** kubeadm 1.35.0 échoue à la fin de `upgrade apply` avec :
```
error: error execution phase post-upgrade: error reading kubelet env file:
no flags found in file "/var/lib/kubelet/kubeadm-flags.env"
```

**Cause :** bug dans kubeadm 1.35.0 — il réécrit `kubeadm-flags.env` vide pendant
l'upgrade, puis échoue à le relire. Le control plane est déjà upgradé à ce stade.

**Fix (géré automatiquement par le script) :**
```bash
echo 'KUBELET_KUBEADM_ARGS=""' > /var/lib/kubelet/kubeadm-flags.env
systemctl daemon-reload && systemctl restart kubelet
```

### Worker bloqué en `SchedulingDisabled` après un échec

Si le script échoue après le drain mais avant l'uncordon :
```bash
./04-upgrade-worker.sh uncordon <nom-du-worker>
# ou directement :
kubectl uncordon <nom-du-worker>
```

### Vérifier l'état des nœuds à tout moment

```bash
kubectl get nodes -o wide
```

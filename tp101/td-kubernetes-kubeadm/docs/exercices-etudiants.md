# TD Kubernetes avec kubeadm

**Durée:** 2h45
**Objectifs:** Maîtriser l'installation, la configuration et la maintenance d'un cluster Kubernetes avec kubeadm

## Prérequis

- 3 machines virtuelles CentOS Stream 10
  - 1 master (control plane): 2 CPU, 4 GB RAM minimum
  - 2 workers: 2 CPU, 2 GB RAM minimum chacun
- Accès root ou sudo sur toutes les machines
- Connexion réseau entre toutes les machines
- Accès Internet pour télécharger les images et paquets

## Architecture cible

```
┌─────────────────┐
│   Master Node   │
│  (Control Plane)│
│  - API Server   │
│  - Scheduler    │
│  - Controller   │
│  - etcd         │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼───┐
│Worker│  │Worker│
│ #1   │  │ #2   │
└──────┘  └──────┘
```

---

## Partie 1 - Installation du cluster (35 min)

### Objectif
Installer et initialiser un cluster Kubernetes avec 1 master et 2 workers, avec le CNI Flannel.

### 1.1 Installation des prérequis (sur TOUS les nœuds)

Exécutez le script d'installation des prérequis sur chaque nœud :

```bash
cd td-kubernetes-kubeadm/scripts/partie1-installation
./01-prereqs.sh
```

**Questions de compréhension:**
1. Pourquoi faut-il désactiver le swap ?
2. Quel est le rôle de containerd ?
3. Quelle est la différence entre kubeadm, kubelet et kubectl ?

### 1.2 Initialisation du control plane (sur le MASTER uniquement)

```bash
./02-init-control-plane.sh
```

**IMPORTANT:** Sauvegardez la commande `kubeadm join` affichée à la fin. Vous en aurez besoin pour joindre les workers.

**À noter:**
- Le fichier de configuration kubectl est automatiquement créé dans `~/.kube/config`
- Le réseau pod CIDR est configuré à `10.244.0.0/16` (requis par Flannel)

### 1.3 Jonction des workers (sur chaque WORKER)

Sur chaque worker, exécutez :

```bash
./03-join-workers.sh
```

Vous serez invité à entrer la commande `kubeadm join` obtenue précédemment.

**Alternative:** Si vous avez perdu la commande, régénérez-la sur le master :
```bash
kubeadm token create --print-join-command
```

### 1.4 Installation du CNI Flannel (sur le MASTER)

```bash
./04-install-flannel.sh
```

Attendez que tous les pods Flannel soient en état `Running`.

### 1.5 Vérification du cluster (sur le MASTER)

```bash
./05-verify-cluster.sh
```

**Vérifications attendues:**
- Tous les nœuds doivent être en état `Ready`
- Les pods système dans `kube-system` doivent être en `Running`
- Les pods Flannel doivent être en `Running` sur chaque nœud
- Un pod de test doit pouvoir se déployer et communiquer

**Checkpoint:** Validez cette partie avec :
```bash
cd ../../validation
./validate-partie.sh 1
```

---

## Partie 2 - Configuration de la Kubelet et Static Pods (30 min)

### Objectif
Comprendre et modifier la configuration de kubelet, créer et gérer des static pods.

### 2.1 Anatomie de la configuration kubelet

Sur n'importe quel nœud, examinez la configuration actuelle :

```bash
sudo cat /var/lib/kubelet/config.yaml
```

**Questions de compréhension:**
1. Où sont stockées les clés d'authentification ?
2. Quelle est la valeur de `maxPods` ?
3. Quel est le chemin des static pods ?

### 2.2 Modification de la configuration kubelet

```bash
cd ../scripts/partie2-kubelet-static-pods
./01-modify-kubelet-config.sh
```

Ce script va :
- Sauvegarder la configuration actuelle
- Modifier le paramètre `maxPods` à 50
- Redémarrer kubelet

**Exercice:** Vérifiez que le changement a bien été pris en compte :
```bash
sudo journalctl -u kubelet -n 50 | grep -i max
```

### 2.3 Création d'un static pod de monitoring disque

Sur un worker, déployez le static pod de monitoring :

```bash
./02-deploy-static-pod.sh
```

**Sur le master**, vérifiez que le pod apparaît dans kubectl :

```bash
kubectl get pods -n kube-system | grep disk-monitor
```

**Exercice:** Affichez les logs du static pod :
```bash
kubectl logs -n kube-system disk-monitor-<nom-du-nœud>
```

### 2.4 Test du comportement des static pods

Sur le master, testez le comportement spécifique des static pods :

```bash
./03-test-static-pod-behavior.sh
```

**Questions de compréhension:**
1. Que se passe-t-il quand vous supprimez un static pod avec kubectl ?
2. Comment supprimer définitivement un static pod ?
3. Quel est l'avantage des static pods pour les composants du control plane ?

**Checkpoint:** Validez cette partie avec :
```bash
cd ../../validation
./validate-partie.sh 2
```

---

## Partie 3 - Taints, Tolerations et scheduling (20 min)

### Objectif
Comprendre les mécanismes de taints et tolerations pour contrôler le scheduling des pods.

### 3.1 Explorer les taints par défaut

Sur le master :

```bash
cd ../scripts/partie3-taints-tolerations
./01-explore-default-taints.sh
```

**Questions de compréhension:**
1. Quel taint est appliqué par défaut sur le master ?
2. Pourquoi les pods utilisateur ne se déploient pas sur le master ?
3. Comment les pods système arrivent-ils à s'exécuter sur le master ?

### 3.2 Ajouter des taints personnalisés

```bash
./02-add-custom-taints.sh
```

Ce script ajoute deux taints sur un worker :
- `gpu=true:NoSchedule` - Empêche le scheduling de nouveaux pods
- `environment=production:NoExecute` - Expulse les pods existants

**Observation:** Notez l'effet immédiat du taint `NoExecute` sur les pods existants.

### 3.3 Observer le comportement du scheduling

```bash
./03-observe-scheduling.sh
```

Ce script teste trois scénarios :
1. Pod sans toleration → Ne peut pas être schedulé sur les nœuds taintés
2. Pod avec tolerations spécifiques → Peut être schedulé sur les nœuds correspondants
3. Pod avec toleration wildcard → Peut être schedulé partout (même sur le master)

**Exercice:** Créez votre propre pod avec une toleration personnalisée.

**Nettoyage:** Supprimez les taints ajoutés :
```bash
WORKER_NODE=$(kubectl get nodes -o json | jq -r '.items[] | select(.metadata.labels."node-role.kubernetes.io/control-plane" == null) | .metadata.name' | head -1)
kubectl taint nodes $WORKER_NODE gpu=true:NoSchedule-
kubectl taint nodes $WORKER_NODE environment=production:NoExecute-
```

**Checkpoint:** Validez cette partie avec :
```bash
cd ../../validation
./validate-partie.sh 3
```

---

## Partie 4 - Migration CNI : Flannel vers Calico (25 min)

### Objectif
Comprendre l'architecture plugable du réseau Kubernetes et effectuer une migration CNI en production.

### 4.1 Sauvegarde de l'état du cluster

**IMPORTANT:** Toujours sauvegarder avant une opération critique !

Sur le master :

```bash
cd ../scripts/partie4-migration-cni
./01-backup-cluster-state.sh
```

### 4.2 Drain progressif des nœuds

```bash
./02-drain-nodes.sh
```

Ce script va drainer tous les workers, évacuant proprement les pods vers d'autres nœuds.

**Questions de compréhension:**
1. Pourquoi doit-on utiliser `--ignore-daemonsets` ?
2. Que signifie `SchedulingDisabled` ?
3. Que deviennent les pods évacués ?

### 4.3 Suppression de Flannel

**Étape A - Sur le master:**
```bash
./03-remove-flannel.sh master
```

**Étape B - Sur CHAQUE nœud (master + workers):**
```bash
sudo ./03-remove-flannel.sh node
```

**ATTENTION:** Ne redémarrez PAS kubelet après cette étape. Attendez l'installation de Calico.

### 4.4 Installation de Calico

Sur le master :

```bash
./04-install-calico.sh
```

Le script va :
- Télécharger le manifest Calico
- Configurer le réseau pod CIDR
- Déployer Calico
- Attendre que tous les pods Calico soient prêts

**Sur TOUS les nœuds**, redémarrez kubelet :
```bash
sudo systemctl start kubelet
```

### 4.5 Uncordon et validation

Sur le master :

```bash
./05-uncordon-and-validate.sh
```

Ce script va :
- Remettre les workers en mode schedulable
- Déployer des pods de test
- Valider la connectivité réseau inter-pods
- Tester le DNS
- Tester la connectivité externe

**Checkpoint:** Validez cette partie avec :
```bash
cd ../../validation
./validate-partie.sh 4
```

---

## Partie 5 - Drain et maintenance de nœuds (20 min)

### Objectif
Maîtriser les opérations de maintenance sur les nœuds avec drain, cordon et gestion des PDB.

### 5.1 Drain avec PodDisruptionBudget

Sur le master :

```bash
cd ../scripts/partie5-drain-maintenance
./01-drain-with-pdb.sh
```

Ce script démontre comment Kubernetes respecte les PDB lors du drain pour garantir la disponibilité des applications.

**Questions de compréhension:**
1. Qu'est-ce qu'un PodDisruptionBudget ?
2. Comment le drain respecte-t-il le PDB ?
3. Que se passe-t-il si le PDB ne peut pas être respecté ?

### 5.2 Drain avec DaemonSets

```bash
./02-drain-with-daemonsets.sh
```

**Observations clés:**
- Les DaemonSets ne peuvent pas être évacués (par design)
- `--ignore-daemonsets` est obligatoire pour drainer un nœud
- Les pods DaemonSet restent actifs même sur un nœud drainé

### 5.3 Simulation de panne et récupération

```bash
./03-simulate-node-failure.sh
```

Ce script interactif simule une panne imprévue de nœud et montre :
- Le délai de détection par Kubernetes
- Le comportement des pods sur un nœud NotReady
- La récupération automatique après redémarrage

**Suivez les instructions affichées** pour arrêter et redémarrer kubelet sur le worker.

**Checkpoint:** Validez cette partie avec :
```bash
cd ../../validation
./validate-partie.sh 5
```

---

## Partie 6 - Mise à jour du cluster avec kubeadm (25 min)

### Objectif
Effectuer une mise à jour sécurisée du cluster Kubernetes (control plane + workers).

### 6.1 Vérification des versions

Sur le master :

```bash
cd ../scripts/partie6-upgrade
./01-check-versions.sh
```

**Note:** Ce TD utilise une version d'exemple. En production, consultez la [documentation officielle](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/) pour la version à utiliser.

### 6.2 Upgrade du control plane

```bash
./02-upgrade-control-plane.sh
```

Le script va :
1. Upgrader kubeadm
2. Planifier l'upgrade (dry-run)
3. Appliquer l'upgrade du control plane

**IMPORTANT:** Vérifiez soigneusement le plan d'upgrade avant de confirmer !

### 6.3 Upgrade de kubelet et kubectl sur le master

```bash
./03-upgrade-master-kubelet.sh
```

Ce script va :
- Drainer le master
- Upgrader kubelet et kubectl
- Redémarrer kubelet
- Remettre le master en service

### 6.4 Upgrade des workers

Pour chaque worker, suivez cette procédure en 3 étapes :

**Étape 1 - Sur le master (drain):**
```bash
./04-upgrade-worker.sh master-drain worker1
```

**Étape 2 - Sur le worker (upgrade):**
```bash
sudo ./04-upgrade-worker.sh worker-upgrade
```

**Étape 3 - Sur le master (uncordon):**
```bash
./04-upgrade-worker.sh master-uncordon worker1
```

Répétez pour worker2.

### 6.5 Validation post-upgrade

Sur le master :

```bash
./05-validate-upgrade.sh
```

Ce script effectue une validation complète :
- Versions de tous les composants
- Santé du cluster
- Déploiement et réseau d'une application de test

**Checkpoint:** Validez cette partie avec :
```bash
cd ../../validation
./validate-partie.sh 6
```

---

## Validation finale

Exécutez le script de validation complète :

```bash
cd ../../validation
./validate-all.sh
```

Ce script vérifie tous les aspects du TD et affiche un rapport de synthèse.

---

## Questions de synthèse

1. **Architecture:** Expliquez le rôle de chaque composant du control plane.

2. **Réseau:** Quelle est la différence entre un CNI de type overlay (Flannel) et un CNI plus avancé (Calico) ?

3. **Static pods:** Pourquoi les composants du control plane (API server, scheduler, etc.) sont-ils déployés en static pods ?

4. **Scheduling:** Comment utiliseriez-vous les taints et tolerations pour dédier des nœuds à des workloads GPU ?

5. **Maintenance:** Quelle est la différence entre `kubectl drain` et `kubectl cordon` ?

6. **Upgrade:** Pourquoi doit-on upgrader le control plane avant les workers ?

7. **Haute disponibilité:** Quelles sont les limitations d'un cluster avec un seul master ? Comment les résoudre ?

---

## Ressources additionnelles

- [Documentation officielle Kubernetes](https://kubernetes.io/docs/)
- [kubeadm Reference](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [CNI Specification](https://github.com/containernetworking/cni)
- [Calico Documentation](https://docs.tigera.io/calico/latest/about/)
- [Best Practices Production](https://kubernetes.io/docs/setup/production-environment/)

---

## Troubleshooting

### Problème: Nœud reste NotReady après installation

**Solution:**
```bash
# Vérifier kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 100

# Vérifier le CNI
kubectl get pods -n kube-system
kubectl get pods -n kube-flannel  # ou kube-system pour Calico
```

### Problème: Pods ne peuvent pas communiquer

**Solution:**
```bash
# Vérifier les routes réseau
ip route
ip addr show

# Vérifier les pods CNI
kubectl get pods -n kube-system -l k8s-app=calico-node -o wide
kubectl logs -n kube-system <calico-pod>
```

### Problème: Drain échoue

**Solution:**
```bash
# Identifier les pods bloquants
kubectl get pods -o wide --field-selector spec.nodeName=<node>

# Forcer le drain si nécessaire (attention !)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force
```

---

## Partie 7 - RuntimeClass et isolation avec gVisor (25 min)

### Objectif

Comprendre le concept de **RuntimeClass** Kubernetes et mettre en place **gVisor** (runsc) comme runtime alternatif offrant une isolation renforcée au niveau du kernel.

> **Contexte** : Par défaut, tous les containers Kubernetes utilisent `runc` (runtime standard) qui partage le kernel Linux du nœud. gVisor implémente un **kernel en espace utilisateur** : chaque pod exécuté avec gVisor dispose de son propre kernel léger qui intercepte tous les syscalls, isolant le pod du vrai kernel hôte.

### 7.1 Installation de gVisor sur tous les nœuds

> **À exécuter sur TOUS les nœuds (master + workers)**

```bash
bash /root/scripts/partie7-runtimeclass/01-install-gvisor.sh
```

Ce script :
- Télécharge `runsc` (le runtime gVisor) et `containerd-shim-runsc-v1` (le shim containerd)
- Détecte la disponibilité de KVM (platform recommandé, plus performant que ptrace)
- Configure containerd via un drop-in file `/etc/containerd/conf.d/gvisor.toml`

> **Note containerd v2** : Le plugin CRI est désormais `io.containerd.cri.v1.runtime` (et non plus `io.containerd.grpc.v1.cri` de la v1). Les drop-in files dans `/etc/containerd/conf.d/` permettent d'étendre la config sans modifier `config.toml`.

### 7.2 Création de la RuntimeClass

> **À exécuter sur le MASTER**

```bash
bash /root/scripts/partie7-runtimeclass/02-create-runtimeclass.sh
```

Une `RuntimeClass` est un objet Kubernetes qui fait le lien entre un nom logique (`gvisor`) et le handler configuré dans containerd (`runsc`) :

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc        # doit correspondre au nom dans containerd config
```

Vérifiez la création :
```bash
kubectl get runtimeclass
```

### 7.3 Démonstration de l'isolation

> **À exécuter sur le MASTER**

```bash
bash /root/scripts/partie7-runtimeclass/03-test-isolation.sh
```

Ce script déploie deux pods côte à côte et compare ce qu'ils voient :

| Observation | Pod runc (standard) | Pod gVisor |
|-------------|---------------------|------------|
| `uname -r` | kernel réel du nœud (ex: `6.12.0`) | `4.4.0` (kernel gVisor) |
| `dmesg` | log kernel hôte | `Starting gVisor...` |
| `/proc/version` | vrai kernel Linux | `Linux version 4.4.0 #1 SMP` |

**Pourquoi c'est important** : avec runc, une CVE kernel (ex: escalade de privilèges via un syscall vulnérable) expose *tous* les containers du nœud. Avec gVisor, l'attaque atteint au maximum le kernel utilisateur de gVisor, pas le vrai kernel.

Pour utiliser gVisor dans un pod, il suffit d'ajouter `runtimeClassName` dans le podSpec :

```yaml
spec:
  runtimeClassName: gvisor   # ← une seule ligne
  containers:
  - name: app
    image: nginx:alpine
```

### 7.4 Déploiement d'une application avec RuntimeClass

```bash
bash /root/scripts/partie7-runtimeclass/04-deploy-with-runtimeclass.sh
```

Ce script montre :
1. Un **Deployment** avec `runtimeClassName: gvisor` (tous les pods utilisent gVisor)
2. Un pod dans un **namespace dédié** (`secure-ns`) pour les workloads sensibles

Vérifiez que tous les pods voient le kernel gVisor :
```bash
for pod in $(kubectl get pods -l app=secure-app -o name | sed 's|pod/||'); do
    echo "$pod: $(kubectl exec $pod -- uname -r)"
done
```

### 7.5 Comparaison de performance

```bash
bash /root/scripts/partie7-runtimeclass/05-performance-comparison.sh
```

gVisor intercepte chaque syscall → overhead systématique. Résultats typiques sur ce cluster :

| Benchmark | runc | gVisor | Overhead |
|-----------|------|--------|----------|
| 100× cat /proc/uptime | ~200 ms | ~620 ms | ~3× |
| 50× fork/exec (/bin/true) | ~160 ms | ~350 ms | ~2× |
| 10× requête DNS | ~140 ms | ~240 ms | ~1.7× |

**Quand utiliser gVisor** :
- Exécution de code non-fiable (CI/CD sandbox, code utilisateur)
- Multi-tenancy strict (plusieurs clients sur le même cluster)
- Traitement de données sensibles nécessitant une isolation maximale

**Quand ne pas l'utiliser** :
- Applications I/O-intensives (bases de données, streaming)
- Workloads temps-réel sensibles à la latence
- Applications nécessitant des accès directs au hardware

---

**Bon TD !**

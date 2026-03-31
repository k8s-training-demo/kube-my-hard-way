# Formation Kubernetes — Spécificités Exoscale

> **Disclaimer** — Ce TP est réalisé à titre purement éducatif et pédagogique. Les contenus, scripts et configurations présentés ici sont produits de manière indépendante et n'engagent en aucun cas Exoscale SA. Ils ne constituent pas une documentation officielle, un support technique ou une recommandation de la part d'Exoscale.
>
> Nous tenons à remercier chaleureusement Exoscale pour leur soutien à la formation des jeunes ingénieures et ingénieurs. Leur plateforme, leur CLI et leur infrastructure cloud rendent possible un apprentissage concret et professionnel de Kubernetes dans des conditions proches du monde réel.

Ce document recense tout ce qui est spécifique à l'environnement Exoscale dans cette formation.

---

## 1. Provisioning des VMs (`infra-exo/`)

Tous les scripts de provisioning utilisent le CLI `exo` et sont une réplique exacte de l'interface DigitalOcean (`infra-do/`) — les mêmes commandes fonctionnent sur les deux providers.

| Fichier | Rôle |
|---------|------|
| [`infra-exo/manage_vm.sh`](infra-exo/manage_vm.sh) | Créer / supprimer des VMs par tag |
| [`infra-exo/check_exo.sh`](infra-exo/check_exo.sh) | Lister les instances avec un label donné |
| [`infra-exo/provision-class.sh`](infra-exo/provision-class.sh) | Provisionner l'ensemble des VMs d'une promotion |
| [`infra-exo/setup-sg.sh`](infra-exo/setup-sg.sh) | Créer le security group `tp-k8s` avec les règles inter-nœuds |
| [`infra-exo/.env`](infra-exo/.env) | Variables de configuration (zone, type d'instance, SG) |

### Différences internes vs DigitalOcean

| Paramètre | DigitalOcean | Exoscale |
|-----------|-------------|---------|
| Tags | Tags natifs DO | Labels Exoscale (`<tag>=true`) |
| Zone par défaut | `fra1` | `de-fra-1` |
| Type d'instance | `s-2vcpu-8gb-amd` | `standard.medium` (2 vCPU / 4 GB) |
| Template OS | CentOS Stream 10 | `Linux CentOS Stream 10 64-bit` |
| Authentication | `DIGITALOCEAN_ACCESS_TOKEN` | `EXOSCALE_API_KEY` + `EXOSCALE_API_SECRET` |

### Prérequis

```bash
# Installer le CLI Exoscale
brew install exoscale/tap/exo       # macOS
# ou https://github.com/exoscale/cli/releases

# Configurer les credentials
exo config

# Variables d'environnement (alternative)
export EXOSCALE_API_KEY=...
export EXOSCALE_API_SECRET=...
```

### Commandes types

```bash
# Créer le security group (une seule fois par compte)
./infra-exo/setup-sg.sh

# Provisionner 3 VMs pour un étudiant
./infra-exo/manage_vm.sh --tags "etudiant-1" --count 3

# Vérifier les instances actives
./infra-exo/check_exo.sh etudiant-1

# Supprimer les VMs d'un étudiant
./infra-exo/manage_vm.sh --tags "etudiant-1" --delete

# Provisionner toute une promotion (N étudiants × 3 VMs)
./infra-exo/provision-class.sh
```

---

## 2. Security Group (`tp-k8s`)

Le script [`infra-exo/setup-sg.sh`](infra-exo/setup-sg.sh) crée un security group avec les règles suivantes :

| Protocole | Port(s) | Source | Usage |
|-----------|---------|--------|-------|
| TCP | 22 | `0.0.0.0/0` | SSH depuis l'instructeur/étudiants |
| TCP | 80 | `0.0.0.0/0` | Grafana via reverse proxy hostPort |
| TCP | 6443 | `0.0.0.0/0` | API Kubernetes — accès `kubectl` externe, `get-kubeconfig.sh` |
| TCP | 30000-32767 | `0.0.0.0/0` | NodePorts (Grafana, services exposés) |
| TCP | 1-65535 | intra-groupe | Trafic inter-nœuds Kubernetes |
| UDP | 1-65535 | intra-groupe | Calico VXLAN (UDP 4789), CoreDNS |

firewalld est **désactivé** sur les nœuds — les security groups Exoscale font office de pare-feu.

```bash
# Création du security group (une seule fois par compte/zone)
./infra-exo/setup-sg.sh

# Référencer le SG dans la config
echo "SECURITY_GROUP=tp-k8s" >> infra-exo/.env
```

---

## 3. Réseau Calico — VXLAN obligatoire

**Fichier concerné :** [`tp101/td-kubernetes-kubeadm/scripts/partie-04-migration-cni/04-install-calico.sh`](tp101/td-kubernetes-kubeadm/scripts/partie-04-migration-cni/04-install-calico.sh)

Sur Exoscale, le protocole IPIP (IP protocol 4) est bloqué par les security groups. Calico utilise IPIP par défaut → il faut passer en **mode VXLAN**.

Le script détecte et applique automatiquement ce mode :

```bash
# Patch automatisé dans 04-install-calico.sh
kubectl patch ippools default-ipv4-ippool --type=merge \
  -p '{"spec": {"ipipMode": "Never", "vxlanMode": "Always"}}'
kubectl rollout restart daemonset/calico-node -n kube-system
```

Après la migration Flannel → Calico, deux étapes supplémentaires sont requises :

```bash
kubectl rollout restart daemonset/kube-proxy -n kube-system
kubectl delete pods -n kube-system -l k8s-app=kube-dns
```

---

## 4. gVisor — KVM disponible

**Fichier concerné :** [`tp101/td-kubernetes-kubeadm/scripts/partie-08-runtimeclass/01-install-gvisor.sh`](tp101/td-kubernetes-kubeadm/scripts/partie-08-runtimeclass/01-install-gvisor.sh)

Les VMs Exoscale exposent `/dev/kvm` → gVisor peut utiliser le **platform KVM** (plus performant que ptrace).

```toml
# /etc/containerd/runsc.toml
[runsc_config]
platform = "kvm"
```

Overhead typique avec KVM : ~2-3× pour les I/O et fork/exec (vs ~10× avec ptrace).

---

## 5. Initialisation des nœuds CentOS Stream 10

**Fichier concerné :** [`tp101/td-kubernetes-kubeadm/scripts/partie-01-installation/01-prereqs.sh`](tp101/td-kubernetes-kubeadm/scripts/partie-01-installation/01-prereqs.sh)

Avant d'exécuter kubeadm sur Exoscale, deux étapes spécifiques au provider :

```bash
# Sur chaque nœud — les security groups Exoscale remplacent firewalld
systemctl stop firewalld && systemctl disable firewalld

# Vérifier que tous les nœuds sont dans le security group tp-k8s
# (ports Kubernetes ouverts intra-groupe : 6443, 2379-2380, 10250-10259, etc.)
```

---

## 6. Module 12 — SKS Exoscale (Kubernetes managé)

La formation propose une partie optionnelle sur **SKS** (Scalable Kubernetes Service), le Kubernetes managé d'Exoscale, en comparaison avec l'installation kubeadm manuelle.

Points abordés dans les slides ([`tp101/td-kubernetes-kubeadm/docs/slides-instructeur.md`](tp101/td-kubernetes-kubeadm/docs/slides-instructeur.md)) :

| Aspect | kubeadm (manuel) | SKS Exoscale |
|--------|-----------------|--------------|
| Control plane | Géré par l'étudiant | Géré par Exoscale |
| CA privée | Générée par kubeadm | Gérée par Exoscale |
| Node pools | VMs libres | Instances Exoscale dédiées |
| Mise à jour | `kubeadm upgrade` | Automatisée via SKS |

```bash
# Créer un cluster SKS
exo compute sks create tp-k8s \
  --zone de-fra-1 \
  --kubernetes-version 1.35 \
  --nodepool-size 2

# Récupérer le kubeconfig
exo compute sks kubeconfig tp-k8s admin > ~/.kube/config
```

---

## 7. Cloud Controller Manager (CCM) Exoscale

**Fichiers concernés :**
- [`infra-exo/setup-ccm-token.sh`](infra-exo/setup-ccm-token.sh) — génération des credentials IAM par étudiant
- [`tp101/td-kubernetes-kubeadm/scripts/partie-13-prometheus/05-install-ccm.sh`](tp101/td-kubernetes-kubeadm/scripts/partie-13-prometheus/05-install-ccm.sh) — déploiement du CCM sur le cluster

Le CCM Exoscale permet aux clusters kubeadm de bénéficier de l'intégration cloud native : tout `Service` de type `LoadBalancer` déclenche automatiquement la création d'un **NLB Exoscale**.

### Architecture

```
kubectl apply Service type:LoadBalancer
        ↓
  CCM Exoscale (pod dans kube-system)
        ↓
  API Exoscale → NLB créé automatiquement
        ↓
  EXTERNAL-IP assignée au Service
```

### Credentials IAM — principe du moindre privilège

Chaque étudiant reçoit un **IAM role restreint** avec uniquement les permissions nécessaires au CCM :

| Service | Opérations autorisées |
|---------|----------------------|
| Compute | `get-instance`, `list-instances`, `get-instance-type`, `list-zones` |
| Load Balancer | `create/delete/get/update-load-balancer`, gestion des services NLB |
| Elastic IP | `list/get-elastic-ip`, `attach/detach-instance-to-elastic-ip` |

```bash
# Sur le poste instructeur — génère 1 IAM role + API key + Secret K8s par étudiant
./infra-exo/setup-ccm-token.sh --prefix etudiant --count 15 --zone de-fra-1

# Les secrets sont écrits dans /tmp/ccm-secrets-XXXXXX/ (jamais dans le repo)
# Distribuer ccm-secret-etudiant-NN.yaml à chaque étudiant
```

### Déploiement sur le cluster étudiant

```bash
# 1. Appliquer le secret fourni par l'instructeur
kubectl apply -f ccm-secret-etudiant-01.yaml

# 2. Installer le CCM (configure kubelet + déploie le pod CCM)
./scripts/partie-13-prometheus/05-install-ccm.sh

# 3. Vérifier — Grafana passe en LoadBalancer avec EXTERNAL-IP
kubectl get svc kube-prom-grafana -n monitoring
```

### Image Docker

```
exoscale/cloud-controller-manager:0.34.0
```
Source : [hub.docker.com/r/exoscale/cloud-controller-manager](https://hub.docker.com/r/exoscale/cloud-controller-manager)

### Secret Kubernetes — format attendu

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: exoscale-ccm-credentials
  namespace: kube-system
type: Opaque
stringData:
  api-key: "EXOxxxxxxxxxxxx"
  api-secret: "xxxxxxxxxxxxxxxxxxxx"
  zone: "de-fra-1"
```

---

## 8. NLB Exoscale — Load Balancer L4

Les NLB sont utilisés à deux fins dans la formation :

### 8a. Via le CCM (automatique — Partie 13)

Dès qu'un `Service type:LoadBalancer` est créé sur un cluster avec le CCM installé, Exoscale provisionne automatiquement un NLB et assigne l'IP au Service. C'est l'usage pédagogique principal — les étudiants voient l'intégration cloud en action.

### 8b. Manuellement via le CLI (Partie 11 — HA)

Le module Haute Disponibilité montre comment créer un NLB manuellement pour exposer l'API server Kubernetes :

```bash
# Créer un NLB
exo compute load-balancer create tp-k8s-nlb --zone de-fra-1

# Ajouter un service (port 6443 → masters)
exo compute load-balancer service add tp-k8s-nlb \
  --name kube-api \
  --port 6443 \
  --target-port 6443 \
  --protocol tcp
```

> **Contrainte Exoscale** : les backends d'un NLB doivent appartenir à un **Instance Pool**. Les VMs standalone (kubeadm) ne sont pas supportées comme backends NLB — le CCM démarre mais retourne `couldn't infer any Instance Pool from cluster Nodes`. Cette intégration fonctionne uniquement avec **SKS** (qui crée des Instance Pools automatiquement). Sur kubeadm, utiliser le reverse proxy hostPort (`04-expose-grafana-hostport.sh`) pour exposer Grafana sur le port 80.

---

## 9. Haute disponibilité multi-zone

Le module 11 présente une stratégie HA spécifique Exoscale :

- Masters répartis sur plusieurs zones (`de-fra-1`, `de-fra-2`)
- NLB Exoscale comme point d'entrée unique pour l'API server
- Node pools SKS dans plusieurs zones pour la résilience des workers

---

## Résumé des adaptations par module

| Module | Adaptation Exoscale | Fichier |
|--------|-------------------|---------|
| Provisioning | CLI `exo` + labels + security groups | `infra-exo/` |
| Partie 1 — Installation | Désactivation firewalld | `partie-01-installation/01-prereqs.sh` |
| Partie 4 — CNI | Calico VXLAN (IPIP bloqué) | `partie-04-migration-cni/04-install-calico.sh` |
| Partie 8 — RuntimeClass | gVisor platform KVM | `partie-08-runtimeclass/01-install-gvisor.sh` |
| Partie 13 — Observabilité | CCM + NLB auto pour Grafana LoadBalancer | `partie-13-prometheus/05-install-ccm.sh` |
| Module 11 — HA | NLB Exoscale manuel | slides-instructeur.md |
| Module 12 — SKS | Kubernetes managé Exoscale | slides-instructeur.md |

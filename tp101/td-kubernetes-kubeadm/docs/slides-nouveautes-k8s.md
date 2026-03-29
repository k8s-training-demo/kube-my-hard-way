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

# Partie 1
## Nouveautés Kubernetes (45 min)
### Versions 1.30 à 1.35

---

<!-- _class: toc -->

## Partie 1 - Plan

| Version | Fonctionnalités clés | Slide |
|---------|---------------------|-------|
| [K8s 1.30](#12) | Swap, ValidatingAdmissionPolicy, User Namespaces | [→](#12) |
| [Sidecars](#17) | Native Sidecar Containers | [→](#17) |
| [K8s 1.31](#25) | AppArmor GA, OCI Volumes, NFTables | [→](#25) |
| [K8s 1.32](#36) | DRA, Memory Manager, Volume Group Snapshots | [→](#36) |
| [K8s 1.33](#47) | In-Place Pod Resize, Sidecars GA, Job Success Policy | [→](#47) |
| [K8s 1.34](#58) | DRA Stable, Traffic Distribution, Container Restart Rules | [→](#58) |
| [K8s 1.35](#68) | In-Place Resize GA, DRA GA, PDB améliorations, ClusterTrustBundle | [→](#68) |

[← Retour menu principal](#8)

---

## Vue d'ensemble des versions récentes

### Timeline des versions

- **Kubernetes 1.30** - Avril 2024 - "Uwubernetes"
- **Kubernetes 1.31** - Août 2024 - "Elli"
- **Kubernetes 1.32** - Décembre 2024 - "Penelope"
- **Kubernetes 1.33** - Avril 2025 - "Octarine"
- **Kubernetes 1.34** - Août 2025 - "Of Wind & Will"
- **Kubernetes 1.35** - Décembre 2025 - "Timbernetes"

**Cycle de release:** ~4 mois entre chaque version
**Support:** 14 mois pour chaque version

---

## Kubernetes 1.30 - Avril 2024

### Fonctionnalités majeures

#### 1. Support du Swap (Beta)
- **KEP-2400:** Support du swap memory en mode beta
- Permet l'utilisation de swap sur les nœuds
- Contrôle fin via `memorySwap` dans kubelet config

```yaml
# Configuration kubelet
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
memorySwap:
  swapBehavior: LimitedSwap  # ou NoSwap, UnlimitedSwap
```

---

## Kubernetes 1.30 - Swap (suite)

### Modes de swap disponibles

![bg right:45% fit](diagrams/swap-memory-kubernetes.png)

**1. NoSwap (défaut)**
```yaml
swapBehavior: NoSwap
```
Comportement classique: pas de swap

**2. LimitedSwap (recommandé)**
```yaml
swapBehavior: LimitedSwap
```
Swap limité aux pods avec QoS "Burstable"
Respecte les limites mémoire des containers

---

## Kubernetes 1.30 - Swap (suite)

**3. UnlimitedSwap (attention)**
```yaml
swapBehavior: UnlimitedSwap
```
Tous les pods peuvent utiliser le swap
Risque de dégradation des performances

### Configuration au niveau Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: swap-demo
spec:
  containers:
  - name: app
    resources:
      limits:
        memory: "200Mi"
        memory.swap: "100Mi"  # Limite de swap
```

---

## K8s 1.30 - ValidatingAdmissionPolicy (GA)

![bg right:45% fit](diagrams/validating-admission-policy.png)

**Remplace les webhooks par des règles CEL natives**

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: max-replicas
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: ["apps"]
      resources: ["deployments"]
  validations:
  - expression: "object.spec.replicas <= 10"
    message: "Max 10 replicas autorisés"
```

---

## K8s 1.30 - User Namespaces (Beta)

![bg right:45% fit](diagrams/user-namespaces.png)

**Protection contre les CVE critiques (CVE-2024-21626)**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  hostUsers: false  # Active user namespaces
  containers:
  - name: app
    image: nginx
    securityContext:
      runAsUser: 0  # root DANS le container
      # Mais mappé à UID 65534 sur l'hôte !
```

---

![bg fit](diagrams/sidecar-containers.png)

---

## Native Sidecars - Le problème résolu

**Avant K8s 1.28**, les sidecars étaient des containers réguliers :

- Aucune garantie d'ordre de démarrage
- Une seule `restartPolicy` pour tous les containers
- Le sidecar pouvait démarrer **après** l'application
- Contournements complexes nécessaires (sleep, scripts)

**Solution K8s 1.28+ (GA en 1.29)** : Init containers avec `restartPolicy: Always`

---

## Native Sidecars - Configuration

```yaml
apiVersion: v1
kind: Pod
spec:
  initContainers:
  - name: istio-proxy
    image: istio/proxyv2
    restartPolicy: Always  # Clé: transforme en sidecar!
    readinessProbe:        # Probes supportées
      tcpSocket:
        port: 15021
      periodSeconds: 5
  containers:
  - name: app
    image: myapp:v1
    # L'app démarre APRÈS que le proxy soit ready
```

---

## Native Sidecars - Caractéristiques

| Aspect | Init Container | Native Sidecar | Container Régulier |
|--------|---------------|----------------|-------------------|
| Ordre de démarrage | Séquentiel strict | Respecté | Aucun |
| Bloque le suivant | Oui | **Non** | Non |
| `restartPolicy` | Once | **Always** | - |
| Probes | Non | **Oui** | Oui |
| Durée de vie | Courte | **Pod entier** | Pod entier |
| Arrêt | Avant app | **Après app** | Avec app |

---

## Native Sidecars - Cycle de vie

1. **Init containers classiques** s'exécutent séquentiellement
2. **Sidecar démarre** mais **ne bloque pas** la suite
3. **Containers réguliers** démarrent en parallèle
4. **Sidecar reste actif** pendant toute la vie du Pod
5. **À l'arrêt** : containers réguliers d'abord, sidecars ensuite

**Cas d'usage :** Istio/Envoy proxy, Fluent-bit, Vault Agent, OpenTelemetry

---

## K8s 1.30 - Sleep PreStop Hook

![bg right:45% fit](diagrams/sleep-prestop-hook.png)

**Action native pour graceful shutdown**

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    lifecycle:
      preStop:
        sleep:
          seconds: 10  # Natif, pas de script!
```

**Avantage:** Fonctionne avec images distroless

---

## K8s 1.30 - HPA Container Metrics (GA)

![bg right:50% fit](diagrams/hpa-container-resources.png)

**Scaling basé sur un container spécifique**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    name: my-deployment
  metrics:
  - type: ContainerResource
    containerResource:
      name: cpu
      container: app  # Ignore les sidecars!
      target:
        type: Utilization
        averageUtilization: 70
```

---

## K8s 1.30 - Pod Scheduling Readiness (GA)

![bg right:45% fit](diagrams/pod-scheduling-readiness.png)

**Contrôle fin du moment de scheduling**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: batch-job
spec:
  schedulingGates:
  - name: quota-controller/approved
  - name: data-loader/ready
  containers:
  - name: training
    image: ml-training:v1
```

**Cas d'usage:** Quota validation, licence check, data prep

---

## Kubernetes 1.31 - Août 2024 "Elli"

### 45 améliorations dont 11 GA, 22 Beta, 12 Alpha

**Thèmes majeurs:**
- **AppArmor GA** - Sécurité renforcée
- Transition vers **cloud-neutral**
- **NFTables** remplace iptables
- **Multi-Service CIDRs** pour grands clusters
- OCI Volumes pour **AI/ML workloads**

**10 ans de Kubernetes!** 🎂

---

## K8s 1.31 - AppArmor Support (GA)

**Sécurité Linux intégrée nativement**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    appArmorProfile:
      type: RuntimeDefault  # ou Localhost, Unconfined
  containers:
  - name: app
    image: nginx
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-nginx  # Profil custom
```

**Migration:** Annotations → champs `securityContext`

---

![bg fit](diagrams/oci-image-volumes.png)

---

## OCI Image Volumes - Configuration

**Monter des images OCI comme volumes read-only**

```yaml
apiVersion: v1
kind: Pod
spec:
  volumes:
  - name: ml-model
    image:
      reference: registry.io/models/bert:v2
      pullPolicy: IfNotPresent
  containers:
  - name: inference
    image: ml-serving:v1  # Image légère sans modèle
    volumeMounts:
    - name: ml-model
      mountPath: /models
      readOnly: true
```

---

## OCI Image Volumes - Avantages

**Pourquoi séparer modèles et code ?**

| Aspect | Image monolithique | OCI Volume |
|--------|-------------------|------------|
| Taille image | 10+ GB avec modèle | ~500 MB sans modèle |
| Temps de pull | Minutes | Secondes |
| Cache | Invalide si modèle change | Réutilisable |
| Versioning | Couplé au code | Indépendant |

**Cas d'usage AI/ML:**
- Modèles LLM (Llama, GPT)
- Datasets de référence
- Configurations partagées

---

## K8s 1.31 - VolumeAttributesClass (Beta)

![bg right:50% fit](diagrams/volume-attributes-class.png)

**Modifier IOPS/throughput sans downtime**

```yaml
apiVersion: storage.k8s.io/v1beta1
kind: VolumeAttributesClass
metadata:
  name: high-performance
driverName: ebs.csi.aws.com
parameters:
  iops: "10000"
  throughput: "500"
---
# Modifier un PVC existant
kubectl patch pvc my-data \
  -p '{"spec":{"volumeAttributesClassName":"high-performance"}}'
```

---

## K8s 1.31 - NFTables Backend (Beta)

**Successeur moderne d'iptables pour kube-proxy**

| Aspect | iptables | NFTables |
|--------|----------|----------|
| Performance | O(n) rules | O(1) lookup |
| Scalabilité | ~5000 services | **~50000 services** |
| Atomicité | Non | **Oui** |
| Kernel requis | 2.4+ | **5.13+** |

---

## NFTables - Migration

**Prérequis:**
- Linux Kernel **5.13+**
- Feature gate `NFTablesProxyMode` (activé par défaut en 1.31)

```bash
# Vérifier le kernel
uname -r  # >= 5.13

# Modifier kube-proxy ConfigMap
kubectl -n kube-system edit cm kube-proxy
# mode: nftables

# Redémarrer kube-proxy
kubectl -n kube-system rollout restart ds kube-proxy
```

**Note:** Les règles iptables existantes ne sont PAS migrées

---

## K8s 1.31 - Multi-Service CIDRs (Beta)

**Résout l'épuisement d'IPs de services**

```yaml
apiVersion: networking.k8s.io/v1beta1
kind: ServiceCIDR
metadata:
  name: secondary-cidr
spec:
  cidrs:
  - 10.200.0.0/16  # Nouveau range!
```

**Avantages:**
- Extension sans downtime
- Pas de migration nécessaire
- Clusters très larges supportés

---

## K8s 1.31 - Deprecations majeures

### Cloud Provider Externalization

**Retiré du core Kubernetes:**
- Code spécifique AWS/GCP/Azure
- In-tree cloud providers

**Nouveau modèle:**
```
Cloud Controller Manager (externe)
     ↓
CSI Drivers (stockage)
     ↓
Out-of-tree plugins
```

---

## Kubernetes 1.32 - Décembre 2024 "Penelope"

### 44 améliorations dont 13 GA, 12 Beta, 19 Alpha

**Thème:** Hommage aux racines grecques (Kubernetes = pilote)

**Highlights:**
- **100% Conformance Test Coverage** - première fois!
- **Memory Manager GA** - allocation NUMA
- **Custom Resource Field Selectors GA** - filtrage efficace
- **DRA Structured Parameters Beta** - GPU/TPU sans driver
- **Volume Group Snapshots Beta** - backups cohérents

---

## K8s 1.32 - Nouvelles fonctionnalités GA

| Feature | Description |
|---------|-------------|
| **Memory Manager** | Allocation mémoire NUMA-aware |
| **Custom Resource Field Selectors** | `kubectl get --field-selector` pour CRs |
| **Bound SA Token + Node** | Token inclut le nom du node |
| **Structured Authorization** | Multi-authorizers + CEL |
| **StatefulSet PVC Auto-Delete** | Nettoyage automatique PVCs |

**13 features GA au total !**

---

![bg fit](diagrams/dynamic-resource-allocation.png)

---

## DRA - Pourquoi pas device plugins ?

| Aspect | Device Plugins | DRA |
|--------|---------------|-----|
| Allocation | Compteur simple | **Sélection avancée** |
| Partage | Non | **Oui** (time-slicing) |
| Scheduler | Aveugle | **Aware** |
| Configuration | Statique | **Dynamique** |
| Cluster Autoscaler | Limité | **Intégré** |

---

## DRA - Configuration complète

```yaml
apiVersion: resource.k8s.io/v1beta1
kind: ResourceClaim
metadata:
  name: gpu-claim
spec:
  devices:
    requests:
    - name: gpu
      deviceClassName: nvidia-gpu
      selectors:
      - cel:
          expression: device.attributes["memory"].quantity >= "16Gi"
---
apiVersion: v1
kind: Pod
spec:
  resourceClaims:
  - name: training-gpu
    resourceClaimName: gpu-claim
  containers:
  - name: training
    resources:
      claims:
      - name: training-gpu
```

---

![bg fit](diagrams/volume-group-snapshots.png)

---

## Volume Group Snapshots - Le problème

**Avant:** Snapshots individuels = incohérences possibles

```
t=0: Snapshot volume données  ✓
t=1: Write transaction...
t=2: Snapshot volume WAL      ✓  ← Désynchronisé!
```

**Après:** Snapshots groupés = cohérence garantie

```
t=0: Snapshot [données + WAL + logs] atomique ✓
```

---

## Volume Group Snapshots - Configuration

```yaml
apiVersion: groupsnapshot.storage.k8s.io/v1beta1
kind: VolumeGroupSnapshot
metadata:
  name: postgres-backup-daily
spec:
  volumeGroupSnapshotClassName: csi-aws-snapclass
  source:
    selector:
      matchLabels:
        app: postgresql
        tier: database
# Capture tous les PVCs avec ces labels ensemble
```

**Cas d'usage:** PostgreSQL, MongoDB replica sets, Kafka

---

## K8s 1.32 - Memory Manager (GA)

**Allocation mémoire NUMA-aware pour workloads critiques**

**Pourquoi NUMA importe ?**
- Accès mémoire locale : ~100ns
- Accès mémoire distante : ~300ns (3x plus lent!)

---

## Memory Manager - Configuration

```yaml
# /var/lib/kubelet/config.yaml
topologyManagerPolicy: single-numa-node  # ou best-effort
memoryManagerPolicy: Static
reservedMemory:
- numaNode: 0
  limits:
    memory: 1Gi  # Réservé système
```

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: latency-critical
    resources:
      requests:
        memory: "8Gi"
        cpu: "4"
      limits:
        memory: "8Gi"  # Guaranteed QoS requis!
        cpu: "4"
```

**Cas d'usage:** HFT, telecom 5G, gaming temps réel

---

## K8s 1.32 - Custom Resource Field Selectors (GA)

**Filtrage efficace côté serveur pour vos CRDs**

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
spec:
  names:
    kind: MyApp
  selectableFields:
  - jsonPath: .spec.environment  # Champ filtrable
  - jsonPath: .status.phase
```

```bash
# Avant: Filtre client (lent, coûteux)
kubectl get myapps -o json | jq '.items[] | select(.spec.environment=="prod")'

# Après: Filtre serveur (rapide, efficace)
kubectl get myapps --field-selector spec.environment=prod
```

---

## K8s 1.32 - Bound SA Token + Node (GA)

**Tokens de service account liés au node**

```yaml
# Le token JWT inclut maintenant:
{
  "kubernetes.io/serviceaccount/node-name": "worker-01",
  "kubernetes.io/serviceaccount/node-uid": "abc-123"
}
```

**Sécurité renforcée:**
- Node compromis → token invalide sur autres nodes
- Empêche escalade de privilèges inter-nodes
- Autorisations basées sur le node source

---

## K8s 1.32 - Nouveaux endpoints de diagnostic

**Endpoints /statusz et /flagz**

```bash
# Santé des composants
curl -k https://localhost:10259/statusz
# Scheduler status: OK
# Last schedule: 2024-12-08T10:30:00Z

# Configuration active
curl -k https://localhost:10259/flagz
# --leader-elect=true
# --v=2
# --bind-address=0.0.0.0
```

**Disponible pour:** kube-scheduler, kube-controller-manager

---

## K8s 1.32 - Windows Graceful Shutdown

**Support shutdown propre sur Windows**

```yaml
# kubelet config Windows
shutdownGracePeriod: 30s
shutdownGracePeriodCriticalPods: 10s
```

**Comportement:**
1. Windows envoie signal shutdown
2. Kubelet évacue les pods gracefully
3. Critical pods en dernier
4. Pas de corruption de données

---

## K8s 1.32 - CPU Manager Strict Reservation

**Réservation CPU exclusive (Alpha)**

```yaml
# kubelet config
cpuManagerPolicy: static
cpuManagerPolicyOptions:
  strict-cpu-reservation: "true"
reservedSystemCPUs: "0-1"  # CPUs réservés système
```

**Avantages:**
- Latence ultra-faible
- Pas de context switch
- Performances prédictibles

---

## Deprecations et removals - Timeline

| Version | Supprimé | Deprecated |
|---------|----------|------------|
| 1.30 | FlowSchema v1beta1 | CSR anciennes APIs |
| 1.31 | ValidatingAdmissionPolicy v1beta1 | Annotations AppArmor |
| 1.32 | FlowSchema v1beta2 | Resource Claims v1alpha |

**Action requise:**
```bash
# Vérifier les APIs deprecated dans votre cluster
kubectl get --raw /apis | jq -r '.groups[].versions[].groupVersion' \
  | grep -E "v1alpha|v1beta"

# Convertir les manifests
kubectl convert -f old-manifest.yaml --output-version apps/v1
```

---

## Kubernetes 1.33 - Avril 2025 "Octarine"

### 64 améliorations dont 18 GA, 20 Beta, 24 Alpha

**Thème:** "The Color of Magic" - référence à Terry Pratchett

**Highlights:**
- **In-Place Pod Vertical Scaling (Beta)** - resize sans redémarrage
- **Native Sidecar Containers (GA)** - support stable
- **User Namespaces activés par défaut**
- **Job Success Policy (GA)** - conditions de succès personnalisées
- **DRA ResourceClaim Device Status (Beta)**

---

![bg fit](diagrams/in-place-pod-resize.png)

---

## K8s 1.33 - In-Place Pod Resize (Beta)

**Scaling vertical sans redémarrage ni rescheduling**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resizable-app
spec:
  containers:
  - name: app
    image: nginx
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
```

```bash
# Resize en live !
kubectl patch pod resizable-app --subresource=resize \
  -p '{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"200m"}}}]}}'
```

---

## In-Place Resize - Conditions et monitoring

**Nouvelles conditions du Pod:**

| Condition | Description |
|-----------|-------------|
| `PodResizePending` | Resize demandé, en attente de ressources |
| `PodResizeInProgress` | Resize en cours d'application |

```bash
# Vérifier le status du resize
kubectl get pod resizable-app -o jsonpath='{.status.conditions}' | jq

# Voir les resources actuelles vs demandées
kubectl get pod resizable-app -o jsonpath='{.status.containerStatuses[*].resources}'
```

**Cas d'usage:** VPA sans downtime, scaling automatique, charge variable

---

## K8s 1.33 - Native Sidecars (GA)

**Support stable des sidecars avec `restartPolicy: Always`**

```yaml
apiVersion: v1
kind: Pod
spec:
  initContainers:
  - name: istio-proxy
    image: istio/proxyv2:1.22
    restartPolicy: Always  # Devient sidecar natif
    securityContext:
      runAsUser: 1337
  containers:
  - name: app
    image: myapp:v2
```

**Garanties GA:** Démarrage avant, arrêt après containers principaux

---

## K8s 1.33 - User Namespaces (Défaut)

**Activé par défaut - plus besoin de feature gate**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: isolated-pod
spec:
  hostUsers: false  # User namespaces activés
  containers:
  - name: app
    image: nginx
    securityContext:
      runAsUser: 0  # root DANS le container
      # Mappé à UID 65534+ sur l'hôte
```

**Impact sécurité:**
- Protection contre CVE-2024-21626 et similaires
- Escalade de privilèges impossible vers l'hôte
- Compatible avec les images rootless

---

![bg fit](diagrams/job-success-policy.png)

---

## K8s 1.33 - Job Success Policy (GA)

**Définir quand un Job indexé est considéré réussi**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: ml-training
spec:
  completionMode: Indexed
  completions: 10
  parallelism: 5
  successPolicy:
    rules:
    - succeededIndexes: "0"  # Leader doit réussir
      succeededCount: 1
    - succeededIndexes: "1-9"  # 7 workers sur 9 suffisent
      succeededCount: 7
  template:
    spec:
      containers:
      - name: trainer
        image: ml-trainer:v1
```

**Cas d'usage:** ML distribué, MapReduce, batch tolérant aux pannes

---

## K8s 1.33 - Per-Index Backoff Limits (GA)

**Limites de retry indépendantes par index**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: data-processing
spec:
  completionMode: Indexed
  completions: 100
  backoffLimitPerIndex: 3  # Chaque index peut retry 3 fois
  maxFailedIndexes: 10     # Max 10 indexes en échec total
  template:
    spec:
      containers:
      - name: processor
        image: processor:v1
```

**Avantage:** Un index défaillant n'épuise pas le backoffLimit global

---

## K8s 1.33 - DRA Device Status (Beta)

**Les drivers peuvent reporter le status des devices**

```yaml
apiVersion: resource.k8s.io/v1beta1
kind: ResourceClaim
metadata:
  name: network-device
status:
  devices:
  - name: nic
    conditions:
    - type: Ready
      status: "True"
    networkData:
      interfaceName: "eth1"
      macAddress: "00:1A:2B:3C:4D:5E"
```

**Utilité:** Debug réseau, configuration automatique, observabilité

---

## K8s 1.33 - Ordered Namespace Deletion

**Suppression structurée respectant les dépendances**

```
Ordre de suppression (nouveau):
1. Pods
2. Services
3. NetworkPolicies  ← Avant: pouvait être supprimé en premier!
4. ConfigMaps/Secrets
5. RBAC resources
6. Finalizers
```

**Problème résolu:**
- Avant: NetworkPolicy supprimée → pods exposés temporairement
- Après: Pods supprimés d'abord → pas de fenêtre de vulnérabilité

---

## K8s 1.33 - Deprecation Endpoints API

**Migration vers EndpointSlices obligatoire**

```yaml
# NOUVEAU - Utiliser EndpointSlices
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: my-service-abc
  labels:
    kubernetes.io/service-name: my-service
addressType: IPv4
endpoints:
- addresses: ["10.0.0.1"]
  conditions:
    ready: true
```

**Avantages:** Dual-stack, meilleur scaling, moins de charge API

---

## Kubernetes 1.34 - Août 2025 "Of Wind & Will"

### 58 améliorations dont 13 nouvelles Alpha

**Particularité:** Zéro deprecation, zéro breaking change !

**Highlights:**
- **Dynamic Resource Allocation (GA)** - API stable pour GPU/TPU
- **Traffic Distribution étendu** - PreferSameNode, PreferSameZone
- **Container Restart Rules** - restart granulaire par exit code
- **Asynchronous Scheduling** - performances améliorées
- **KYAML** - format YAML sans ambiguïtés

---

![bg fit](diagrams/dra-stable.png)

---

## K8s 1.34 - DRA Stable (GA)

**API `resource.k8s.io/v1` pour hardware spécialisé**

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaim
metadata:
  name: gpu-training
spec:
  devices:
    requests:
    - name: gpu
      deviceClassName: nvidia-gpu
      selectors:
      - cel:
          expression: device.attributes["memory"].quantity >= "24Gi"
```

**Nouveau en GA:** API stable, structured parameters, Cluster Autoscaler intégré

---

## DRA 1.34 - DeviceClass et ResourceSlice

```yaml
apiVersion: resource.k8s.io/v1
kind: DeviceClass
metadata:
  name: nvidia-gpu
spec:
  selectors:
  - cel:
      expression: device.driver == "nvidia.com"
  config:
  - opaque:
      driver: nvidia.com
      parameters:
        sharing: time-slicing
---
apiVersion: resource.k8s.io/v1
kind: ResourceSlice
metadata:
  name: node-01-gpus
spec:
  nodeName: node-01
  driver: nvidia.com
  devices:
  - name: gpu-0
    basic:
      attributes:
        memory: {quantity: "80Gi"}
        model: {string: "H100"}
```

---

![bg fit](diagrams/traffic-distribution-extended.png)

---

## K8s 1.34 - Traffic Distribution étendu

**Nouveaux modes pour optimiser la latence**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-api
spec:
  selector:
    app: api
  ports:
  - port: 80
  trafficDistribution: PreferSameNode  # Nouveau!
```

| Mode | Comportement |
|------|-------------|
| `PreferClose` | Zone la plus proche (existant) |
| `PreferSameZone` | Même zone en priorité |
| `PreferSameNode` | **Même node en priorité** |

**Cas d'usage:** Sidecars, caches locaux, latence critique

---

![bg fit](diagrams/pod-replacement-policy.png)

---

## K8s 1.34 - Container Restart Rules (Alpha)

**Restart granulaire basé sur le code de sortie**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: batch-job
spec:
  restartPolicy: Never  # Pod level
  containers:
  - name: processor
    image: batch:v1
    restartPolicyRules:  # Container level - Nouveau!
    - exitCodeRanges:
      - start: 1
        end: 10    # Erreurs récupérables
      action: Restart
    - exitCodeRanges:
      - start: 11
        end: 255   # Erreurs fatales
      action: Terminate
```

**Avantage:** Récupération des erreurs transitoires sans rescheduler le Pod

---

## K8s 1.34 - Resource Health Tracking (Alpha)

**Status de santé des devices dans le Pod**

```yaml
status:
  containerStatuses:
  - name: ml-trainer
    resourceHealth:
      devices:
      - deviceID: "gpu-0"
        health: Healthy
      - deviceID: "gpu-1"
        health: Unhealthy  # GPU défaillant!
        message: "Temperature exceeded threshold"
```

**Utilité:**
- Distinguer erreur app vs hardware défaillant
- Alerting proactif
- Décision de rescheduling informée

---

## K8s 1.34 - Asynchronous Scheduling

**Queue asynchrone pour les appels API du scheduler**

```
Avant (synchrone):
  Pod pending → API call → BLOCK → Response → Continue

Après (asynchrone):
  Pod pending → API Queue → Continue scheduling
                    ↓
              Background processing
              (merge, cancel, batch)
```

**Améliorations:**
- Scheduling non bloquant
- Fusion d'opérations redondantes
- Re-queue plus rapide des pods unschedulable

---

## K8s 1.34 - KYAML Format

**Dialect YAML sans ambiguïtés (le "Norway problem")**

```yaml
# YAML standard - Problème!
country: NO        # Interprété comme boolean false!
version: 1.20      # Interprété comme float 1.2!

# KYAML - Résolu
country: "NO"      # String garantie
version: "1.20"    # String garantie
```

**Caractéristiques:**
- Strings toujours quotées
- Pas de conversion implicite
- Commentaires préservés
- Compatible JSON

---

## K8s 1.34 - Native Pod Certificates (Alpha)

**Pods peuvent demander des certificats X.509 directement**

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    volumeMounts:
    - name: cert
      mountPath: /etc/certs
  volumes:
  - name: cert
    projected:
      sources:
      - clusterTrustBundle:
          signerName: kubernetes.io/kube-apiserver-client
        path: ca.crt
      - certificateRequest:
          signerName: kubernetes.io/kube-apiserver-client
          usages: ["client auth"]
        path: tls.crt
```

**Avantage:** mTLS sans dépendre de Cert-Manager ou SPIFFE

---

## K8s 1.34 - Custom Pod Hostnames (Alpha)

**Pods peuvent avoir des FQDNs personnalisés**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
spec:
  hostnameOverride: "legacy.internal.company.com"  # Nouveau!
  containers:
  - name: app
    image: legacy:v1
```

**Cas d'usage:**
- Applications legacy avec hostname hardcodé
- Migration depuis VMs
- Certificats avec CN spécifique

---

## Deprecations et removals - Timeline complète

| Version | Supprimé | Deprecated |
|---------|----------|------------|
| 1.30 | FlowSchema v1beta1 | CSR anciennes APIs |
| 1.31 | ValidatingAdmissionPolicy v1beta1 | Annotations AppArmor |
| 1.32 | FlowSchema v1beta2 | Resource Claims v1alpha |
| 1.33 | kubeProxyVersion field | Endpoints API |
| 1.34 | - | - (aucune!) |
| 1.35 | Resource Claims v1alpha2 | Device Plugins (remplacés par DRA) |

**K8s 1.34:** Release exceptionnelle sans breaking changes
**K8s 1.35:** "Timbernetes" — stabilisation de la gestion des ressources avancées

---

## Kubernetes 1.35 — "Timbernetes" (Décembre 2025)

| Feature | État |
|---------|------|
| In-Place Pod Vertical Scaling | **GA** ✓ |
| Dynamic Resource Allocation (DRA) | **GA** ✓ |
| PDB `unhealthyPodEvictionPolicy` | **GA** ✓ |
| VolumeAttributesClass | **GA** (depuis 1.34) |
| ClusterTrustBundle | **Beta** (v1beta1) |

**Thème 1.35 :** stabilisation de la gestion avancée des ressources (GPU, mémoire, volumes)

---

## K8s 1.35 - In-Place Pod Vertical Scaling (GA)

**Avant :** modifier CPU/RAM d'un pod → suppression + recréation (downtime)
**Maintenant :** resize à chaud via `--subresource resize`

```yaml
spec:
  containers:
  - name: app
    resizePolicy:
    - resourceName: cpu
      restartPolicy: NotRequired      # CPU: hot-resize sans interruption
    - resourceName: memory
      restartPolicy: RestartContainer # RAM: restart du container uniquement
    resources:
      requests: { cpu: "500m", memory: "256Mi" }
      limits:   { cpu: "500m", memory: "256Mi" }
```

---

## K8s 1.35 - In-Place Resize — Utilisation

```bash
# Augmenter le CPU sans restart
kubectl patch pod mon-pod --subresource resize \
  --patch '{"spec":{"containers":[{
    "name":"app",
    "resources":{"requests":{"cpu":"800m"},
                 "limits":{"cpu":"800m"}}
  }]}}'

# Surveiller l'état du resize
kubectl get pod mon-pod \
  -o jsonpath='{.status.resize}'
# Valeurs: "InProgress" | "Infeasible" | (absent = succès)
```

**Cas d'usage :** apps stateful (BDD, caches), jobs longs — scaling vertical sans downtime

---

## K8s 1.35 - DRA (Dynamic Resource Allocation) GA

<svg width="1100" height="270" viewBox="0 0 1100 270" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
<defs>
<marker id="dra1" markerWidth="9" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,9 3,0 6" fill="#6b7280"/></marker>
<marker id="dra2" markerWidth="9" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,9 3,0 6" fill="#7c3aed"/></marker>
</defs>
<style>text{font-family:sans-serif;font-size:13px}</style>
<text x="550" y="20" text-anchor="middle" font-size="15" font-weight="bold" fill="#111827">DRA — Flux d'allocation de ressources (GPU, FPGA…)</text>
<rect x="10" y="40" width="180" height="80" rx="8" fill="#ede9fe" stroke="#7c3aed" stroke-width="2"/>
<text x="100" y="68" text-anchor="middle" fill="#5b21b6" font-weight="bold">Pod spec</text>
<text x="100" y="86" text-anchor="middle" fill="#5b21b6" font-size="11">resourceClaims:</text>
<text x="100" y="101" text-anchor="middle" fill="#5b21b6" font-size="11">- gpu-claim-tpl</text>
<line x1="190" y1="80" x2="240" y2="80" stroke="#6b7280" stroke-width="2" marker-end="url(#dra1)"/>
<rect x="243" y="40" width="200" height="80" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
<text x="343" y="65" text-anchor="middle" fill="#166534" font-weight="bold">ResourceClaim</text>
<text x="343" y="82" text-anchor="middle" fill="#166534" font-size="11">auto-créé par le scheduler</text>
<text x="343" y="97" text-anchor="middle" fill="#166534" font-size="11">durée de vie = durée du Pod</text>
<line x1="443" y1="80" x2="493" y2="80" stroke="#6b7280" stroke-width="2" marker-end="url(#dra1)"/>
<rect x="496" y="40" width="200" height="80" rx="8" fill="#fef3c7" stroke="#f59e0b" stroke-width="2"/>
<text x="596" y="65" text-anchor="middle" fill="#78350f" font-weight="bold">DeviceClass</text>
<text x="596" y="82" text-anchor="middle" fill="#78350f" font-size="11">nvidia-gpu</text>
<text x="596" y="97" text-anchor="middle" fill="#78350f" font-size="11">filtre CEL: memory ≥ 16Gi</text>
<line x1="696" y1="80" x2="746" y2="80" stroke="#6b7280" stroke-width="2" marker-end="url(#dra1)"/>
<rect x="749" y="40" width="180" height="80" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="839" y="68" text-anchor="middle" fill="#1d4ed8" font-weight="bold">GPU Hardware</text>
<text x="839" y="86" text-anchor="middle" fill="#1d4ed8" font-size="11">alloué exclusivement</text>
<text x="839" y="101" text-anchor="middle" fill="#1d4ed8" font-size="11">au Pod</text>
<rect x="380" y="155" width="240" height="55" rx="8" fill="#f3f4f6" stroke="#6b7280" stroke-width="1.5"/>
<text x="500" y="178" text-anchor="middle" fill="#374151" font-weight="bold">DRA Driver (DaemonSet)</text>
<text x="500" y="196" text-anchor="middle" fill="#374151" font-size="11">surveille et alloue les devices</text>
<line x1="500" y1="155" x2="596" y2="121" stroke="#7c3aed" stroke-width="1.5" stroke-dasharray="5,3" marker-end="url(#dra2)"/>
<rect x="10" y="195" width="350" height="65" rx="6" fill="#fef2f2" stroke="#fca5a5" stroke-width="1.5"/>
<text x="185" y="215" text-anchor="middle" fill="#dc2626" font-weight="bold" font-size="12">Device Plugins (ancienne méthode)</text>
<text x="185" y="232" text-anchor="middle" fill="#dc2626" font-size="11">allocation statique par container</text>
<text x="185" y="248" text-anchor="middle" fill="#dc2626" font-size="11">pas de partage, pas de filtrage CEL</text>
<text x="25" y="268" fill="#dc2626" font-size="10">↗ remplacé progressivement par DRA</text>
<rect x="749" y="155" width="340" height="65" rx="6" fill="#f0fdf4" stroke="#86efac" stroke-width="1.5"/>
<text x="919" y="178" text-anchor="middle" fill="#15803d" font-weight="bold" font-size="12">Avantages DRA vs Device Plugins</text>
<text x="919" y="196" text-anchor="middle" fill="#15803d" font-size="11">✓ Filtrage CEL (capacité, type, modèle)</text>
<text x="919" y="212" text-anchor="middle" fill="#15803d" font-size="11">✓ Partage de device entre Pods possible</text>
</svg>

---

## K8s 1.35 - DRA — Exemple ResourceClaimTemplate GPU

```yaml
apiVersion: resource.k8s.io/v1
kind: ResourceClaimTemplate
metadata:
  name: gpu-claim-tpl
spec:
  spec:
    devices:
      requests:
      - name: gpu
        exactly:
          deviceClassName: nvidia-gpu
          selectors:
          - cel:
              expression: >
                device.capacity["driver.nvidia.com"].memory
                >= quantity("16Gi")
---
# Job utilisant le template DRA
spec:
  template:
    spec:
      resourceClaims:
      - name: gpu-claim
        resourceClaimTemplateName: gpu-claim-tpl
      containers:
      - name: training
        resources:
          claims:
          - name: gpu-claim
```

---

## K8s 1.35 - PDB unhealthyPodEvictionPolicy (GA)

**Problème :** un pod unhealthy bloquait les drains → cluster upgrade impossible

| Policy | Comportement |
|--------|-------------|
| `IfHealthyBudget` *(défaut)* | Pod unhealthy évincé seulement si budget respecté |
| `AlwaysAllow` | Pod unhealthy toujours évincé, budget ignoré |

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels: { app: myapp }
  unhealthyPodEvictionPolicy: AlwaysAllow
```

**Usage :** `AlwaysAllow` lors des upgrades — évite le blocage sur pods crashés

---

## K8s 1.35 - ClusterTrustBundle (Beta)

**Problème :** distribuer des CA certificates → ConfigMap par namespace, maintenance lourde

<svg width="1100" height="200" viewBox="0 0 1100 200" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
<defs><marker id="ctb1" markerWidth="9" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,9 3,0 6" fill="#6b7280"/></marker></defs>
<style>text{font-family:sans-serif;font-size:12px}</style>
<rect x="10" y="30" width="200" height="60" rx="8" fill="#ede9fe" stroke="#7c3aed" stroke-width="2"/>
<text x="110" y="56" text-anchor="middle" fill="#5b21b6" font-weight="bold">Admin K8s</text>
<text x="110" y="74" text-anchor="middle" fill="#5b21b6" font-size="11">crée ClusterTrustBundle</text>
<line x1="210" y1="60" x2="280" y2="60" stroke="#6b7280" stroke-width="2" marker-end="url(#ctb1)"/>
<rect x="283" y="20" width="230" height="80" rx="8" fill="#fef3c7" stroke="#f59e0b" stroke-width="2"/>
<text x="398" y="50" text-anchor="middle" fill="#78350f" font-weight="bold">ClusterTrustBundle</text>
<text x="398" y="67" text-anchor="middle" fill="#78350f" font-size="11">resource cluster-scoped</text>
<text x="398" y="82" text-anchor="middle" fill="#78350f" font-size="11">contient PEM du CA root</text>
<line x1="513" y1="60" x2="583" y2="60" stroke="#6b7280" stroke-width="2" marker-end="url(#ctb1)"/>
<rect x="586" y="20" width="230" height="80" rx="8" fill="#dcfce7" stroke="#16a34a" stroke-width="2"/>
<text x="701" y="47" text-anchor="middle" fill="#166534" font-weight="bold">Projected Volume</text>
<text x="701" y="64" text-anchor="middle" fill="#166534" font-size="11">monté dans chaque Pod</text>
<text x="701" y="81" text-anchor="middle" fill="#166534" font-size="11">→ /run/ca-certs/ca.crt</text>
<line x1="816" y1="60" x2="886" y2="60" stroke="#6b7280" stroke-width="2" marker-end="url(#ctb1)"/>
<rect x="889" y="30" width="195" height="60" rx="8" fill="#dbeafe" stroke="#3b82f6" stroke-width="2"/>
<text x="986" y="56" text-anchor="middle" fill="#1d4ed8" font-weight="bold">App → vérifie TLS</text>
<text x="986" y="73" text-anchor="middle" fill="#1d4ed8" font-size="11">avec CA distribué</text>
<text x="550" y="155" text-anchor="middle" fill="#374151" font-size="13">Un seul objet cluster-scoped → tous les namespaces l'utilisent automatiquement</text>
<text x="550" y="178" text-anchor="middle" fill="#6b7280" font-size="11">Remplace: ConfigMap ca-bundle par namespace + montage manuel</text>
</svg>

```yaml
volumes:
- name: ca-certs
  projected:
    sources:
    - clusterTrustBundle:
        name: mon-ca-bundle
        path: ca.crt
```

---

## Améliorations du swap - Focus technique

### Pourquoi le swap est important ?

**Avantages:**
- Réduction des coûts (moins de RAM nécessaire)
- Évite les OOMKills pour pics temporaires
- Meilleure utilisation des ressources

**Inconvénients:**
- Impact sur les performances
- Latence accrue pour certaines workloads

---

## Swap - Cas d'usage recommandés

### ✅ Bon cas d'usage

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: batch-job
spec:
  containers:
  - name: processor
    resources:
      requests:
        memory: "1Gi"
      limits:
        memory: "2Gi"
        memory.swap: "1Gi"  # Permet bursts
  # QoS: Burstable
```

- Jobs batch non critiques
- Workloads avec pics prévisibles
- Environnements dev/test

---

## Swap - Configuration des nœuds

### Activation du swap sur CentOS 10

```bash
# 1. Créer un fichier swap (dd plus fiable que fallocate sur certains FS)
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 2. Persister dans /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 3. Configurer kubelet
cat <<EOF | sudo tee /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
memorySwap:
  swapBehavior: LimitedSwap
failSwapOn: false
EOF
```

---

## Swap - Monitoring

### Commandes de monitoring

```bash
# Vérifier l'utilisation du swap sur le nœud
free -h
swapon --show

# Voir les pods utilisant le swap
kubectl top pods --containers

# Métriques kubelet
curl http://localhost:10255/stats/summary | jq '.node.memory'
```

### Métriques importantes
- `container_memory_swap` - Swap utilisé par container
- `node_memory_SwapTotal` - Total swap disponible
- `node_memory_SwapFree` - Swap libre

---

## Améliorations de sécurité

### User Namespaces (1.32 - Beta)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  hostUsers: false  # Active user namespaces
  containers:
  - name: app
    securityContext:
      runAsUser: 1000
      runAsGroup: 3000
```

**Avantages:**
- Root dans le container ≠ root sur l'hôte
- Isolation renforcée
- Protection contre les escalations

---

## Améliorations de sécurité - AppArmor

### AppArmor (1.30 - GA)

Configuration native AppArmor dans Kubernetes:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-pod
spec:
  containers:
  - name: app
    securityContext:
      appArmorProfile:
        type: Localhost
        localhostProfile: k8s-custom-profile
```

**Types disponibles:** `RuntimeDefault`, `Localhost`, `Unconfined`

---

## Améliorations de sécurité - Service Account Tokens

### Bounded Service Account Tokens (1.32 - GA)

Tokens avec expiration et audience spécifique:

```yaml
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: my-sa
  volumes:
  - name: token
    projected:
      sources:
      - serviceAccountToken:
          expirationSeconds: 3600  # 1 heure
          audience: api
```

---

## Améliorations de performance

### 1.31 - Informer Watchlist
- Réduction de 50% de la charge API server
- Startup plus rapide des controllers
- Moins de bande passante réseau

### 1.31 - Traffic Distribution
```yaml
apiVersion: v1
kind: Service
spec:
  trafficDistribution: PreferClose
```
- Latence réduite
- Trafic local privilégié
- Économie de coûts cloud

---

## Améliorations de la gestion de resources

### VolumeAttributesClass (1.32 - Beta)

**Cas d'usage:** Modifier les IOPS d'un volume sans downtime

```yaml
# Avant
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  storageClassName: standard

# Après - modification dynamique
apiVersion: v1
kind: PersistentVolumeClaim
spec:
  storageClassName: standard
  volumeAttributesClassName: high-performance
```

---

## Conseils de migration

### Préparation

1. **Lire les release notes complètes**
   - Deprecations et removals
   - Breaking changes
   - New features

2. **Tester dans un environnement de dev**
   - Valider la compatibilité
   - Tester les nouvelles fonctionnalités

3. **Planifier le rollback**
   - Backup etcd
   - Procédure de downgrade

---

## Conseils de migration - Control Plane

### Étape 1: Upgrade du Control Plane

**Règle d'or:** 1 version mineure à la fois

```bash
# Vérifier les versions disponibles
kubeadm upgrade plan

# Appliquer la mise à jour
kubeadm upgrade apply v1.34.0
```

⚠️ Toujours upgrade le control plane AVANT les workers

---

## Conseils de migration - Kubelet & Workers

### Étape 2: Kubelet sur le master

```bash
sudo dnf versionlock delete kubelet kubectl 2>/dev/null || true
sudo dnf install -y kubelet-1.34.0 kubectl-1.34.0
sudo dnf versionlock add kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

### Étape 3: Workers (un par un)

```bash
kubectl drain <node> --ignore-daemonsets
# Upgrade kubelet sur le worker
kubectl uncordon <node>
```

---

## Feature gates importantes

### Activation des features alpha/beta

```yaml
# /var/lib/kubelet/config.yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
featureGates:
  InPlacePodVerticalScaling: true  # 1.33 Beta (défaut on)
  ContainerRestartRules: true      # 1.34 Alpha
  ImageVolume: true                # 1.31 Alpha
```

```yaml
# kube-apiserver
apiVersion: v1
kind: Pod
spec:
  containers:
  - command:
    - kube-apiserver
    - --feature-gates=ContainerRestartRules=true,NativePodCertificates=true
```

---

## Ressources et documentation

### Documentation officielle
- Release notes: https://kubernetes.io/docs/setup/release/notes/
- Change log: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/
- KEPs: https://github.com/kubernetes/enhancements

### Outils utiles
- **kubectl version:** Vérifier la version
- **kubeadm upgrade plan:** Voir les upgrades disponibles
- **kubectl api-resources:** Lister les APIs disponibles

---

## Points clés à retenir

### Scaling & Ressources
- **In-Place Pod Resize (1.33 Beta)** - scaling vertical sans downtime
- **DRA GA (1.34)** - gestion GPU/TPU production ready
- Memory Manager GA (1.32) - NUMA-aware allocation

### Sécurité
- **User Namespaces (1.33 défaut)** - activé automatiquement
- AppArmor GA (1.30) - production ready
- Ordered Namespace Deletion (1.33) - pas de fenêtre vulnérabilité

---

## Points clés à retenir (suite)

### Performance
- **Traffic Distribution étendu (1.34)** - PreferSameNode
- Async Scheduling (1.34) - scheduler non bloquant
- Informer Watchlist (1.31) - moins de charge API

### Containers & Jobs
- **Native Sidecars GA (1.33)** - support stable
- Job Success Policy GA (1.33) - critères personnalisés
- Container Restart Rules (1.34 Alpha) - retry granulaire

### Production readiness
- K8s 1.34: Zéro breaking changes!
- Suivre les deprecations (Endpoints → EndpointSlices)
- Planifier les upgrades régulièrement

---

## Questions fréquentes

**Q: Dois-je activer le swap en production ?**
R: Dépend du workload. OK pour batch jobs non critiques avec `LimitedSwap`. Attention pour les services à faible latence.

**Q: À quelle fréquence upgrader ?**
R: Au minimum tous les 12 mois pour rester dans la fenêtre de support (14 mois). Idéalement suivre N-1 ou N-2.

**Q: Comment tester les features alpha ?**
R: Environnement de dev isolé, feature gates activées, ne JAMAIS en production.

---

<!-- _class: lead -->

# Merci !



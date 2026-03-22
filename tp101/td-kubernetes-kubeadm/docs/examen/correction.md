# Grille de Correction - Examen Docker, Sécurité et Kubernetes

**Document réservé aux correcteurs**

---

## PARTIE 1 : Docker Fondamentaux (25 points)

| Q | Réponse | Explication courte |
|---|---------|---------------------|
| 1 | **B** | `docker ps -a` affiche tous les conteneurs |
| 2 | **B** | Dockerfile définit les instructions de build |
| 3 | **C** | CMD définit la commande par défaut |
| 4 | **B** | ENTRYPOINT = commande principale, CMD = arguments par défaut |
| 5 | **B** | `docker build -t` construit et tag l'image |
| 6 | **C** | bridge est le réseau par défaut pour les conteneurs sur un hôte |
| 7 | **A** | `-v host:container` monte un volume |
| 8 | **B** | `-f` suit les logs en temps réel (follow) |
| 9 | **B** | COPY copie du contexte de build vers l'image |
| 10 | **B** | ADD peut extraire des archives tar et télécharger depuis URLs |
| 11 | **B** | `-p host:container` donc `-p 80:8080` |
| 12 | **B** | `docker image prune -a` supprime les images non utilisées |
| 13 | **B** | latest est le tag par défaut, pas forcément le plus récent |
| 14 | **A** | WORKDIR définit le répertoire de travail |
| 15 | **B** | `-e` ou `--env` passe des variables d'environnement |
| 16 | **B** | Multi-stage permet des images finales plus petites |
| 17 | **B** | `docker exec -it` exécute une commande dans un conteneur actif |
| 18 | **B** | `-d` (detached) démarre en arrière-plan |
| 19 | **B** | LABEL ajoute des métadonnées |
| 20 | **A** | `--memory 512m` limite la mémoire |
| 21 | **B** | Docker utilise des union filesystems (overlay2, etc.) |
| 22 | **A** | `docker stats` affiche l'utilisation des ressources |
| 23 | **A** | `docker network create` crée un réseau |
| 24 | **B** | Instructions stables en premier pour optimiser le cache |
| 25 | **B** | HEALTHCHECK définit une commande de vérification de santé |

---

## PARTIE 2 : Sécurité des Conteneurs (25 points)

| Q | Réponse | Explication courte |
|---|---------|---------------------|
| 26 | **B** | Root dans le conteneur = risque de privilèges élevés si compromis |
| 27 | **B** | USER change l'utilisateur d'exécution |
| 28 | **A** | `--privileged` donne accès à tous les devices |
| 29 | **A** | `--cap-add` et `--cap-drop` gèrent les capabilities |
| 30 | **B** | Images minimales réduisent la surface d'attaque |
| 31 | **A** | `docker scan` ou Trivy pour scanner les vulnérabilités |
| 32 | **B** | Secrets = données sensibles gérées de manière sécurisée |
| 33 | **B** | Les couches d'image sont inspectables, exposant les secrets |
| 34 | **B** | Tags versionnés pour la reproductibilité en production |
| 35 | **B** | Read-only = système de fichiers en lecture seule |
| 36 | **A** | `--read-only` active le mode lecture seule |
| 37 | **B** | SecurityContext = paramètres de sécurité pour pods/conteneurs |
| 38 | **B** | `runAsNonRoot: true` empêche l'exécution en tant que root |
| 39 | **B** | NetworkPolicy = règles firewall entre pods |
| 40 | **B** | Par défaut, tout le trafic est autorisé entre pods |
| 41 | **B** | PSS = profils prédéfinis (privileged, baseline, restricted) |
| 42 | **C** | restricted est le niveau le plus restrictif |
| 43 | **A** | Namespaces isolent les ressources (PID, network, mount, etc.) |
| 44 | **B** | PID namespace isole les processus |
| 45 | **B** | seccomp filtre les appels système |
| 46 | **B** | Registres privés + scanning pour la sécurité |
| 47 | **B** | `--no-new-privileges` empêche l'acquisition de nouveaux privilèges |
| 48 | **B** | Docker Content Trust (DCT) ou Notary pour signer |
| 49 | **B** | AppArmor = module de sécurité Linux limitant les actions |
| 50 | **B** | N'exposer que les ports nécessaires |

---

## PARTIE 3 : Kubernetes Fondamentaux (25 points)

| Q | Réponse | Explication courte |
|---|---------|---------------------|
| 51 | **C** | etcd stocke l'état du cluster |
| 52 | **B** | kube-scheduler assigne les pods aux nodes |
| 53 | **B** | Pod est la plus petite unité déployable |
| 54 | **B** | `--all-namespaces` ou `-A` liste tous les namespaces |
| 55 | **C** | Deployment gère le déploiement et scaling |
| 56 | **A** | `kubectl expose` crée un service |
| 57 | **B** | NodePort expose sur un port de chaque node |
| 58 | **C** | ClusterIP est le type par défaut |
| 59 | **B** | ReplicaSet maintient un nombre défini de pods identiques |
| 60 | **D** | `create` et `apply` sont tous deux valides |
| 61 | **B** | Namespace = isolation logique des ressources |
| 62 | **A** | `kubectl logs` affiche les logs |
| 63 | **B** | `kubectl exec -it -- /bin/sh` ouvre un shell |
| 64 | **B** | ConfigMap stocke des données de configuration non sensibles |
| 65 | **B** | Secret est encodé base64 pour données sensibles |
| 66 | **A** | DaemonSet s'exécute sur tous les nodes |
| 67 | **A** | StatefulSet pour pods avec identité et stockage persistants |
| 68 | **A** | `kubectl scale --replicas=5` met à l'échelle |
| 69 | **B** | Ingress gère l'accès externe HTTP/HTTPS |
| 70 | **B** | kubelet s'exécute sur chaque worker node |
| 71 | **B** | kubelet s'assure que les conteneurs tournent dans les pods |
| 72 | **B** | kube-proxy gère les règles réseau pour les Services |
| 73 | **B** | `kubectl describe` donne les détails |
| 74 | **B** | PV = ressource de stockage provisionnée |
| 75 | **A** | PVC = demande de stockage par un pod |

---

## PARTIE 4 : Kubernetes Avancé et Bonnes Pratiques (25 points)

| Q | Réponse | Explication courte |
|---|---------|---------------------|
| 76 | **B** | livenessProbe vérifie si le conteneur doit être redémarré |
| 77 | **A** | readinessProbe vérifie si prêt à recevoir du trafic |
| 78 | **B** | Échec liveness = conteneur redémarré |
| 79 | **B** | RollingUpdate met à jour progressivement |
| 80 | **B** | Recreate supprime tout avant de recréer |
| 81 | **A** | `kubectl rollout undo` annule un déploiement |
| 82 | **B** | HPA ajuste automatiquement le nombre de replicas |
| 83 | **B** | HPA se base sur CPU par défaut |
| 84 | **B** | ResourceQuota limite les ressources par namespace |
| 85 | **B** | requests = garanti, limits = maximum |
| 86 | **B** | Dépassement mémoire = OOMKilled |
| 87 | **B** | LimitRange définit valeurs par défaut et limites |
| 88 | **B** | Helm est le package manager Kubernetes |
| 89 | **B** | Helm Chart = package de ressources K8s |
| 90 | **B** | RBAC = Role-Based Access Control |
| 91 | **B** | Role, ClusterRole, RoleBinding, ClusterRoleBinding |
| 92 | **B** | Role = namespace, ClusterRole = global |
| 93 | **B** | ServiceAccount = identité pour les pods |
| 94 | **B** | Labels cohérents et standardisés |
| 95 | **B** | Pod Affinity = règles de placement |
| 96 | **B** | Taint repousse les pods sans toleration |
| 97 | **B** | Toleration permet le scheduling sur un node tainté |
| 98 | **B** | Federation = gestion multi-clusters |
| 99 | **B** | Configurer liveness et readiness probes |
| 100 | **B** | kubectl describe, logs, events + outils comme k9s |
| 101 | **C** | CM crée les pods sans nodeName, Scheduler les assigne — en parallèle sur l'API |
| 102 | **B** | cordon pose le taint `node.kubernetes.io/unschedulable:NoSchedule` — DaemonSet controller ajoute automatiquement la toleration correspondante |

---

## Barème de notation

| Mention | Note | Pourcentage |
|---------|------|-------------|
| Excellent | 90-100 | 90%+ |
| Très bien | 80-89 | 80-89% |
| Bien | 70-79 | 70-79% |
| Assez bien | 60-69 | 60-69% |
| Passable | 50-59 | 50-59% |
| Insuffisant | < 50 | < 50% |

---

## Répartition par compétence

| Domaine | Questions | Points |
|---------|-----------|--------|
| Docker fondamentaux | 1-25 | 25 |
| Sécurité des conteneurs | 26-50 | 25 |
| Kubernetes fondamentaux | 51-75 | 25 |
| Kubernetes avancé | 76-100 | 25 |
| **Total** | **100** | **100** |

---

## Grille de réponses rapide

```
PARTIE 1 (Docker)           PARTIE 2 (Sécurité)
1.B   6.C   11.B  16.B  21.B    26.B  31.A  36.A  41.B  46.B
2.B   7.A   12.B  17.B  22.A    27.B  32.B  37.B  42.C  47.B
3.C   8.B   13.B  18.B  23.A    28.A  33.B  38.B  43.A  48.B
4.B   9.B   14.A  19.B  24.B    29.A  34.B  39.B  44.B  49.B
5.B   10.B  15.B  20.A  25.B    30.B  35.B  40.B  45.B  50.B

PARTIE 3 (K8s Fondamentaux) PARTIE 4 (K8s Avancé)
51.C  56.A  61.B  66.A  71.B    76.B  81.A  86.B  91.B  96.B
52.B  57.B  62.A  67.A  72.B    77.A  82.B  87.B  92.B  97.B
53.B  58.C  63.B  68.A  73.B    78.B  83.B  88.B  93.B  98.B
54.B  59.B  64.B  69.B  74.B    79.B  84.B  89.B  94.B  99.B
55.C  60.D  65.B  70.B  75.A    80.B  85.B  90.B  95.B  100.B
```

---

*Document de correction - Ne pas diffuser aux étudiants*

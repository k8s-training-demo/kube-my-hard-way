---
marp: true
theme: default
paginate: true
style: |
  section {
    font-size: 22px;
    padding: 30px 50px;
  }
  h1 { color: #326CE5; }
  h2 { color: #326CE5; font-size: 24px; }
  ul { list-style: none; padding: 0; }
  li { padding: 8px 12px; margin: 6px 0; background: #f5f5f5; border-radius: 6px; border-left: 4px solid #ccc; }
  .partie { background: #326CE5; color: white; padding: 6px 16px; border-radius: 20px; font-size: 16px; }
---

# Examen QCM
## Docker · Sécurité · Kubernetes

**102 questions**

---

# PARTIE 1
## Docker Fondamentaux
### Questions 1 → 25

---

## Q1. Lister tous les conteneurs, y compris arrêtés ?

- A) `docker ps`
- B) `docker ps -a`
- C) `docker list --all`
- D) `docker containers`

---

## Q2. Fichier pour définir une image Docker ?

- A) docker-compose.yml
- B) Dockerfile
- C) docker.conf
- D) image.yaml

---

## Q3. Instruction Dockerfile pour la commande par défaut au démarrage ?

- A) RUN
- B) EXEC
- C) CMD
- D) START

---

## Q4. Différence principale entre CMD et ENTRYPOINT ?

- A) CMD ne peut pas être surchargé, ENTRYPOINT peut l'être
- B) ENTRYPOINT définit la commande principale, CMD fournit les arguments par défaut
- C) Il n'y a aucune différence
- D) CMD est exécuté en premier, puis ENTRYPOINT

---

## Q5. Construire une image à partir d'un Dockerfile ?

- A) `docker create -f Dockerfile`
- B) `docker build -t nom_image .`
- C) `docker make image`
- D) `docker compile .`

---

## Q6. Réseau Docker pour communication sur le même hôte ?

- A) host
- B) none
- C) bridge
- D) overlay

---

## Q7. Monter un volume persistant dans un conteneur ?

- A) `docker run -v /host/path:/container/path image`
- B) `docker run --mount /host/path image`
- C) `docker run -d /host/path image`
- D) `docker run --volume-only /path image`

---

## Q8. Afficher les logs d'un conteneur en temps réel ?

- A) `docker logs container_id`
- B) `docker logs -f container_id`
- C) `docker output container_id`
- D) `docker stream container_id`

---

## Q9. Que fait l'instruction COPY dans un Dockerfile ?

- A) Copie des fichiers depuis une URL
- B) Copie des fichiers du contexte de build vers l'image
- C) Copie des fichiers entre conteneurs
- D) Copie des fichiers depuis un autre conteneur

---

## Q10. Différence entre COPY et ADD ?

- A) Aucune différence
- B) ADD peut extraire des archives et télécharger depuis des URLs
- C) COPY est plus rapide mais moins sécurisé
- D) ADD est déprécié

---

## Q11. Exposer le port 8080 d'un conteneur sur le port 80 de l'hôte ?

- A) `docker run -p 8080:80 image`
- B) `docker run -p 80:8080 image`
- C) `docker run --expose 80:8080 image`
- D) `docker run -P 80 image`

---

## Q12. Supprimer toutes les images non utilisées ?

- A) `docker rmi --all`
- B) `docker image prune -a`
- C) `docker clean images`
- D) `docker delete unused`

---

## Q13. Que signifie le tag "latest" ?

- A) C'est toujours la version la plus récente
- B) C'est le tag par défaut si aucun tag n'est spécifié
- C) C'est la version la plus stable
- D) C'est la version recommandée pour la production

---

## Q14. Instruction définissant le répertoire de travail dans un conteneur ?

- A) WORKDIR
- B) CD
- C) DIR
- D) SETDIR

---

## Q15. Passer une variable d'environnement à un conteneur ?

- A) `docker run --var NAME=value image`
- B) `docker run -e NAME=value image`
- C) `docker run --env-file NAME=value image`
- D) `docker run -E NAME=value image`

---

## Q16. Avantage principal des multi-stage builds ?

- A) Construction plus rapide
- B) Images finales plus petites et sécurisées
- C) Meilleure compatibilité
- D) Support du multi-threading

---

## Q17. Exécuter une commande dans un conteneur en cours d'exécution ?

- A) `docker run -it container_id bash`
- B) `docker exec -it container_id bash`
- C) `docker attach container_id bash`
- D) `docker connect container_id bash`

---

## Q18. Que fait `docker-compose up -d` ?

- A) Affiche les logs en mode détaché
- B) Démarre les services en arrière-plan
- C) Télécharge les images
- D) Détruit les conteneurs

---

## Q19. Instruction pour définir des métadonnées dans une image ?

- A) META
- B) LABEL
- C) INFO
- D) TAG

---

## Q20. Limiter la mémoire d'un conteneur à 512 Mo ?

- A) `docker run --memory 512m image`
- B) `docker run -m 512 image`
- C) `docker run --ram 512m image`
- D) `docker run --limit-memory 512m image`

---

## Q21. Système de fichiers utilisé par Docker pour les couches d'images ?

- A) ext4 uniquement
- B) Union filesystem (overlay2, aufs, etc.)
- C) NTFS
- D) ZFS uniquement

---

## Q22. Afficher l'utilisation des ressources des conteneurs ?

- A) `docker stats`
- B) `docker top`
- C) `docker resources`
- D) `docker monitor`

---

## Q23. Créer un réseau Docker personnalisé ?

- A) `docker network create mon_reseau`
- B) `docker create network mon_reseau`
- C) `docker net add mon_reseau`
- D) `docker add-network mon_reseau`

---

## Q24. Bonne pratique pour l'ordre des instructions dans un Dockerfile ?

- A) Mettre les instructions qui changent souvent en premier
- B) Mettre les instructions qui changent rarement en premier
- C) L'ordre n'a pas d'importance
- D) Toujours commencer par CMD

---

## Q25. Que fait l'instruction HEALTHCHECK ?

- A) Vérifie la santé de l'image pendant le build
- B) Définit une commande pour vérifier l'état du conteneur
- C) Envoie des alertes en cas de problème
- D) Redémarre automatiquement le conteneur

---

# PARTIE 2
## Sécurité des Conteneurs
### Questions 26 → 50

---

## Q26. Pourquoi éviter d'exécuter des conteneurs en tant que root ?

- A) Les performances sont réduites
- B) Un attaquant qui compromet le conteneur a des privilèges élevés
- C) Docker ne le supporte pas officiellement
- D) Les volumes ne fonctionnent pas

---

## Q27. Instruction Dockerfile pour changer l'utilisateur d'exécution ?

- A) SETUSER
- B) USER
- C) RUNAS
- D) SWITCHUSER

---

## Q28. Que signifie le flag `--privileged` ?

- A) Le conteneur a accès à tous les devices de l'hôte
- B) Le conteneur est prioritaire en ressources
- C) Le conteneur peut modifier son image
- D) Le conteneur a un accès réseau prioritaire

---

## Q29. Option pour limiter les capabilities Linux d'un conteneur ?

- A) `--cap-add` et `--cap-drop`
- B) `--limit-caps`
- C) `--capabilities`
- D) `--linux-caps`

---

## Q30. Bonne pratique pour les images de base ?

- A) Utiliser toujours ubuntu:latest
- B) Utiliser des images minimales (alpine, distroless)
- C) Utiliser des images avec le plus de paquets possible
- D) Créer sa propre image from scratch pour tout

---

## Q31. Scanner une image Docker pour les vulnérabilités ?

- A) `docker scan image_name` ou outils comme Trivy
- B) `docker check image_name`
- C) `docker verify image_name`
- D) `docker audit image_name`

---

## Q32. Qu'est-ce qu'un "secret" dans Docker/Kubernetes ?

- A) Des fichiers cachés dans l'image
- B) Des données sensibles (mots de passe, clés) gérées de manière sécurisée
- C) Des conteneurs invisibles
- D) Des réseaux privés

---

## Q33. Pourquoi ne jamais stocker de secrets dans une image Docker ?

- A) Cela augmente la taille de l'image
- B) Les couches d'image peuvent être inspectées et les secrets exposés
- C) Docker refuse de construire l'image
- D) Les secrets sont automatiquement supprimés

---

## Q34. Bonne pratique pour le tag des images en production ?

- A) Utiliser :latest
- B) Utiliser des tags versionnés spécifiques (ex: v1.2.3)
- C) Ne pas utiliser de tags
- D) Utiliser :stable

---

## Q35. Qu'est-ce que le "read-only filesystem" pour un conteneur ?

- A) Le conteneur ne peut pas lire les fichiers
- B) Le système de fichiers du conteneur est en lecture seule
- C) Les logs sont désactivés
- D) Le réseau est en lecture seule

---

## Q36. Activer le mode read-only pour un conteneur ?

- A) `docker run --read-only image`
- B) `docker run --ro image`
- C) `docker run --filesystem=readonly image`
- D) `docker run -r image`

---

## Q37. Qu'est-ce qu'une "Security Context" dans Kubernetes ?

- A) Un pare-feu pour les pods
- B) Des paramètres de sécurité appliqués aux pods/conteneurs
- C) Un certificat SSL
- D) Un mot de passe administrateur

---

## Q38. Que fait `runAsNonRoot: true` dans un SecurityContext ?

- A) Désactive le réseau
- B) Empêche le conteneur de s'exécuter en tant que root
- C) Supprime tous les fichiers root
- D) Crée un utilisateur non-root automatiquement

---

## Q39. Qu'est-ce qu'une NetworkPolicy dans Kubernetes ?

- A) Une politique de routage
- B) Des règles de firewall pour contrôler le trafic entre pods
- C) Une configuration DNS
- D) Un load balancer

---

## Q40. Comportement réseau par défaut entre pods Kubernetes ?

- A) Tout le trafic est bloqué
- B) Tout le trafic est autorisé
- C) Seul le trafic HTTP est autorisé
- D) Seul le trafic interne au namespace est autorisé

---

## Q41. Qu'est-ce que Pod Security Standards (PSS) ?

- A) Des normes de nommage des pods
- B) Des profils de sécurité prédéfinis (privileged, baseline, restricted)
- C) Des règles de déploiement
- D) Des standards de performance

---

## Q42. Niveau de Pod Security Standards le plus restrictif ?

- A) privileged
- B) baseline
- C) restricted
- D) default

---

## Q43. Isolation des namespaces Linux dans les conteneurs ?

- A) Une séparation des ressources (PID, network, mount, etc.)
- B) Un système de fichiers virtuel
- C) Un pare-feu
- D) Un antivirus

---

## Q44. Namespace Linux qui isole les processus d'un conteneur ?

- A) NET namespace
- B) PID namespace
- C) MNT namespace
- D) USER namespace

---

## Q45. Qu'est-ce que "seccomp" ?

- A) Un outil de compression sécurisée
- B) Un mécanisme de filtrage des appels système
- C) Un protocole de communication sécurisé
- D) Un système de secrets

---

## Q46. Bonne pratique pour les registres d'images ?

- A) Utiliser uniquement Docker Hub public
- B) Utiliser des registres privés et scanner les images
- C) Ne jamais utiliser de registre
- D) Stocker les images localement uniquement

---

## Q47. Que fait l'option `--no-new-privileges` ?

- A) Désactive les mises à jour
- B) Empêche les processus d'acquérir de nouveaux privilèges
- C) Désactive les nouveaux utilisateurs
- D) Bloque les nouvelles connexions réseau

---

## Q48. Comment signer une image Docker ?

- A) `docker sign image`
- B) Utiliser Docker Content Trust (DCT) ou Notary
- C) Ajouter une signature dans le Dockerfile
- D) Utiliser `docker verify`

---

## Q49. Qu'est-ce qu'AppArmor dans le contexte des conteneurs ?

- A) Un antivirus pour conteneurs
- B) Un module de sécurité Linux limitant les actions des programmes
- C) Un pare-feu applicatif
- D) Un outil de monitoring

---

## Q50. Bonne pratique pour les ports exposés ?

- A) Exposer tous les ports pour faciliter le debug
- B) N'exposer que les ports strictement nécessaires
- C) Toujours utiliser les ports par défaut
- D) Utiliser des ports aléatoires

---

# PARTIE 3
## Kubernetes Fondamentaux
### Questions 51 → 75

---

## Q51. Composant du Control Plane qui stocke l'état du cluster ?

- A) kube-scheduler
- B) kube-apiserver
- C) etcd
- D) kube-controller-manager

---

## Q52. Rôle du kube-scheduler ?

- A) Stocker les données du cluster
- B) Assigner les pods aux nodes
- C) Gérer les secrets
- D) Exposer l'API

---

## Q53. Plus petite unité déployable dans Kubernetes ?

- A) Container
- B) Pod
- C) Deployment
- D) Node

---

## Q54. Lister tous les pods dans tous les namespaces ?

- A) `kubectl get pods`
- B) `kubectl get pods --all-namespaces`
- C) `kubectl get pods -all`
- D) `kubectl list pods --global`

---

## Q55. Objet Kubernetes gérant le déploiement et la mise à l'échelle des pods ?

- A) Service
- B) ConfigMap
- C) Deployment
- D) Pod

---

## Q56. Exposer un déploiement en tant que service ?

- A) `kubectl expose deployment nom --port=80`
- B) `kubectl service create nom`
- C) `kubectl publish deployment nom`
- D) `kubectl network deployment nom`

---

## Q57. Type de Service exposant l'application sur un port de chaque Node ?

- A) ClusterIP
- B) NodePort
- C) LoadBalancer
- D) ExternalName

---

## Q58. Type de Service par défaut ?

- A) NodePort
- B) LoadBalancer
- C) ClusterIP
- D) ExternalName

---

## Q59. Qu'est-ce qu'un ReplicaSet ?

- A) Une copie d'un cluster
- B) Un ensemble de pods identiques maintenus à un nombre défini
- C) Un système de backup
- D) Un groupe de nodes

---

## Q60. Appliquer un fichier de configuration YAML ?

- A) `kubectl create -f fichier.yaml`
- B) `kubectl apply -f fichier.yaml`
- C) `kubectl deploy -f fichier.yaml`
- D) Les deux A et B sont valides

---

## Q61. Qu'est-ce qu'un Namespace dans Kubernetes ?

- A) Un type de réseau
- B) Une isolation logique des ressources dans un cluster
- C) Un conteneur spécial
- D) Un système de fichiers

---

## Q62. Voir les logs d'un pod ?

- A) `kubectl logs nom-pod`
- B) `kubectl get logs nom-pod`
- C) `kubectl describe logs nom-pod`
- D) `kubectl show logs nom-pod`

---

## Q63. Exécuter un shell dans un pod ?

- A) `kubectl ssh nom-pod`
- B) `kubectl exec -it nom-pod -- /bin/sh`
- C) `kubectl connect nom-pod`
- D) `kubectl terminal nom-pod`

---

## Q64. Qu'est-ce qu'un ConfigMap ?

- A) Une carte du cluster
- B) Un objet pour stocker des données de configuration non sensibles
- C) Un fichier de logs
- D) Une configuration réseau

---

## Q65. Différence entre ConfigMap et Secret ?

- A) Aucune différence
- B) Secret est encodé en base64 et conçu pour les données sensibles
- C) ConfigMap est plus rapide
- D) Secret ne peut contenir que des mots de passe

---

## Q66. Qu'est-ce qu'un DaemonSet ?

- A) Un pod qui s'exécute sur tous les nodes (ou un sous-ensemble)
- B) Un démon système
- C) Un service en arrière-plan
- D) Un type de conteneur

---

## Q67. Qu'est-ce qu'un StatefulSet ?

- A) Un ensemble de pods avec identité et stockage persistants
- B) Un pod qui ne change jamais
- C) Un type de Service
- D) Un conteneur avec état activé

---

## Q68. Mettre à l'échelle un deployment à 5 replicas ?

- A) `kubectl scale deployment nom --replicas=5`
- B) `kubectl resize deployment nom -r 5`
- C) `kubectl set replicas deployment nom 5`
- D) `kubectl update deployment nom --count=5`

---

## Q69. Qu'est-ce qu'un Ingress ?

- A) Un type de pod
- B) Un objet gérant l'accès externe HTTP/HTTPS aux services
- C) Un pare-feu
- D) Un volume de stockage

---

## Q70. Composant qui s'exécute sur chaque node worker ?

- A) kube-apiserver
- B) kubelet
- C) etcd
- D) kube-scheduler

---

## Q71. Rôle du kubelet ?

- A) Stocker les images
- B) S'assurer que les conteneurs sont en cours d'exécution dans les pods
- C) Router le trafic
- D) Gérer le DNS

---

## Q72. Qu'est-ce que kube-proxy ?

- A) Un proxy HTTP
- B) Un composant gérant les règles réseau pour les Services
- C) Un cache d'images
- D) Un outil de monitoring

---

## Q73. Décrire un pod en détail ?

- A) `kubectl get pod nom -v`
- B) `kubectl describe pod nom`
- C) `kubectl info pod nom`
- D) `kubectl details pod nom`

---

## Q74. Qu'est-ce qu'un PersistentVolume (PV) ?

- A) Un volume temporaire
- B) Une ressource de stockage provisionnée dans le cluster
- C) Un disque local uniquement
- D) Un système de backup

---

## Q75. Qu'est-ce qu'un PersistentVolumeClaim (PVC) ?

- A) Une demande de stockage par un utilisateur/pod
- B) Un volume créé automatiquement
- C) Un type de ConfigMap
- D) Un backup de volume

---

# PARTIE 4
## Kubernetes Avancé
### Questions 76 → 102

---

## Q76. Qu'est-ce qu'une probe "liveness" ?

- A) Vérifie si l'application est prête à recevoir du trafic
- B) Vérifie si le conteneur doit être redémarré
- C) Vérifie l'utilisation CPU
- D) Vérifie la connexion réseau

---

## Q77. Qu'est-ce qu'une probe "readiness" ?

- A) Vérifie si l'application est prête à recevoir du trafic
- B) Vérifie si le conteneur doit être redémarré
- C) Vérifie l'utilisation mémoire
- D) Vérifie le stockage

---

## Q78. Conséquence d'une probe liveness qui échoue ?

- A) Le pod est supprimé du Service
- B) Le conteneur est redémarré
- C) Le node est marqué comme défaillant
- D) Une alerte est envoyée

---

## Q79. Stratégie de déploiement mettant à jour les pods progressivement ?

- A) Recreate
- B) RollingUpdate
- C) BlueGreen
- D) Canary

---

## Q80. Que fait la stratégie "Recreate" ?

- A) Mise à jour progressive
- B) Supprime tous les anciens pods avant de créer les nouveaux
- C) Crée des copies des pods
- D) Ne modifie que la configuration

---

## Q81. Annuler un déploiement en cours ?

- A) `kubectl rollout undo deployment nom`
- B) `kubectl cancel deployment nom`
- C) `kubectl revert deployment nom`
- D) `kubectl rollback deployment nom`

---

## Q82. Qu'est-ce qu'un HorizontalPodAutoscaler (HPA) ?

- A) Un équilibreur de charge
- B) Un objet qui ajuste automatiquement le nombre de replicas
- C) Un système de rotation des logs
- D) Un outil de monitoring

---

## Q83. Métrique sur laquelle un HPA se base par défaut ?

- A) Utilisation disque
- B) Utilisation CPU
- C) Nombre de requêtes
- D) Latence réseau

---

## Q84. Qu'est-ce qu'un ResourceQuota ?

- A) Un quota de pods par node
- B) Des limites sur les ressources consommables par namespace
- C) Un quota d'utilisateurs
- D) Une limite de taille d'images

---

## Q85. Différence entre "requests" et "limits" pour les ressources ?

- A) Aucune différence
- B) requests = minimum garanti, limits = maximum autorisé
- C) limits = minimum, requests = maximum
- D) requests concerne la CPU, limits la mémoire

---

## Q86. Que se passe-t-il si un conteneur dépasse sa limite mémoire ?

- A) Il est ralenti
- B) Il est terminé (OOMKilled)
- C) La limite est augmentée automatiquement
- D) Rien, c'est une limite souple

---

## Q87. Qu'est-ce qu'un LimitRange ?

- A) Un range d'adresses IP
- B) Des valeurs par défaut et limites pour les ressources dans un namespace
- C) Un intervalle de ports
- D) Une plage de versions

---

## Q88. Outil pour gérer les packages Kubernetes ?

- A) npm
- B) Helm
- C) apt
- D) pip

---

## Q89. Qu'est-ce qu'un Helm Chart ?

- A) Un graphique de monitoring
- B) Un package de ressources Kubernetes
- C) Un diagramme d'architecture
- D) Un outil de visualisation

---

## Q90. Qu'est-ce que RBAC dans Kubernetes ?

- A) Un type de réseau
- B) Role-Based Access Control pour la gestion des permissions
- C) Un système de backup
- D) Un protocole de communication

---

## Q91. Objets principaux de RBAC ?

- A) Users et Groups
- B) Role, ClusterRole, RoleBinding, ClusterRoleBinding
- C) Pods et Services
- D) Namespaces et Nodes

---

## Q92. Différence entre Role et ClusterRole ?

- A) Aucune différence
- B) Role est limité à un namespace, ClusterRole est global
- C) ClusterRole est plus sécurisé
- D) Role est pour les utilisateurs, ClusterRole pour les services

---

## Q93. Qu'est-ce qu'un ServiceAccount ?

- A) Un compte utilisateur
- B) Une identité pour les pods interagissant avec l'API
- C) Un type de Service
- D) Un compte de facturation

---

## Q94. Bonne pratique pour les labels ?

- A) Ne pas utiliser de labels
- B) Utiliser des labels cohérents et standardisés (app, version, env)
- C) Utiliser uniquement des labels numériques
- D) Un seul label par ressource

---

## Q95. Qu'est-ce que l'affinité de pod (Pod Affinity) ?

- A) Une préférence pour un type de node
- B) Des règles pour placer des pods ensemble ou séparément
- C) Une connexion entre pods
- D) Un type de réseau

---

## Q96. Qu'est-ce qu'un Taint sur un node ?

- A) Une erreur système
- B) Une marque qui repousse les pods sans tolération correspondante
- C) Un virus
- D) Un type de monitoring

---

## Q97. Comment un pod peut-il être schedulé sur un node avec un taint ?

- A) Avec un label correspondant
- B) Avec une toleration correspondante
- C) En étant privileged
- D) Impossible

---

## Q98. Qu'est-ce que Kubernetes Federation ?

- A) Un type de deployment
- B) La gestion de plusieurs clusters Kubernetes
- C) Un réseau fédéré
- D) Un système d'authentification

---

## Q99. Bonne pratique pour les health checks ?

- A) Ne pas utiliser de health checks
- B) Configurer livenessProbe et readinessProbe appropriées
- C) Utiliser uniquement livenessProbe
- D) Vérifier uniquement le port

---

## Q100. Outil pour débugger un cluster Kubernetes ?

- A) Uniquement kubectl logs
- B) kubectl describe, logs, events, et outils comme k9s
- C) Docker uniquement
- D) SSH sur les nodes uniquement

---

## Q101. Rôle du Controller Manager et du Scheduler ?

- A) Le Controller Manager place les pods, le Scheduler les crée
- B) Ils travaillent en séquence : Controller Manager attend que le Scheduler ait fini
- C) Controller Manager crée les pods (sans nœud), Scheduler les assigne — en parallèle sur l'API
- D) Le Scheduler crée les pods, le Controller Manager les place

---

## Q102. Pourquoi un DaemonSet tourne sur un nœud cordonné ?

- A) Les DaemonSet ignorent toutes les règles de placement et les taints
- B) `kubectl cordon` pose le taint `unschedulable:NoSchedule` — DaemonSet controller ajoute la toleration automatiquement
- C) Les pods DaemonSet ont des privilèges administrateur sur le scheduler
- D) Le cordoning ne s'applique qu'aux Deployments

---

# Fin du QCM

**102 questions — Bonne chance !**

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This repo contains infrastructure tooling and a Kubernetes practical lab (TD) for an advanced course:

- `infra-do/` — DigitalOcean VM provisioning scripts (run locally)
- `infra-exo/` — Exoscale VM provisioning scripts (run locally, même interface que DO)
- `tp101/td-kubernetes-kubeadm/` — Kubernetes kubeadm lab material (see its own `CLAUDE.md` for details)

## Infrastructure DigitalOcean (`infra-do/`)

Scripts use `doctl` (DigitalOcean CLI) and require the env var `DIGITALOCEAN_ACCESS_TOKEN`.

```bash
# Check droplets with a given tag
./infra-do/check_do.sh <tag>

# Create VMs (CentOS Stream 10, fra1 region, s-2vcpu-8gb-amd size)
./infra-do/manage_vm.sh --tags "tag1,tag2" --count 3

# Delete VMs by tag
./infra-do/manage_vm.sh --tags "tag1" --delete

# Delete ALL VMs (interactive confirmation required)
./infra-do/manage_vm.sh --delete --all

# Initialize SSH key path in .env
./infra-do/manage_vm.sh --init /path/to/key
```

The SSH key (`infra-do/vm_key`) is auto-generated on first run if absent. Key configuration can be overridden via `infra-do/.env` (`KEY_NAME=...`).

## Infrastructure Exoscale (`infra-exo/`)

Scripts use `exo` (Exoscale CLI) and require `EXOSCALE_API_KEY` + `EXOSCALE_API_SECRET`.
**Interface identique à infra-do** — les mêmes commandes fonctionnent sur les deux providers.

Différences internes vs DigitalOcean :
- Les "tags" DO sont mappés en **labels Exoscale** (`<tag>=true`)
- Zone par défaut : `de-fra-1` (Frankfurt)
- Instance type : `standard.medium` (2 vCPU / 4 GB)
- Template : `Linux CentOS Stream 10 64-bit`
- `jq` requis pour le parsing JSON

```bash
# Check instances with a given tag
./infra-exo/check_exo.sh <tag>

# Create VMs
./infra-exo/manage_vm.sh --tags "tag1,tag2" --count 3

# Delete VMs by tag
./infra-exo/manage_vm.sh --tags "tag1" --delete

# Delete ALL VMs (interactive confirmation required)
./infra-exo/manage_vm.sh --delete --all

# Initialize SSH key path in .env
./infra-exo/manage_vm.sh --init /path/to/key
```

Optional: set `SECURITY_GROUP` in `infra-exo/.env` to attach a pre-existing Exoscale security group (needed for inbound SSH/Kubernetes ports).

The SSH key (`infra-exo/vm_key`) is auto-generated on first run if absent. Key configuration can be overridden via `infra-exo/.env` (`KEY_NAME=...`, `SECURITY_GROUP=...`).

## Kubernetes Lab (`tp101/td-kubernetes-kubeadm/`)

See `tp101/td-kubernetes-kubeadm/CLAUDE.md` for full details on the lab architecture, script execution order (especially the critical CNI migration sequence), and editing conventions.

Key points:
- Target OS: **CentOS Stream 10** (uses `dnf`, `firewall-cmd`)
- Scripts run **on cluster nodes**, not locally
- Kubernetes 1.28.x → 1.29.x upgrade path
- `jq` required for validation scripts

## Slides Marp — Contraintes de mise en page

Le fichier `tp101/td-kubernetes-kubeadm/docs/slides-instructeur.md` est rendu par Marp (1280×720px, font-size 20px, padding 30px 50px). Zone de contenu utile : **1180px × 660px**.

### Règles de contenu par slide
- Max **8 bullet points** par slide
- Code blocks : max **12-15 lignes**
- Tableaux : max **6 lignes de données** + header
- Mixte (bullets + code) : 4 bullets + 8 lignes code max

### Diagrammes SVG — règle impérative
**Les diagrammes doivent occuper la pleine page du slide.** Ne jamais mélanger un grand diagramme avec plusieurs bullets sur le même slide. Règles :
- SVG "pleine page" : `width="1100" height="280"` minimum (ou plus grand selon le contenu)
- Un slide avec diagramme = diagramme + **maximum 1-2 lignes** de texte d'accompagnement
- Si un diagramme est petit, le compléter avec du texte — mais si le diagramme est grand, le mettre seul sur son slide
- Pour les SVG inline : toujours utiliser `viewBox` cohérent avec `width`/`height`

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Kubernetes practical lab (TD) for an advanced course, covering the full lifecycle of a kubeadm-managed multi-node cluster. Target OS is **CentOS Stream 10** (scripts use `dnf`, `dnf versionlock`, `firewall-cmd`). The lab is designed to run on real or virtual machines — there is no local test environment.

Kubernetes versions: 1.34.x (initial install) → 1.35.x (upgrade in Partie 6).

## Running Scripts

Scripts must be executed **on the actual cluster nodes** (master or workers), not locally. Each script includes comments specifying where to run it.

```bash
# Validate a specific lab section (run on master node)
cd validation && ./validate-partie.sh <1-6>

# Validate entire lab
cd validation && ./validate-all.sh
```

Scripts in `scripts/partie-04-migration-cni/03-remove-flannel.sh` take a positional argument:
```bash
./03-remove-flannel.sh master   # run on control plane
sudo ./03-remove-flannel.sh node  # run on each node (requires root)
```

## Architecture

### Lab Sections (sequential dependencies)

| Section | Focus | Key dependency |
|---------|-------|---------------|
| Partie 1 | Cluster install (containerd, kubeadm, Flannel CNI) | Required for all others |
| Partie 2 | kubelet config + static pods | Requires Partie 1 |
| Partie 3 | Taints & tolerations | Requires Partie 1 |
| Partie 4 | CNI migration: Flannel → Calico | Requires Partie 1 |
| Partie 5 | Node drain/maintenance, PDB, DaemonSets | Independent |
| Partie 6 | Cluster upgrade 1.34 → 1.35 | Independent |
| Partie 7 | RuntimeClass + gVisor sandbox runtime | Independent (requires Partie 1) |

### CNI Migration Sequence (Partie 4 — critical ordering)

The Flannel→Calico migration is the most complex part. The correct order is:
1. `01-backup-cluster-state.sh` — backup on master
2. `02-drain-nodes.sh` — drain workers on master
3. `03-remove-flannel.sh master` — remove Flannel resources from cluster
4. `03-remove-flannel.sh node` — clean network interfaces on **each node** (do NOT restart kubelet yet)
5. `04-install-calico.sh` — install Calico on master (waits for pods ready)
6. `sudo systemctl start kubelet` — restart kubelet on each node only after step 5 completes
7. `05-uncordon-and-validate.sh` — uncordon workers and validate connectivity

### Config Files

- `configs/kubelet/kubelet-config-custom.yaml` — modified kubelet params (maxPods, staticPodPath)
- `configs/static-pods/disk-monitor.yaml` — static pod manifest deployed to `/etc/kubernetes/manifests/`
- `configs/workloads/` — test manifests for scheduling experiments (pods with/without tolerations, PDB, DaemonSet)

### Calico CIDR

`04-install-calico.sh` auto-detects pod CIDR from `/etc/kubernetes/manifests/kube-controller-manager.yaml` and patches Calico's default `192.168.0.0/16`. If auto-detection fails, it falls back to `10.244.0.0/16` (Flannel default).

### Calico on Exoscale (VXLAN required)

On Exoscale (and similar cloud providers), Calico's default BGP+IPIP mode fails because IPIP (IP protocol 4) is blocked by security groups. After installing Calico, switch to VXLAN mode:

```bash
kubectl patch ippools default-ipv4-ippool --type=merge \
  -p '{"spec": {"ipipMode": "Never", "vxlanMode": "Always"}}'
kubectl rollout restart daemonset/calico-node -n kube-system
```

Also required after the Flannel→Calico migration on Exoscale:
1. Restart kube-proxy: `kubectl rollout restart daemonset/kube-proxy -n kube-system`
2. Recycle CoreDNS: `kubectl delete pods -n kube-system -l k8s-app=kube-dns`

### gVisor (Partie 7)

- Requires `runsc` + `containerd-shim-runsc-v1` on each node (both from `storage.googleapis.com/gvisor/releases/release/latest/x86_64/`)
- containerd v2 config path: `plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc` (NOT `io.containerd.grpc.v1.cri`)
- Use drop-in file `/etc/containerd/conf.d/gvisor.toml` — do not edit `config.toml` directly
- KVM is available on Exoscale VMs (`/dev/kvm` exists) — use `platform = 'kvm'` in `/etc/containerd/runsc.toml`
- Typical overhead: ~2-3× for I/O and fork/exec syscalls

### Exoscale-specific setup

Before running any Kubernetes scripts on CentOS Stream 10 nodes on Exoscale:
1. Disable firewalld on all nodes: `systemctl stop firewalld && systemctl disable firewalld`
2. Ensure all nodes are in the `tp-k8s` security group (allows all TCP/UDP intra-group + SSH from anywhere)
3. The `tp-k8s` security group must be created with self-referencing TCP+UDP rules for inter-node K8s traffic

## Editing Scripts

- Scripts targeting CentOS/RHEL use `dnf`; if adapting for Ubuntu/Debian, swap to `apt-get`, `apt-mark hold`, `ufw`
- The `set -e` pattern is used throughout — use `|| true` for optional steps, `false` instead of `exit 1` inside conditionals (to allow `set -e` to trigger the trap properly)
- `jq` is required by several validation scripts for JSON processing

## Docs & Diagrams

- `docs/exercices-etudiants.md` — student-facing lab guide
- `docs/guide-instructeur.md` — instructor guide with timing and common issues
- `docs/diagrams/*.puml` — PlantUML architecture diagrams for each lab concept
- `docs/presentation/` — slide deck served via Docker (`./run-presentation.sh`)

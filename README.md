<div align="center">

# 🚢 Kubernetes — My Hard Way

**Hands-on kubeadm lab from scratch** — CentOS Stream 10 — 13 modules

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.34_→_1.35-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![OS](https://img.shields.io/badge/CentOS_Stream_10-EE0000?style=flat-square&logo=redhat&logoColor=white)](https://centos.org)
[![CNI](https://img.shields.io/badge/CNI-Flannel_→_Calico-FB6C1E?style=flat-square)](https://docs.tigera.io)
[![Runtime](https://img.shields.io/badge/Runtime-containerd-575757?style=flat-square)](https://containerd.io)
[![gVisor](https://img.shields.io/badge/Sandbox-gVisor-4285F4?style=flat-square)](https://gvisor.dev)

</div>

---

A practical lab covering **the full lifecycle of a Kubernetes cluster** built by hand with `kubeadm` on CentOS Stream 10 — from initial installation through CNI migration, cluster upgrade, sandbox isolation, observability, and finally a full HA control plane setup.

| | |
|---|---|
| **Total duration** | ~5h30 (modules 2–12 + HA) |
| **Level** | Advanced |
| **Target OS** | CentOS Stream 10 |
| **Infrastructure** | 3 VMs — DigitalOcean or Exoscale |
| **Kubernetes** | 1.34.x → upgrade to 1.35.x |
| **Instructor slides** | 340+ Marp slides |

---

## Table of Contents

| Module | Topic | Duration |
|--------|-------|----------|
| [2 — Cluster Installation](#module-2--cluster-installation) | containerd · kubeadm · kubelet · Flannel | 35 min |
| [3 — Kubelet & Static Pods](#module-3--kubelet--static-pods) | configuration · reconciliation loop · CRI | 30 min |
| [4 — Taints & Tolerations](#module-4--taints--tolerations) | advanced scheduling · NoSchedule · NoExecute | 30 min |
| [5 — CNI Migration](#module-5--cni-migration) | Flannel → Calico · VXLAN · overlay networks | 25 min |
| [6 — Drain & Maintenance](#module-6--drain--maintenance) | PDB · DaemonSets · node failure simulation | 20 min |
| [7 — etcd & etcdctl](#module-7--etcd--etcdctl) | backup · restore · member list · stacked vs external | 25 min |
| [8 — Cluster Upgrade](#module-8--cluster-upgrade) | 1.34 → 1.35 · mandatory upgrade order | 25 min |
| [9 — RuntimeClass & gVisor](#module-9--runtimeclass--gvisor) | sandbox isolation · KVM · containerd shims | 25 min |
| [10 — Multi-Master Control Plane](#module-10--multi-master-control-plane) | 3 masters · etcd quorum · worker promotion | 30 min |
| [11 — cgroups](#module-11--cgroups) | v2 · QoS classes · kernel memory management | 20 min |
| [12 — Public vs Private Networking](#module-12--public-vs-private-networking) | architecture · DIY load balancer · Exoscale | 10 min |
| [13 — SKS Exoscale](#module-13--sks-exoscale) | managed Kubernetes vs kubeadm | 15 min |
| [14 — kube-prometheus-stack](#module-14--kube-prometheus-stack) | Grafana · Prometheus · pre-built alerts | 30 min |

---

## Module 2 — Cluster Installation

Install all components from scratch and bootstrap a working 3-node cluster.

- System prerequisites: swap, SELinux, kernel modules, sysctl, firewall
- containerd installation and `SystemdCgroup` configuration
- kubeadm, kubelet, kubectl from the official Kubernetes repo
- Control plane init with `kubeadm init`
- Workers joining the cluster
- Flannel CNI installation and cluster verification

**Scripts:** `scripts/partie1-installation/`

---

## Module 3 — Kubelet & Static Pods

Understand the kubelet as the node agent and explore static pods as the foundation of the control plane itself.

- kubelet reconciliation loop and CRI interface
- Reading and modifying `kubelet-config.yaml`
- Static pod manifests in `/etc/kubernetes/manifests/`
- How `kube-apiserver`, `etcd`, `kube-scheduler` are themselves static pods
- Static pod behavior: resurrection after manual deletion

**Scripts:** `scripts/partie2-kubelet-static-pods/`

---

## Module 4 — Taints & Tolerations

Control which pods land on which nodes using Kubernetes' push-based scheduling mechanism.

- Default `control-plane:NoSchedule` taint and why it exists
- The 3 effects: `NoSchedule`, `PreferNoSchedule`, `NoExecute`
- Writing tolerations in pod specs
- Real-world use cases: GPU nodes, spot instances, dedicated infra nodes
- `tolerationSeconds` and eviction delay

**Scripts:** `scripts/partie3-taints-tolerations/`

---

## Module 5 — CNI Migration

Live-migrate the cluster network from Flannel to Calico without losing connectivity.

- Why migrate: policy enforcement, BGP, better observability
- VXLAN vs IPIP encapsulation (IPIP blocked on Exoscale/DO)
- Drain → remove Flannel → install Calico → uncordon: the mandatory sequence
- Validating pod-to-pod connectivity post-migration

**Scripts:** `scripts/partie4-migration-cni/`

---

## Module 6 — Drain & Maintenance

Safely take nodes out of service without disrupting running workloads.

- `kubectl drain` vs `kubectl cordon`
- PodDisruptionBudget: preventing unsafe evictions
- DaemonSets and drain: why `--ignore-daemonsets` is required
- Simulating a node failure and observing Kubernetes recovery timeline

**Scripts:** `scripts/partie5-drain-maintenance/`

---

## Module 7 — etcd & etcdctl

Understand etcd as the single source of truth for the cluster, and learn to back it up and restore it before any upgrade.

- etcd's role: everything kubectl returns comes from etcd
- Stacked vs external etcd topology in kubeadm
- etcdctl setup: API v3, TLS certificates, endpoint
- Essential commands: `member list`, `endpoint health`, `get --prefix --keys-only`
- Snapshot backup (`etcdctl snapshot save`) — mandatory before an upgrade
- Restoring a cluster from a snapshot: stop API server → restore → point etcd at new data-dir

**Scripts:** (covered in slides — `scripts/partie6-upgrade/` for the backup step)

---

## Module 8 — Cluster Upgrade

Upgrade a live cluster following the mandatory component order.

- Version skew policy: why order matters
- Upgrading the control plane with `kubeadm upgrade apply`
- Upgrading kubelet and kubectl on the master
- Rolling worker upgrade: drain → upgrade → uncordon
- Post-upgrade validation

**Scripts:** `scripts/partie6-upgrade/`

---

## Module 9 — RuntimeClass & gVisor

Run untrusted workloads with stronger isolation using a second container runtime.

- The isolation problem with standard containers (shared kernel)
- gVisor: a user-space kernel intercepting syscalls
- Installing gVisor and configuring containerd
- Creating a `RuntimeClass` resource to link Kubernetes to gVisor
- Demonstrating syscall isolation and measuring performance overhead

**Scripts:** `scripts/partie7-runtimeclass/`

---

## Module 10 — Multi-Master Control Plane

Transform the existing `1 master + 2 workers` topology into **3 nodes each running the full control plane stack** — API server, scheduler, controller-manager, etcd, and kubelet.

This is not a production recommendation (no real load balancer in front of the API servers), but it demonstrates the mechanics of multi-master Kubernetes and etcd quorum.

**What changes:**
- etcd goes from 1 member to 3 — the cluster now tolerates losing 1 node
- All 3 nodes run `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`
- The `NoSchedule` taint is removed so application pods schedule on all nodes

**Key constraint:** `--control-plane-endpoint` must be set at `kubeadm init` time. Without it the API server certificate only covers the original master's IP and adding further control planes requires a full cluster reset.

**Scripts:** `scripts/partie-bonus-ha/`

| Step | Script | Node |
|------|--------|------|
| 1 | `00-reinit-master.sh` | master |
| 2 | `scp /tmp/ha-join-info.sh` | master → each worker |
| 3 | `01-promote-worker.sh` | worker1 |
| 4 | `01-promote-worker.sh` | worker2 |
| 5 | `02-allow-scheduling.sh` | master |
| 6 | `03-validate-ha.sh` | master |

---

## Module 11 — cgroups

Understand how Kubernetes resource limits actually work at the kernel level.

- cgroup v2 hierarchy and the `/sys/fs/cgroup` filesystem
- Mapping a running container to its cgroup
- QoS classes: `Guaranteed`, `Burstable`, `BestEffort`
- What happens at the kernel level when a pod hits its memory limit
- Writing a C snippet that manually creates a cgroup

**Scripts:** `scripts/partie9-cgroups/`

---

## Module 12 — Public vs Private Networking

Understand the network architecture trade-offs when running Kubernetes on cloud VMs.

- Risks of exposing nodes directly on public IPs
- Private network isolation with a dedicated security group per role
- DIY load balancer: what it actually implies (health checks, failover, BGP)
- NLB on Exoscale as an alternative for the API server endpoint

---

## Module 13 — SKS Exoscale

Compare a managed Kubernetes service with the kubeadm cluster built in this lab.

- SKS architecture: managed control plane, worker node pools
- What you give up (etcd access, control plane tuning) and what you gain
- Single-zone limitation and its implications
- Hybrid scenario: SKS + on-prem kubeadm nodes

---

## Module 14 — kube-prometheus-stack

Deploy a full observability stack on the cluster using Helm.

- kube-prometheus-stack components: Prometheus, Alertmanager, Grafana, exporters
- Installing via Helm and verifying the deployment
- Built-in dashboards: nodes, pods, control plane components
- Writing custom PromQL queries and adding dashboards via ConfigMap
- ~150 pre-configured alert rules

**Scripts:** `scripts/partie12-prometheus/`

---

## Quick Start

### 1 — Provision VMs

```bash
# DigitalOcean (3 VMs, CentOS Stream 10, fra1)
./infra-do/manage_vm.sh --tags "k8s-lab" --count 3

# Exoscale (same interface)
./infra-exo/manage_vm.sh --tags "k8s-lab" --count 3
```

### 2 — Prerequisites (on every node)

```bash
git clone https://github.com/k8s-training-demo/kube-my-hard-way
cd kube-my-hard-way/tp101/td-kubernetes-kubeadm/scripts

./partie1-installation/01-prereqs.sh
```

### 3 — Bootstrap the cluster (master only)

```bash
./partie1-installation/02-init-control-plane.sh
./partie1-installation/03-join-workers.sh       # paste the kubeadm join output
./partie1-installation/04-install-flannel.sh
./partie1-installation/05-verify-cluster.sh
```

---

## Repository Layout

```
kube-my-hard-way/
├── infra-do/                          ← DigitalOcean provisioning (doctl)
├── infra-exo/                         ← Exoscale provisioning (exo CLI)
└── tp101/td-kubernetes-kubeadm/
    ├── scripts/
    │   ├── partie1-installation/
    │   ├── partie2-kubelet-static-pods/
    │   ├── partie3-taints-tolerations/
    │   ├── partie4-migration-cni/
    │   ├── partie5-drain-maintenance/
    │   ├── partie6-upgrade/
    │   ├── partie7-runtimeclass/
    │   ├── partie9-cgroups/
    │   ├── partie12-prometheus/
    │   └── partie-bonus-ha/
    ├── configs/
    ├── validation/
    └── docs/
        ├── exercices-etudiants.md
        └── slides-instructeur.md      ← Marp · 340+ slides
```

---

## Resources

- 📄 [Student guide](tp101/td-kubernetes-kubeadm/docs/exercices-etudiants.md)
- 🎓 [Instructor slides](tp101/td-kubernetes-kubeadm/docs/slides-instructeur.md)
- 🐛 [Issues](https://github.com/k8s-training-demo/kube-my-hard-way/issues)

---

<div align="center">
  <sub>Educational material — Advanced Kubernetes course</sub>
</div>

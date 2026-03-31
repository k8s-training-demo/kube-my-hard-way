#!/bin/bash
# Partie 7 - Installation de gVisor (runsc)
# À exécuter sur TOUS les nœuds (master + workers)
# Compatible CentOS Stream 10 / containerd v2

set -e

echo "=== Installation de gVisor (runsc) ==="
echo ""

echo "1. Vérification des prérequis..."
# KVM accélère gVisor (mode kvm) — vérifier sa disponibilité
if [ -e /dev/kvm ]; then
    echo "   ✓ KVM disponible — gVisor utilisera le platform kvm (recommandé)"
    PLATFORM="kvm"
else
    echo "   ⚠️  KVM non disponible — gVisor utilisera le platform ptrace (plus lent)"
    PLATFORM="ptrace"
fi

echo ""
echo "2. Téléchargement des binaires gVisor..."
# POURQUOI deux binaires:
#   runsc                    : le runtime gVisor (équivalent de runc)
#   containerd-shim-runsc-v1 : le shim containerd qui fait l'interface entre
#                              containerd et runsc (containerd v2 l'exige)
curl -fsSL https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/runsc \
    -o /usr/local/bin/runsc
curl -fsSL https://storage.googleapis.com/gvisor/releases/release/latest/x86_64/containerd-shim-runsc-v1 \
    -o /usr/local/bin/containerd-shim-runsc-v1

chmod +x /usr/local/bin/runsc /usr/local/bin/containerd-shim-runsc-v1
echo "   ✓ Binaires installés"

echo ""
echo "3. Vérification des versions..."
echo "   runsc: $(runsc --version | head -1)"

echo ""
echo "4. Configuration de containerd pour gVisor..."
# POURQUOI conf.d: containerd v2 supporte les drop-in files dans /etc/containerd/conf.d/
# Cela évite de modifier le fichier principal config.toml (plus sûr).
# Le plugin CRI v2 est 'io.containerd.cri.v1.runtime' (différent de containerd v1 !).
mkdir -p /etc/containerd/conf.d

cat > /etc/containerd/conf.d/gvisor.toml << EOF
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc]
  runtime_type = 'io.containerd.runsc.v1'
  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runsc.options]
    TypeUrl = 'io.containerd.runsc.v1.options'
    ConfigPath = '/etc/containerd/runsc.toml'
EOF

cat > /etc/containerd/runsc.toml << EOF
[runsc_config]
  platform = '$PLATFORM'
EOF

echo "   ✓ Drop-in /etc/containerd/conf.d/gvisor.toml créé (platform: $PLATFORM)"

echo ""
echo "5. Redémarrage de containerd..."
systemctl restart containerd
sleep 3
systemctl is-active containerd > /dev/null && echo "   ✓ containerd redémarré avec succès"

echo ""
echo "✓ gVisor installé avec succès sur $(hostname)!"
echo ""
echo "PROCHAINE ÉTAPE: Exécutez 02-create-runtimeclass.sh sur le MASTER"

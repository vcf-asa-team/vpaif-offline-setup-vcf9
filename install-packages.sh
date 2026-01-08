#!/bin/bash

# ==============================================================================
# VCF 9 & Private AI - Air Gap Preparation (Direct Artifactory Method)
# ==============================================================================
# REMEDIATION NOTES:
# 1. Removes all Tanzu CLI references.
# 2. Removes requirement for Broadcom Support Portal Token/Login.
# 3. Uses direct 'packages.broadcom.com' Artifactory links (per KB 415112)
#    to fetch VCF CLI and Offline Plugin Bundles.
# 4. Prepares all artifacts locally for air-gapped usage.
# ==============================================================================

set -e

# --- Configuration ---
# VCF 9.0.0 Direct Artifact URLs (Verified via KB 415112 patterns)
VCF_CLI_URL="https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli/linux/amd64/v9.0.0/vcf-cli.tar.gz"
VCF_PLUGIN_BUNDLE_URL="https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli-plugins/v9.0.0/linux/amd64/plugins.tar.gz"

DOWNLOAD_DIR="$HOME/vcf_airgap_prep"
mkdir -p "$DOWNLOAD_DIR"

echo "=== Starting VCF 9 Air-Gap Preparation (Token-Free Method) ==="

# 1. Update System & Install Dependencies
echo "[1/6] Updating package list and installing base dependencies..."
sudo apt update
sudo apt install -y \
    wget curl jq git openssl openssh-server \
    nginx ca-certificates sshpass software-properties-common \
    python3 python3-pip apt-transport-https gnupg lsb-release

# 2. Install Docker Engine
echo "[2/6] Installing Docker Engine..."
if ! command -v docker &> /dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo usermod -aG docker $USER
    echo "Docker installed."
else
    echo "Docker already installed."
fi

# Enable Services
sudo systemctl enable --now docker
sudo systemctl enable --now nginx

# 3. Install Kubernetes Tools (Kubectl & Helm)
echo "[3/6] Installing kubectl and Helm..."
# Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# yq (YAML processor)
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq

# 4. Fetch & Install VCF CLI (Direct Download)
echo "[4/6] Downloading VCF 9 CLI from Artifactory..."
# NOTE: Using direct URL to bypass Portal Auth
wget -c "$VCF_CLI_URL" -O "$DOWNLOAD_DIR/vcf-cli.tar.gz"

echo "Extracting and Installing VCF CLI..."
# Extract to temp location to find the binary
mkdir -p "$DOWNLOAD_DIR/vcf_cli_extracted"
tar -xvf "$DOWNLOAD_DIR/vcf-cli.tar.gz" -C "$DOWNLOAD_DIR/vcf_cli_extracted"

# Locate the 'vcf' binary (path inside tar may vary)
VCF_BIN=$(find "$DOWNLOAD_DIR/vcf_cli_extracted" -type f -name "vcf" | head -n 1)

if [ -z "$VCF_BIN" ]; then
    echo "ERROR: Could not find 'vcf' binary in downloaded archive."
    exit 1
fi

sudo cp "$VCF_BIN" /usr/local/bin/vcf
sudo chmod +x /usr/local/bin/vcf

echo "VCF CLI Installed:"
vcf version

# 5. Fetch & Install Offline Plugins (Direct Download)
echo "[5/6] Downloading VCF Offline Plugin Bundle..."
PLUGIN_BUNDLE="$DOWNLOAD_DIR/plugins.tar.gz"
wget -c "$VCF_PLUGIN_BUNDLE_URL" -O "$PLUGIN_BUNDLE"

echo "Extracting Plugin Bundle for Local Install..."
BUNDLE_EXTRACT_DIR="$DOWNLOAD_DIR/vcf_plugins_extracted"
mkdir -p "$BUNDLE_EXTRACT_DIR"
tar -xvf "$PLUGIN_BUNDLE" -C "$BUNDLE_EXTRACT_DIR"

echo "Installing Plugins from Local Source..."
# This command installs all plugins from the offline bundle without checking online registries
vcf plugin install all --local-source "$BUNDLE_EXTRACT_DIR"

echo "Verifying Plugin Installation..."
vcf plugin list

# 6. Prepare Private AI Artifacts (Helm & Images)
echo "[6/6] Pre-fetching Private AI Helm Charts..."

# NVIDIA GPU Operator (Required for PAIF)
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
helm pull nvidia/gpu-operator --untar --untardir "$DOWNLOAD_DIR/charts"

echo "
==============================================================================
AIR GAP PREPARATION COMPLETE
==============================================================================
The VCF environment is now bootstrapped with:
1. VCF CLI (v9.0.0)
2. All VCF Plugins (Installed from Offline Bundle)
3. Docker, Kubectl, Helm, yq

Artifacts stored in: $DOWNLOAD_DIR
- vcf-cli.tar.gz
- plugins.tar.gz
- Extracted plugin source: $BUNDLE_EXTRACT_DIR
- NVIDIA GPU Operator Charts: $DOWNLOAD_DIR/charts

NOTE: 
For the actual Private AI Foundation OVA/Images (Deep Learning VM),
you must still manually move those files to:
$DOWNLOAD_DIR
(These specific OVAs are EULA-restricted and cannot be wget'd directly).
==============================================================================
"
sudo systemctl daemon-reload

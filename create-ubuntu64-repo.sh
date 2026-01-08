#!/bin/bash
# create ubuntu jammy mirror & VCF CLI repo
set -o pipefail

# Ensure configuration is loaded
if [ -f "./config/env.config" ]; then
    source ./config/env.config
else
    echo "Error: ./config/env.config not found."
    exit 1
fi

# Define VCF CLI Versions (Update these as new versions release)
VCF_CLI_VERSION="v9.0.0"
VCF_CLI_URL="https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli/linux/amd64/${VCF_CLI_VERSION}/vcf-cli.tar.gz"
# Note: Verify the exact bundle filename on the Broadcom portal if the download fails
VCF_PLUGIN_BUNDLE_URL="https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli-plugins/${VCF_CLI_VERSION}/VCF-Consumption-CLI-PluginBundle-Linux_AMD64.tar.gz"

echo "Updating apt and installing apt-mirror..."
apt update
apt install -y apt-mirror

# Backup existing mirror list
if [ -f "/etc/apt/mirror.list" ]; then
    mv /etc/apt/mirror.list /etc/apt/mirror.list-bak
fi

# Create mirror.list file with 64-bit (amd64) restriction
cat > /etc/apt/mirror.list << EOF
############# config ##################
#
set base_path $BASTION_REPO_DIR
set nthreads     20
set _tilde 0
# Force 64-bit architecture
set defaultarch amd64
#
############# end config ##############

deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
#deb http://archive.ubuntu.com/ubuntu jammy-proposed main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
EOF

echo "Starting apt-mirror..."
apt-mirror

# ------------------------------------------------------------------
# Manual Fixes & Ubuntu Icons/CNF
# ------------------------------------------------------------------
echo "Running manual fixes for icons and CNF metadata..."
base_dir="$BASTION_REPO_DIR/mirror/archive.ubuntu.com/ubuntu/dists"

if [ -d "$base_dir" ]; then
    cd $base_dir
    for dist in jammy jammy-updates jammy-security jammy-backports; do
      for comp in main multiverse universe; do
        mkdir -p "$dist/$comp/dep11"
        for size in 48 64 128; do
            wget -q "http://archive.ubuntu.com/ubuntu/dists/$dist/$comp/dep11/icons-${size}x${size}@2.tar.gz" -O "$dist/$comp/dep11/icons-${size}x${size}@2.tar.gz"
        done
      done
    done
else
    echo "Warning: Mirror directory $base_dir not found. Skipping icon download."
fi

cd /var/tmp
# Download commands and binaries (AMD64 ONLY)
for p in "${1:-jammy}"{,-{security,updates,backports}}/{main,restricted,universe,multiverse}; do
  >&2 echo "Processing: ${p}"
  wget -q -c -r -np -R "index.html*" "http://archive.ubuntu.com/ubuntu/dists/${p}/cnf/Commands-amd64.xz"
done

echo "Copying manual Ubuntu downloads to repo..."
cp -av archive.ubuntu.com/ubuntu/ "$BASTION_REPO_DIR/mirror/archive.ubuntu.com/ubuntu"

# ------------------------------------------------------------------
# VCF-CLI & Bundles Download/Install
# ------------------------------------------------------------------
echo "Starting VCF-CLI and Offline Bundle download..."

# Create directory for VCF tools in the repo
VCF_REPO_DIR="$BASTION_REPO_DIR/vcf-cli"
mkdir -p "$VCF_REPO_DIR"
cd "$VCF_REPO_DIR"

# 1. Download VCF CLI Binary
echo "Downloading VCF-CLI binary..."
wget -q -c "$VCF_CLI_URL" -O vcf-cli.tar.gz

# 2. Download VCF CLI Offline Plugin Bundle
echo "Downloading VCF-CLI Plugin Bundle..."
wget -q -c "$VCF_PLUGIN_BUNDLE_URL" -O vcf-plugins-bundle.tar.gz

# 3. Install VCF-CLI on this Bastion Host
echo "Installing VCF-CLI locally on Bastion..."
# Extract and install binary
tar -xf vcf-cli.tar.gz
chmod +x vcf-cli-linux-amd64
mv vcf-cli-linux-amd64 /usr/local/bin/vcf

# 4. Install Plugins from the downloaded Offline Bundle
if command -v vcf &> /dev/null; then
    echo "VCF-CLI installed successfully. Installing plugins from offline bundle..."
    # Create a temp dir to extract the bundle for installation
    mkdir -p /tmp/vcf-bundle
    tar -xf vcf-plugins-bundle.tar.gz -C /tmp/vcf-bundle
    
    # Install all plugins using local source
    vcf plugin install all --local-source /tmp/vcf-bundle
    
    # Cleanup temp bundle extraction
    rm -rf /tmp/vcf-bundle
    echo "VCF-CLI plugins installed."
else
    echo "Error: VCF-CLI binary install failed."
fi

# ------------------------------------------------------------------
# Sync to Remote Server
# ------------------------------------------------------------------
if [[ $SYNC_DIRECTORIES == "True" ]]; then
  echo "Syncing Ubuntu Mirror to remote server..."
  sshpass -p "$HTTP_PASSWORD" rsync -avz "$BASTION_REPO_DIR/mirror/archive.ubuntu.com/ubuntu" "$HTTP_USERNAME@$HTTP_HOST:$REPO_LOCATION/debs"
  
  echo "Syncing VCF-CLI files to remote server..."
  # Assuming you want the VCF tools in a 'tools' or 'vcf' directory on the remote host
  sshpass -p "$HTTP_PASSWORD" rsync -avz "$VCF_REPO_DIR" "$HTTP_USERNAME@$HTTP_HOST:$REPO_LOCATION/tools"
fi

echo "Mirror and VCF setup complete."

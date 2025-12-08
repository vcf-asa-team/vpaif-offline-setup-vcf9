#!/bin/bash

# Update package list
echo "Updating package list..."
sudo apt update

# Install required packages
echo "Installing required packages..."
sudo apt install -y wget curl jq git openssl openssh-server nginx ca-certificates sshpass

# Install Docker Engine
# Add Docker's official GPG key:

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Add the Tanzu repository
curl -fsSL \
  https://storage.googleapis.com/tanzu-cli-installer-packages/keys/TANZU-PACKAGING-GPG-RSA-KEY.gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/tanzu-archive-keyring.gpg
echo \
  "deb [signed-by=/etc/apt/keyrings/tanzu-archive-keyring.gpg] \
  https://storage.googleapis.com/tanzu-cli-installer-packages/apt \
  tanzu-cli-jessie main" | sudo tee /etc/apt/sources.list.d/tanzu.list
sudo apt-get update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Tanzu CLI
sudo apt install -y tanzu-cli

# Install yq
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && \
    sudo chmod +x /usr/bin/yq

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Start and enable docker service
echo "Starting and enabling docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Start and enable nginx service
echo "Starting and enabling nginx service..."
sudo systemctl start nginx
sudo systemctl enable nginx

# Reload the system to apply changes
echo "Reloading the system to apply changes..."
sudo systemctl daemon-reload

# Print a success message
echo "Installation completed successfully!"
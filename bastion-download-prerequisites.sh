#!/bin/bash
set -o pipefail
source ./config/env.config

# --- Dependency Checks ---

if ! command -v curl >/dev/null 2>&1 ; then
    echo "curl missing. Please install curl."
    exit 1
fi

if ! command -v wget >/dev/null 2>&1 ; then
    echo "wget missing. Please install wget."
    exit 1
fi

if ! command -v vcf >/dev/null 2>&1 ; then
  echo "VCF CLI missing. Please install VCF CLI."
  exit 1
else
    if ! vcf imgpkg --help > /dev/null 2>&1 ; then 
        vcf plugin install imgpkg
    fi
fi

#if ! command -v imgpkg >/dev/null 2>&1 ; then
#  echo "imgpkg missing. Please install imgpkg CLI first."
#  exit 1
#fi

if ! command -v yq >/dev/null 2>&1 ; then
    echo "yq missing. Please install yq CLI version 4.x from https://github.com/mikefarah/yq/releases"
    exit 1
else
    if ! yq -P > /dev/null 2>&1 ; then 
        echo "yq version 4.x required. Please install yq version 4.x from https://github.com/mikefarah/yq/releases."
        exit 1
    fi
fi

# Create the download directories if they don't exist
mkdir -p "$DOWNLOAD_DIR_YML"
mkdir -p "$DOWNLOAD_DIR_TAR"
mkdir -p "$DOWNLOAD_DIR_BIN"

# Downloading VCF CLI, Tanzu vmware-vsphere plugin bundle and Tanzu Standard Packages
echo "Downloading VCF CLI, VCF Packages and VCF CLI plugins..."
wget -q -O "$DOWNLOAD_DIR_BIN"/vcf-cli.tar.gz https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli/linux/amd64/v9.0.1/vcf-cli.tar.gz
wget -q -O "$DOWNLOAD_DIR_BIN"/vcf-cli-plugins.tar.gz https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli-plugins/v9.0.0/linux/amd64/plugins.tar.gz
# vcf plugin download-bundle --group vmware-vsphere/default:v8.0.3 --to-tar "$DOWNLOAD_DIR_BIN"/vmware-vsphere-plugin.tar.gz
# tar -xzvf "$DOWNLOAD_DIR_BIN"/tanzu-cli-linux-amd64.tar.gz -C $DOWNLOAD_DIR_BIN
# sudo mv $DOWNLOAD_DIR_BIN/v1.1.0/tanzu* /usr/local/bin/tanzu
# vcf plugin install --group vmware-vsphere/default
vcf plugin install imgpkg
# vcf imgpkg copy -b projects.registry.vmware.com/tkg/packages/standard/repo:"$TANZU_STANDARD_REPO_VERSION" --to-tar "$DOWNLOAD_DIR_BIN"/tanzu-packages.tar
# upload tanzu plugins to bootstrap harbor
# tanzu config cert add --host $BOOTSTRAP_REGISTRY --insecure true --skip-cert-verify true
# tanzu plugin upload-bundle --tar tanzu-plugin.tar.gz --to-repo $BOOTSTRAP_REGISTRY/charts/plugin


# Download the package.yaml files for all the Supervisor Services. Modify as needed.
echo "Downloading all Supervisor Services configuration files..."

# TKG Service
wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-tkg-service.yaml          'https://packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/kubernetes-service/3.3.0-package.yaml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-cci-supervisor-service-package.yaml             'https://vmwaresaas.jfrog.io/artifactory/supervisor-services/cci-supervisor-service/v1.0.2/cci-supervisor-service.yml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-cci-values.yaml      'https://vmwaresaas.jfrog.io/artifactory/supervisor-services/cci-supervisor-service/v1.0.2/values.yml'
wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-harbor.yaml          'https://packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/harbor/harbor-service-2.12.4.yml'
wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-harbor-values.yaml   'https://packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/harbor/harbor-data-values-v2.12.4.yml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-contour.yaml         'https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=supervisor-services&path=contour/v1.28.2/contour.yml'
wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-externaldns.yaml     'https://packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/external-dns/external-dns-service-0.14.2.yml'
wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-externaldns-values.yaml     'https://packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/external-dns/external-dns-data-values_0.14.2.yaml'
wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-nsxmgmt.yaml         'https://packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/nsx-management-proxy/v0.2.2/nsx-management-proxy.yml'
wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-nsxmgmt-values.yaml         'https://packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/nsx-management-proxy/v0.2.2/nsx-management-proxy-data-values.yml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-argocd-operator.yaml 'https://raw.githubusercontent.com/vsphere-tmm/Supervisor-Services/refs/heads/main/supervisor-services-labs/argocd-operator/v0.12.0/argocd-operator.yaml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc_config_from_automation.py      'https://vmwaresaas.jfrog.io/artifactory/supervisor-services/cci-supervisor-service/v1.0.2/service_config_from_automation.py'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-dsm-operator.yaml    'https://packages.broadcom.com/artifactory/dsm-distro/dsm-consumption-operator/supervisor-service/2.2.1/package.yaml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-dsm-values.yaml    'https://packages.broadcom.com/artifactory/dsm-distro/dsm-consumption-operator/supervisor-service/2.2.1/values.yaml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-minio.yaml           'https://projects.packages.broadcom.com/artifactory/vsphere-distro/vsphere/iaas/minio/minio-service-definition-v2.0.10-3.yaml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-cloudian.yaml        'https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=vDPP-Partner-YAML&path=Cloudian%252FHyperstore%252FSupervisorService%252F1.3.1%252Fhyperstore-supervisorservice-1.3.1.yaml'
# wget -q -O "$DOWNLOAD_DIR_YML"/supsvc-velero-operator.yaml 'https://vmwaresaas.jfrog.io/ui/api/v1/download?repoKey=Velero-YAML&path=Velero%252FSupervisorService%252F1.6.1%252Fvelero-vsphere-1.6.1-def.yaml'

echo
echo "Downloading Supervisor Services images using imgpkg..."
echo

for file in "$DOWNLOAD_DIR_YML"/*.y*ml; do
    full_filename=$(basename "$file")
    file_name="${full_filename%.y*ml}"   
    image=$(yq -P '(.|select(.kind == "Package").spec.template.spec.fetch[].imgpkgBundle.image)' "$file")

    if [ "$image" ]
    then
        echo Now downloading "$image"...
        vcf imgpkg copy -b "$image" --to-tar "$DOWNLOAD_DIR_TAR"/"$file_name".tar --cosign-signatures

        # Get the name of the image from the package.spec.template.spec.fetch[].imgpkgBundle.image 
        # and replace the URL with the new harbor location
        if [ "$file_name" == "harbor-service-v*" ] || [ "$file_name" == "supsvc-harbor" ]
        then
            newurl="$BOOTSTRAP_REGISTRY"/"${BOOTSTRAP_SUPSVC_REPO}"/"${image##*/}"
        else
            newurl="$PLATFORM_REGISTRY"/"${PLATFORM_SUPSVC_REPO}"/"${image##*/}"
        fi
        
        echo "Updating Supervisor Service config file image to $newurl..."
        a=$newurl yq -P '(.|select(.kind == "Package").spec.template.spec.fetch[].imgpkgBundle.image = env(a))' -i "$file"
    fi
done

# --- Sync to Admin Host ---

if [[ $SYNC_DIRECTORIES == "True" ]]; then
    sshpass -p "$HTTP_PASSWORD" rsync -avz {supervisor-services*,vcf-common*} $HTTP_USERNAME@$HTTP_HOST:$ADMIN_RESOURCES_DIR

    # Copy yq and imgpkg binaries to admin host
    sshpass -p "$HTTP_PASSWORD" rsync -avz /usr/bin/yq "$HTTP_USERNAME"@"$HTTP_HOST":"$ADMIN_RESOURCES_DIR"
    sshpass -p "$HTTP_PASSWORD" rsync -avz /usr/local/bin/imgpkg "$HTTP_USERNAME"@"$HTTP_HOST":"$ADMIN_RESOURCES_DIR"
fi

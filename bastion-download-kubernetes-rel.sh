#!/bin/bash
set -o pipefail
source ./config/env.config

if ! command -v jq >/dev/null 2>&1 ; then
  echo "JQ not installed. Exiting...."
  exit 1
fi
if ! command -v wget >/dev/null 2>&1 ; then
  echo "wget not installed. Exiting...."
  exit 1
fi

# Create the download directory if it doesn't exist
mkdir -p "$DOWNLOAD_VKR_OVA"
mkdir -p "$DOWNLOAD_DLVM_OVA"

echo
echo "The VMware subscribed content library has the following Kubernetes Release images ... "
echo
curl -s https://wp-content.vmware.com/v2/latest/items.json |jq -r '.items[]| .created + "\t" + .name'|sort

echo
echo "The list shown above is sorted by release date with the corrosponding names of the"
echo "Kubernetes Release in the second column."
read -p "Enter the name of the Kubernetes Release OVA that you want to download and zip for offline upload: " tkgrimage

echo
echo "Downloading all files for the TKG image: ${tkgrimage} ..."
echo
wget -q --show-progress --no-parent -r -nH --cut-dirs=2 --reject="index.html*" https://wp-content.vmware.com/v2/latest/"${tkgrimage}"/

echo "Compressing downloaded files..."
tar -cvzf "${tkgrimage}".tar.gz "${tkgrimage}"


echo
echo "Cleaning up..."
[ -d "${tkgrimage}" ] && rm -rf "${tkgrimage}"
mv "${tkgrimage}".tar.gz "${DOWNLOAD_VKR_OVA}" 

echo "Downloading DLVM"
wget -q --show-progress --no-parent -r -nH --cut-dirs=2 --reject="index.html*" https://packages.vmware.com/dl-vm/common-container-nv-vgpu-ubuntu-2204-v20240814/

echo "Compressing downloaded files..."
tar -cvzf common-container-nv-vgpu-ubuntu-2204-v20240814.tar.gz common-container-nv-vgpu-ubuntu-2204-v20240814*

echo
echo "Cleaning up..."
mv common-container-nv-vgpu-ubuntu-2204-v20240814.tar.gz "${DOWNLOAD_DLVM_OVA}"
# [ -d common-container-nv-vgpu-ubuntu-2204-v20240814 ] && 
rm -rf common-container-nv-vgpu-ubuntu-2204-v20240814*

# copy tar/yaml to admin host
if [[ $SYNC_DIRECTORIES == "True" ]]; then
  sshpass -p "$HTTP_PASSWORD" rsync -avz {kubernetes-releases-ova,dlvm-releases-ova} $HTTP_USERNAME@$HTTP_HOST:$ADMIN_RESOURCES_DIR
fi

# echo "Copy the file ${tkgrimage}.tar.gz to the offline admin machine that has access to the vSphere environment."
# echo "You can untar the file and upload the OVA files to a Content Library called Local..."
# echo "Optionally, you can install and configure govc on the offline admin machine."
# echo "Use the following command on the admin machine to import the image to the vCenter Content Library called "Local"..."
# echo
# echo "     tar -xzvf ${tkgrimage}.tar.gz"
# echo "     cd ${tkgrimage}"
# echo "     govc library.import -n ${tkgrimage} -m=true Local photon-ova.ovf"
# echo "     or"
# echo "     govc library.import -n ${tkgrimage} -m=true Local ubuntu-ova.ovf"
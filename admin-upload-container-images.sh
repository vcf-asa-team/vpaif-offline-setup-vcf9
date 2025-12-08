#!/bin/bash
set -o pipefail
source ./config/env.config

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <bootstrap|platform>"
	exit 1
fi

if ! command -v curl >/dev/null 2>&1 ; then
	echo "curl missing. Please install curl."
	exit 1
fi

if ! command -v wget >/dev/null 2>&1 ; then
	echo "wget missing. Please install curl."
	exit 1
fi

if ! command -v tanzu >/dev/null 2>&1 ; then
	echo "Tanzu CLI missing. Please install Tanzu CLI."
  	tar -xzvf "$DOWNLOAD_DIR_BIN"/tanzu-cli-linux-amd64.tar.gz -C $DOWNLOAD_DIR_BIN
	sudo mv $DOWNLOAD_DIR_BIN/v1.1.0/tanzu* /usr/local/bin/tanzu
else
    if ! tanzu imgpkg --help > /dev/null 2>&1 ; then 
		mkdir -p ~/.local/share/tanzu-cli/
		tar -xzvf "$DOWNLOAD_DIR_BIN"/tanzu-cli-plugins.tar.gz -C  ~/.local/share/tanzu-cli/
		tanzu plugin source update default --uri $BOOTSTRAP_REGISTRY/tanzu-plugins/plugin-inventory:latest
		tanzu plugin install --group vmware-vsphere/default
		tanzu config cert add --host $BOOTSTRAP_REGISTRY --insecure true --skip-cert-verify true
#    	echo tanzu imgpkg plugin not installed. Please install the vmware-vsphere-plugin on this system
#       exit 1
    fi
fi

if ! command -v kubectl >/dev/null 2>&1 ; then
	echo "Kubectl CLI missing. Please install Kubectl CLI."
  	exit 1
else
    if ! kubectl vsphere --help > /dev/null 2>&1 ; then 
		wget --no-check-certificate https://"${K8S_SUPERVISOR_IP}"/wcp/plugin/linux-amd64/vsphere-plugin.zip -O /tmp/vsphere-plugin.zip
		if [ $? -ne 0 ]; then
			echo "Error: Could not download the vsphere-plugin.zip. Please validate if the Supervisor is running and the IP is valid!!"
			exit 1
		fi
		unzip /tmp/vsphere-plugin.zip -d /tmp/vsphere-plugin
		sudo install /tmp/vsphere-plugin/bin/kubectl-vsphere /usr/local/bin/kubectl-vsphere
    fi
fi

if ! command -v yq >/dev/null 2>&1 ; then
	echo "yq missing. Please install yq CLI first."
	exit 1
fi

# The main code
if [ "$1" == "bootstrap" ]; then
	echo "Bootstrap Supervisor Services"
	REGISTRY_NAME=${BOOTSTRAP_REGISTRY}
	REGISTRY_IP=${BOOTSTRAP_REGISTRY_IP}
	REGISTRY_URL=${BOOTSTRAP_REGISTRY}/${BOOTSTRAP_SUPSVC_REPO}
	REGISTRY_URL1=${BOOTSTRAP_REGISTRY}/${BOOTSTRAP_TNZPKG_REPO}
	REGISTRY_USERNAME=${BOOTSTRAP_REGISTRY_USERNAME}
	REGISTRY_PASSWORD=${BOOTSTRAP_REGISTRY_PASSWORD}
elif [ "$1" == "platform" ]; then
	echo "Platform Supervisor Services"
	REGISTRY_NAME=${PLATFORM_REGISTRY}
	REGISTRY_IP=${PLATFORM_REGISTRY_IP}
	REGISTRY_URL=${PLATFORM_REGISTRY}/${PLATFROM_SUPSVC_REPO}
	REGISTRY_URL1=${PLATFORM_REGISTRY}/${PLATFROM_TNZSVC_REPO}
	REGISTRY_USERNAME=${PLATFORM_REGISTRY_USERNAME}
	REGISTRY_PASSWORD=${PLATFORM_REGISTRY_PASSWORD}
	# tanzu imgpkg copy --tar "$DOWNLOAD_DIR_BIN"/tanzu-packages.tar --to-repo "${REGISTRY_URL1}" --cosign-signatures --registry-username "${REGISTRY_USERNAME}" --registry-password "${REGISTRY_PASSWORD}"
fi

IPs=$(getent hosts "${REGISTRY_NAME}" | awk '{ print $1 }')
if [[ -z "${IPs}" ]]; then
	echo "Error: Could not resolve the IP address for ${REGISTRY_NAME}. Please validate!!"
	exit 1
fi

found=false
for ip in "${IPs[@]}"; do
  	if [[ "$ip" == "${REGISTRY_IP}" ]]; then
		found=true
		break
  	fi
done

if [ "$found" = false ]; then
  	echo "Error: Could not resolve the IP address ${REGISTRY_IP} for ${REGISTRY_NAME}. Please validate!!"
  	exit 1
fi

# get certificate from harbor
openssl s_client -showcerts -servername $REGISTRY_NAME -connect $REGISTRY_NAME:443 </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > ./certificates/$REGISTRY_NAME.crt

HEADER_CONTENTTYPE="Content-Type: application/json"
################################################
# Login to VCenter and get Session ID
###############################################
SESSION_ID=$(curl -sk -X POST https://${VCENTER_HOSTNAME}/rest/com/vmware/cis/session --user ${VCENTER_USERNAME}:${VCENTER_PASSWORD} |jq -r '.value')
if [ -z "${SESSION_ID}" ]
then
	echo "Error: Could not connect to the VCenter. Please validate!!"
	exit 1
fi
echo Authenticated successfully to VC with Session ID - "${SESSION_ID}" ...
HEADER_SESSIONID="vmware-api-session-id: ${SESSION_ID}"

################################################
# Get Supervisor details from vCenter
###############################################
echo "Searching for Supervisor on Cluster ${K8S_SUP_CLUSTER} ..."
response=$(curl -ks --write-out "%{http_code}" --output /tmp/temp_cluster.json -X GET -H "${HEADER_SESSIONID}" https://"${VCENTER_HOSTNAME}"/api/vcenter/namespace-management/supervisors/summaries?config_status=RUNNING&kubernetes_status=READY)
if [[ "${response}" -ne 200 ]] ; then
  	echo "Error: Could not fetch clusters. Please validate!!"
	exit 1
fi

SUPERVISOR_ID=$(jq -r --arg K8S_SUP_CLUSTER "$K8S_SUP_CLUSTER" '.items[] | select(.info.name == $K8S_SUP_CLUSTER) | .supervisor' /tmp/temp_cluster.json)
if [ -z "${SUPERVISOR_ID}" ]
then
	echo "Error: Could not find the Supervisor Cluster ${K8S_SUP_CLUSTER}. Please validate!!"
	exit 1
fi

################################################
# Add the registry to the vCenter
###############################################
echo "Found Supervisor Cluster ${K8S_SUP_CLUSTER} with Supervisor ID - ${SUPERVISOR_ID} ..."
export REGISTRY_CACERT=$(jq -sR . "${REGISTRY_CERT_FOLDER}"/"${REGISTRY_NAME}".crt)
export REGISTRY_NAME
export REGISTRY_PASSWORD
export REGISTRY_USERNAME

envsubst < ./config/registry-spec.json > temp_registry.json
echo "Adding Registry ${REGISTRY_NAME} to ${VCENTER_HOSTNAME} ..."
response=$(curl -ks --write-out "%{http_code}" --output /tmp/status.json  -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "@temp_registry.json" https://"${VCENTER_HOSTNAME}"/api/vcenter/namespace-management/supervisors/"${SUPERVISOR_ID}"/container-image-registries)
echo $response
# if [[ "${response}" -ne 200 ]] ; then
# 	echo "Error: Could not add registry to Supervisor. This may happen if the registry has been previously added. Please validate!!"
# fi
echo $DOWNLOAD_DIR_YML

for file in "${DOWNLOAD_DIR_YML}"/supsvc-*.yaml; do
	echo $file
	full_filename=$(basename "$file")
	file_name="${full_filename%.yaml}"
	stripped=$(echo -n "$file_name" | sed 's/supsvc-//g') # strip the supsvc- from filename
    image=$(yq -P '(.|select(.kind == "Package").spec.template.spec.fetch[].imgpkgBundle.image)' "$file")
	
    if [ "$image" ];then
		if [[ "$image" == *"${REGISTRY_URL}"* ]]; then
			echo Now uploading "${DOWNLOAD_DIR_TAR}"/"$file_name".tar ...
			tanzu imgpkg copy --tar "${DOWNLOAD_DIR_TAR}"/"$file_name".tar --to-repo "${REGISTRY_URL}"/"$stripped" --cosign-signatures --registry-ca-cert-path ./certificates/$REGISTRY_NAME.crt --registry-username "${REGISTRY_USERNAME}" --registry-password "${REGISTRY_PASSWORD}"

			echo "Processing file - ${file} ..."
			export FILE_CONTENT=$(base64 "${file}" -w0)
			#	echo "$FILE_CONTENT"

			envsubst < ./config/carvel-spec.json > temp_final.json
			echo "Adding Supervisor Service to ${VCENTER_HOSTNAME}  ..."
			curl -ks -X POST -H "${HEADER_SESSIONID}" -H "${HEADER_CONTENTTYPE}" -d "@temp_final.json" https://"${VCENTER_HOSTNAME}"/api/vcenter/namespace-management/supervisor-services
		fi
	fi
done

################################################
# setup nginx
################################################
cat > /etc/nginx/conf.d/mirror.conf << EOF
server {
 listen 80;
 server_name $HTTP_HOST;
 root /data/debs/;

 location / {
   autoindex on;
 }
}
EOF
sudo systemctl restart nginx

################################################
# copy the kubernetes deployment files to the 
# nginx location to be downloaded during deployments.
################################################
cp gpu-operator/gpu-operator* $REPO_LOCATION/debs/

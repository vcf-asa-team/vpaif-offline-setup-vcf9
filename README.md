# VKS Offline setup automation

This directory contains multiple scripts that provide assistance to automate the various stages of the VKS setup in an airgapped setup. The names of the script should signify the stage at which each script should be run. There is a `config` folder that contains the necessary files for users to provide enviornmental configurations.  

## Requirements

Bastion Ubuntu Server with Harbor installed - [Deploy an Offline Harbor Registry on vSphere](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid/2-5/tkg/mgmt-reqs-harbor.html)
Ubuntu Repo/HTTP Server with minimum 800gb storage


## Installation
Update the env.config file located in the config directory with information about your platform and bootstrap Harbor instance, vCenter and Ubuntu Repo location.

Run both `bastion-download-prequisites.sh` and `bastion-download-kubernetes.sh` scripts to stage neccessary containers and services files in the bootstrap Harbor registry.

### Ubuntu Repo
Run the `create-ubuntu-repo.sh` on the Ubuntu Repo server.
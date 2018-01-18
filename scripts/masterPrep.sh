#!/bin/bash
echo $(date) " - Starting Master Prep Script"

STORAGEACCOUNT=$1
SUDOUSER=$2
LOCATION=$3

if [ -f /run/ostree-booted ]; then
    echo $(date) " - Atomic Host!!! No need for YUM package installs..."

    # Docker comes pre-configured on RHEL Atomic, need to remove existing config
    systemctl stop docker
    rm -rf /var/lib/docker
    sed -i -e "s#^OPTIONS='--selinux-enabled --log-driver=journald --signature-verification=false'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker

    # Install OpenShift utilities
    echo $(date) " - Installing OpenShift utilities"
    yum -y install centos-release-openshift-origin37.noarch
    yum -y install atomic-openshift-utils

else
    # Install base packages and update system to latest packages
    echo $(date) " - Non Atomic Host system"
    echo $(date) " - Install base packages and update system to latest packages"

    yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools kexec-tools sos psacct
    yum -y install cloud-utils-growpart.noarch
    yum -y update --exclude=WALinuxAgent
    #yum -y install centos-release-openshift-origin37.noarch
    #yum -y install origin-excluder origin-docker-excluder

    #origin-excluder unexclude

    # Only install Ansible and pyOpenSSL on Master-0 Node
    # python-passlib needed for metrics

    if hostname -f|grep -- "-0" >/dev/null
    then
       echo $(date) " - Installing Ansible, pyOpenSSL and python-passlib"
       yum -y --enablerepo=epel install ansible pyOpenSSL python-passlib
    fi

    # Install java to support metrics
    echo $(date) " - Installing Java"

    yum -y install java-1.8.0-openjdk-headless

    # Grow Root File System
    echo $(date) " - Grow Root FS"

    rootdev=`findmnt --target / -o SOURCE -n`
    rootdrivename=`lsblk -no pkname $rootdev`
    rootdrive="/dev/"$rootdrivename
    majorminor=`lsblk  $rootdev -o MAJ:MIN | tail -1`
    part_number=${majorminor#*:}

    growpart $rootdrive $part_number -u on
    xfs_growfs $rootdev

    # Install OpenShift utilities
    #echo $(date) " - Installing OpenShift utilities"

    #yum -y install atomic-openshift-utils

    # Install Docker 1.12.x
    echo $(date) " - Installing Docker 1.12.x"

    yum -y install docker
    sed -i -e "s#^OPTIONS='--selinux-enabled'#OPTIONS='--selinux-enabled --insecure-registry 172.30.0.0/16'#" /etc/sysconfig/docker
fi

# Create thin pool logical volume for Docker
echo $(date) " - Creating thin pool logical volume for Docker and starting service"

DOCKERVG=$( parted -m /dev/sda print all 2>/dev/null | grep unknown | grep /dev/sd | cut -d':' -f1 )

echo "DEVS=${DOCKERVG}" >> /etc/sysconfig/docker-storage-setup
echo "VG=docker-vg" >> /etc/sysconfig/docker-storage-setup

docker-storage-setup
if [ $? -eq 0 ]
then
   echo "Docker thin pool logical volume created successfully"
else
   echo "Error creating logical volume for Docker"
   exit 5
fi

# Enable and start Docker services

systemctl enable docker
systemctl start docker

# Create Storage Class yml files on MASTER-0

if hostname -f|grep -- "-0" >/dev/null
then
cat <<EOF > /home/${SUDOUSER}/scunmanaged.yml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: generic
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  location: ${LOCATION}
  storageAccount: ${STORAGEACCOUNT}
EOF

cat <<EOF > /home/${SUDOUSER}/scmanaged.yml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: generic
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  kind: managed
  location: ${LOCATION}
  storageaccounttype: Premium_LRS
EOF

fi

echo $(date) " - Script Complete"

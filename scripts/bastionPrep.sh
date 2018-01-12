#!/bin/bash
echo $(date) " - Starting Bastion Prep Script"

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools kexec-tools sos psacct
yum -y update --exclude=WALinuxAgent
yum -y install centos-release-openshift-origin37.noarch

# Install OpenShift utilities
echo $(date) " - Installing OpenShift utilities"

yum -y install atomic-openshift-utils

# Create playbook to update ansible.cfg file to include path to library

cat > updateansiblecfg.yaml <<EOF
#!/usr/bin/ansible-playbook

- hosts: localhost
  gather_facts: no
  tasks:
  - lineinfile:
      dest: /etc/ansible/ansible.cfg
      regexp: '^library '
      insertafter: '#library        = /usr/share/my_modules/'
      line: 'library = /usr/share/ansible/openshift-ansible/library/'
EOF

# Run Ansible Playbook to update ansible.cfg file

echo $(date) " - Updating ansible.cfg file"

ansible-playbook ./updateansiblecfg.yaml

echo $(date) " - Script Complete"


#!/bin/bash
echo $(date) " - Starting Script"

vm_os=$(cat /etc/os-release)
echo $vm_os
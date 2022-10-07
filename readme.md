# Enterprise Automation POC - Check Point

This repository contains a collection of scripts to demonstrate how to create a complete Check Point Enterprise environment using Terraform and Ansible.
The scripts have been written to run against a VMware ESXi / vCenter environment. You can either configure your environment to match what was used here or change the appropriate variables and values in the scripts.
Terraform has been configured to use remote state. If you wish to use this you will need to initialise it in your environment according to the instructions provided by your state host.
The Ansible gateway scripts (2.x, 3.9 and 3.8, 3.9 and 3.10) should be used against a 'hosts' file. There is a sample in the ansible/ folder here which relates to the network diagram. 
The general flow should be to run the Terraform scripts first to create the management infrastructure, then the gateways. The Ansible playbooks can all then be run in order according to the numbering in the file names.

This will create:
- 2x MDS (R81.20)
- 2x DMS (R81.20)
- 1x DLS (R81.20)
- 3x Gateways (R81.10)

For reference, the complete environment looks like this (complementary products are not part of the automation scripts).

![alt text](https://github.com/chkp-stuartgreen/enterprise-automation-poc/raw/main/enterprise%20automation%20poc.drawio.png "Logical diagram")

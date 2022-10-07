terraform {
  backend "http" {}
}

provider "vsphere" {
  user = var.vsphere_user
  password = var.vsphere_password
  vsphere_server = var.vsphere_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_dc
}

data "vsphere_datastore" "datastore" {
  name = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_host" "host" {
  name = var.vsphere_host
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "mgmt-net" {
  name = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_ovf_vm_template" "ovfMgmt" {
  name              = "CPMgmtTemplate"
  disk_provisioning = "thin"
  resource_pool_id  = data.vsphere_host.host.resource_pool_id
  datastore_id      = data.vsphere_datastore.datastore.id
  host_system_id    = data.vsphere_host.host.id
  remote_ovf_url    = "http://192.168.100.53/R81.20-mgmt-ivory_main-take-569-991001290-CloudGuard-Network.ovf"
  ovf_network_map = {
    "Network 1" : data.vsphere_network.mgmt-net.id
  }
}

resource "vsphere_virtual_machine" "poc-mds-a" {
  name                 = "poc-mds-a"
  datacenter_id        = data.vsphere_datacenter.datacenter.id
  datastore_id         = data.vsphere_datastore.datastore.id
  host_system_id       = data.vsphere_host.host.id
  resource_pool_id     = data.vsphere_host.host.resource_pool_id
  folder               = var.vsphere_server_folder

  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0
  
  num_cpus             = data.vsphere_ovf_vm_template.ovfMgmt.num_cpus
  num_cores_per_socket = data.vsphere_ovf_vm_template.ovfMgmt.num_cores_per_socket
  memory               = data.vsphere_ovf_vm_template.ovfMgmt.memory
  guest_id             = data.vsphere_ovf_vm_template.ovfMgmt.guest_id
  scsi_type            = data.vsphere_ovf_vm_template.ovfMgmt.scsi_type
  
  dynamic "network_interface" {
    for_each = data.vsphere_ovf_vm_template.ovfMgmt.ovf_network_map
    content {
      network_id = network_interface.value
    }
  }
  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = data.vsphere_ovf_vm_template.ovfMgmt.remote_ovf_url
    disk_provisioning         = data.vsphere_ovf_vm_template.ovfMgmt.disk_provisioning
    ovf_network_map           = data.vsphere_ovf_vm_template.ovfMgmt.ovf_network_map
    ip_protocol               = "IPV4"
    ip_allocation_policy      = "STATIC_MANUAL"
    enable_hidden_properties = true
  }
  vapp {
    properties = {
      
      "hostname" = "poc-mds-a",
      "mgmt_admin_passwd" = "${var.chkp_otp_key}",
# Everything below is optional.
      "CheckPoint.adminHash" = "${var.chkp_otp_key}",
      "eth0.ipaddress" = "192.168.100.110",
      "eth0.subnetmask" = "24",
      "eth0.gatewayaddress" = "192.168.100.1",
#      "primary" = "172.23.39.5",
      "user_data" = "${base64encode(<<EOF
echo "cloud-init start" `date`
clish -s -c "set ntp server primary 192.168.100.101 version 3"
clish -s -c "delete ntp server ntp2.checkpoint.com"
clish -s -c "set ntp active on"
clish -s -c "set timezone Etc / GMT+3"
clish -s -c "set user admin shell /bin/bash"
clish -s -c "set dns mode default"
clish -s -c "set dns suffix local"
clish -s -c "set timezone Etc / GMT+3"
echo "Add user ansibleuser"
clish -s -c "add user ansibleuser uid 0 homedir /home/ansibleuser"
clish -s -c "set user ansibleuser password-hash '\$6\$rounds=10000\$zgxp7pre\$6qRpAlDWERrmPRbQWKNhztq1TBGVwTOjK.aO/w2umokjiI92z0MN5vJvlFxPSJbwMsa.RQ51xyBAht3YE7VeW/'"
clish -s -c "add rba user ansibleuser roles adminRole"
clish -s -c "set user ansibleuser shell /bin/bash"
echo "Give ansibleuser gaia API access"
gaia_api access -u ansibleuser -e true
echo "Update SSH configuration"
sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
service sshd restart
echo "Run first time configuration"
config_system --config-string 'mgmt_admin_radio=gaia_admin&mgmt_gui_clients_radio=any&install_mds_primary=true&install_mds_interface=eth0&download_info=true&reboot_if_required=true&maintenance_hash=grub.pbkdf2.sha512.10000.EED96942B7C4CD093DB77FD1C71CFB2DF901F2B8719FFAC15C2C1C8ACF5D8420A8059978CE3DFD5EE057071E1A30E5E34A1D380FA5D212E58E7C50AAFE26F0E0.F0824ED6973BB399CA79F2E743F41137E89DFC73D78B8B0F8D89F6D8F2D78B0AA75AF3939DD554403D32D08047293E263F11541B0816032754A9DB9784253509'
sleep 5
while true; do
    status=`api status |grep 'API readiness test SUCCESSFUL. The server is up and ready to receive connections' |wc -l`
    echo "Checking if the API is ready"
    if [[ ! $status == 0 ]]; then
         break
    fi
       sleep 15
    done
echo "API ready " `date`
sleep 5
echo "Set R80 API to accept all ip addresses"
mgmt_cli -r true set api-settings accepted-api-calls-from "All IP addresses" --domain 'System Data'
echo "Configure ansibleuser as Multi-Domain Super User"
mgmt_cli -r true add administrator name ansibleuser authentication-method "os password" multi-domain-profile "Multi-Domain Super User" color red comments "Automation Admin"
echo "Reloading API Server"
api reconf
### Upload and copy API hotfix files
echo "Upload and copy API hotfix files"
curl_cli -o  r81.20-api-fix.tgz http://192.168.100.53/r81.20-api-fix.tgz
source /etc/profile; mdsstop
tar -xvzf r81.20-api-fix.tgz --directory /opt/CPsuite-R81.20/fw1/cpm-server/
source /etc/profile; mdsstart
### Import and install hotfix or jumbo hotfix
echo "Importing hotfix package" `date`
clish -c 'installer import ftp 192.168.100.53 path Check_Point_CDT_Bundle_T26_FULL.tar username ftpuser password Cpwins2022'
echo " Waiting for automatic update to finish" `date`
sleep 180
echo "Installing hotfix package" `date`
clish -c 'installer install Check_Point_CDT_Bundle_T26_FULL.tar not-interactive'
sleep 5
while true; do
    show_installer=$(clish -c 'show installer package Check_Point_CDT_Bundle_T26_FULL.tgz status')
    status=$(echo "$show_installer" |grep 'Status:')
    status_wc=$(echo "$show_installer" |grep 'Status: Installed' |wc -l)
    echo "Hotfix package installation $status"
    if [[ ! $status_wc == 0 ]]; then
         break
    fi
       sleep 15
    done
echo "Hotfix package installation $status" `date`
sleep 5
clish -c 'show installer package Check_Point_CDT_Bundle_T26_FULL.tgz'
clish -s -c 'set dns primary 172.23.39.5'
echo "cloud-init end" `date`
      EOF
      )}"


#### parameters for R81.10 images
#      "admin_hash"     = "${var.chkp_otp_key}",
#      "password_type" = "Plain",
#      "ipaddr_v4" = "192.168.100.110",
#      "run_ftw" = "No",
#      "user_data" = "Y2xpc2ggLXMgLWMgInNldCB0aW1lem9uZSBFdXJvcGUgLyBTdG9ja2hvbG0iCmNsaXNoIC1zIC1jICJzZXQgdXNlciBhZG1pbiBzaGVsbCAvYmluL2Jhc2giCmNsaXNoIC1zIC1jICJzZXQgaG9zdG5hbWUgbHNlZy1tZHMtYSIKY2xpc2ggLXMgLWMgInNldCBpbnRlcmZhY2UgZXRoMCBpcHY0LWFkZHJlc3MgMTkyLjE2OC4xMDAuMTEwIG1hc2stbGVuZ3RoIDI0IgpjbGlzaCAtcyAtYyAic2V0IHN0YXRpYy1yb3V0ZSBkZWZhdWx0IG5leHRob3AgZ2F0ZXdheSBhZGRyZXNzIDE5Mi4xNjguMTAwLjEgb24iCmNsaXNoIC1zIC1jICJzZXQgbnRwIGFjdGl2ZSBvbiIKY2xpc2ggLXMgLWMgInNldCBudHAgc2VydmVyIHByaW1hcnkgc2UucG9vbC5udHAub3JnIHZlcnNpb24gNCIKY2xpc2ggLXMgLWMgInNldCBkbnMgbW9kZSBkZWZhdWx0IgpjbGlzaCAtcyAtYyAic2V0IGRucyBzdWZmaXggbG9jYWwiCmNsaXNoIC1zIC1jICJzZXQgZG5zIHByaW1hcnkgMTcyLjIzLjM5LjUi"
#      "clish_commands" = "${
#                            "set timezone Europe / Stockholm"                                                                 }${
#                            ";set user admin shell /bin/bash"                                                                 }${
#                            ";set hostname poc-mds-a"                                                                        }${
#                            ";set interface eth0 ipv4-address 192.168.100.110 mask-length 24"                                 }${
#                            ";set static-route default nexthop gateway address 192.168.100.1 on"                            }${
#                            ";set ntp active on"                                                                              }${
#                            ";set ntp server primary se.pool.ntp.org version 4"                                               }${
#                            ";set dns mode default"                                                                           }${
#                            ";set dns suffix local"                                                                           }${
#                            ";set dns primary 172.23.39.5"                                                                        }${
#                            ";config_system --config-string '"                                                                }${
#                            "mgmt_admin_radio=gaia_admin"                                                                     }${
#                            "&mgmt_gui_clients_radio=any"                                                                     }${
#                            "&install_mds_primary=true"                                                                       }${
#                            "&install_mds_interface=eth0"                                                                     }${
#                            "&download_info=true"                                                                             }${
#                            "&reboot_if_required=true"                                                                        }${                          
#                            "'"
#                            }"
    }
  }
}

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
  name = "datastore1"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_host" "host" {
  name = "172.23.23.44"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_resource_pool" "default" {
  name = "172.23.23.44/Resources"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "mgmt-net" {
  name = "Internal_1"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "internal-net" {
  name = "pg-isolated-1"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "isolated-net" {
  name = "pg-isolated-2"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_ovf_vm_template" "ovfRemote" {
  name              = "CPGateway01"
  disk_provisioning = "thin"
  resource_pool_id  = data.vsphere_resource_pool.default.id
  datastore_id      = data.vsphere_datastore.datastore.id
  host_system_id    = data.vsphere_host.host.id
  remote_ovf_url    = "http://192.168.100.53/Check_Point_R81.10_Cloudguard_Security_Gateway_VE.ova"
  ovf_network_map = {
    "Network 1" : data.vsphere_network.mgmt-net.id
    "Network 2" : data.vsphere_network.internal-net.id
    "Network 3" : data.vsphere_network.isolated-net.id
  }
}

resource "vsphere_virtual_machine" "vmFromRemoteOvf" {
  count = 3
  name                 = "AutomationTest${count.index + 1}"
  datacenter_id        = data.vsphere_datacenter.datacenter.id
  datastore_id         = data.vsphere_datastore.datastore.id
  host_system_id       = data.vsphere_host.host.id
  resource_pool_id     = data.vsphere_resource_pool.default.id
  
  folder = "automation-poc"

  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0
  
  num_cpus             = data.vsphere_ovf_vm_template.ovfRemote.num_cpus
  num_cores_per_socket = data.vsphere_ovf_vm_template.ovfRemote.num_cores_per_socket
  memory               = data.vsphere_ovf_vm_template.ovfRemote.memory
  guest_id             = data.vsphere_ovf_vm_template.ovfRemote.guest_id
  scsi_type            = data.vsphere_ovf_vm_template.ovfRemote.scsi_type
  cpu_hot_add_enabled = true
  memory_hot_add_enabled = true
  
  dynamic "network_interface" {
    for_each = data.vsphere_ovf_vm_template.ovfRemote.ovf_network_map
    content {
      network_id = network_interface.value
    }
  }
  ovf_deploy {
    allow_unverified_ssl_cert = true
    remote_ovf_url            = data.vsphere_ovf_vm_template.ovfRemote.remote_ovf_url
    disk_provisioning         = data.vsphere_ovf_vm_template.ovfRemote.disk_provisioning
    ovf_network_map           = data.vsphere_ovf_vm_template.ovfRemote.ovf_network_map
    ip_protocol               = "IPV4"
    ip_allocation_policy      = "STATIC_MANUAL"
    enable_hidden_properties = true
  }
  vapp {
    properties = {
      "admin_hash"     = "YOURPASSWORD",
      "password_type" = "Plain",
      "ntp_primary" = "192.168.100.101",
      "primary" = "172.23.39.5",
      "solution_type" = "Security Gateway",
      "run_ftw" = "Yes",
      "ftw_sic_key" = "YOURSICKEY",
      "hostname" = "testgateway${count.index + 1}",
      "default_gw_v4" = "192.168.100.1",
      "ipaddr_v4" = "192.168.100.1${count.index + 1}",
      "masklen_v4" = "24"
      "eth1_ipaddr_v4" = "50.50.50.1${count.index + 1}",
      "eth1_masklen_v4" = "24",
      "ntp_primary_version" = "3",
      "is_gateway_cluster_member" = "Yes"
      "clish_commands" = "set interface eth2 ipv4-address 60.60.60.1${count.index + 1} mask-length 24; set interface eth2 state on; add user ansibleuser uid 0 homedir /home/ansibleuser; set user ansibleuser password-hash 'YOURPASSWORDHASHHERE'; add rba user ansibleuser roles adminRole; set user ansibleuser shell /bin/bash; set timezone Etc / GMT+3"
    }
  }
  lifecycle {

    ignore_changes = [
      vapp[0]
    ]
  }
}

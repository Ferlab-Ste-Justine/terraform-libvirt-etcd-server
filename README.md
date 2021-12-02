# About

This is a terraform module that provisions a single member of an etcd cluster.

Given a certificate authority as argument (can be an internal-only self-signed authority), it will generate its own secret key and certificate to communicate with clients and peers in the cluster.

One of the servers can also be set to bootstrap authentication in the cluster: it will generates a passwordless **root** user and enable authentication. You are expected to use your certificate authority to generate a client user certificate for **root** to further configure your etcd cluster. 

See: https://github.com/Ferlab-Ste-Justine/openstack-etcd-client-certificate

# Libvirt Networking Support

This module supports both libvirt networks and direct macvtap connection (bridge mode) and was validated with both setups.


# Usage

## Variables



variable "etcd_version" {
  description = "Version of etcd to use in the format: vX.Y.Z"
  type        = string
  default     = "v3.4.15"
}

variable "etcd_auto_compaction_mode" {
  description = "The policy of etcd's auto compaction. Can be either 'periodic' to delete revision older than x or 'revision' to keep at most y revisions"
  type        = string
  default     = "revision"
}

variable "etcd_auto_compaction_retention" {
  #see for expected format: https://etcd.io/docs/v3.4/op-guide/maintenance/
  description = "Boundary specifying what revisions should be compacted. Can be a time value for 'periodic' or a number in string format for 'revision'"
  type        = string
  default     = "1000"
}

variable "etcd_space_quota" {
  description = "Maximum disk space that etcd can take before the cluster goes into alarm mode"
  type        = number
  #Defaults to 8GB
  default     = 8*1024*1024*1024
}

variable "is_initial_cluster" {
  description = "Whether or not this etcd vm is generated as part of a new cluster"
  type        = bool
  default     = true
}

variable "initial_cluster_token" {
  description = "Initial token given to uniquely identify the new cluster"
  type        = string
  default     = "etcd-cluster"
}

variable "initial_cluster" {
  description = "List indicating the initial cluster. Each entry in the list should be a map with the following two keys: 'ip' and 'name'. The name should be the same as the 'name' variable passed to each node."
  type        = list(map(string))
}

variable "organization" {
  description = "The etcd cluster's certificates' organization"
  type        = string
  default     = "Ferlab"
}

variable "certificate_validity_period" {
  description = "The etcd server's certificate's validity period in hours"
  type        = number
  #Defaults to 100 years
  default     = 100*365*24
}

variable "certificate_early_renewal" {
  description = "How long before the end of the validity period the certificate should be renewed in hours"
  type        = number
  #Defaults to 1 year
  default     = 365*24
}

variable "ca" {
  description = "The ca that will sign the member's certificate. Should have the following keys: key, key_algorithm, certificate"
  type        = any
  sensitive   = true
}

variable "bootstrap_authentication" {
  description = "Whether the node should bootstrap authentication for the cluster: creating an admin root user and enabling authentication"
  type        = bool
  default     = false
}

variable "dns_servers" {
  description = "Ip of dns servers to setup, useful mostly during the initial cloud-init bootstraping to resolve domain of intallables"
  type        = list(string)
  default     = []
}

This module takes the following variables as input:

- **name**: Name to give to the vm. Will be used both as hostname and member name in the etcd cluster.
- **vcpus**: Number of vcpus to assign to the vm. Defaults to 2.
- **memory**: Amount of memory in MiB to assign to the vm. Defaults to 8192.
- **volume_id**: Id of the image volume to attach to the vm. A recent version of ubuntu is recommended as this is what this module has been validated against.
- **network_id**: Id (ie, uuid) of the libvirt network to connect the vm to if you wish to connect the vm to a libvirt network.
- **macvtap_interface**: Host network interface that you plan to connect your vm to via a lower macvtap interface. Note that either this or network_id should be set, but not both.
- **macvtap_vm_interface_name_match**: Expected pattern of the network interface name in the vm. Defaults to "en*". Used with macvtap only.
- **macvtap_subnet_prefix_length**: Length of the subnet prefix (ie, the yy in xxx.xxx.xxx.xxx/yy) in the host network. Used with macvtap only.
- **macvtap_gateway_ip**: Ip of the host network's gateway. Used with macvtap only.
- **ip**: Ip of the vm on whichever network it is connected. Note that this isn't an optional parameter. Dhcp cannot be used.
- **mac**: Mac address of the vm. If none is passed, a random one will be generated.
- **cloud_init_volume_pool**: Name of the volume pool that will contain the cloud-init volume of the vm.
- **cloud_init_volume_name**: Name of the cloud-init volume that will be generated by the module for your vm. If left empty, it will default to **<name>-cloud-init.iso**.
- **ssh_admin_user**: Username of the default sudo user in the image. Defaults to **ubuntu**.
- **admin_user_password**: Optional password for the default sudo user of the image. Note that this will not enable ssh password connections, but it will allow you to log into the vm from the host using the **virsh console** command.
- **ssh_admin_public_key**: Public part of the ssh key the admin will be able to login as
- **etcd_version**: Version of etcd that should be install. Defaults to **v3.4.18** and this is the version this module was validated against. Your mileage may vary with other versions.
- **etcd_auto_compaction_mode**: The kind of auto compaction to use. Can be **periodic** or **revision** (defaults to **revision**). See: https://etcd.io/docs/v3.4/op-guide/maintenance/
- **etcd_auto_compaction_retention**: Specifies what versions will be preserved during auto compaction given the **etcd_auto_compaction_mode**. Defaults to **1000** (if the defaults are kept, the last 1000 revisions will be preserved and all revisions older than that will be fair game for compaction)
- **etcd_space_quota**: The maximum disk space the etcd instance can use before the cluster hits **panic mode** and becomes **read only**. Given that etcd tries to cache all its key values in the memory for performance reasons, it make sense not to make this much greater than the amount of memory you have on the machine (because of fragmentation, a key space that fits in the memory could theoretically take an amount of disk space that is larger than the amount of memory). Defaults to 8GiB.
- **is_initial_cluster**: Set this to **true** if the machine is created as part of the initial cluster creation. If the machine is created to join an existing cluster, then set this to **false**
- initial_cluster_token: Token to uniquely identify the cluster during the initial cluster bootstraping phase. Defaults to **etcd-cluster**
- **initial_cluster**: List indicating the initial cluster to join. It should contain a list of maps, each entry having the following keys: ip, name. The **name** value in each map should be the same as the **name** value that is passed to the corresponding member as a module variable. Will be used when the vm is initially created and ignored after that. See: https://etcd.io/docs/v3.4/op-guide/clustering/
- **organization**: Organization that will be used in the etcd member's certificate
- **certificate_validity_period**: Validity period of the member's certificate in hours. Defaults to 100 years.
- **certificate_early_renewal**: How long before the end of the validity period the certificate should be renewed in hours. Defaults to 1 year.
- **ca**: Certificate authority that will be used to sign the member's certificat. It is expected to contain the following keys: key, key_algorithm, certificate
- **bootstrap_authentication**: See to **true** on **one** (and only one) member to boostrap authentication when you initially create the etcd cluster. 

## Example

### Libvirt Network

Assuming I have a pre-existing os volume and the following libvirt network:

```
<network>
    <name>mynetwork</name>
    <forward mode='nat'>
        <nat />
    </forward>
    <bridge name='cqgc0' stp='on' delay='0' />
    <ip address="192.168.121.1" netmask="255.255.255.0"></ip>
</network>
```

The terraform for each server will be:

```
resource "libvirt_volume" "etcd_alpha" {
  name             = var.etcd_alpha_volume_name
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_alpha" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git?ref=v1"
  name = var.etcd_alpha_name
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_alpha.id
  network_id = var.etcd_alpha_network_id
  ip = var.etcd_alpha_ip
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  bootstrap_authentication = var.etcd_alpha_bootstrap_authentication
  ca = {
    key = chomp(data.local_file.etcd_ca_key.content)
    key_algorithm = chomp(data.local_file.etcd_ca_key_algorithm.content)
    certificate = chomp(data.local_file.etcd_ca_cert.content)
  }
  initial_cluster = var.etcd_alpha_initial_cluster
}
```

Lets fill some of the noteworthy variables here...

The following parameters will be the same between the hosts:
```
initial_cluster = [
  {
    ip = "192.168.121.4"
    name = "etcd-alpha-1"
  },
  {
    ip = "192.168.121.5"
    name = "etcd-alpha-2"
  },
  {
    ip = "192.168.121.6"
    name = "etcd-alpha-3"
  }
] 
```

The following parameters will vary between the 3 hosts of the cluster:

```
etcd-1:
name = etcd-alpha-1
etcd_alpha_ip = 192.168.121.4
bootstrap_authentication = true

etcd-2:
name = etcd-alpha-2
etcd_alpha_ip = 192.168.121.5
bootstrap_authentication = false

etcd-3:
name = etcd-alpha-3
etcd_alpha_ip = 192.168.121.6
bootstrap_authentication = false
```

### Macvtap

Assuming that I have an host network interface named **ens3** connected to a **192.168.21.1/24** network with a gateway (that also qualifies as a dns server) that has an ip of **192.168.21.1** and that ips ranging from 192.168.21.200 to 192.168.21.254 are not managed by the network's dhcp server... 

The terraform for each server will be:

```
resource "libvirt_volume" "etcd_alpha" {
  name             = var.etcd_alpha_volume_name
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_alpha" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git?ref=v1"
  name = var.etcd_alpha_name
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_alpha.id
  macvtap_interface = var.etcd_alpha_macvtap_interface
  macvtap_subnet_prefix_length = var.etcd_alpha_macvtap_subnet_prefix_length
  macvtap_gateway_ip = var.etcd_alpha_macvtap_gateway_ip
  ip = var.etcd_alpha_ip
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  bootstrap_authentication = var.etcd_alpha_bootstrap_authentication
  ca = {
    key = chomp(data.local_file.etcd_ca_key.content)
    key_algorithm = chomp(data.local_file.etcd_ca_key_algorithm.content)
    certificate = chomp(data.local_file.etcd_ca_cert.content)
  }
  initial_cluster = var.etcd_alpha_initial_cluster
  dns_servers = var.etcd_alpha_dns_servers
}
```

Lets fill some of the noteworthy variables here...

The following parameters will be the same between the hosts:
```
etcd_alpha_initial_cluster = [
  {
    ip = "192.168.21.200"
    name = "etcd-alpha-1"
  },
  {
    ip = "192.168.21.201"
    name = "etcd-alpha-2"
  },
  {
    ip = "192.168.21.202"
    name = "etcd-alpha-3"
  }
]
etcd_alpha_macvtap_interface = "ens3"
etcd_alpha_macvtap_subnet_prefix_length = "24"
etcd_alpha_macvtap_gateway_ip = "192.168.21.1"
etcd_alpha_dns_servers = ["192.168.21.1"]
```

The following parameters will vary between the 3 hosts of the cluster:

```
etcd-1:
name = etcd-alpha-1
etcd_alpha_ip = 192.168.21.200
bootstrap_authentication = true

etcd-2:
name = etcd-alpha-2
etcd_alpha_ip = 192.168.21.201
bootstrap_authentication = false

etcd-3:
name = etcd-alpha-3
etcd_alpha_ip = 192.168.21.202
bootstrap_authentication = false
```

## Gotchas

### Macvtap and Host Traffic

Because of the way macvtap is setup in bridge mode, traffic from the host to the guest vm is not possible. However, traffic from other guest vms on the host or from other physical hosts on the network will work fine.

### Volume Pools, Ubuntu and Apparmor

At the time of this writing, libvirt will not set the apparmor permission of volume pools properly on recent versions of ubuntu. This will result in volumes that cannot be attached to your vms (you will get a permission error).

You need to setup the permissions in apparmor yourself for it to work.

See the following links for the bug and workaround:

https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/1677398
https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/1677398/comments/43

### Requisite Outgoing Traffic

Note that because cloud-init installs external dependencies, you will need working dns that can resolve names on the internet and outside connectivity for the vm.
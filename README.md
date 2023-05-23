# About

This is a terraform module that provisions a single member of an etcd cluster.

Given a certificate authority as argument (can be an internal-only self-signed authority), it will generate its own secret key and certificate to communicate peers in the cluster and also with clients if certificate authentication is chosen.

One of the servers can also be set to bootstrap authentication in the cluster: it will generates a **root** (passwordless if certificate authentication is chosen) user and enable authentication. 

Note that if certificate authentication is chosen, you are expected to use your certificate authority to generate a client user certificate for **root** to further configure your etcd cluster.

See: https://github.com/Ferlab-Ste-Justine/openstack-etcd-client-certificate

You can alternatively user username/password authentication.

# Libvirt Networking Support

This module supports both libvirt networks and direct macvtap connection (bridge mode) and was validated with both setups.

# Usage

## Variables

This module takes the following variables as input:

- **name**: Name to give to the vm. Will be used both as hostname and member name in the etcd cluster.
- **vcpus**: Number of vcpus to assign to the vm. Defaults to 2.
- **memory**: Amount of memory in MiB to assign to the vm. Defaults to 8192.
- **volume_id**: Id of the image volume to attach to the vm. A recent version of ubuntu is recommended as this is what this module has been validated against.
- **data_volume_id**: Id for an optional separate disk volume to attach to the vm on etcd's data path
- **libvirt_network**: Parameters to connect to a libvirt network if you opt for that instead of macvtap interfaces. In has the following keys:
  - **ip**: Ip of the vm.
  - **mac**: Mac address of the vm. If none is passed, a random one will be generated.
  - **network_id**: Id (ie, uuid) of the libvirt network to connect to (in which case **network_name** should be an empty string).
  - **network_name**: Name of the libvirt network to connect to (in which case **network_id** should be an empty string).
- **macvtap_interfaces**: List of macvtap interfaces to connect the vm to if you opt for macvtap interfaces instead of a libvirt network. Note that etcd will only bind on and listen on the mapvtap interface of the list. Each entry in the list is a map with the following keys:
  - **interface**: Host network interface that you plan to connect your macvtap interface with.
  - **prefix_length**: Length of the network prefix for the network the interface will be connected to. For a **192.168.1.0/24** for example, this would be **24**.
  - **ip**: Ip associated with the macvtap interface. 
  - **mac**: Mac address associated with the macvtap interface
  - **gateway**: Ip of the network's gateway for the network the interface will be connected to.
  - **dns_servers**: Dns servers for the network the interface will be connected to. If there aren't dns servers setup for the network your vm will connect to, the ip of external dns servers accessible accessible from the network will work as well.
- **cloud_init_volume_pool**: Name of the volume pool that will contain the cloud-init volume of the vm.
- **cloud_init_volume_name**: Name of the cloud-init volume that will be generated by the module for your vm. If left empty, it will default to **<name>-cloud-init.iso**.
- **ssh_admin_user**: Username of the default sudo user in the image. Defaults to **ubuntu**.
- **admin_user_password**: Optional password for the default sudo user of the image. Note that this will not enable ssh password connections, but it will allow you to log into the vm from the host using the **virsh console** command.
- **ssh_admin_public_key**: Public part of the ssh key the admin will be able to login as
- **etcd**: Etcd configuration. It should be the same on each member of the cluster and have the following keys:
  - **auto_compaction_mode**: The kind of auto compaction to use. Can be **periodic** or **revision** (defaults to **revision**). See: https://etcd.io/docs/v3.4/op-guide/maintenance/
  - **auto_compaction_retention**: Specifies what versions will be preserved during auto compaction given the **auto_compaction_mode**. Defaults to **1000** (if the defaults are kept, the last 1000 revisions will be preserved and all revisions older than that will be fair game for compaction)
  - **space_quota**: The maximum disk space the etcd instance can use before the cluster hits **panic mode** and becomes **read only**. Given that etcd tries to cache all its key values in the memory for performance reasons, it make sense not to make this much greater than the amount of memory you have on the machine (because of fragmentation, a key space that fits in the memory could theoretically take an amount of disk space that is larger than the amount of memory). Defaults to 8GiB.
  - **grpc_gateway_enabled**: If set to true (defaults to false), the legacy REST v3 endpoints are enabled which might be needed if you use a client that isn't up to date. Note that if you set this to true, you need to set **client_cert_auth** to false.
  - **client_cert_auth**: Whether to use client certificate authentication (defaults to true). If set to false, username/password authentication will be used instead.
- **authentication_bootstrap**: Configuration parameter for one (and only one) of the starting node that will create the root user and enabled authentication for the cluster. It has the following keys:
  - **bootstrap**: Whether the node should bootstrap authentication. Defaults to false.
  - **root_password**: Password to assign to the root user if **etcd.client_cert_auth** is set to false.
- **cluster**: Configuration parameter to set on all nodes to indicate whether the cluster is getting initialized and the initialization settings. It has the following keys:
  - **is_initializing**: Set to true if the cluster is getting generated along with the creation of this node.
  - **initial_token**: Initialization token for the cluster.
  - **initial_members**: List of the initial members that are present when the cluster is initially boostraped. It should contain a list of maps, each entry having the following keys: ip, name. The **name** value in each map should be the same as the **name** value that is passed to the corresponding member as a module variable.
- **tls**: Tls authentication parameters for peer-to-peer communication and server-to-client communitcation. It has the following keys.
  - **ca_cert**: CA certificate that will be used to validate the authenticity of peers and clients.
  - **server_cert**: Server certificate that will be used to authentify the server to its peers and to clients. In addition to being signed for all the ips and domains the server will use, it should be signed with the **127.0.0.1** loopback address in order to initialize authentication from one of the servers. Its allowed uses should be both server authentication and client authentication.
  - **server_key**: Server private key that complements its certificate for authentication.
- **chrony**: Optional chrony configuration for when you need a more fine-grained ntp setup on your vm. It is an object with the following fields:
  - **enabled**: If set the false (the default), chrony will not be installed and the vm ntp settings will be left to default.
  - **servers**: List of ntp servers to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server)
  - **pools**: A list of ntp server pools to sync from with each entry containing two properties, **url** and **options** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool)
  - **makestep**: An object containing remedial instructions if the clock of the vm is significantly out of sync at startup. It is an object containing two properties, **threshold** and **limit** (see: https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep)
- **fluentbit**: Optional fluend configuration to securely route logs to a fluend/fluent-bit node using the forward plugin. Alternatively, configuration can be 100% dynamic by specifying the parameters of an etcd store to fetch the configuration from. It has the following keys:
  - **enabled**: If set the false (the default), fluent-bit will not be installed.
  - **etcd_tag**: Tag to assign to logs coming from etcd
  - **node_exporter_tag** Tag to assign to logs coming from the prometheus node exporter
  - **forward**: Configuration for the forward plugin that will talk to the external fluend/fluent-bit node. It has the following keys:
    - **domain**: Ip or domain name of the remote fluend node.
    - **port**: Port the remote fluend node listens on
    - **hostname**: Unique hostname identifier for the vm
    - **shared_key**: Secret shared key with the remote fluentd node to authentify the client
    - **ca_cert**: CA certificate that signed the remote fluentd node's server certificate (used to authentify it)
  - **etcd**: Parameters to fetch fluent-bit configurations dynamically from an etcd cluster. It has the following keys:
    - **enabled**: If set to true, configurations will be set dynamically. The default configurations can still be referenced as needed by the dynamic configuration. They are at the following paths:
      - **Global Service Configs**: /etc/fluent-bit-customization/default-config/fluent-bit-service.conf
      - **Systemd Inputs**: /etc/fluent-bit-customization/default-config/fluent-bit-inputs.conf
      - **Forward Output**: /etc/fluent-bit-customization/default-config/fluent-bit-output.conf
    - **key_prefix**: Etcd key prefix to search for fluent-bit configuration
    - **endpoints**: Endpoints of the etcd cluster. Endpoints should have the format `<ip>:<port>`
    - **ca_certificate**: CA certificate against which the server certificates of the etcd cluster will be verified for authenticity
    - **client**: Client authentication. It takes the following keys:
      - **certificate**: Client tls certificate to authentify with. To be used for certificate authentication.
      - **key**: Client private tls key to authentify with. To be used for certificate authentication.
      - **username**: Client's username. To be used for username/password authentication.
      - **password**: Client's password. To be used for username/password authentication.
- **install_dependencies**: Whether cloud-init should install external dependencies (should be set to false if you already provide an image with the external dependencies built-in).

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

The terraform for each servers might be:

```
locals {
  cluster = {
    is_initializing = true
    initial_token = "etcd-cluster"
    initial_members = initial_members = [
      {
        "ip": "192.168.121.4",
        "name": "etcd-1"
      },
      {
        "ip": "192.168.121.5",
        "name": "etcd-2"
      },
      {
        "ip": "192.168.121.6",
        "name": "etcd-3"
      }
    ]
  }
  ca_cert = file("/opt/etcd_ca.crt")
  server_1 = {
    cert = "${file(/opt/etcd_server_1.crt)}\n${local.ca_cert}"
    key = file("/opt/etcd_server_1.key")
  }
  server_2 = {
    cert = "${file(/opt/etcd_server_2.crt)}\n${local.ca_cert}"
    key = file("/opt/etcd_server_2.key")
  }
  server_3 = {
    cert = "${file(/opt/etcd_server_3.crt)}\n${local.ca_cert}"
    key = file("/opt/etcd_server_3.key")
  }
}

resource "libvirt_volume" "etcd_1" {
  name             = "etcd-1"
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_1" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git"
  name = "etcd-1"
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_1.id
  libvirt_network = {
    network_id = var.etcd_alpha_network_id
    ip = "192.168.121.4"
  }
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  tls = {
    ca_cert = local.ca_cert
    server_cert = local.server_1.cert
    server_key  = local.server_1.key
  }
  authentication_bootstrap = {
    bootstrap = true
    root_password = ""
  }
  cluster = local.cluster
}

resource "libvirt_volume" "etcd_2" {
  name             = "etcd-2"
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_2" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git"
  name = "etcd-2"
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_2.id
  libvirt_network = {
    network_id = var.etcd_alpha_network_id
    ip = "192.168.121.5"
  }
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  tls = {
    ca_cert = local.ca_cert
    server_cert = local.server_2.cert
    server_key  = local.server_2.key
  }
  authentication_bootstrap = {
    bootstrap = false
    root_password = ""
  }
  cluster = local.cluster
}

resource "libvirt_volume" "etcd_3" {
  name             = "etcd-3"
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_3" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git"
  name = "etcd-3"
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_3.id
  libvirt_network = {
    network_id = var.etcd_alpha_network_id
    ip = "192.168.121.6"
  }
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  tls = {
    ca_cert = local.ca_cert
    server_cert = local.server_3.cert
    server_key  = local.server_3.key
  }
  authentication_bootstrap = {
    bootstrap = false
    root_password = ""
  }
  cluster = local.cluster
}
```

### Macvtap

Assuming that I have an host network interface named **ens3** connected to a **192.168.21.1/24** network with a gateway (that also qualifies as a dns server) that has an ip of **192.168.21.1** and that ips ranging from 192.168.21.200 to 192.168.21.254 are not managed by the network's dhcp server... Also assume that mac addresses **52:54:00:DE:E3:64**, **52:54:00:DE:E3:65** and **52:54:00:DE:E3:66** are free.

The terraform for each server will be:

```
locals {
  cluster = {
    is_initializing = true
    initial_token = "etcd-cluster"
    initial_members = initial_members = [
      {
        "ip": "192.168.21.200",
        "name": "etcd-1"
      },
      {
        "ip": "192.168.21.201",
        "name": "etcd-2"
      },
      {
        "ip": "192.168.21.202",
        "name": "etcd-3"
      }
    ]
  }
  ca_cert = file("/opt/etcd_ca.crt")
  server_1 = {
    cert = "${file(/opt/etcd_server_1.crt)}\n${local.ca_cert}"
    key = file("/opt/etcd_server_1.key")
  }
  server_2 = {
    cert = "${file(/opt/etcd_server_2.crt)}\n${local.ca_cert}"
    key = file("/opt/etcd_server_2.key")
  }
  server_3 = {
    cert = "${file(/opt/etcd_server_3.crt)}\n${local.ca_cert}"
    key = file("/opt/etcd_server_3.key")
  }
}

resource "libvirt_volume" "etcd_1" {
  name             = "etcd-1"
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_1" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git"
  name = "etcd-1"
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_1.id
  macvtap_interfaces = [{
    interface     = "ens3"
    prefix_length = "24"
    ip            = "192.168.21.200"
    mac           = "52:54:00:DE:E3:64"
    gateway       = "192.168.21.1"
    dns_servers   = ["192.168.21.1"]
  }]
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  tls = {
    ca_cert = local.ca_cert
    server_cert = local.server_1.cert
    server_key  = local.server_1.key
  }
  authentication_bootstrap = {
    bootstrap = true
    root_password = ""
  }
  cluster = local.cluster
}

resource "libvirt_volume" "etcd_2" {
  name             = "etcd-2"
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_2" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git"
  name = "etcd-2"
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_2.id
  macvtap_interfaces = [{
    interface     = "ens3"
    prefix_length = "24"
    ip            = "192.168.21.201"
    mac           = "52:54:00:DE:E3:65"
    gateway       = "192.168.21.1"
    dns_servers   = ["192.168.21.1"]
  }]
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  tls = {
    ca_cert = local.ca_cert
    server_cert = local.server_2.cert
    server_key  = local.server_2.key
  }
  authentication_bootstrap = {
    bootstrap = false
    root_password = ""
  }
  cluster = local.cluster
}

resource "libvirt_volume" "etcd_3" {
  name             = "etcd-3"
  pool             = libvirt_pool.etcd.name
  // 30 GiB
  size             = 30 * 1024 * 1024 * 1024
  base_volume_pool = var.os_volumes_pool_name
  base_volume_name = var.etcd_os_volume_name
  format = "qcow2"
}

module "etcd_3" {
  source = "git::https://github.com/Ferlab-Ste-Justine/kvm-etcd-server.git"
  name = "etcd-3"
  vcpus = tonumber(var.etcd_alpha_vcpus)
  memory = tonumber(var.etcd_alpha_memory)
  volume_id = libvirt_volume.etcd_3.id
  macvtap_interfaces = [{
    interface     = "ens3"
    prefix_length = "24"
    ip            = "192.168.21.202"
    mac           = "52:54:00:DE:E3:66"
    gateway       = "192.168.21.1"
    dns_servers   = ["192.168.21.1"]
  }]
  cloud_init_volume_pool = libvirt_pool.etcd.name
  ssh_admin_public_key = tls_private_key.etcd_ssh.public_key_openssh
  tls = {
    ca_cert = local.ca_cert
    server_cert = local.server_3.cert
    server_key  = local.server_3.key
  }
  authentication_bootstrap = {
    bootstrap = false
    root_password = ""
  }
  cluster = local.cluster
}
```

## Gotchas

### Macvtap and Host Traffic

Because of the way macvtap is setup in bridge mode, traffic from the host to the guest vm is not possible. However, traffic from other guest vms on the host or from other physical hosts on the network will work fine.

### Volume Pools, Ubuntu and Apparmor

At the time of this writing, libvirt will not set the apparmor permission of volume pools properly on recent versions of ubuntu. This will result in volumes that cannot be attached to your vms (you will get a permission error).

You need to setup the permissions in apparmor yourself for it to work.

See the following links for the bug and workaround:

- https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/1677398
- https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/1677398/comments/43

### Requisite Outgoing Traffic

Note that because cloud-init installs external dependencies, you will need working dns that can resolve names on the internet and outside connectivity for the vm.
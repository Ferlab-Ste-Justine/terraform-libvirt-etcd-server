variable "name" {
  description = "Name to give to the vm."
  type        = string
  default     = "etcd"
}

variable "vcpus" {
  description = "Number of vcpus to assign to the vm"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory in MiB"
  type        = number
  default     = 8192
}

variable "volume_id" {
  description = "Id of the disk volume to attach to the vm"
  type        = string
}

variable "libvirt_network" {
  description = "Parameters of the libvirt network connection if a libvirt network is used. Has the following parameters: network_id, ip, mac"
  type = object({
      network_id = string
      ip = string
      mac = string
  })
  default = {
      network_id = ""
      ip = ""
      mac = ""
  }
}

variable "macvtap_interfaces" {
  description = "List of macvtap interfaces. Mutually exclusive with the libvirt_network Field. Each entry has the following keys: interface, prefix_length, ip, mac, gateway and dns_servers"
  type        = list(object({
    interface     = string
    prefix_length = string
    ip            = string
    mac           = string
    gateway       = string
    dns_servers   = list(string)
  }))
  default = []
}

variable "cloud_init_volume_pool" {
  description = "Name of the volume pool that will contain the cloud init volume"
  type        = string
}

variable "cloud_init_volume_name" {
  description = "Name of the cloud init volume"
  type        = string
  default = ""
}

variable "ssh_admin_user" { 
  description = "Pre-existing ssh admin user of the image"
  type        = string
  default     = "ubuntu"
}

variable "admin_user_password" { 
  description = "Optional password for admin user"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_admin_public_key" {
  description = "Public ssh part of the ssh key the admin will be able to login as"
  type        = string
}

variable "etcd" {
  description = "Etcd parameters"
  type        = object({
    version                   = string,
    auto_compaction_mode      = string,
    auto_compaction_retention = string,
    space_quota               = number,
  })
  default = {
    version                   = "v3.4.18"
    auto_compaction_mode      = "revision"
    auto_compaction_retention = "1000"
    space_quota               = 8*1024*1024*1024
  }
}

variable "cluster" {
  description = "Etcd cluster parameters"
  type        = object({
    is_initializing = bool,
    initial_token   = string,
    initial_members = list(object({
      ip   = string,
      name = string,
    })),
  })
}

variable "bootstrap_authentication" {
  description = "Whether the node should bootstrap authentication for the cluster: creating an admin root user and enabling authentication"
  type        = bool
  default     = false
}

variable "certificate" {
  description = "Certificate Parameters"
  type = object({
    organization         = string,
    validity_period      = number,
    early_renewal_period = number,
    key_length           = number,
  })
  default = {
    organization         = "Ferlab",
    validity_period      = 100*365*24,
    early_renewal_period = 365*24,
    key_length           = 4096
  }
}

variable "ca" {
  description = "The ca that will sign the member's certificate. Should have the following keys: key, key_algorithm, certificate"
  sensitive   = true
  type        = object({
    key           = string,
    key_algorithm = string,
    certificate   = string,
  })
}

variable "chrony" {
  description = "Chrony configuration for ntp. If enabled, chrony is installed and configured, else the default image ntp settings are kept"
  type        = object({
    enabled = bool,
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#server
    servers = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#pool
    pools = list(object({
      url = string,
      options = list(string)
    })),
    //https://chrony.tuxfamily.org/doc/4.2/chrony.conf.html#makestep
    makestep = object({
      threshold = number,
      limit = number
    })
  })
  default = {
    enabled = false
    servers = []
    pools = []
    makestep = {
      threshold = 0,
      limit = 0
    }
  }
}

variable "fluentd" {
  description = "Fluentd configurations"
  sensitive   = true
  type = object({
    enabled = bool,
    etcd_tag = string,
    node_exporter_tag = string,
    syslog_tag = string,
    forward = object({
      domain = string,
      port = number,
      hostname = string,
      shared_key = string,
      ca_cert = string,
    }),
  })
  default = {
    enabled = false
    etcd_tag = ""
    node_exporter_tag = ""
    syslog_tag = ""
    forward = {
      domain = ""
      port = 0
      hostname = ""
      shared_key = ""
      ca_cert = ""
    }
  }
}
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

variable "network_id" {
  description = "Id of the libvirt network to connect the vm to if you plan on connecting the vm to a libvirt network"
  type        = string
  default     = ""
}

variable "macvtap_interface" {
  description = "Interface that you plan to connect your vm to via a lower macvtap interface. Note that either this or network_id should be set, but not both."
  type        = string
  default     = ""
}

variable "macvtap_vm_interface_name_match" {
  description = "Expected pattern of the network interface name in the vm."
  type        = string
  //https://github.com/systemd/systemd/blob/main/src/udev/udev-builtin-net_id.c#L932
  default     = "en*"
}

variable "macvtap_subnet_prefix_length" {
  description = "Length of the subnet prefix (ie, the yy in xxx.xxx.xxx.xxx/yy). Used for macvtap only."
  type        = string
  default     = ""
}

variable "macvtap_gateway_ip" {
  description = "Ip of the physical network's gateway. Used for macvtap only."
  type        = string
  default     = ""
}

variable "macvtap_dns_servers" {
  description = "Ip of dns servers to setup on the vm, useful mostly during the initial cloud-init bootstraping to resolve domain of installables. Used for macvtap only."
  type        = list(string)
  default     = []
}

variable "ip" {
  description = "Ip address of the vm"
  type        = string
}

variable "mac" {
  description = "Mac address of the vm"
  type        = string
  default     = ""
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

variable "etcd_version" {
  description = "Version of etcd to use in the format: vX.Y.Z"
  type        = string
  default     = "v3.4.18"
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
  #Defaults to 8GiB
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
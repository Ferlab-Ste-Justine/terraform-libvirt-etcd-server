locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  network_config = templatefile(
    "${path.module}/files/network_config.yaml.tpl", 
    {
      interface_name_match = var.macvtap_vm_interface_name_match
      subnet_prefix_length = var.macvtap_subnet_prefix_length
      vm_ip = var.ip
      gateway_ip = var.macvtap_gateway_ip
      dns_servers = var.macvtap_dns_servers
    }
  )
}

data "template_cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  part {
    content_type = "text/cloud-config"
    content = templatefile(
      "${path.module}/files/user_data.yaml.tpl", 
      {
        etcd_version = var.etcd_version
        etcd_space_quota = var.etcd_space_quota
        etcd_auto_compaction_mode = var.etcd_auto_compaction_mode
        etcd_auto_compaction_retention = var.etcd_auto_compaction_retention
        etcd_initial_cluster_token = var.initial_cluster_token
        self_ip = var.ip
        etcd_initial_cluster_state = var.is_initial_cluster ? "new" : "existing"
        etcd_name = var.name
        etcd_cluster = join(
          ",",
          [for elem in var.initial_cluster: "${elem["name"]}=https://${elem["ip"]}:2380"]
        )
        ca_cert = var.ca.certificate
        cert = tls_locally_signed_cert.certificate.cert_pem
        key = tls_private_key.key.private_key_pem
        bootstrap_authentication = var.bootstrap_authentication
        root_key = module.root_certificate.key
        root_cert = module.root_certificate.certificate
        ssh_admin_public_key = var.ssh_admin_public_key
        ssh_admin_user = var.ssh_admin_user
        admin_user_password = var.admin_user_password
      }
    )
  }
}

resource "libvirt_cloudinit_disk" "etcd" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = var.macvtap_interface != "" ? local.network_config : null
  pool           = var.cloud_init_volume_pool
}

resource "libvirt_domain" "etcd" {
  name = var.name

  cpu {
    mode = "host-passthrough"
  }

  vcpu = var.vcpus
  memory = var.memory

  disk {
    volume_id = var.volume_id
  }

  network_interface {
    network_id = var.network_id != "" ? var.network_id : null
    macvtap = var.macvtap_interface != "" ? var.macvtap_interface : null
    addresses = var.network_id != "" ? [var.ip] : null
    mac = var.mac != "" ? var.mac : null
    hostname = var.network_id != "" ? var.name : null
  }

  autostart = true

  cloudinit = libvirt_cloudinit_disk.etcd.id

  //https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf#L61
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
}
locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  network_config = templatefile(
    "${path.module}/files/network_config.yaml.tpl", 
    {
      macvtap_interfaces = var.macvtap_interfaces
    }
  )
  network_interfaces = length(var.macvtap_interfaces) == 0 ? [{
    network_id = var.libvirt_network.network_id
    macvtap = null
    addresses = [var.libvirt_network.ip]
    mac = var.libvirt_network.mac != "" ? var.libvirt_network.mac : null
    hostname = var.name
  }] : [for macvtap_interface in var.macvtap_interfaces: {
    network_id = null
    macvtap = macvtap_interface.interface
    addresses = null
    mac = macvtap_interface.mac
    hostname = null
  }]
  ips = length(var.macvtap_interfaces) == 0 ? [
    var.libvirt_network.ip
  ] : [
    for macvtap_interface in var.macvtap_interfaces: macvtap_interface.ip
  ]
  fluentd_conf = templatefile(
    "${path.module}/files/fluentd.conf.tpl", 
    {
        fluentd = var.fluentd
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
        etcd_version = var.etcd.version
        etcd_space_quota = var.etcd.space_quota
        etcd_auto_compaction_mode = var.etcd.auto_compaction_mode
        etcd_auto_compaction_retention = var.etcd.auto_compaction_retention
        etcd_initial_cluster_token = var.cluster.initial_token
        self_ip = local.ips.0
        etcd_initial_cluster_state = var.cluster.is_initializing ? "new" : "existing"
        etcd_name = var.name
        etcd_cluster = join(
          ",",
          [for elem in var.cluster.initial_members: "${elem["name"]}=https://${elem["ip"]}:2380"]
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
        chrony = var.chrony
        fluentd = var.fluentd
        fluentd_conf = local.fluentd_conf
      }
    )
  }
}

resource "libvirt_cloudinit_disk" "etcd" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = length(var.macvtap_interfaces) > 0 ? local.network_config : null
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

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network_id = network_interface.value["network_id"]
      macvtap = network_interface.value["macvtap"]
      addresses = network_interface.value["addresses"]
      mac = network_interface.value["mac"]
      hostname = network_interface.value["hostname"]
    }
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
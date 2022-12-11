locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
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
}

module "network_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//network?ref=main"
  network_interfaces = var.macvtap_interfaces
}

module "etcd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//etcd?ref=main"
  install_dependencies = var.install_dependencies
  etcd_host = {
    name                     = var.name
    ip                       = local.ips.0
    bootstrap_authentication = var.authentication_bootstrap.bootstrap
  }
  etcd_cluster = {
    auto_compaction_mode       = var.etcd.auto_compaction_mode
    auto_compaction_retention  = var.etcd.auto_compaction_retention
    space_quota                = var.etcd.space_quota
    grpc_gateway_enabled       = var.etcd.grpc_gateway_enabled
    client_cert_auth           = var.etcd.client_cert_auth
    root_password              = var.authentication_bootstrap.root_password
  }
  etcd_initial_cluster = {
    is_initializing = var.cluster.is_initializing
    token           = var.cluster.initial_token
    members         = var.cluster.initial_members
  }
  tls = {
    server_cert = "${tls_locally_signed_cert.certificate.cert_pem}\n${var.ca.certificate}"
    server_key  = tls_private_key.key.private_key_pem
    ca_cert     = var.ca.certificate
  }
}

module "prometheus_node_exporter_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//prometheus-node-exporter?ref=main"
  install_dependencies = var.install_dependencies
}

module "chrony_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//chrony?ref=main"
  install_dependencies = var.install_dependencies
  chrony = {
    servers  = var.chrony.servers
    pools    = var.chrony.pools
    makestep = var.chrony.makestep
  }
}

module "fluentd_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluentd?ref=main"
  install_dependencies = var.install_dependencies
  fluentd = {
    docker_services = []
    systemd_services = [
      {
        tag     = var.fluentd.etcd_tag
        service = "etcd"
      },
      {
        tag     = var.fluentd.node_exporter_tag
        service = "node-exporter"
      }
    ]
    forward = var.fluentd.forward,
    buffer = var.fluentd.buffer
  }
}

data "template_cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  part {
    filename     = "base.cfg"
    content_type = "text/cloud-config"
    content = templatefile(
      "${path.module}/files/user_data.yaml.tpl", 
      {
        hostname = var.name
        ssh_admin_public_key = var.ssh_admin_public_key
        ssh_admin_user = var.ssh_admin_user
        admin_user_password = var.admin_user_password
      }
    )
  }

  part {
    filename     = "etcd.cfg"
    content_type = "text/cloud-config"
    content      = module.etcd_configs.configuration
  }

  part {
    filename     = "node_exporter.cfg"
    content_type = "text/cloud-config"
    content      = module.prometheus_node_exporter_configs.configuration
  }

  part {
    filename     = "chrony.cfg"
    content_type = "text/cloud-config"
    content      = module.chrony_configs.configuration
  }

  part {
    filename     = "fluentd.cfg"
    content_type = "text/cloud-config"
    content      = module.fluentd_configs.configuration
  }
}

resource "libvirt_cloudinit_disk" "etcd" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = length(var.macvtap_interfaces) > 0 ? module.network_configs.configuration : null
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
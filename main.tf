locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  network_interfaces = length(var.macvtap_interfaces) == 0 ? [{
    network_name = var.libvirt_network.network_name != "" ? var.libvirt_network.network_name : null
    network_id = var.libvirt_network.network_id != "" ? var.libvirt_network.network_id : null
    macvtap = null
    addresses = [var.libvirt_network.ip]
    mac = var.libvirt_network.mac != "" ? var.libvirt_network.mac : null
    hostname = var.name
  }] : [for macvtap_interface in var.macvtap_interfaces: {
    network_name = null
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
  volumes = var.data_volume_id != "" ? [var.volume_id, var.data_volume_id] : [var.volume_id]
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

module "fluentbit_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//fluent-bit?ref=main"
  install_dependencies = var.install_dependencies
  fluentbit = {
    metrics = var.fluentbit.metrics
    systemd_services = [
      {
        tag     = var.fluentbit.etcd_tag
        service = "etcd.service"
      },
      {
        tag     = var.fluentbit.node_exporter_tag
        service = "node-exporter.service"
      }
    ]
    forward = var.fluentbit.forward
  }
  etcd    = var.fluentbit.etcd
}

module "data_volume_configs" {
  source = "git::https://github.com/Ferlab-Ste-Justine/terraform-cloudinit-templates.git//data-volumes?ref=main"
  volumes = [{
    label         = "etcd_data"
    device        = "vdb"
    filesystem    = "ext4"
    mount_path    = "/var/lib/etcd"
    mount_options = "defaults"
  }]
}

locals {
  cloudinit_templates = concat([
      {
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
      },
      {
        filename     = "etcd.cfg"
        content_type = "text/cloud-config"
        content      = module.etcd_configs.configuration
      },
      {
        filename     = "node_exporter.cfg"
        content_type = "text/cloud-config"
        content      = module.prometheus_node_exporter_configs.configuration
      }
    ],
    var.chrony.enabled ? [{
      filename     = "chrony.cfg"
      content_type = "text/cloud-config"
      content      = module.chrony_configs.configuration
    }] : [],
    var.fluentbit.enabled ? [{
      filename     = "fluent_bit.cfg"
      content_type = "text/cloud-config"
      content      = module.fluentbit_configs.configuration
    }] : [],
    var.data_volume_id != "" ? [{
      filename     = "data_volume.cfg"
      content_type = "text/cloud-config"
      content      = module.data_volume_configs.configuration
    }]: []
  )
}

data "template_cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
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

  dynamic "disk" {
    for_each = local.volumes
    content {
      volume_id = disk.value
    }
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network_id = network_interface.value["network_id"]
      network_name = network_interface.value["network_name"]
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
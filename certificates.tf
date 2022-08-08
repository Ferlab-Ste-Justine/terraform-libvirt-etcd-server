resource "tls_private_key" "key" {
  algorithm   = "RSA"
  rsa_bits    = var.certificate.key_length
}

resource "tls_cert_request" "request" {
  private_key_pem = tls_private_key.key.private_key_pem
  ip_addresses    = concat(local.ips, ["127.0.0.1"])
  dns_names       = var.certificate.extra_domains
  subject {
    common_name  = var.cluster.initial_token
    organization = var.certificate.organization
  }
}

resource "tls_locally_signed_cert" "certificate" {
  cert_request_pem   = tls_cert_request.request.cert_request_pem
  ca_key_algorithm   = var.ca.key_algorithm
  ca_private_key_pem = var.ca.key
  ca_cert_pem        = var.ca.certificate

  validity_period_hours = var.certificate.validity_period
  early_renewal_hours = var.certificate.early_renewal_period

  allowed_uses = [
    "client_auth",
    "server_auth",
  ]

  is_ca_certificate = false
}

module "root_certificate" {
  source = "git::https://github.com/Ferlab-Ste-Justine/openstack-etcd-client-certificate.git"
  ca = var.ca
  username = "root"
}
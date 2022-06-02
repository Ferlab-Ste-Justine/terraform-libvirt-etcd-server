<system>
  Log_Level info
</system>

<source>
  @type systemd
  tag ${fluentd.etcd_tag}
  path /var/log/journal
  matches [{ "_SYSTEMD_UNIT": "etcd.service" }]
  read_from_head true

  <storage>
    @type local
    path /opt/fluentd-state/etcd-cursor.json
  </storage>
</source>

<source>
  @type systemd
  tag ${fluentd.node_exporter_tag}
  path /var/log/journal
  matches [{ "_SYSTEMD_UNIT": "node-exporter.service" }]
  read_from_head true

  <storage>
    @type local
    path /opt/fluentd-state/node-exporter-cursor.json
  </storage>
</source>

<source>
  @type syslog
  tag ${fluentd.syslog_tag}
  port 5140
  bind 127.0.0.1

  <transport tcp>
  </transport>
</source>

<match *>
  @type forward
  transport tls
  tls_insecure_mode false
  tls_allow_self_signed_cert false
  tls_verify_hostname true
  tls_cert_path /opt/fluentd_ca.crt
  send_timeout 20
  connect_timeout 20
  hard_timeout 20
  recover_wait 10
  expire_dns_cache 5
  dns_round_robin true

  <server>
    host ${fluentd.forward.domain}
    port ${fluentd.forward.port}
  </server>

  <security>
    self_hostname ${fluentd.forward.hostname}
    shared_key ${fluentd.forward.shared_key}
  </security>

  ${indent(2, fluentd_buffer_conf)}
</match>
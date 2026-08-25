resource "oci_load_balancer_load_balancer" "this" {
  compartment_id             = var.compartment_ocid
  display_name               = "${var.name_prefix}-lb"
  shape                      = var.shape
  subnet_ids                 = [var.subnet_id]
  network_security_group_ids = var.nsg_ids
  is_private                 = false
  freeform_tags              = var.tags

  shape_details {
    minimum_bandwidth_in_mbps = var.min_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.max_bandwidth_mbps
  }
}

resource "oci_load_balancer_backend_set" "http" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "traefik-http"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.traefik_http_nodeport
    url_path          = "/ping"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend" "http" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  backendset_name  = oci_load_balancer_backend_set.http.name
  ip_address       = var.instance_ip
  port             = var.traefik_http_nodeport
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  name                     = "http"
  port                     = var.http_port
  protocol                 = "HTTP"
  default_backend_set_name = oci_load_balancer_backend_set.http.name

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}

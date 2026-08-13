resource "incus_certificate" "cert" {
  name        = "cert"
  description = "Client certificate for accessing the cluster"
  restricted  = false
  type        = "client"

  certificate = file("${path.module}/incus/client.crt")
}

resource "null_resource" "post_certificates" {
  depends_on = [
    incus_certificate.cert,
  ]
}


locals {
  ttl = 3600

  rrsets_ipv4 = concat(
    [
      { subname = "", type = "A", rdata = [var.address] },
      { subname = "*", type = "A", rdata = [var.address] },
      { subname = "", type = "MX", rdata = var.records.mx },
    ],
    [for subname, values in var.records.txt : { subname = subname == "@" ? "" : subname, type = "TXT", rdata = [for v in values : "\"${v}\""] }],
    [for subname, target in var.records.cname : { subname = subname, type = "CNAME", rdata = [target] }],
    [
      for name, r in var.names : {
        subname = trimsuffix(name, ".${var.public_domain}")
        type    = r.type
        rdata   = r.type == "A" ? [var.address] : r.type == "CNAME" ? ["${r.value}."] : ["\"${r.value}\""]
      }
    ],
  )

  # every A record gets an AAAA record with the VPS's IPv6 address
  rrsets_ipv6 = var.address6 == null ? [] : [
    for r in local.rrsets_ipv4 : { subname = r.subname, type = "AAAA", rdata = [var.address6] } if r.type == "A"
  ]

  rrsets = concat(local.rrsets_ipv4, local.rrsets_ipv6)

  acme_challenges = toset([for name in var.certificates : trimsuffix("_acme-challenge.${trimprefix(name, "*.")}", ".${var.public_domain}")])
}

resource "desec_domain" "public" {
  name = var.public_domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "desec_records" "public" {
  domain    = desec_domain.public.name
  exclusive = true
  rrsets    = [for r in local.rrsets : merge(r, { ttl = local.ttl })]

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = alltrue([for name in keys(var.names) : endswith(name, ".${var.public_domain}")])
      error_message = "Names with their own records must be below the public domain."
    }
  }
}

resource "desec_token" "caddy" {
  name = "caddy"
}

resource "desec_token_policy" "caddy_default" {
  token_id   = desec_token.caddy.id
  perm_write = false
}

resource "desec_token_policy" "caddy" {
  for_each = local.acme_challenges

  token_id   = desec_token.caddy.id
  domain     = desec_domain.public.name
  subname    = each.key
  type       = "TXT"
  perm_write = true

  depends_on = [desec_token_policy.caddy_default]

  lifecycle {
    precondition {
      condition     = alltrue([for name in var.certificates : name == var.public_domain || endswith(name, ".${var.public_domain}")])
      error_message = "Certificates must be for the public domain or names below it."
    }
  }
}

output "caddy_token" {
  value     = desec_token.caddy.token
  sensitive = true
}

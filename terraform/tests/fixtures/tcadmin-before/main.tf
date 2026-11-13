terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

resource "cloudflare_page_rule" "managed" {
  for_each = { "xtremeidiots.com/tcadmin" = true }

  zone_id  = "00000000000000000000000000000000"
  target   = "*tcadmin.xtremeidiots.com/*"
  priority = 2
  status   = "active"
  actions  = { ssl = "flexible" }
}

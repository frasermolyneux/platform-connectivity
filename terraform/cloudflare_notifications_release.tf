moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|apex-ms-domain-verification"]
  to   = cloudflare_dns_record.notification_verification_release
}

removed {
  from = cloudflare_dns_record.notification_verification_release

  lifecycle {
    destroy = false
  }
}

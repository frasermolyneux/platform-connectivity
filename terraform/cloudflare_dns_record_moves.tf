# Preserve the existing DNS resource identities while moving to explicit keys.

moved {
  from = cloudflare_dns_record.a["xtremeidiots.com|A|@|144.217.22.232"]
  to   = cloudflare_dns_record.a["xtremeidiots.com|A|apex"]
}

moved {
  from = cloudflare_dns_record.a["xtremeidiots.com|A|cdn|192.95.23.11"]
  to   = cloudflare_dns_record.a["xtremeidiots.com|A|cdn"]
}

moved {
  from = cloudflare_dns_record.a["xtremeidiots.com|A|maps|192.95.23.11"]
  to   = cloudflare_dns_record.a["xtremeidiots.com|A|maps"]
}

moved {
  from = cloudflare_dns_record.a["xtremeidiots.com|A|test|100.87.229.111"]
  to   = cloudflare_dns_record.a["xtremeidiots.com|A|test"]
}

moved {
  from = cloudflare_dns_record.a["xtremeidiots.com|A|ts|192.95.39.66"]
  to   = cloudflare_dns_record.a["xtremeidiots.com|A|ts"]
}

moved {
  from = cloudflare_dns_record.a["xtremeidiots.com|A|www|192.95.23.11"]
  to   = cloudflare_dns_record.a["xtremeidiots.com|A|www"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|autodiscover"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|enterpriseenrollment"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|enterpriseregistration"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|mte1._domainkey|dkim1.mandrillapp.com"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|mte1-domainkey"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|mte2._domainkey|dkim2.mandrillapp.com"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|mte2-domainkey"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|portal|app-portal-web-prd-uksouth-fe584e15256a.azurewebsites.net"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|portal"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector1._domainkey|selector1-xtremeidiots-com._domainkey.MolyneuxIO.p-v1.dkim.mail.microsoft"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector1-domainkey"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector2._domainkey|selector2-xtremeidiots-com._domainkey.MolyneuxIO.p-v1.dkim.mail.microsoft"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector2-domainkey"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|status|mxstatus.io"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|status"]
}

moved {
  from = cloudflare_dns_record.mx["xtremeidiots.com|MX|@|xtremeidiots-com.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["xtremeidiots.com|MX|apex"]
}

moved {
  from = cloudflare_dns_record.srv["xtremeidiots.com|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["xtremeidiots.com|SRV|sipfederationtls-tcp"]
}

moved {
  from = cloudflare_dns_record.srv["xtremeidiots.com|SRV|_ts3._udp.ts|ts.xtremeidiots.com:9182"]
  to   = cloudflare_dns_record.srv["xtremeidiots.com|SRV|ts3-udp-ts"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|@|MS=ms76092282"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|apex-ms"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|@|google-site-verification=VSeQG9SAzJJb9xKKL-T43TwuUfLIkli-UcU6UDN7AR0"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|apex-google-site-verification"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|@|ms-domain-verification=1dbcb9a5-f9b7-4725-b222-d5b44445f2bd"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|apex-ms-domain-verification"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|_dmarc|v=DMARC1; p=reject; rua=mailto:dmarc@mx-mail.io"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|dmarc"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|_dnsauth.portal|s9lyvdr9z5s2bjfl7gl0s0pglm3qdqcg"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|dnsauth-portal"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|asuid.portal|BDBD8BC935C8905D5B7678B11047530953788118A6EC6223639484FD72437651"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|asuid-portal"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|google._domainkey|v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArubo6nvYzXyiZDHXu1pUpsp/QHWSXgXUpCAYaVIJM9VKVgTC83Kf9WOpoUnoTvmz0qcHNhrJihrZeXlhCVYsK+rbJZsqmWydR2V4sVgFgna6GTi+X6kuR46T8PILRX/k5/hnTAi3w+jGDrZ7xNGiqQuiCkaifLdvRppRkXiz2l8XjddGEzfb46hQFtKLGPsYl2NuaBay8BBLO0iJ2RXoKdnGieBv345dwLx7jaTg3jE8TKz5zmUUS51i4VKL4usw3nay1F5NGuVmgfVpsNFpV2QTMC48cyB2VvsqySYtps+vYBjRR7mIlWCr3jBEEbioUkJkxEF1kEm1HG9alE2gTQIDAQAB"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|google-domainkey"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.com|TXT|mandrill._domainkey|v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCrLHiExVd55zd/IQ/J/mRwSRMAocV/hMB3jXwaHH36d9NaVynQFYV8NaWi69c1veUtRzGt7yAioXqLj7Z4TeEUoOLgrKsn8YnckGs9i3B3tVFB+Ch/4mPhXWiNfNdynHWBcPcbJ8kjEQ2U8y78dHZj1YeRXXVvWob2OaKynO8/lQIDAQAB;"]
  to   = cloudflare_dns_record.txt["xtremeidiots.com|TXT|mandrill-domainkey"]
}

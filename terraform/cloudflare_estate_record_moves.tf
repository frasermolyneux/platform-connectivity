# Preserve existing DNS bindings while adopting stable configuration keys.

moved {
  from = cloudflare_dns_record.a["bishopsbees.co.uk|A|@|5.196.80.194"]
  to   = cloudflare_dns_record.a["bishopsbees.co.uk|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["bishopsbees.co.uk|A|staging|5.196.80.194"]
  to   = cloudflare_dns_record.a["bishopsbees.co.uk|A|staging-1"]
}

moved {
  from = cloudflare_dns_record.a["bishopsbees.co.uk|A|www|5.196.80.194"]
  to   = cloudflare_dns_record.a["bishopsbees.co.uk|A|www-1"]
}

moved {
  from = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|@|alt1.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|@|alt2.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|apex-2"]
}

moved {
  from = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|@|alt3.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|apex-3"]
}

moved {
  from = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|@|alt4.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|apex-4"]
}

moved {
  from = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|@|aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["bishopsbees.co.uk|MX|apex-5"]
}

moved {
  from = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|asuid|094C19A879ADBD321825791B5F1433ECB226343E000DED0F02CF2391AB10C282"]
  to   = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|asuid-1"]
}

moved {
  from = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|@|facebook-domain-verification=y3e092wjsg3jb467rfnd8809zhnggt"]
  to   = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|@|google-site-verification=PzPosMaVrZSdkqH6_GDA6jnOZAr6Bl4G-ttK19-GhKw"]
  to   = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|@|google-site-verification=b-b9AQZwMqSQxpEsGiYU3Ojgl7GVeGBfp0_HbShhpWo"]
  to   = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|apex-3"]
}

moved {
  from = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|@|v=spf1 include:_spf.google.com ~all"]
  to   = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|apex-4"]
}

moved {
  from = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|google._domainkey|v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAg9xNROLn/nic+vyH2CdxXxUPGWj23gzCxmyP5Jx5MRhMsyRN0rV2Eu11o6iIbo/nfWp9oqEOhQLDeF6fnhS0NvGKFoTJLlDr9iUeUKffBXl9RO7j0BAiwBiNeQY2FkePzK+Dv3f1MhRXS8XYCil/B3Vt5b5geIPua7Yd6GX/IRFb848q7OCkLD+MBoE/PH1iLx+1PsiEbvfaMwUat853Dt7mWuUtPyFv0O1o2Nj46FAC9FoWMyed8cfVvHVKlIF8Y/dqXkC3OEuJNABQKfjJ4v9W4kPHtXCVBOz66FSSWgCeQbhJUJjXYYgF1z/1pU+LtWRC8Qid8zJLC7nsVG+llQIDAQAB"]
  to   = cloudflare_dns_record.txt["bishopsbees.co.uk|TXT|google-_domainkey-1"]
}

moved {
  from = cloudflare_dns_record.a["bqba.co.uk|A|@|5.196.80.194"]
  to   = cloudflare_dns_record.a["bqba.co.uk|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["bqba.co.uk|A|www|5.196.80.194"]
  to   = cloudflare_dns_record.a["bqba.co.uk|A|www-1"]
}

moved {
  from = cloudflare_dns_record.a["buckfastqueen.co.uk|A|@|217.160.0.33"]
  to   = cloudflare_dns_record.a["buckfastqueen.co.uk|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["buckfastqueen.co.uk|A|www|217.160.0.33"]
  to   = cloudflare_dns_record.a["buckfastqueen.co.uk|A|www-1"]
}

moved {
  from = cloudflare_dns_record.aaaa["buckfastqueen.co.uk|AAAA|@|2001:8d8:100f:f000::254"]
  to   = cloudflare_dns_record.aaaa["buckfastqueen.co.uk|AAAA|apex-1"]
}

moved {
  from = cloudflare_dns_record.aaaa["buckfastqueen.co.uk|AAAA|www|2001:8d8:100f:f000::254"]
  to   = cloudflare_dns_record.aaaa["buckfastqueen.co.uk|AAAA|www-1"]
}

moved {
  from = cloudflare_dns_record.cname["buckfastqueen.co.uk|CNAME|_domainconnect|_domainconnect.1and1.com"]
  to   = cloudflare_dns_record.cname["buckfastqueen.co.uk|CNAME|_domainconnect-1"]
}

moved {
  from = cloudflare_dns_record.cname["buckfastqueen.co.uk|CNAME|autodiscover|adsredir.ionos.info"]
  to   = cloudflare_dns_record.cname["buckfastqueen.co.uk|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.mx["buckfastqueen.co.uk|MX|@|mx00.ionos.co.uk"]
  to   = cloudflare_dns_record.mx["buckfastqueen.co.uk|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.mx["buckfastqueen.co.uk|MX|@|mx01.ionos.co.uk"]
  to   = cloudflare_dns_record.mx["buckfastqueen.co.uk|MX|apex-2"]
}

moved {
  from = cloudflare_dns_record.txt["buckfastqueen.co.uk|TXT|@|v=spf1 include:_spf-eu.ionos.com ~all"]
  to   = cloudflare_dns_record.txt["buckfastqueen.co.uk|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["dm-electricalservices.co.uk|A|@|5.196.80.194"]
  to   = cloudflare_dns_record.a["dm-electricalservices.co.uk|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["dm-electricalservices.co.uk|A|www|5.196.80.194"]
  to   = cloudflare_dns_record.a["dm-electricalservices.co.uk|A|www-1"]
}

moved {
  from = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|@|alt1.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|@|alt2.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|apex-2"]
}

moved {
  from = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|@|alt3.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|apex-3"]
}

moved {
  from = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|@|alt4.aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|apex-4"]
}

moved {
  from = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|@|aspmx.l.google.com"]
  to   = cloudflare_dns_record.mx["dm-electricalservices.co.uk|MX|apex-5"]
}

moved {
  from = cloudflare_dns_record.txt["dm-electricalservices.co.uk|TXT|@|google-site-verification=WMP13AiawWjWNjihai8Fds3xOmJJTzs1-i0nGkXHYtk"]
  to   = cloudflare_dns_record.txt["dm-electricalservices.co.uk|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["dm-electricalservices.co.uk|TXT|@|v=spf1 include:_spf.google.com -all"]
  to   = cloudflare_dns_record.txt["dm-electricalservices.co.uk|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.cname["midlr.com|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["midlr.com|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["midlr.com|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["midlr.com|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["midlr.com|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["midlr.com|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.mx["midlr.com|MX|@|midlr-com.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["midlr.com|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["midlr.com|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["midlr.com|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["midlr.com|TXT|asuid.www|C075B21DD93CF3A5068CCD102CAD8F897ABA519285E86A80138B26D1D56703B6"]
  to   = cloudflare_dns_record.txt["midlr.com|TXT|asuid-www-1"]
}

moved {
  from = cloudflare_dns_record.txt["midlr.com|TXT|@|MS=ms65417230"]
  to   = cloudflare_dns_record.txt["midlr.com|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["midlr.com|TXT|@|google-site-verification=CGKpKpdaZ_R49cNGOP5x4pRwv8YDfxxZAlMgio4nrHo"]
  to   = cloudflare_dns_record.txt["midlr.com|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.txt["midlr.com|TXT|@|v=spf1 include:spf.protection.outlook.com -all"]
  to   = cloudflare_dns_record.txt["midlr.com|TXT|apex-3"]
}

moved {
  from = cloudflare_dns_record.a["moanclub.com|A|@|144.217.22.232"]
  to   = cloudflare_dns_record.a["moanclub.com|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["moanclub.com|A|www|144.217.22.232"]
  to   = cloudflare_dns_record.a["moanclub.com|A|www-1"]
}

moved {
  from = cloudflare_dns_record.cname["moanclub.com|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["moanclub.com|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["moanclub.com|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["moanclub.com|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["moanclub.com|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["moanclub.com|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.mx["moanclub.com|MX|@|moanclub-com.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["moanclub.com|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["moanclub.com|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["moanclub.com|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["moanclub.com|TXT|google._domainkey|v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAh0DwNQ57WsoBbrhd+ONfHjjLre9gqH/ogNlhcsFdAu9ANdJaXqIRB2ln3SHRn/gd01byrwvrdXojYw4KsPTwPl+X+wsYh5sc6UAjlQ4lr08ydXCt3v1VmPjeBWGOC4aQBF5V2MCFRBqVH7hxH5zWid4f6SoT8Irz8Z+/fh97/iHIbANi6TMKLN7Tjbb2cgWmyILWNLPZbCGh+60Whrt/ZsgXIco1A91FX2hzmSvv7owGuE1PIVKZMiDz67H46rT3qw4yuayqsMpClo8/zI6nvpdfRfisD9wVAGlWJmobckMUgHhdmsR2bOUsa9IA9LQOx0+hNs54atsfR+vxUObaawIDAQAB"]
  to   = cloudflare_dns_record.txt["moanclub.com|TXT|google-_domainkey-1"]
}

moved {
  from = cloudflare_dns_record.txt["moanclub.com|TXT|@|MS=ms20556898"]
  to   = cloudflare_dns_record.txt["moanclub.com|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["moanclub.com|TXT|@|google-site-verification=yqKoRMJ714_s8SCEjkaGOUxpWrDjsMWuUXkB3u3BEi4"]
  to   = cloudflare_dns_record.txt["moanclub.com|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.txt["moanclub.com|TXT|@|v=spf1 include:_spf.google.com include:spf.protection.outlook.com ~all"]
  to   = cloudflare_dns_record.txt["moanclub.com|TXT|apex-3"]
}

moved {
  from = cloudflare_dns_record.cname["molyfra.uk|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["molyfra.uk|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["molyfra.uk|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["molyfra.uk|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["molyfra.uk|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["molyfra.uk|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.mx["molyfra.uk|MX|@|molyfra-uk.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["molyfra.uk|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["molyfra.uk|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["molyfra.uk|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["molyfra.uk|TXT|asuid.crypto|094C19A879ADBD321825791B5F1433ECB226343E000DED0F02CF2391AB10C282"]
  to   = cloudflare_dns_record.txt["molyfra.uk|TXT|asuid-crypto-1"]
}

moved {
  from = cloudflare_dns_record.txt["molyfra.uk|TXT|@|MS=ms25053694"]
  to   = cloudflare_dns_record.txt["molyfra.uk|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["molyfra.uk|TXT|@|v=spf1 include:spf.protection.outlook.com -all"]
  to   = cloudflare_dns_record.txt["molyfra.uk|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.a["mx-mail.io|A|*|15.197.172.60"]
  to   = cloudflare_dns_record.a["mx-mail.io|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["mx-mail.io|A|@|15.197.172.60"]
  to   = cloudflare_dns_record.a["mx-mail.io|A|apex-2"]
}

moved {
  from = cloudflare_dns_record.a["mx-mail.io|A|www|15.197.172.60"]
  to   = cloudflare_dns_record.a["mx-mail.io|A|www-1"]
}

moved {
  from = cloudflare_dns_record.cname["mx-mail.io|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["mx-mail.io|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["mx-mail.io|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["mx-mail.io|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["mx-mail.io|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["mx-mail.io|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.cname["mx-mail.io|CNAME|selector1._domainkey|selector1-mxmail-io0e._domainkey.MolyneuxIO.q-v1.dkim.mail.microsoft"]
  to   = cloudflare_dns_record.cname["mx-mail.io|CNAME|selector1-_domainkey-1"]
}

moved {
  from = cloudflare_dns_record.cname["mx-mail.io|CNAME|selector2._domainkey|selector2-mxmail-io0e._domainkey.MolyneuxIO.q-v1.dkim.mail.microsoft"]
  to   = cloudflare_dns_record.cname["mx-mail.io|CNAME|selector2-_domainkey-1"]
}

moved {
  from = cloudflare_dns_record.mx["mx-mail.io|MX|@|mxmail-io0e.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["mx-mail.io|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["mx-mail.io|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["mx-mail.io|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["mx-mail.io|TXT|_dmarc|v=DMARC1; p=reject; rua=mailto:dmarc@mx-mail.io; fo=1"]
  to   = cloudflare_dns_record.txt["mx-mail.io|TXT|_dmarc-1"]
}

moved {
  from = cloudflare_dns_record.txt["mx-mail.io|TXT|molyneux.io._report._dmarc|v=DMARC1"]
  to   = cloudflare_dns_record.txt["mx-mail.io|TXT|molyneux-io-_report-_dmarc-1"]
}

moved {
  from = cloudflare_dns_record.txt["mx-mail.io|TXT|@|MS=ms67988408"]
  to   = cloudflare_dns_record.txt["mx-mail.io|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["mx-mail.io|TXT|@|v=spf1 include:spf.protection.outlook.com -all"]
  to   = cloudflare_dns_record.txt["mx-mail.io|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.txt["mx-mail.io|TXT|xtremeidiots.com._report._dmarc|v=DMARC1"]
  to   = cloudflare_dns_record.txt["mx-mail.io|TXT|xtremeidiots-com-_report-_dmarc-1"]
}

moved {
  from = cloudflare_dns_record.a["queensforsale.co.uk|A|@|144.217.22.232"]
  to   = cloudflare_dns_record.a["queensforsale.co.uk|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.a["queensforsale.co.uk|A|www|144.217.22.232"]
  to   = cloudflare_dns_record.a["queensforsale.co.uk|A|www-1"]
}

moved {
  from = cloudflare_dns_record.a["talkwithtiles.com|A|@|5.196.80.194"]
  to   = cloudflare_dns_record.a["talkwithtiles.com|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|www|talkwithtiles.com"]
  to   = cloudflare_dns_record.cname["talkwithtiles.com|CNAME|www-1"]
}

moved {
  from = cloudflare_dns_record.mx["talkwithtiles.com|MX|@|talkwithtiles-com.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["talkwithtiles.com|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["talkwithtiles.com|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["talkwithtiles.com|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["talkwithtiles.com|TXT|asuid.www|C075B21DD93CF3A5068CCD102CAD8F897ABA519285E86A80138B26D1D56703B6"]
  to   = cloudflare_dns_record.txt["talkwithtiles.com|TXT|asuid-www-1"]
}

moved {
  from = cloudflare_dns_record.txt["talkwithtiles.com|TXT|google._domainkey|v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkBkc54x+du5jnmjT62Re5GUsANEsJpX1RMh0anMhIUSwPfqMPXgE/cpTzUCfx3dP6bfOXx9avAigtP7i7kgW9KYUnO+A+ZOGtezDKwF4DX+8oTVJZnK+1myvHGgv+WMVo32jxveOylGKtt4BWW8sSJX1YtivqfvTWK/mlKODekUP3DqDAlM/xcxZNQoOSDUlpUnuJLGk/qJ5dKZrzk+N4LEfeAgWJ+adXOH7RoTNHrz4/dwxzKDmaEZ0X7MBB8wiziFOnrOJ+2Ou0ZyYotbfViktrzHAFl4JwjoBk4xfoL8R7pgNV4SRiF/U8u5ueXaU4BRIPM31+ZNX1Jn8PLJaMwIDAQAB"]
  to   = cloudflare_dns_record.txt["talkwithtiles.com|TXT|google-_domainkey-1"]
}

moved {
  from = cloudflare_dns_record.txt["talkwithtiles.com|TXT|@|MS=ms43281192"]
  to   = cloudflare_dns_record.txt["talkwithtiles.com|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["talkwithtiles.com|TXT|@|google-site-verification=1ceB4EmXkNGlYuTPgMd4K9Bj9zD81Jv9XrNFIb5n2S4"]
  to   = cloudflare_dns_record.txt["talkwithtiles.com|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.txt["talkwithtiles.com|TXT|@|v=spf1 include:_spf.google.com include:spf.protection.outlook.com ~all"]
  to   = cloudflare_dns_record.txt["talkwithtiles.com|TXT|apex-3"]
}

moved {
  from = cloudflare_dns_record.cname["travellingkermit.com|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["travellingkermit.com|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["travellingkermit.com|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["travellingkermit.com|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["travellingkermit.com|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["travellingkermit.com|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.mx["travellingkermit.com|MX|@|travellingkermit-com.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["travellingkermit.com|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["travellingkermit.com|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["travellingkermit.com|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["travellingkermit.com|TXT|@|MS=ms73828115"]
  to   = cloudflare_dns_record.txt["travellingkermit.com|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["travellingkermit.com|TXT|@|v=spf1 include:spf.protection.outlook.com -all"]
  to   = cloudflare_dns_record.txt["travellingkermit.com|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.a["xiredirect.com|A|www|198.27.126.226"]
  to   = cloudflare_dns_record.a["xiredirect.com|A|www-1"]
}

moved {
  from = cloudflare_dns_record.a["xiredirect.com|A|@|198.27.126.226"]
  to   = cloudflare_dns_record.a["xiredirect.com|A|apex-1"]
}

moved {
  from = cloudflare_dns_record.cname["xiredirect.com|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["xiredirect.com|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["xiredirect.com|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["xiredirect.com|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["xiredirect.com|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["xiredirect.com|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.mx["xiredirect.com|MX|@|xiredirect-com.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["xiredirect.com|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["xiredirect.com|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["xiredirect.com|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["xiredirect.com|TXT|@|MS=ms53518622"]
  to   = cloudflare_dns_record.txt["xiredirect.com|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["xiredirect.com|TXT|@|v=spf1 include:spf.protection.outlook.com -all"]
  to   = cloudflare_dns_record.txt["xiredirect.com|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.cname["xtre.co.uk|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["xtre.co.uk|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["xtre.co.uk|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["xtre.co.uk|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["xtre.co.uk|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["xtre.co.uk|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.mx["xtre.co.uk|MX|@|xtre-co-uk.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["xtre.co.uk|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["xtre.co.uk|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["xtre.co.uk|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["xtre.co.uk|TXT|@|MS=ms68580922"]
  to   = cloudflare_dns_record.txt["xtre.co.uk|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["xtre.co.uk|TXT|@|v=spf1 include:spf.protection.outlook.com -all"]
  to   = cloudflare_dns_record.txt["xtre.co.uk|TXT|apex-2"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector1-domainkey"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector1-_domainkey-1"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector2-domainkey"]
  to   = cloudflare_dns_record.cname["xtremeidiots.com|CNAME|selector2-_domainkey-1"]
}

moved {
  from = cloudflare_dns_record.a["xtremeidiots.net|A|redirect|192.95.23.11"]
  to   = cloudflare_dns_record.a["xtremeidiots.net|A|redirect-1"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.net|CNAME|autodiscover|autodiscover.outlook.com"]
  to   = cloudflare_dns_record.cname["xtremeidiots.net|CNAME|autodiscover-1"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.net|CNAME|enterpriseenrollment|enterpriseenrollment.manage.microsoft.com"]
  to   = cloudflare_dns_record.cname["xtremeidiots.net|CNAME|enterpriseenrollment-1"]
}

moved {
  from = cloudflare_dns_record.cname["xtremeidiots.net|CNAME|enterpriseregistration|enterpriseregistration.windows.net"]
  to   = cloudflare_dns_record.cname["xtremeidiots.net|CNAME|enterpriseregistration-1"]
}

moved {
  from = cloudflare_dns_record.mx["xtremeidiots.net|MX|@|xtremeidiots-net.mail.protection.outlook.com"]
  to   = cloudflare_dns_record.mx["xtremeidiots.net|MX|apex-1"]
}

moved {
  from = cloudflare_dns_record.srv["xtremeidiots.net|SRV|_sipfederationtls._tcp|sipfed.online.lync.com:5061"]
  to   = cloudflare_dns_record.srv["xtremeidiots.net|SRV|_sipfederationtls-_tcp-1"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.net|TXT|@|MS=ms93878704"]
  to   = cloudflare_dns_record.txt["xtremeidiots.net|TXT|apex-1"]
}

moved {
  from = cloudflare_dns_record.txt["xtremeidiots.net|TXT|@|v=spf1 include:spf.protection.outlook.com -all"]
  to   = cloudflare_dns_record.txt["xtremeidiots.net|TXT|apex-2"]
}

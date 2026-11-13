import json
import unittest
from pathlib import Path


ZONES = Path(__file__).resolve().parents[1] / "zones"


class CloudflareQuickWinsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.zones = [
            json.loads(path.read_text(encoding="utf-8"))
            for path in ZONES.glob("*.json")
        ]
        cls.cloudflare_zones = [
            zone for zone in cls.zones if zone.get("dns_provider") == "cloudflare"
        ]
        cls.xtremeidiots = next(
            zone for zone in cls.cloudflare_zones if zone["name"] == "xtremeidiots.com"
        )

    def test_managed_cloudflare_zones_use_tls_1_2_or_higher(self):
        managed = [
            zone for zone in self.cloudflare_zones
            if zone.get("management") == "terraform"
        ]
        self.assertTrue(managed)
        for zone in managed:
            with self.subTest(zone=zone["name"]):
                self.assertIn(zone["settings"]["min_tls_version"], ("1.2", "1.3"))

    def test_retired_tcadmin_configuration_is_absent(self):
        self.assertNotIn("tcadmin", json.dumps(self.xtremeidiots).lower())

    def test_rate_limits_target_www_and_describe_their_thresholds(self):
        rules = self.xtremeidiots["rulesets"]["http_ratelimit"]["rules"]
        self.assertEqual(len(rules), 2)
        expected = [
            (50, 10, "50 requests in 10 seconds - Challenge"),
            (150, 60, "150 requests in 1 minute - Challenge"),
        ]
        for rule, (requests, period, description) in zip(rules, expected):
            self.assertEqual(rule["expression"], '(http.host eq "www.xtremeidiots.com")')
            self.assertEqual(rule["action"], "managed_challenge")
            self.assertTrue(rule["enabled"])
            self.assertEqual(rule["ratelimit"]["requests_per_period"], requests)
            self.assertEqual(rule["ratelimit"]["period"], period)
            self.assertEqual(rule["description"], description)

    def test_managed_waf_runs_without_duc_exclusions(self):
        rules = self.xtremeidiots["rulesets"]["http_request_firewall_managed"]["rules"]
        self.assertEqual(len(rules), 3)
        for rule in rules:
            self.assertEqual(rule["action"], "execute")
            self.assertTrue(rule["enabled"])
            self.assertEqual(rule["expression"], "true")

    def test_free_waf_scopes_only_declared_proxied_web_hosts(self):
        expected = {
            "bishopsbees.co.uk": {"bishopsbees.co.uk", "www.bishopsbees.co.uk", "staging.bishopsbees.co.uk"},
            "bqba.co.uk": {"bqba.co.uk", "www.bqba.co.uk"},
            "buckfastqueen.co.uk": {"buckfastqueen.co.uk", "www.buckfastqueen.co.uk"},
            "dm-electricalservices.co.uk": {"dm-electricalservices.co.uk", "www.dm-electricalservices.co.uk"},
            "moanclub.com": {"moanclub.com", "www.moanclub.com"},
            "mx-mail.io": {"mx-mail.io", "www.mx-mail.io"},
            "queensforsale.co.uk": {"queensforsale.co.uk", "www.queensforsale.co.uk"},
            "talkwithtiles.com": {"talkwithtiles.com", "www.talkwithtiles.com"},
            "xtremeidiots.net": {"redirect.xtremeidiots.net"},
        }
        actual = {
            zone["name"]: set(zone["managed_waf_hostnames"])
            for zone in self.cloudflare_zones if zone.get("managed_waf_hostnames")
        }
        self.assertEqual(actual, expected)
        for zone in self.cloudflare_zones:
            if zone["name"] not in expected:
                continue
            proxied = {
                zone["name"] if record["name"] == "@" else record["name"] + "." + zone["name"]
                for record in zone["records"]
                if record.get("proxied") and record["type"] in ("A", "AAAA", "CNAME")
            }
            self.assertLessEqual(expected[zone["name"]], proxied)


if __name__ == "__main__":
    unittest.main()

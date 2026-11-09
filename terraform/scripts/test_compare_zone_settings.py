import io
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from compare_zone_settings import _read_zone_settings, compare_snapshot


def response(settings):
    return {"success": True, "result": settings}


class ZoneSettingsSnapshotTests(unittest.TestCase):
    def test_api_read_uses_bearer_token_without_returning_sensitive_response_body(self):
        body = b'{"success": true, "result": []}'
        response_context = io.BytesIO(body)
        with patch("compare_zone_settings.urlopen", return_value=response_context) as urlopen:
            _read_zone_settings("0" * 32, "synthetic-token")

        request = urlopen.call_args.args[0]
        self.assertEqual(request.headers["Authorization"], "Bearer synthetic-token")
        self.assertEqual(
            request.full_url,
            f"https://api.cloudflare.com/client/v4/zones/{'0' * 32}/settings",
        )

    def test_api_error_reports_status_without_response_body(self):
        error = HTTPError(
            "https://api.cloudflare.com/client/v4/zones/00000000000000000000000000000000/settings",
            403,
            "forbidden",
            {},
            io.BytesIO(b"synthetic-token"),
        )
        with patch("compare_zone_settings.urlopen", side_effect=error):
            with self.assertRaisesRegex(ValueError, "HTTP 403") as raised:
                _read_zone_settings("0" * 32, "synthetic-token")

        self.assertNotIn("synthetic-token", str(raised.exception))

    def test_exact_editable_settings_match_and_read_only_settings_are_ignored(self):
        expected = {
            "ssl": "strict",
            "browser_cache_ttl": 1382400,
            "mobile_redirect": {"status": "off", "mobile_subdomain": None},
        }
        live = response([
            {"id": "ssl", "editable": True, "value": "strict"},
            {"id": "browser_cache_ttl", "editable": True, "value": 1382400},
            {"id": "mobile_redirect", "editable": True, "value": {"status": "off"}},
            {"id": "read_only_setting", "editable": False, "value": "ignored"},
        ])

        self.assertEqual(compare_snapshot(expected, live), [])

    def test_configured_differences_fail_but_unmanaged_settings_are_preserved(self):
        expected = {"ssl": "strict"}
        live = response([
            {"id": "ssl", "editable": True, "value": "flexible"},
            {"id": "new_setting", "editable": True, "value": "on"},
        ])

        self.assertEqual(compare_snapshot(expected, live), ["ssl"])

    def test_missing_setting_and_invalid_api_response_fail_closed(self):
        self.assertEqual(compare_snapshot({"ssl": "strict"}, response([])), ["ssl"])
        with self.assertRaisesRegex(ValueError, "unsuccessful"):
            compare_snapshot({}, {"success": False, "result": []})
        with self.assertRaisesRegex(ValueError, "settings list"):
            compare_snapshot({}, {"success": True, "result": None})

    def test_duplicate_setting_ids_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            compare_snapshot({}, response([
                {"id": "ssl", "editable": True, "value": "strict"},
                {"id": "ssl", "editable": True, "value": "strict"},
            ]))

    def test_empty_object_is_not_equivalent_to_null(self):
        self.assertEqual(
            compare_snapshot(
                {"security_header": {"strict_transport_security": None}},
                response([{"id": "security_header", "editable": True, "value": None}]),
            ),
            ["security_header"],
        )

    def test_invalid_expected_snapshot_or_editability_metadata_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "JSON object"):
            compare_snapshot([], response([]))
        with self.assertRaisesRegex(ValueError, "invalid setting"):
            compare_snapshot({}, response([{"id": "ssl", "value": "strict"}]))


if __name__ == "__main__":
    unittest.main()

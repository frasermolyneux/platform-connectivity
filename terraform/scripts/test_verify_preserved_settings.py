import copy
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from verify_preserved_settings import verify


ROOT = Path(__file__).resolve().parents[1]
SETTINGS = json.loads((ROOT / "zones" / "xtremeidiots.com.json").read_text())["settings"]
QUERY = {"zone_id": "0" * 32, "settings": json.dumps(SETTINGS)}
LIVE = [{"id": key, "value": value, "editable": True} for key, value in SETTINGS.items()]


class PreservedSettingsTests(unittest.TestCase):
    def run_discovery(self, values):
        response = io.BytesIO(json.dumps({"success": True, "result": values}).encode())
        with patch("urllib.request.urlopen", return_value=response) as request:
            result = verify(QUERY, "disposable-token")
            self.assertEqual(request.call_args.args[0].get_method(), "GET")
            return result

    def test_exact_snapshot(self):
        self.assertEqual(self.run_discovery(LIVE), {"verified": "true"})

    def test_missing_duplicate_uneditable_and_changed_settings_fail(self):
        variants = [LIVE[:-1], LIVE + [LIVE[0]]]
        for field, value in (("editable", False), ("value", "strict")):
            changed = copy.deepcopy(LIVE)
            changed[0][field] = value
            variants.append(changed)
        for values in variants:
            with self.subTest(values=values), self.assertRaises((ValueError, KeyError)):
                self.run_discovery(values)

    def test_structured_values_are_checked_exactly(self):
        changed = copy.deepcopy(LIVE)
        setting = next(item for item in changed if item["id"] == "security_header")
        setting["value"]["strict_transport_security"]["enabled"] = True
        with self.assertRaises(ValueError):
            self.run_discovery(changed)


if __name__ == "__main__":
    unittest.main()

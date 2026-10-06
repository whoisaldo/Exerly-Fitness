import copy
import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location("release_checks", Path(__file__).parents[1] / "release_checks.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


class ReleaseChecksTests(unittest.TestCase):
    def setUp(self):
        self.info = {
            "CFBundleIdentifier": "com.exerly.fitness",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "2610061200",
            "EXERLY_API_BASE_URL": "https://api.example.test",
            "CFBundleIcons": {"CFBundlePrimaryIcon": {"CFBundleIconName": "AppIcon"}},
            "NSHealthShareUsageDescription": "Read steps and active energy with your permission.",
            "NSHealthUpdateUsageDescription": "Save workouts with your permission.",
            "NSAppTransportSecurity": {"NSAllowsArbitraryLoads": False},
        }
        self.privacy = {
            "NSPrivacyTracking": False,
            "NSPrivacyTrackingDomains": [],
            "NSPrivacyAccessedAPITypes": [{
                "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
            }],
        }

    def validate(self):
        checks.validate_metadata(self.info, self.privacy, "1.0", "2610061200")

    def test_accepts_release_metadata(self):
        self.validate()

    def test_staging_requires_explicit_validation_and_exact_internal_endpoint(self):
        self.info["EXERLY_API_BASE_URL"] = "http://100.80.149.7:39110"
        self.info["EXERLY_BUILD_ENVIRONMENT"] = "staging"
        with self.assertRaises(ValueError):
            self.validate()
        checks.validate_metadata(self.info, self.privacy, "1.0", "2610061200", internal_staging=True)
        for endpoint in ["http://100.80.149.7:3001", "http://example.test", "http://100.80.149.7:39110/other"]:
            self.info["EXERLY_API_BASE_URL"] = endpoint
            with self.subTest(endpoint=endpoint), self.assertRaises(ValueError):
                checks.validate_metadata(self.info, self.privacy, "1.0", "2610061200", internal_staging=True)

    def test_rejects_wrong_identity_or_version(self):
        for key, value in [("CFBundleIdentifier", "other.app"), ("CFBundleVersion", "1"),
                           ("CFBundleShortVersionString", "0.9")]:
            with self.subTest(key=key):
                original = self.info[key]
                self.info[key] = value
                with self.assertRaises(ValueError):
                    self.validate()
                self.info[key] = original

    def test_rejects_local_http_and_credentialled_release_endpoints(self):
        for url in ["http://api.example.test", "https://localhost", "https://127.0.0.1",
                    "https://100.80.149.7:39200", "https://10.1.2.3", "https://[::1]",
                    "https://user:password@api.example.test", "$(EXERLY_API_BASE_URL)"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.info["EXERLY_API_BASE_URL"] = url
                self.validate()

    def test_rejects_missing_icons_privacy_reason_or_health_purpose(self):
        del self.info["CFBundleIcons"]
        with self.assertRaises(ValueError):
            self.validate()
        self.setUp()
        self.privacy["NSPrivacyAccessedAPITypes"] = []
        with self.assertRaises(ValueError):
            self.validate()
        self.setUp()
        self.info["NSHealthShareUsageDescription"] = ""
        with self.assertRaises(ValueError):
            self.validate()

    def test_rejects_tracking_and_unrestricted_http(self):
        self.privacy["NSPrivacyTracking"] = True
        with self.assertRaises(ValueError):
            self.validate()
        self.setUp()
        self.info["NSAppTransportSecurity"]["NSAllowsArbitraryLoads"] = True
        with self.assertRaises(ValueError):
            self.validate()

    def test_profile_must_be_exerly_distribution_with_healthkit(self):
        from datetime import datetime, timedelta, timezone
        profile = {
            "UUID": "test-profile", "TeamIdentifier": ["9X79V37Q89"],
            "ExpirationDate": datetime.now(timezone.utc) + timedelta(days=30),
            "Entitlements": {"application-identifier": "9X79V37Q89.com.exerly.fitness",
                             "get-task-allow": False, "com.apple.developer.healthkit": True},
        }
        checks.validate_profile(profile)
        for key, value in [("application-identifier", "9X79V37Q89.some.other.app"),
                           ("get-task-allow", True), ("com.apple.developer.healthkit", False)]:
            invalid = copy.deepcopy(profile)
            invalid["Entitlements"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                checks.validate_profile(invalid)
        profile["ExpirationDate"] = datetime.now(timezone.utc) - timedelta(days=1)
        with self.assertRaises(ValueError):
            checks.validate_profile(profile)


if __name__ == "__main__":
    unittest.main()

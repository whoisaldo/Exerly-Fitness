#!/usr/bin/env python3
"""Validate Exerly's release payload before any upload. No credentials are read."""
import argparse
from datetime import datetime, timezone
import ipaddress
from pathlib import Path
import plistlib
import subprocess
from urllib.parse import urlparse

BUNDLE = "com.exerly.fitness"
TEAM = "9X79V37Q89"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_metadata(info, privacy, version, build, internal_staging=False):
    for key, expected in [("CFBundleIdentifier", BUNDLE),
                          ("CFBundleShortVersionString", version), ("CFBundleVersion", build)]:
        require(info.get(key) == expected, f"Unexpected {key}")
    endpoint = urlparse(info.get("EXERLY_API_BASE_URL", ""))
    if internal_staging:
        require(info.get("EXERLY_BUILD_ENVIRONMENT") == "staging"
                and info.get("EXERLY_API_BASE_URL") == "http://100.80.149.7:39110",
                "Internal staging must use the authorized devbox1 API")
    else:
        require(endpoint.scheme == "https" and endpoint.hostname and not endpoint.username
                and not endpoint.password, "Release API must use public HTTPS without credentials")
        host = endpoint.hostname.lower()
        require(host != "localhost" and not host.endswith((".local", ".ts.net")), "Local release API")
        try:
            address = ipaddress.ip_address(host)
        except ValueError:
            address = None
        if address:
            require(address.is_global, "Private release API")
    require(not info.get("NSAppTransportSecurity", {}).get("NSAllowsArbitraryLoads", False),
            "Release cannot allow arbitrary HTTP")
    require(info.get("CFBundleIcons", {}).get("CFBundlePrimaryIcon", {}).get("CFBundleIconName") == "AppIcon",
            "Missing compiled AppIcon")
    for key in ["NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"]:
        require(bool(info.get(key, "").strip()), f"Missing {key}")
    require(privacy.get("NSPrivacyTracking") is False, "Tracking must be disabled")
    require(not privacy.get("NSPrivacyTrackingDomains"), "Tracking domains are not permitted")
    reasons = {item.get("NSPrivacyAccessedAPIType"): item.get("NSPrivacyAccessedAPITypeReasons", [])
               for item in privacy.get("NSPrivacyAccessedAPITypes", [])}
    require("CA92.1" in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", []),
            "Missing app-only UserDefaults reason")


def validate_profile(profile):
    entitlements = profile.get("Entitlements", {})
    require(profile.get("TeamIdentifier") == [TEAM], "Profile team mismatch")
    require(entitlements.get("application-identifier") == f"{TEAM}.{BUNDLE}", "Profile is for another app")
    require(entitlements.get("get-task-allow") is False, "Profile allows debugging")
    require(entitlements.get("com.apple.developer.healthkit") is True, "Profile lacks HealthKit")
    require(not profile.get("ProvisionedDevices") and not profile.get("ProvisionsAllDevices"),
            "Profile is not for App Store distribution")
    expiry = profile.get("ExpirationDate")
    require(isinstance(expiry, datetime), "Profile expiry missing")
    require(expiry.replace(tzinfo=timezone.utc) > datetime.now(timezone.utc), "Expired profile")


def read_profile(path):
    return plistlib.loads(subprocess.run(["security", "cms", "-D", "-i", str(path)],
                                        capture_output=True, check=True).stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--unsigned", action="store_true")
    parser.add_argument("--internal-staging", action="store_true")
    args = parser.parse_args()
    app = args.archive / "Products/Applications/Exerly.app"
    info = plistlib.loads((app / "Info.plist").read_bytes())
    privacy = plistlib.loads((app / "PrivacyInfo.xcprivacy").read_bytes())
    validate_metadata(info, privacy, args.version, args.build, args.internal_staging)
    require((app / "Assets.car").is_file(), "Compiled assets missing")
    binary = subprocess.run(["strings", str(app / "Exerly")], capture_output=True, text=True, check=True).stdout
    for marker in ["--ui-testing", "EXERLY_TEST_STORE_ID", "EXERLY_TEST_LEGACY_TOKEN"]:
        require(marker not in binary, f"Debug fixture marker in release binary: {marker}")
    if not args.unsigned:
        validate_profile(read_profile(app / "embedded.mobileprovision"))
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        raw = subprocess.run(["codesign", "-d", "--entitlements", ":-", str(app)],
                             capture_output=True, check=True).stdout
        entitlements = plistlib.loads(raw)
        require(entitlements.get("application-identifier") == f"{TEAM}.{BUNDLE}", "Signature identity mismatch")
        require(entitlements.get("com.apple.developer.healthkit") is True, "Signed app lacks HealthKit")
        require(not entitlements.get("get-task-allow", False), "Signed app allows debugging")
    print(f"Verified Exerly {args.version} ({args.build}); {'unsigned' if args.unsigned else 'signed'} archive")


if __name__ == "__main__":
    main()

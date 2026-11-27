#!/usr/bin/env python3
"""Generate exportOptions.plist from a decoded .mobileprovision file."""
import os
import plistlib
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: gen_export_options.py <decoded_profile.plist> <output.plist>", file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f:
        profile = plistlib.load(f)
    profile_name = profile.get("Name", "")
    bundle_id = os.environ.get("BUNDLE_ID", "com.yourteam.axoverlay")
    team_id = os.environ.get("TEAM_ID", "")
    if not team_id:
        entitlements = profile.get("Entitlements", {}) or {}
        app_id = entitlements.get("application-identifier", "") or ""
        team_id = app_id.split(".")[0]
    if not profile_name:
        print("cannot resolve provisioning profile Name", file=sys.stderr)
        return 2

    options = {
        "method": "development",
        "signingStyle": "manual",
        "teamID": team_id,
        "provisioningProfiles": {bundle_id: profile_name},
        "compileBitcode": False,
        "stripSwiftSymbols": True,
        "uploadSymbols": False,
        "destination": "export",
    }
    with open(dst, "wb") as f:
        plistlib.dump(options, f)
    print(f"wrote {dst}: team={team_id} profile={profile_name} bundle={bundle_id}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

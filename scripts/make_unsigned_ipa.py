#!/usr/bin/env python3
"""Wrap a .app bundle produced by xcodebuild into an unsigned IPA."""
import os
import sys
import zipfile


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: make_unsigned_ipa.py <APP_PATH> <OUTPUT_IPA>", file=sys.stderr)
        return 2
    app_path = os.path.abspath(sys.argv[1])
    output_ipa = os.path.abspath(sys.argv[2])
    if not os.path.isdir(app_path):
        print(f"app not found: {app_path}", file=sys.stderr)
        return 2

    payload_root = os.path.dirname(output_ipa)
    os.makedirs(payload_root, exist_ok=True)
    tmp_ipa = output_ipa + ".tmp"
    app_name = os.path.basename(app_path)
    with zipfile.ZipFile(tmp_ipa, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(app_path):
            dirs.sort()
            for name in sorted(files):
                full = os.path.join(root, name)
                rel = os.path.relpath(full, os.path.dirname(app_path))
                zf.write(full, os.path.join("Payload", rel))
    os.replace(tmp_ipa, output_ipa)
    print(f"wrote {output_ipa} ({os.path.getsize(output_ipa)} bytes, app={app_name})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

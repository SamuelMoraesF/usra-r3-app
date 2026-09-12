"""Derive a reproducible, increasing Android version code from a release tag."""
import re
import sys

match = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", sys.argv[1])
if not match:
    sys.exit("Use a stable release tag in the format vMAJOR.MINOR.PATCH")
major, minor, patch = map(int, match.groups())
if major > 2099 or minor > 999 or patch > 999:
    sys.exit("Version exceeds supported limits (2099.999.999)")
code = major * 1_000_000 + minor * 1_000 + patch
if code < 1:
    sys.exit("Version must be greater than v0.0.0")
print(f"RELEASE_VERSION={major}.{minor}.{patch}")
print(f"RELEASE_BUILD={code}")

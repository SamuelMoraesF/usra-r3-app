"""Generate a local backup and upload Android signing secrets via gh."""
import base64
import json
import os
from pathlib import Path
import secrets
import subprocess

repo = "SamuelMoraesF/usra-r3-app"
os.umask(0o077)
directory = Path(__file__).resolve().parents[1] / ".release-signing"
directory.mkdir(exist_ok=True)
credentials_file = directory / "credentials.json"
keystore = directory / "release.jks"
if not credentials_file.exists():
    if keystore.exists():
        raise SystemExit("Existing keystore found without credentials; refusing to overwrite")
    existing = json.loads(subprocess.check_output(
        ["gh", "secret", "list", "--repo", repo, "--json", "name"]
    ))
    if any(item["name"].startswith("ANDROID_KEY") for item in existing):
        raise SystemExit("Signing secrets already exist; restore their local backup first")
    credentials = {
        "ANDROID_KEYSTORE_PASSWORD": secrets.token_urlsafe(32),
        "ANDROID_KEY_PASSWORD": secrets.token_urlsafe(32),
        "ANDROID_KEY_ALIAS": "usra-r3-release",
    }
    credentials_file.write_text(json.dumps(credentials, indent=2) + "\n")
else:
    credentials = json.loads(credentials_file.read_text())
if not keystore.exists():
    subprocess.run([
        "keytool", "-genkeypair", "-noprompt", "-storetype", "JKS",
        "-keystore", str(keystore), "-alias", credentials["ANDROID_KEY_ALIAS"],
        "-storepass:env", "ANDROID_KEYSTORE_PASSWORD",
        "-keypass:env", "ANDROID_KEY_PASSWORD",
        "-keyalg", "RSA", "-keysize", "3072", "-validity", "10000",
        "-dname", "CN=USRA R3 App",
    ], env={**os.environ, **credentials}, check=True)
values = {**credentials, "ANDROID_KEYSTORE_BASE64": base64.b64encode(keystore.read_bytes()).decode()}
for name, value in values.items():
    subprocess.run(["gh", "secret", "set", name, "--repo", repo], input=value, text=True, check=True)
    print(f"Configured {name}")
print(f"Keep an encrypted backup of {directory}")

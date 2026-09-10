#!/usr/bin/env bash
set -euo pipefail

config="${1:-tool/maps.json}"
command -v pmtiles >/dev/null || {
  echo "Erro: instale o binário pmtiles e deixe-o no PATH." >&2
  echo "Veja: https://github.com/protomaps/go-pmtiles/releases" >&2
  exit 1
}

python3 - "$config" <<'PY'
import json
import os
import subprocess
import sys

config_path = sys.argv[1]
with open(config_path, encoding="utf-8") as file:
    config = json.load(file)

source = os.environ.get("PROTOMAPS_SOURCE", config["source"])
for city in config["cities"]:
    output = city["output"]
    os.makedirs(os.path.dirname(output), exist_ok=True)
    bbox = ",".join(str(value) for value in city["bbox"])
    command = [
        "pmtiles", "extract", source, output,
        f"--bbox={bbox}",
        f"--minzoom={city['minzoom']}",
        f"--maxzoom={city['maxzoom']}",
        "--overfetch=0",
    ]
    print("+", " ".join(command))
    subprocess.run(command, check=True)
PY

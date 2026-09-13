#!/usr/bin/env bash
set -euo pipefail

config="${1:-tool/maps.json}"
command -v gdalbuildvrt >/dev/null || { echo "Erro: instale GDAL (gdalbuildvrt, gdalwarp e gdal_translate)." >&2; exit 1; }
command -v curl >/dev/null || { echo "Erro: instale curl para baixar os tiles de elevação." >&2; exit 1; }

python3 - "$config" <<'PY'
import gzip, json, math, os, shutil, subprocess, sys, tempfile
from concurrent.futures import ThreadPoolExecutor

with open(sys.argv[1], encoding="utf-8") as file:
    config = json.load(file)
bucket = os.environ.get("ELEVATION_BUCKET", "https://s3.amazonaws.com/elevation-tiles-prod/skadi")
# Three arc-seconds (~90 m) keeps the bundled offline asset compact while
# preserving useful relief for the map heatmap.
resolution = float(os.environ.get("ELEVATION_STEP_DEGREES", 1 / 1200))

for item in config.get("areas", []) + config.get("cities", []):
    west, south, east, north = item["bbox"]
    item_id = item["id"]
    output_dir = os.path.dirname(item["output"])
    os.makedirs(output_dir, exist_ok=True)
    base = os.path.join(output_dir, f"{item_id}-elevation")
    output_bin, output_hdr, output_meta = f"{base}.bin", f"{base}.hdr", f"{base}.json"
    with tempfile.TemporaryDirectory(prefix=f"{item_id}-dem-") as work:
        jobs = []
        for lat in range(math.floor(south), math.ceil(north)):
            ns = "N" if lat >= 0 else "S"
            for lon in range(math.floor(west), math.ceil(east)):
                ew = "E" if lon >= 0 else "W"
                name = f"{ns}{abs(lat):02d}{ew}{abs(lon):03d}"
                jobs.append((name, f"{bucket}/{ns}{abs(lat):02d}/{name}.hgt.gz"))

        def download(job):
            name, url = job
            compressed, raw = os.path.join(work, name + ".hgt.gz"), os.path.join(work, name + ".hgt")
            print("+", url, flush=True)
            subprocess.run(["curl", "--fail", "--location", "--retry", "3", "-C", "-", "-o", compressed, url], check=True, stdout=subprocess.DEVNULL)
            with gzip.open(compressed, "rb") as source, open(raw, "wb") as target:
                shutil.copyfileobj(source, target)
            return raw

        with ThreadPoolExecutor(max_workers=min(6, len(jobs))) as pool:
            tiles = list(pool.map(download, jobs))
        tile_list = os.path.join(work, "tiles.txt")
        with open(tile_list, "w", encoding="utf-8") as file:
            file.write("\n".join(tiles) + "\n")
        vrt = os.path.join(work, "mosaic.vrt")
        subprocess.run(["gdalbuildvrt", "-overwrite", "-input_file_list", tile_list, vrt], check=True)
        cropped = os.path.join(work, "cropped.tif")
        subprocess.run(["gdalwarp", "-overwrite", "-te", str(west), str(south), str(east), str(north), "-te_srs", "EPSG:4326", "-tr", str(resolution), str(resolution), "-r", "bilinear", "-ot", "Int16", "-dstnodata", "-32768", vrt, cropped], check=True)
        subprocess.run(["gdal_translate", "-of", "ENVI", "-ot", "Int16", "-co", "INTERLEAVE=BIP", cropped, output_bin], check=True)
        info = json.loads(subprocess.check_output(["gdalinfo", "-json", "-stats", cropped], text=True))
        size_x, size_y = info["size"]
        transform = info["geoTransform"]
        band = info.get("bands", [{}])[0]
        metadata = {
            "version": 1, "source": "NASA SRTM 1 arc-second (USGS/NASA) via elevation-tiles-prod",
            "west": transform[0], "north": transform[3], "east": transform[0] + transform[1] * size_x,
            "south": transform[3] + transform[5] * size_y, "stepLongitude": abs(transform[1]),
            "stepLatitude": abs(transform[5]), "columns": size_x, "rows": size_y, "nodata": -32768,
            "minimum": band.get("minimum", band.get("computedMin")), "maximum": band.get("maximum", band.get("computedMax")),
        }
        with open(output_meta, "w", encoding="utf-8") as file:
            json.dump(metadata, file, indent=2); file.write("\n")
    os.remove(output_hdr)
    aux = f"{output_bin}.aux.xml"
    if os.path.exists(aux): os.remove(aux)
    print(f"Gerado: {output_bin} ({os.path.getsize(output_bin)} bytes)")
    print(f"Metadados: {output_meta}")
PY

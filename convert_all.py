"""Convert reMarkable .rmdoc archives to Excalidraw markdown, preserving the
tablet's folder hierarchy. Each .rmdoc is processed in isolation so a single
failure does not abort the whole run.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

if len(sys.argv) != 3:
    print("usage: convert_all.py <download_dir> <output_dir>", file=sys.stderr)
    sys.exit(2)

download_dir = Path(sys.argv[1]).resolve()
output_dir = Path(sys.argv[2]).resolve()
output_dir.mkdir(parents=True, exist_ok=True)

rmdocs = sorted(download_dir.rglob("*.rmdoc"))
print(f"[convert-all] found {len(rmdocs)} .rmdoc files under {download_dir}")

ok = 0
skipped = 0
for rmdoc in rmdocs:
    rel_folder = rmdoc.parent.relative_to(download_dir)
    target_dir = output_dir / rel_folder
    target_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="rm-xochitl-") as tmp:
        try:
            with zipfile.ZipFile(rmdoc) as zf:
                zf.extractall(tmp)
        except zipfile.BadZipFile as e:
            print(f"[skip] {rmdoc.relative_to(download_dir)}: bad zip: {e}")
            skipped += 1
            continue

        try:
            subprocess.run(
                ["python", "/app/main.py", "-i", tmp, "-o", str(target_dir)],
                check=True, timeout=180,
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            )
            ok += 1
        except subprocess.CalledProcessError as e:
            print(f"[skip] {rmdoc.relative_to(download_dir)}: converter exited {e.returncode}")
            skipped += 1
        except subprocess.TimeoutExpired:
            print(f"[skip] {rmdoc.relative_to(download_dir)}: timeout")
            skipped += 1

print(f"[convert-all] ok={ok} skipped={skipped}")

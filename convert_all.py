"""Run remarkable-obsidian-sync's main.py once per document UUID to isolate errors."""
import os
import shutil
import subprocess
import sys
import tempfile

if len(sys.argv) != 3:
    print("usage: convert_all.py <xochitl_dir> <output_dir>", file=sys.stderr)
    sys.exit(2)

in_dir, out_dir = sys.argv[1], sys.argv[2]
os.makedirs(out_dir, exist_ok=True)

uuids = sorted(
    d for d in os.listdir(in_dir)
    if os.path.isdir(os.path.join(in_dir, d))
)

ok, skipped = 0, 0
for uuid in uuids:
    with tempfile.TemporaryDirectory(prefix=f"rm-{uuid[:8]}-") as tmp:
        for ext in ("content", "metadata", "pagedata", "pdf", "epub"):
            src = os.path.join(in_dir, f"{uuid}.{ext}")
            if os.path.exists(src):
                shutil.copy(src, tmp)
        src_sub = os.path.join(in_dir, uuid)
        if os.path.isdir(src_sub):
            shutil.copytree(src_sub, os.path.join(tmp, uuid))
        try:
            subprocess.run(
                ["python", "/app/main.py", "-i", tmp, "-o", out_dir],
                check=True, timeout=180,
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
            )
            ok += 1
        except subprocess.CalledProcessError as e:
            print(f"[skip] {uuid}: converter exited {e.returncode}")
            skipped += 1
        except subprocess.TimeoutExpired:
            print(f"[skip] {uuid}: timeout")
            skipped += 1

print(f"[convert-all] ok={ok} skipped={skipped}")

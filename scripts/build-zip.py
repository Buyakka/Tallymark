# Builds the release zip: dist/Tallymark-<version>.zip with the Tallymark
# folder inside, ready to upload. The version is read from the TOC.
# Run from anywhere:  py scripts/build-zip.py
import os
import re
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Tallymark")
DIST = os.path.join(ROOT, "dist")
SKIP = {"Thumbs.db", "desktop.ini", ".DS_Store"}

with open(os.path.join(SRC, "Tallymark_Forever.toc"), encoding="utf-8") as f:
    version = re.search(r"^## Version:\s*(\S+)", f.read(), re.M).group(1)

os.makedirs(DIST, exist_ok=True)
out = os.path.join(DIST, "Tallymark-" + version + ".zip")
count = 0
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in os.walk(SRC):
        for name in sorted(files):
            if name in SKIP:
                continue
            path = os.path.join(folder, name)
            rel = os.path.relpath(path, ROOT).split(os.sep)
            z.write(path, "/".join(rel))
            count += 1

print("Built " + out + " (" + str(count) + " files, " + str(os.path.getsize(out) // 1024) + " KB)")

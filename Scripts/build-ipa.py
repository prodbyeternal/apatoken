#!/usr/bin/env python3
"""Fresh device build, verified resources, and a new IPA directly on Desktop."""
from datetime import datetime
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import shutil
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("localizations", ROOT / "Scripts/verify-localizations.py")
localizations = importlib.util.module_from_spec(spec)
spec.loader.exec_module(localizations)
source_tables = localizations.verify_sources()
stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
build = ROOT / "Builds" / stamp
build.mkdir(parents=True)
with (build / "build.log").open("w") as log:
    subprocess.run(["xcodebuild", "-project", "APATOKEN.xcodeproj", "-target", "APATOKEN", "-sdk", "iphoneos",
                    "-configuration", "Release", "ARCHS=arm64", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO",
                    f"SYMROOT={build}", f"OBJROOT={build}/Intermediates", "build"], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
app = build / "Release-iphoneos/iAPATOKEN.app"
info = plistlib.loads((app / "Info.plist").read_bytes())
version = info["CFBundleShortVersionString"]
number = info["CFBundleVersion"]
for family in ("CFBundleIcons", "CFBundleIcons~ipad"):
    primary = info[family]["CFBundlePrimaryIcon"]
    for name in primary["CFBundleIconFiles"]:
        assert list(app.glob(name + "*.png")), f"Missing icon: {name}"
for filename, size in [("AppIcon60x60@2x.png", 120), ("AppIcon60x60@3x.png", 180), ("AppIcon76x76@2x.png", 152), ("AppIcon83.5x83.5@2x.png", 167), ("AppIcon1024.png", 1024)]:
    data = (app / filename).read_bytes()
    # Xcode may rewrite PNGs with a CgBI chunk; locate IHDR rather than assuming an offset.
    header = data.index(b"IHDR") + 4
    width, height, depth = struct.unpack(">IIB", data[header:header + 9])
    assert (width, height, depth) == (size, size, 8), f"Incorrect icon: {filename}"
for logo in ("apator_logo.jpg", "eternal_logo.jpg", "apatoken_logo.png"):
    assert (app / logo).stat().st_size > 0, f"Missing logo: {logo}"
tables = {lang: localizations.decode_strings((app / f"{lang}.lproj/Localizable.strings").read_bytes()) for lang in localizations.LANGUAGES}
localizations.verify_tables(tables)
assert tables == source_tables, "Built strings differ from the source translations"
ipa = Path.home() / "Desktop" / f"iAPATOKEN-{version}-build{number}-{stamp}.ipa"
with zipfile.ZipFile(ipa, "x", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in sorted(app.rglob("*")):
        if path.is_file():
            archive.write(path, "Payload/iAPATOKEN.app/" + str(path.relative_to(app)))
with zipfile.ZipFile(ipa) as archive:
    assert archive.testzip() is None
    for path in app.rglob("*"):
        if path.is_file():
            assert archive.read("Payload/iAPATOKEN.app/" + str(path.relative_to(app))) == path.read_bytes(), f"Stale packaged file: {path}"
latest = Path.home() / "Desktop/iAPATOKEN.ipa"
shutil.copy2(ipa, latest)
digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
report = f"IPA: {ipa}\nLatest copy: {latest}\nVersion: {version} ({number})\nSHA-256: {digest}\nSource build: {build}\nVerified: all packaged bytes match the fresh app; en/pl/fr tables; iPhone/iPad icons; logos.\n"
(build / "verification.txt").write_text(report)
print(report)

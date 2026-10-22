#!/usr/bin/env python3
"""Fetch and verify the pinned public survival-package colon trial data.

The unmodified cancer.rda contains the original colon object together with
other package datasets. Loading only that object is the preparation helper's
responsibility. The original dictionary and randomization description are
retained, along with the package license declaration and GNU license texts.
"""

import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import urllib.request


COMMIT = "b76de62301f2ed4efcdbd8c062acc6759a54e511"
REPOSITORY = "https://github.com/therneau/survival"
RAW_BASE = f"https://raw.githubusercontent.com/therneau/survival/{COMMIT}/"
R_COMMIT = "afa4d6c2b0163d85790d5f188e0cf09b99004fcd"
LICENSE_BASE = f"https://raw.githubusercontent.com/wch/r-source/{R_COMMIT}/share/licenses/"
FILES = (
    ("cancer.rda", RAW_BASE + "data/cancer.rda", 171118,
     "31f15835cfc5cb7c3b1ba0556acc4c9a34f4ab318cb2a28ba47b2a6045cd773f"),
    ("colon.Rd", RAW_BASE + "man/colon.Rd", 3200,
     "dc231706d01d695d8e35153acc49d79187df532318b3991dfada9dfa8ee22069"),
    ("DESCRIPTION", RAW_BASE + "DESCRIPTION", 898,
     "70d443f5c447ff1b505a9e39c8e3af2d5bb7be22cc344adbc447010daf3f41ce"),
    ("survival.Rnw", RAW_BASE + "vignettes/survival.Rnw", 173152,
     "1948df993345e9a9ed73a0b81b7cf712527498cf17c854dbaff877f76996b285"),
    ("LGPL-2", LICENSE_BASE + "LGPL-2", 25292,
     "655bbf126cb0247df3a5cfce85e2293e76a1cbd588568b3b482b6e5029646097"),
    ("GPL-2", LICENSE_BASE + "GPL-2", 18092,
     "8177f97513213526df2cf6184d8ff986c675afb514d4e68a404010521b880643"),
)


def validate(path, byte_count, sha256):
    content = path.read_bytes()
    if len(content) != byte_count or hashlib.sha256(content).hexdigest() != sha256:
        raise RuntimeError(f"Size or SHA-256 mismatch: {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path,
        default=Path(__file__).resolve().parents[1] / "data" / "colon",
    )
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest_files = []
    for filename, url, byte_count, sha256 in FILES:
        target = args.output_dir / filename
        if target.exists():
            validate(target, byte_count, sha256)
        elif args.verify_only:
            raise FileNotFoundError(target)
        else:
            request = urllib.request.Request(url, headers={"User-Agent": "jcod-colon-data/1.0"})
            with urllib.request.urlopen(request, timeout=60) as response:
                content = response.read(byte_count + 1)
            if len(content) != byte_count or hashlib.sha256(content).hexdigest() != sha256:
                raise RuntimeError(f"Downloaded content failed verification: {url}")
            with tempfile.NamedTemporaryFile(dir=args.output_dir, delete=False) as stream:
                stream.write(content)
                temporary = Path(stream.name)
            try:
                temporary.replace(target)
            finally:
                temporary.unlink(missing_ok=True)
        manifest_files.append({"file": filename, "url": url,
                               "bytes": byte_count, "sha256": sha256})
        print(f"Verified {filename}")
    manifest = {
        "dataset": "colon object in the public survival package",
        "source_repository": REPOSITORY,
        "source_commit": COMMIT,
        "source_package_version": "3.8-13",
        "verified_equal_installed_colon_version": "3.8-3",
        "license": "LGPL (>= 2), as declared in the original package DESCRIPTION",
        "license_text_source": "GNU license texts supplied by the R source distribution",
        "license_text_source_commit": R_COMMIT,
        "dataset_specific_license": "No separate dataset-specific license was supplied",
        "files": manifest_files,
    }
    manifest_path = args.output_dir / "manifest.json"
    serialized = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    if args.verify_only:
        if not manifest_path.exists() or manifest_path.read_text() != serialized:
            raise RuntimeError("Provenance manifest is missing or differs from the pinned record")
    else:
        manifest_path.write_text(serialized)


if __name__ == "__main__":
    main()

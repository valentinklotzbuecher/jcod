#!/usr/bin/env python3
"""Fetch the pinned public IST version-2 release and verify every file.

The Edinburgh deposit is canonical. This script uses a fixed public mirror
commit because that deposit is not reachable from the prepared cloud runtime.
No unverified fallback source is used.
"""

import argparse
import hashlib
import json
from pathlib import Path
import tempfile
import urllib.parse
import urllib.request


COMMIT = "e9ebea9d6202bed786abc89785740e13ac087fed"
REPOSITORY = "https://github.com/ebergel/ist-1-database"
RAW_BASE = f"https://raw.githubusercontent.com/ebergel/ist-1-database/{COMMIT}/"
FILES = (
    ("data/IST_corrected.csv", "IST_corrected.csv", 4798288,
     "a350aed2329bbcde23c05caaa96b9275b44b017adecc2fd02231d590454695d5"),
    ("docs/IST_variables.csv", "IST_variables.csv", 6129,
     "bab564a5e44328d4c8c1cce534d029366d2847c79548d8a5de5f00f2d1bbcf8c"),
    ("license_text", "license_text", 20765,
     "48d327284f2e0eb65312be37199ca20695eae409777e9aca99156ec309959626"),
    ("docs/IST version 2 additional commentary.pdf",
     "IST version 2 additional commentary.pdf", 9307,
     "eb392b636feb05a8e4b442a54f8ec959b72206376bd282adcceeb82f599b4208"),
    ("docs/IST_database_paper.pdf", "IST_database_paper.pdf", 88482,
     "168a482f078e3581dc9e7f09d30c13ecddf89fa8af96e720808f4fc1a78e4b0d"),
)


def validate(path, byte_count, sha256):
    content = path.read_bytes()
    if len(content) != byte_count or hashlib.sha256(content).hexdigest() != sha256:
        raise RuntimeError(f"Size or SHA-256 mismatch: {path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path,
        default=Path(__file__).resolve().parents[1] / "data" / "ist",
    )
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest_files = []
    for source_path, filename, byte_count, sha256 in FILES:
        url = RAW_BASE + urllib.parse.quote(source_path, safe="/")
        target = args.output_dir / filename
        if target.exists():
            validate(target, byte_count, sha256)
        elif args.verify_only:
            raise FileNotFoundError(target)
        else:
            request = urllib.request.Request(url, headers={"User-Agent": "jcod-ist-data/1.0"})
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
        manifest_files.append({
            "file": filename, "source_path": source_path, "url": url,
            "bytes": byte_count, "sha256": sha256,
        })
        print(f"Verified {filename}")
    manifest = {
        "dataset": "International Stroke Trial database, version 2 (corrected)",
        "canonical_dataset": "https://doi.org/10.7488/ds/104",
        "database_paper": "https://doi.org/10.1186/1745-6215-12-101",
        "correction": "https://doi.org/10.1186/1745-6215-13-24",
        "mirror_repository": REPOSITORY,
        "mirror_commit": COMMIT,
        "license": "ODC Attribution License v1.0",
        "license_url": "https://opendatacommons.org/licenses/by/1-0/",
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

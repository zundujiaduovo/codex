"""Verify that V10's frozen V8 engine differs only in function identifiers."""
from pathlib import Path
import hashlib
import json
import re


def check(root):
    manifest = json.loads((root / 'V8_SEARCH_SNAPSHOT.json').read_text())
    reverse = {new: old for old, new in manifest['renames'].items()}
    for entry in manifest['files']:
        text = (root / 'matlab' / entry['frozen']).read_text()
        for new, old in sorted(reverse.items(), key=lambda p: -len(p[0])):
            text = re.sub(r'\b' + re.escape(new) + r'\b', old, text)
        assert hashlib.sha256(text.encode()).hexdigest() == entry['originalSha256'], entry['frozen']
    print(f"PASS: {len(manifest['files'])} frozen V8 files match {manifest['commit']} after identifier reversal.")


if __name__ == '__main__':
    check(Path(__file__).resolve().parents[1])

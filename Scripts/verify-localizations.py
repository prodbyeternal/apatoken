#!/usr/bin/env python3
"""Validate the actual plist format Xcode reads, exact key coverage and UI literals."""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ("en", "pl", "fr")


def decode_strings(data):
    result = subprocess.run(["plutil", "-convert", "json", "-o", "-", "--", "-"],
                            input=data, capture_output=True, check=True)
    return json.loads(result.stdout)


def verify_tables(tables):
    source = "\n".join(p.read_text() for p in (ROOT / "APATOKEN").rglob("*.swift"))
    required = set(re.findall(r'(?:LocalizedKey|L\.text)\("([^"\\]+)"\)', source))
    for lang in LANGUAGES:
        table = tables[lang]
        missing = required - table.keys()
        assert not missing, f"{lang}: missing keys {sorted(missing)}"
        assert table.keys() == tables["en"].keys(), f"{lang}: key sets differ"
        for key, value in table.items():
            assert value and not re.search(r'\b(?:txt|msg)[A-Z]\w*', value), f"{lang}: placeholder {key}={value}"
            assert sorted(re.findall(r'\{\d+\}', value)) == sorted(re.findall(r'\{\d+\}', tables['en'][key])), f"{lang}: format arguments differ for {key}"
        assert "txtCodename" not in table
    return len(required)


def verify_sources():
    tables = {}
    for lang in LANGUAGES:
        path = ROOT / f"APATOKEN/Resources/{lang}.lproj/Localizable.strings"
        keys = re.findall(r'^"([^"\\]+)"\s*=', path.read_text(), re.M)
        assert len(keys) == len(set(keys)), f"{lang}: duplicate keys"
        tables[lang] = decode_strings(path.read_bytes())
    required = verify_tables(tables)
    for path in (ROOT / "APATOKEN/Views").rglob("*.swift"):
        for text in re.findall(r'(?:Text|Label|Section|Button|navigationTitle)\("([^"\n]*)"', path.read_text()):
            assert not re.search(r'[A-Za-z]{2}', text) or '\\(' in text or text == 'kWh', f"Hardcoded UI text in {path}: {text}"
    print(f"Localization checks passed: {required} used keys, {len(tables['en'])} translations per language, no raw UI literals.")
    return tables


if __name__ == "__main__":
    verify_sources()

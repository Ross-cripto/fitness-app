#!/usr/bin/env python3
"""Copies the PNG attachments exported by `xcresulttool export attachments` to a folder with readable names.

Usage: collect-screenshots.py <exported-dir> <output-dir>
Attachment names are set in ScreenshotTests (e.g. "es-1-workouts"); Xcode appends "_<n>_<UUID>" to them.
"""
import json
import os
import re
import shutil
import sys

source, target = sys.argv[1], sys.argv[2]
os.makedirs(target, exist_ok=True)
manifest_path = os.path.join(source, "manifest.json")
copied = 0

if os.path.exists(manifest_path):
    with open(manifest_path) as handle:
        manifest = json.load(handle)
    for test in manifest:
        for attachment in test.get("attachments", []):
            exported = attachment.get("exportedFileName", "")
            human = attachment.get("suggestedHumanReadableName", exported)
            if not exported.lower().endswith(".png"):
                continue
            name = re.sub(r"_\d+_[0-9A-Fa-f-]{36}(\.png)?$", "", human)
            name = re.sub(r"[^A-Za-z0-9._-]+", "-", name) or "screenshot"
            shutil.copy(os.path.join(source, exported), os.path.join(target, name + ".png"))
            copied += 1
else:
    # Fallback: keep whatever PNGs are there.
    for entry in sorted(os.listdir(source)):
        if entry.lower().endswith(".png"):
            shutil.copy(os.path.join(source, entry), os.path.join(target, entry))
            copied += 1

print(f"collected {copied} screenshots")

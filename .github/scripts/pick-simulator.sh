#!/bin/bash
# Prints the UDID of an iPhone simulator that exists on this runner, creating one when none does.
# Runner images change which devices are pre-installed, so the workflow must not hard-code a device name.
set -euo pipefail

udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "iOS" not in runtime:
        continue
    for device in devices[runtime]:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
')

if [ -z "$udid" ]; then
  runtime=$(xcrun simctl list runtimes available -j | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"] if r["identifier"].split(".")[-1].startswith("iOS") and r.get("isAvailable")]
print(runtimes[-1]["identifier"] if runtimes else "")
')
  type=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
types = [t for t in json.load(sys.stdin)["devicetypes"] if t["name"].startswith("iPhone")]
print(types[-1]["identifier"] if types else "")
')
  udid=$(xcrun simctl create "CI iPhone" "$type" "$runtime")
fi

echo "$udid"

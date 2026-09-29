#!/bin/bash
# Builds Momentum and installs it on a USB- or Wi-Fi-connected iPhone. Run on a Mac with Xcode 15.3+.
#
#   scripts/install-on-phone.sh --team ABCDE12345 [--bundle-id com.yourname.momentum] [--device "My iPhone"]
#
# --team       your Apple Developer Team ID (Xcode > Settings > Accounts > your team; a free Apple ID works)
# --bundle-id  must be unique to you (default com.<your mac username>.momentum)
# --device     device name or UDID (default: the first connected iPhone)
#
# One-time on the phone: Settings > Privacy & Security > Developer Mode > On (it restarts), and after the first
# install trust yourself under Settings > General > VPN & Device Management. A free Apple ID's builds expire
# after 7 days: run this script again to renew.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="${TEAM_ID:-}"
BUNDLE="com.$(whoami | tr -cd 'a-zA-Z0-9').momentum"
DEVICE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --team) TEAM="$2"; shift 2 ;;
    --bundle-id) BUNDLE="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TEAM" ]; then
  echo "Missing --team. Find your Team ID in Xcode > Settings > Accounts (select your team), or at developer.apple.com > Membership." >&2
  exit 2
fi

command -v xcodebuild >/dev/null || { echo "Xcode is required (install it from the App Store)." >&2; exit 1; }
command -v xcodegen >/dev/null || brew install xcodegen

echo "==> Generating the Xcode project"
xcodegen generate

echo "==> Finding your iPhone"
LIST="$(mktemp)"
xcrun devicectl list devices --json-output "$LIST" >/dev/null 2>&1 || true
UDID="$(python3 - "$LIST" "$DEVICE" <<'PY'
import json, sys
path, wanted = sys.argv[1], sys.argv[2].lower()
try:
    devices = json.load(open(path))["result"]["devices"]
except Exception:
    devices = []
for d in devices:
    hw, props, conn = d.get("hardwareProperties", {}), d.get("deviceProperties", {}), d.get("connectionProperties", {})
    if hw.get("platform") != "iOS" or conn.get("tunnelState") == "unavailable":
        continue
    name, udid = props.get("name", ""), hw.get("udid", "")
    if not wanted or wanted in (name.lower(), udid.lower()):
        print(udid)
        break
PY
)"
rm -f "$LIST"
if [ -z "$UDID" ]; then
  echo "No iPhone found. Connect it with a cable, unlock it, tap 'Trust', and turn on Developer Mode (Settings > Privacy & Security)." >&2
  exit 1
fi
echo "    device: $UDID"

echo "==> Building (first time takes a few minutes)"
xcodebuild \
  -project Momentum.xcodeproj -scheme Momentum -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM" PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" CODE_SIGN_STYLE=Automatic \
  build | tail -n 25

APP="build/Build/Products/Debug-iphoneos/Momentum.app"
[ -d "$APP" ] || { echo "Build did not produce $APP" >&2; exit 1; }

echo "==> Installing on the phone"
xcrun devicectl device install app --device "$UDID" "$APP"
echo "==> Launching"
xcrun devicectl device process launch --device "$UDID" "$BUNDLE" || \
  echo "Installed. If it does not open, trust the developer profile: Settings > General > VPN & Device Management."
echo "Done. Bundle id: $BUNDLE"

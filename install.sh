#!/bin/bash
set -e
if [ "$(id -u)" -eq 0 ]; then echo "Run this as your normal user, not root."; exit 1; fi
APPLET_ID="io.github.micahottah.otterblink"
D=$(cd "$(dirname "$0")" && pwd)
H=$HOME

echo "== packages"
if command -v kpackagetool6 >/dev/null 2>&1; then
  echo "kpackagetool6 found, nothing to install"
else
  sudo dnf install -y kf6-kpackage
fi

echo "== applet files"
mkdir -p "$H/plasmoids/$APPLET_ID"
cp -rv "$D/files/home/plasmoid/." "$H/plasmoids/$APPLET_ID/"

echo "== applet"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "$APPLET_ID"; then
  kpackagetool6 -t Plasma/Applet -u "$H/plasmoids/$APPLET_ID"
else
  kpackagetool6 -t Plasma/Applet -i "$H/plasmoids/$APPLET_ID"
fi

echo
echo "Done. Restart the panel with: plasmashell --replace >/dev/null 2>&1 & disown"
echo "Then add the 'Otter Blink' widget to a panel, and run verify.sh."

#!/bin/bash
APPLET_ID="io.github.micahottah.otterblink"
DISK_RE='^(sd[a-z]+|hd[a-z]+|vd[a-z]+|nvme[0-9]+n[0-9]+|mmcblk[0-9]+)$'
ok=0
bad=0
chk() {
  if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; ok=$((ok+1)); else echo "FAIL  $1"; bad=$((bad+1)); fi
}
applet_ok() {
  [ -d "/usr/share/plasma/plasmoids/$APPLET_ID" ] || kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q "$APPLET_ID"
}

chk "kpackagetool6 available" 'command -v kpackagetool6'
chk "applet installed" applet_ok
chk "/proc/diskstats readable" '[ -r /proc/diskstats ]'
chk "/proc/net/dev readable" '[ -r /proc/net/dev ]'
chk "Dirty counter in /proc/meminfo" 'grep -q "^Dirty:" /proc/meminfo'
chk "default disk filter matches a disk" 'awk "{print \$3}" /proc/diskstats | grep -Eq "$DISK_RE"'
chk "Ethernet or Wi-Fi interface present" 'grep -Eq "^ *(en|eth|wl|wlan)[^:]*:" /proc/net/dev'

echo
echo "Disks matched by the default filter:"
awk '{print $3}' /proc/diskstats | grep -E "$DISK_RE" | sed 's/^/  /'
echo "Network interfaces:"
ip -br link | sed 's/^/  /'

echo
echo "$ok passed, $bad failed"
[ "$bad" -eq 0 ]

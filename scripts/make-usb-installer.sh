#!/usr/bin/env bash
# Build a bootable macOS Tahoe recovery USB with this EFI (Linux).
#   ./scripts/make-usb-installer.sh download            # fetch macOS recovery + HeliPort only (no USB touched)
#   sudo ./scripts/make-usb-installer.sh /dev/sdX       # ERASE /dev/sdX, then write EFI + recovery
# Needs: python3, parted, mkfs.vfat (dosfstools), rsync, curl access to Apple's CDN.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CACHE="${CACHE:-$HOME/.cache/helios-macos-recovery}"
OC_VER="1.0.8"
OC_URL="https://github.com/acidanthera/OpenCorePkg/releases/download/$OC_VER/OpenCore-$OC_VER-RELEASE.zip"
# Board id for the latest macOS recovery (OpenCore macrecovery README, "Latest version")
BOARD_ID="Mac-CFF7D910A743CAAF"
HELIPORT_VER="v1.5.0"   # latest stable; needed to join Wi-Fi with itlwm
HELIPORT_ALPHA="v2.0.0-alpha"   # fallback build (new UI, testing only)

download_recovery() {
  [ -s "$CACHE/com.apple.recovery.boot/BaseSystem.dmg" ] && { echo "Recovery already cached in $CACHE"; return; }
  mkdir -p "$CACHE"; cd "$CACHE"
  if [ ! -f macrecovery/macrecovery.py ]; then
    curl -fsSL -o oc.zip "$OC_URL"
    unzip -qo oc.zip 'Utilities/macrecovery/*' -d oc
    mv oc/Utilities/macrecovery macrecovery; rm -rf oc oc.zip
  fi
  python3 -I macrecovery/macrecovery.py -b "$BOARD_ID" -m 00000000000000000 -os latest -o com.apple.recovery.boot download
  ls -lh com.apple.recovery.boot
}

download_heliport() {
  mkdir -p "$CACHE"
  [ -s "$CACHE/HeliPort.dmg" ] || curl -fsSL -o "$CACHE/HeliPort.dmg" "https://github.com/OpenIntelWireless/HeliPort/releases/download/$HELIPORT_VER/HeliPort.dmg"
  [ -s "$CACHE/HeliPort-$HELIPORT_ALPHA.dmg" ] || curl -fsSL -o "$CACHE/HeliPort-$HELIPORT_ALPHA.dmg" "https://github.com/OpenIntelWireless/HeliPort/releases/download/$HELIPORT_ALPHA/HeliPort.dmg"
  ls -lh "$CACHE"/HeliPort*.dmg
}

[ $# -eq 1 ] || { sed -n '2,6p' "$0"; exit 1; }
if [ "$1" = download ]; then download_recovery; download_heliport; exit 0; fi

DEV="$1"
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo."; exit 1; }
[ -b "$DEV" ] || { echo "$DEV is not a block device."; exit 1; }
[ "$(lsblk -dno TYPE "$DEV")" = disk ] || { echo "$DEV must be a whole disk (e.g. /dev/sdb), not a partition."; exit 1; }
[ "$(lsblk -dno RM "$DEV")" = 1 ] || [ "$(lsblk -dno TRAN "$DEV")" = usb ] || { echo "$DEV is not removable/USB. Refusing."; exit 1; }
if lsblk -no MOUNTPOINTS "$DEV" | grep -qE '^(/|/boot|/boot/efi|/home)$'; then echo "$DEV holds a system mount. Refusing."; exit 1; fi

download_recovery; download_heliport
echo; lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS "$DEV"
read -r -p "ALL DATA on $DEV will be ERASED. Type the device path to confirm: " ans
[ "$ans" = "$DEV" ] || { echo "Aborted."; exit 1; }

for p in $(lsblk -lno PATH "$DEV" | tail -n +2); do umount "$p" 2>/dev/null || true; done
parted -s "$DEV" mklabel gpt mkpart OPENCORE fat32 1MiB 100% set 1 esp on
partprobe "$DEV"; sleep 2
PART="$(lsblk -lno PATH "$DEV" | sed -n 2p)"
mkfs.vfat -F 32 -n OPENCORE "$PART"
MNT="$(mktemp -d)"; trap 'umount "$MNT" 2>/dev/null || true; rmdir "$MNT"' EXIT
mount "$PART" "$MNT"
rsync -rt --no-perms --no-owner --no-group "$ROOT/EFI" "$MNT/"
rsync -rt --no-perms --no-owner --no-group "$CACHE/com.apple.recovery.boot" "$MNT/"
mkdir -p "$MNT/HeliPort"; cp "$CACHE"/HeliPort*.dmg "$MNT/HeliPort/"
sync
echo "Done. HeliPort.dmg is on the USB (HeliPort/) - install it in macOS after the first boot. Boot the laptop from this USB -> OpenCore -> 'macOS Base System (External)' -> Disk Utility (erase target as APFS/GUID) -> Reinstall macOS (needs internet; Wi-Fi via itlwm needs HeliPort, so use Ethernet or USB tethering)."

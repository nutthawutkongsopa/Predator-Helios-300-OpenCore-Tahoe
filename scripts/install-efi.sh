#!/usr/bin/env bash
# Replace the OpenCore already on this machine's ESP with this repo's EFI/OC (Linux).
#   sudo ./scripts/install-efi.sh [--dry-run] [--esp /boot/efi]
# - backs up every existing OpenCore folder (EFI/OC*, detected by OpenCore.efi) to ~/efi-backup/<ts>.tar.gz
# - installs EFI/OC, removes the old OC folders, and swaps the UEFI boot entries (efibootmgr)
# - never touches EFI/Boot, Microsoft, ubuntu, kali. Repo EFI/BOOT/BOOTx64.efi is NOT copied (would clobber the fallback loader).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ESP=/boot/efi; DRY=0
while [ $# -gt 0 ]; do case "$1" in
  --dry-run) DRY=1 ;; --esp) ESP="$2"; shift ;; *) sed -n '2,6p' "$0"; exit 1 ;; esac; shift; done
run() { if [ $DRY = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
[ $DRY = 1 ] || [ "$(id -u)" -eq 0 ] || { echo "Run with sudo (or --dry-run)."; exit 1; }
mountpoint -q "$ESP" || { echo "$ESP is not a mount point."; exit 1; }
[ -f "$ROOT/EFI/OC/OpenCore.efi" ] && [ -f "$ROOT/EFI/OC/config.plist" ] || { echo "EFI/OC missing in repo."; exit 1; }

# Existing OpenCore folders on the ESP
OLD=(); for d in "$ESP"/EFI/*/; do [ -f "$d/OpenCore.efi" ] && OLD+=("$(basename "$d")"); done
echo "Existing OpenCore folders: ${OLD[*]:-none}"

# Backup
TS="$(date +%Y%m%d-%H%M%S)"; BK="${SUDO_USER:+/home/$SUDO_USER}"; BK="${BK:-$HOME}/efi-backup"
if [ ${#OLD[@]} -gt 0 ]; then
  run mkdir -p "$BK"
  run tar -czf "$BK/oc-$TS.tar.gz" -C "$ESP/EFI" "${OLD[@]}"
  [ $DRY = 1 ] || { ls -lh "$BK/oc-$TS.tar.gz"; [ -n "${SUDO_USER:-}" ] && chown -R "$SUDO_USER" "$BK"; }
fi

# Install new EFI/OC (stage first, then swap)
NEW="$ESP/EFI/OC"
run rm -rf "$ESP/EFI/.OC-new"
run mkdir -p "$ESP/EFI/.OC-new"
run rsync -rt --no-perms --no-owner --no-group "$ROOT/EFI/OC/" "$ESP/EFI/.OC-new/"
if [ $DRY = 0 ]; then
  cmp -s "$ROOT/EFI/OC/OpenCore.efi" "$ESP/EFI/.OC-new/OpenCore.efi" && cmp -s "$ROOT/EFI/OC/config.plist" "$ESP/EFI/.OC-new/config.plist" || { echo "Copy verification failed; old EFI untouched."; exit 1; }
fi
for o in "${OLD[@]}"; do run rm -rf "$ESP/EFI/$o"; done
run mv "$ESP/EFI/.OC-new" "$NEW"
run sync

# UEFI boot entries
if command -v efibootmgr >/dev/null; then
  SRC="$(findmnt -no SOURCE "$ESP")"; DISK="/dev/$(lsblk -no PKNAME "$SRC")"; PARTN="$(cat /sys/class/block/$(basename "$SRC")/partition)"
  ORDER="$(efibootmgr | sed -n 's/^BootOrder: //p')"
  OLDNUMS="$(efibootmgr | grep -E '\\EFI\\OC[^\\]*\\OpenCore\.efi' | sed -E 's/^Boot([0-9A-F]{4}).*/\1/' || true)"
  # position of the first old OC entry in BootOrder (0 if none)
  POS=0; i=0; for n in ${ORDER//,/ }; do [ "$POS" = 0 ] && echo "$OLDNUMS" | grep -qx "$n" && POS=$i; i=$((i+1)); done
  for n in $OLDNUMS; do run efibootmgr -q -b "$n" -B; done
  run efibootmgr -q -c -d "$DISK" -p "$PARTN" -L "OpenCore Tahoe" -l '\EFI\OC\OpenCore.efi'
  if [ $DRY = 0 ]; then
    NEWNUM="$(efibootmgr | sed -n 's/^Boot\([0-9A-F]\{4\}\)\* OpenCore Tahoe$/\1/p' | head -1)"
    REST=(); for n in ${ORDER//,/ }; do echo "$OLDNUMS" | grep -qx "$n" || [ "$n" = "$NEWNUM" ] || REST+=("$n"); done
    FINAL=("${REST[@]:0:$POS}" "$NEWNUM" "${REST[@]:$POS}")
    efibootmgr -q -o "$(IFS=,; echo "${FINAL[*]}")"
  else echo "[dry-run] insert new entry at BootOrder position $POS (removing: ${OLDNUMS:-none})"; fi
  efibootmgr | head -3
else echo "efibootmgr not found - add \\EFI\\OC\\OpenCore.efi manually in the BIOS boot menu."; fi
echo "Done. Backup: ${BK}/oc-$TS.tar.gz. Reboot and pick 'OpenCore Tahoe' (or F12 menu)."

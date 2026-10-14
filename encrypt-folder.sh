#!/usr/bin/env bash
#
# encrypt-folder.sh — password-protect a file or folder as an encrypted .dmg (macOS).
#
# Does the same thing as Disk Utility > File > New Image > Image from Folder,
# then verifies the image opens and its contents match the original, and
# (optionally) moves the unencrypted original to the Trash.
#
# Usage:
#   ./encrypt-folder.sh [options] <file-or-folder>
#
# Options:
#   -o <file.dmg>   Output path (default: <name>.dmg next to the original;
#                   for a file, the extension is dropped: taxes.pdf -> taxes.dmg)
#   -a 128|256      AES key size (default: 256)
#   -w              Read/write image (can add/change files later).
#                   Default is read-only (compressed).
#   -t              After a successful verify, move the original file or
#                   folder to the Trash (asks for confirmation first).
#   -h              Show this help.
#
# Opening the image later: double-click the .dmg, enter the password, and a
# drive appears in Finder. Eject it when you're done.

set -euo pipefail

usage() { sed -n '3,23p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
die()   { echo "Error: $*" >&2; exit 1; }

out=""
aes=256
format="UDZO"   # read-only, compressed
trash=0

while getopts ":o:a:wth" opt; do
  case "$opt" in
    o) out="$OPTARG" ;;
    a) aes="$OPTARG" ;;
    w) format="UDRW" ;;
    t) trash=1 ;;
    h) usage 0 ;;
    :) die "option -$OPTARG needs a value." ;;
    *) usage 1 ;;
  esac
done
shift $((OPTIND - 1))

[[ "$(uname)" == "Darwin" ]] || die "this script only runs on macOS (it uses hdiutil)."

[[ $# -eq 1 ]] || usage 1
src="${1%/}"
[[ -e "$src" ]] || die "'$src' does not exist."
[[ -d "$src" || -f "$src" ]] || die "'$src' is not a file or folder."
[[ "$aes" == "128" || "$aes" == "256" ]] || die "-a must be 128 or 256."

name="$(basename "$src")"
if [[ -f "$src" ]]; then
  what="file"
  volname="${name%.*}"; [[ -n "$volname" ]] || volname="$name"   # taxes.pdf -> taxes
else
  what="folder"
  volname="$name"
fi
[[ -n "$out" ]] || out="$(dirname "$src")/$volname.dmg"
[[ "$out" == *.dmg ]] || out="$out.dmg"
[[ ! -e "$out" ]] || die "'$out' already exists; pick another name with -o."

# --- Password (asked twice, never shown or stored) ---------------------------
read -r -s -p "Password: " pw;  echo
read -r -s -p "Verify password: " pw2; echo
[[ -n "$pw" ]]        || die "password cannot be empty."
[[ "$pw" == "$pw2" ]] || die "passwords do not match."
unset pw2
(( ${#pw} >= 8 )) || echo "Warning: that password is short; 12+ characters is much safer." >&2

# --- Stage a single file in its own folder (hdiutil images a folder) ---------
# A hard link avoids leaving an extra unencrypted copy; fall back to a copy if
# the temp folder is on another disk. Either way it's removed when we exit.
stage=""
if [[ "$what" == "file" ]]; then
  stage="$(mktemp -d)"
  ln "$src" "$stage/$name" 2>/dev/null || cp -p "$src" "$stage/$name"
  srcdir="$stage"
else
  srcdir="$src"
fi
remove_stage() { [[ -z "$stage" ]] || rm -rf "$stage"; }
trap remove_stage EXIT

# --- Create the encrypted image ----------------------------------------------
[[ "$format" == "UDRW" ]] && kind="read/write" || kind="read-only"
echo "Creating $kind AES-$aes image: $out"
printf '%s\0' "$pw" | hdiutil create \
  -srcfolder "$srcdir" \
  -volname "$volname" \
  -encryption "AES-$aes" \
  -stdinpass \
  -format "$format" \
  "$out" >/dev/null

# Make sure the image really is encrypted before going any further.
# (Captured into a variable, not piped into grep: with pipefail, grep -q exiting
# early can make the pipeline "fail" and wrongly delete a good image.)
enc="$(hdiutil isencrypted "$out" 2>/dev/null || true)"
if [[ "$enc" != *"encrypted: YES"* ]]; then
  rm -f "$out"
  die "the image was created WITHOUT encryption; deleted it. Nothing else was changed."
fi

# --- Verify: mount it with the password and compare contents -----------------
echo "Verifying the image opens and matches the original..."
mnt="$(mktemp -d)"
# Unmount the image. If it stayed mounted, double-clicking the .dmg would open it
# WITHOUT asking for the password, so retry with -force and complain loudly.
# (rmdir fails on a folder that is still a mount point, so it doubles as the
# "is it still mounted?" check; matching `mount` output is unreliable on macOS
# because mktemp's /var/... path shows up there as /private/var/....)
cleanup() {
  if ! rmdir "$mnt" 2>/dev/null; then
    hdiutil detach "$mnt" -quiet 2>/dev/null \
      || { sleep 2; hdiutil detach "$mnt" -force -quiet 2>/dev/null; } \
      || true
    rmdir "$mnt" 2>/dev/null \
      || echo "WARNING: could not unmount the image. Run: hdiutil detach -force \"$mnt\"" >&2
  fi
  remove_stage
}
trap cleanup EXIT

printf '%s\0' "$pw" | hdiutil attach "$out" \
  -stdinpass -readonly -nobrowse -mountpoint "$mnt" >/dev/null
unset pw

if diff -rq "$srcdir" "$mnt" >/dev/null 2>&1; then
  echo "OK: image opened with your password and all files match."
else
  echo "WARNING: contents differ from the original. Keeping the original $what." >&2
  diff -rq "$srcdir" "$mnt" >&2 || true
  exit 1
fi
cleanup
trap - EXIT

# --- Optionally trash the unencrypted original -------------------------------
if (( trash )); then
  read -r -p "Move the original $what '$src' to the Trash? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    abs="$(cd "$(dirname "$src")" && pwd)/$name"
    abs="${abs//\\/\\\\}"; abs="${abs//\"/\\\"}"   # escape for AppleScript
    osascript -e "tell application \"Finder\" to delete POSIX file \"$abs\"" >/dev/null
    echo "Moved to Trash (empty the Trash to remove it for good)."
  else
    echo "Original kept."
  fi
fi

echo "Done: $out"
echo "To open it later, double-click the .dmg and enter your password; eject when finished."

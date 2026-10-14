#!/usr/bin/env bash
#
# encrypt-folder.sh — password-protect a folder as an encrypted .dmg (macOS).
#
# Does the same thing as Disk Utility > File > New Image > Image from Folder,
# then verifies the image opens and its contents match the original, and
# (optionally) moves the unencrypted original to the Trash.
#
# Usage:
#   ./encrypt-folder.sh [options] <folder>
#
# Options:
#   -o <file.dmg>   Output path (default: <folder>.dmg next to the folder)
#   -a 128|256      AES key size (default: 256)
#   -w              Read/write image (can add/change files later).
#                   Default is read-only (compressed).
#   -t              After a successful verify, move the original folder to
#                   the Trash (asks for confirmation first).
#   -h              Show this help.
#
# Opening the image later: double-click the .dmg, enter the password, and a
# drive appears in Finder. Eject it when you're done.

set -euo pipefail

usage() { sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
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
[[ -d "$src" ]] || die "'$src' is not a folder."
[[ "$aes" == "128" || "$aes" == "256" ]] || die "-a must be 128 or 256."

name="$(basename "$src")"
[[ -n "$out" ]] || out="$(dirname "$src")/$name.dmg"
[[ "$out" == *.dmg ]] || out="$out.dmg"
[[ ! -e "$out" ]] || die "'$out' already exists; pick another name with -o."

# --- Password (asked twice, never shown or stored) ---------------------------
read -r -s -p "Password: " pw;  echo
read -r -s -p "Verify password: " pw2; echo
[[ -n "$pw" ]]        || die "password cannot be empty."
[[ "$pw" == "$pw2" ]] || die "passwords do not match."
unset pw2
(( ${#pw} >= 8 )) || echo "Warning: that password is short; 12+ characters is much safer." >&2

# --- Create the encrypted image ----------------------------------------------
[[ "$format" == "UDRW" ]] && kind="read/write" || kind="read-only"
echo "Creating $kind AES-$aes image: $out"
printf '%s\0' "$pw" | hdiutil create \
  -srcfolder "$src" \
  -volname "$name" \
  -encryption "AES-$aes" \
  -stdinpass \
  -format "$format" \
  "$out" >/dev/null

# --- Verify: mount it with the password and compare contents -----------------
echo "Verifying the image opens and matches the original..."
mnt="$(mktemp -d)"
cleanup() { hdiutil detach "$mnt" -quiet 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true; }
trap cleanup EXIT

printf '%s\0' "$pw" | hdiutil attach "$out" \
  -stdinpass -readonly -nobrowse -mountpoint "$mnt" >/dev/null
unset pw

if diff -rq "$src" "$mnt" >/dev/null 2>&1; then
  echo "OK: image opened with your password and all files match."
else
  echo "WARNING: contents differ from the original. Keeping the original folder." >&2
  diff -rq "$src" "$mnt" >&2 || true
  exit 1
fi
cleanup
trap - EXIT

# --- Optionally trash the unencrypted original -------------------------------
if (( trash )); then
  read -r -p "Move the original folder '$src' to the Trash? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    abs="$(cd "$src" && pwd)"
    abs="${abs//\\/\\\\}"; abs="${abs//\"/\\\"}"   # escape for AppleScript
    osascript -e "tell application \"Finder\" to delete POSIX file \"$abs\"" >/dev/null
    echo "Moved to Trash (empty the Trash to remove it for good)."
  else
    echo "Original kept."
  fi
fi

echo "Done: $out"
echo "To open it later, double-click the .dmg and enter your password; eject when finished."

#!/bin/bash
# Icelandic hyphenation & spelling installer for Adobe InDesign (macOS).
#
# One-liner (downloads everything it needs):
#   curl -fsSL https://raw.githubusercontent.com/arnorb/hunspell-is-indesign/main/install.sh | sudo bash
#
# Usage (from a checkout, or appended to the one-liner after `bash -s --`):
#   sudo ./install.sh                    # install into every detected InDesign version
#   sudo ./install.sh 2025 2026          # only these versions
#   sudo ./install.sh --hyph-only        # hyphenation only, no spellcheck
#   sudo ./install.sh --uninstall        # remove from every detected version
#   sudo ./install.sh 2025 --uninstall   # remove from one version
#
# Detects InDesign versions in /Applications. Idempotent; re-run after Adobe
# updates. See scripts/install-core.sh for what it does per version.
set -euo pipefail

REPO_TARBALL="https://github.com/arnorb/hunspell-is-indesign/archive/refs/heads/main.tar.gz"

usage() {
  cat <<'EOF'
Icelandic hyphenation & spelling installer for Adobe InDesign (macOS).

One-liner (downloads everything it needs):
  curl -fsSL https://raw.githubusercontent.com/arnorb/hunspell-is-indesign/main/install.sh | sudo bash

Usage:
  sudo ./install.sh                    # install into every detected InDesign version
  sudo ./install.sh 2025 2026          # only these versions
  sudo ./install.sh --hyph-only        # hyphenation only, no spellcheck
  sudo ./install.sh --uninstall        # remove from every detected version
  sudo ./install.sh 2025 --uninstall   # remove from one version

With the one-liner, pass options after `sudo bash -s --`, e.g.:
  curl -fsSL .../install.sh | sudo bash -s -- --uninstall

Idempotent; re-run after Adobe updates.
EOF
}

MODE=""
YEARS=()
for ARG in "$@"; do
  case "$ARG" in
    --uninstall|--hyph-only)
      if [ -n "$MODE" ] && [ "$MODE" != "$ARG" ]; then
        echo "ERROR: --hyph-only and --uninstall can't be combined"; exit 1
      fi
      MODE="$ARG" ;;
    20[0-9][0-9]) YEARS+=("$ARG") ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument '$ARG' (expected a year like 2026, --hyph-only or --uninstall)"; exit 1 ;;
  esac
done

SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$(dirname "$SELF")/scripts/install-core.sh" ]; then
  DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
  # Running via `curl | bash` (or a lone copy of this script):
  # fetch the repo so the dictionaries and core script are available.
  echo "Downloading hunspell-is-indesign..."
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fsSL "$REPO_TARBALL" | tar -xz -C "$TMP"
  DIR="$TMP/hunspell-is-indesign-main"
  [ -f "$DIR/scripts/install-core.sh" ] || { echo "ERROR: download failed"; exit 1; }
fi
CORE="$DIR/scripts/install-core.sh"

if [ ${#YEARS[@]} -eq 0 ]; then
  for APP in "/Applications/Adobe InDesign "20*; do
    [ -d "$APP" ] || continue
    YEAR="${APP##* }"
    PLIST="$APP/Resources/Dictionaries/LILO/Linguistics/Providers/Plugins2/AdobeHunspellPlugin.bundle/Contents/Info.plist"
    [ -f "$PLIST" ] && YEARS+=("$YEAR")
  done
  [ ${#YEARS[@]} -gt 0 ] || { echo "ERROR: no InDesign installation found in /Applications"; exit 1; }
  echo "Detected InDesign: ${YEARS[*]}"
fi

RC=0
for YEAR in "${YEARS[@]}"; do
  echo "--- InDesign $YEAR ---"
  if [ -n "$MODE" ]; then
    bash "$CORE" "$YEAR" "$MODE" || RC=1
  else
    bash "$CORE" "$YEAR" || RC=1
  fi
  echo
done

if [ $RC -eq 0 ] && [ "$MODE" != "--uninstall" ]; then
  echo "Done. Restart InDesign, set text language to Icelandic, enable Hyphenate."
elif [ $RC -eq 0 ]; then
  echo "Done. Restart InDesign."
else
  echo "Completed with errors — see messages above."
fi
exit $RC

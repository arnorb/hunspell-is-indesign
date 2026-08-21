#!/bin/bash
# CLI installer — non-interactive bypass of the double-click .command installer.
#
# Usage:
#   sudo ./install.sh                    # install into every detected InDesign version
#   sudo ./install.sh 2025 2026          # only these versions
#   sudo ./install.sh --hyph-only        # hyphenation only, no spellcheck
#   sudo ./install.sh --uninstall        # remove from every detected version
#   sudo ./install.sh 2025 --uninstall   # remove from one version
#
# Detects InDesign versions in /Applications. Idempotent; re-run after Adobe
# updates. See scripts/install-core.sh for what it does per version.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$DIR/scripts/install-core.sh"
[ -f "$CORE" ] || { echo "ERROR: scripts/install-core.sh missing"; exit 1; }

MODE=""
YEARS=()
for ARG in "$@"; do
  case "$ARG" in
    --uninstall|--hyph-only) MODE="$ARG" ;;
    20[0-9][0-9]) YEARS+=("$ARG") ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown argument '$ARG' (expected a year like 2026, --hyph-only or --uninstall)"; exit 1 ;;
  esac
done

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

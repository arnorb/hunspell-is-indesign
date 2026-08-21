#!/bin/bash
# Íslensk orðskipting fyrir Adobe InDesign — fjarlæging
# Icelandic hyphenation for Adobe InDesign — uninstaller
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$DIR/scripts/install-core.sh"

echo "=================================================================="
echo "  Fjarlægja íslenska orðskiptingu úr Adobe InDesign"
echo "  Remove Icelandic hyphenation from Adobe InDesign"
echo "=================================================================="
echo

[ -f "$CORE" ] || { echo "Villa / Error: scripts/install-core.sh vantar / missing"; exit 1; }

YEARS=()
for APP in "/Applications/Adobe InDesign "20*; do
  [ -d "$APP" ] || continue
  YEAR="${APP##* }"
  B="/Applications/Adobe InDesign $YEAR/Resources/Dictionaries/LILO/Linguistics/Providers/Plugins2/AdobeHunspellPlugin.bundle"
  grep -q is_IS "$B/Contents/Info.plist" 2>/dev/null && YEARS+=("$YEAR")
done

if [ ${#YEARS[@]} -eq 0 ]; then
  echo "Íslenska er ekki uppsett í neinni InDesign útgáfu."
  echo "Icelandic is not installed in any InDesign version."
  exit 0
fi

echo "Íslenska er uppsett í / Icelandic is installed in: InDesign ${YEARS[*]}"
printf "Fjarlægja úr öllum? / Remove from all? [J/y/n] "
read -r ANSWER
case "${ANSWER:-j}" in
  [JjYy]*|"") ;;
  *) echo "Hætt við / Cancelled"; exit 0 ;;
esac
echo

echo "Þarf kerfisstjóraheimild / Administrator rights needed:"
sudo -v
echo

for YEAR in "${YEARS[@]}"; do
  echo "--- InDesign $YEAR ---"
  sudo bash "$CORE" "$YEAR" --uninstall
  echo
done

echo "Lokið. Endurræstu InDesign. / Done. Restart InDesign."

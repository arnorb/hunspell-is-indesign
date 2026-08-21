#!/bin/bash
# Íslensk orðskipting fyrir Adobe InDesign — uppsetning
# Icelandic hyphenation for Adobe InDesign — installer
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE="$DIR/scripts/install-core.sh"

echo "=================================================================="
echo "  Íslensk orðskipting og stafsetning fyrir Adobe InDesign"
echo "  Icelandic hyphenation and spelling for Adobe InDesign"
echo "=================================================================="
echo

[ -f "$CORE" ] || { echo "Villa / Error: scripts/install-core.sh vantar / missing"; exit 1; }

# ---- find installed InDesign versions ----
YEARS=()
for APP in "/Applications/Adobe InDesign "20*; do
  [ -d "$APP" ] || continue
  YEAR="${APP##* }"
  PLIST="$APP/Resources/Dictionaries/LILO/Linguistics/Providers/Plugins2/AdobeHunspellPlugin.bundle/Contents/Info.plist"
  [ -f "$PLIST" ] && YEARS+=("$YEAR")
done

if [ ${#YEARS[@]} -eq 0 ]; then
  echo "Engin InDesign uppsetning fannst í /Applications."
  echo "No InDesign installation found in /Applications."
  exit 1
fi

echo "Fann InDesign / Found InDesign:"
for YEAR in "${YEARS[@]}"; do
  B="/Applications/Adobe InDesign $YEAR/Resources/Dictionaries/LILO/Linguistics/Providers/Plugins2/AdobeHunspellPlugin.bundle"
  if grep -q is_IS "$B/Contents/Info.plist" 2>/dev/null; then
    if codesign --verify --deep "$B" >/dev/null 2>&1; then
      STATUS="íslenska þegar uppsett / Icelandic already installed"
    else
      STATUS="uppsett en þarfnast viðgerðar / installed but needs repair"
    fi
  else
    STATUS="íslenska ekki uppsett / Icelandic not installed"
  fi
  echo "  • InDesign $YEAR — $STATUS"
done
echo

# ---- warn about running instances ----
RUNNING=()
for YEAR in "${YEARS[@]}"; do
  pgrep -f "Adobe InDesign $YEAR.app/Contents/MacOS/Adobe InDesign" >/dev/null && RUNNING+=("$YEAR")
done
if [ ${#RUNNING[@]} -gt 0 ]; then
  echo "ATH: InDesign ${RUNNING[*]} er í gangi. Lokaðu forritinu og endurræstu"
  echo "það eftir uppsetninguna svo breytingarnar taki gildi."
  echo "NOTE: InDesign ${RUNNING[*]} is running. Quit it and relaunch after the"
  echo "installation for the changes to take effect."
  echo
fi

printf "Setja upp fyrir allar útgáfur? / Install for all versions? [J/y/n] "
read -r ANSWER
case "${ANSWER:-j}" in
  [JjYy]*|"") ;;
  *) echo "Hætt við / Cancelled"; exit 0 ;;
esac
echo

echo "Uppsetningin þarf kerfisstjóraheimild (lykilorðið þitt)."
echo "The installation needs administrator rights (your password)."
sudo -v
echo

FAILED=()
for YEAR in "${YEARS[@]}"; do
  echo "--- InDesign $YEAR ---"
  if sudo bash "$CORE" "$YEAR"; then
    echo
  else
    FAILED+=("$YEAR"); echo
  fi
done

echo "=================================================================="
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "Uppsetningu lokið! / Installation complete!"
  echo
  echo "Næstu skref / Next steps:"
  echo "  1. Endurræstu InDesign / Restart InDesign"
  echo "  2. Veldu textann og stilltu tungumál á „Íslenska/Icelandic\""
  echo "     í Character-spjaldinu (eða í málsgreinarstíl)."
  echo "     Select the text and set its language to Icelandic in the"
  echo "     Character panel (or in your paragraph styles)."
  echo "  3. Kveiktu á „Hyphenate\" í Paragraph-spjaldinu."
  echo "     Enable Hyphenate in the Paragraph panel."
  echo
  echo "Ábending: Í vinstrijöfnuðum texta þarf oft að setja"
  echo "„Hyphenation Zone\" á 0 svo orðskipting sjáist."
  echo "Tip: in left-aligned text you often need to set the Hyphenation"
  echo "Zone to 0 for hyphenation to appear."
else
  echo "Villa kom upp fyrir / Errors occurred for: ${FAILED[*]}"
  echo "Sjá villuboð að ofan / See messages above."
fi
echo "=================================================================="

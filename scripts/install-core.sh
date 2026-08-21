#!/bin/bash
# Install (or uninstall) Icelandic Hunspell hyphenation + spelling into Adobe InDesign.
#
# Usage:
#   ./install.sh 2025              # install into InDesign 2025
#   ./install.sh 2025 --hyph-only  # register hyphenation only (no spellcheck)
#   ./install.sh 2025 --uninstall  # restore stock state in InDesign 2025
#
# IMPORTANT: any modification to the AdobeHunspellPlugin bundle (even adding a
# dictionary file) invalidates its code signature, and macOS then silently
# refuses to load the plugin — which kills hyphenation AND spelling for EVERY
# Hunspell language in InDesign. This script therefore re-signs the bundle
# (ad hoc) after changing it, and backs up the original signature files so
# --uninstall restores the exact stock state.
#
# Needs sudo (script re-runs itself with sudo automatically).
set -euo pipefail

YEAR="${1:-2025}"
ACTION="${2:-install}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SRC="$REPO_DIR/dictionaries/is_IS"
APP_DIR="/Applications/Adobe InDesign $YEAR"
BUNDLE_ROOT="$APP_DIR/Resources/Dictionaries/LILO/Linguistics/Providers/Plugins2/AdobeHunspellPlugin.bundle"
BUNDLE="$BUNDLE_ROOT/Contents"
PLIST="$BUNDLE/Info.plist"
DICT_DEST="$BUNDLE/SharedSupport/Dictionaries/is_IS"
# Backups live in /Users/Shared so they survive the download folder being deleted
BACKUP_DIR="/Users/Shared/is_IS-indesign/backups/$YEAR"
LEGACY_BACKUP_DIR="$REPO_DIR/backups/$YEAR"   # location used by an earlier version
OLD_BACKUP="$BUNDLE/Info.plist.stock-backup"   # location used by an earlier version of this script

edit_plist() { # $1 = add|hyphonly|remove
  python3 - "$1" "$PLIST" <<'PYEOF'
import plistlib, sys
action, path = sys.argv[1], sys.argv[2]
with open(path, 'rb') as f:
    pl = plistlib.load(f)
langs = pl['ALPlugInLanguages']
changed = False
# per-service desired state: True = registered, False = absent
want = {
    'add':      {'HyphenationService': True,  'SpellingService': True,  'UserDictionaryService': True},
    'hyphonly': {'HyphenationService': True,  'SpellingService': False, 'UserDictionaryService': False},
    'remove':   {'HyphenationService': False, 'SpellingService': False, 'UserDictionaryService': False},
}[action]
for svc, wanted in want.items():
    arr = langs.get(svc, [])
    if wanted and 'is_IS' not in arr:
        arr.append('is_IS'); langs[svc] = arr; changed = True
        print(f"Registered is_IS in {svc}")
    elif not wanted and 'is_IS' in arr:
        langs[svc] = [x for x in arr if x != 'is_IS']; changed = True
        print(f"Removed is_IS from {svc}")
if changed:
    with open(path, 'wb') as f:
        plistlib.dump(pl, f)
else:
    print("No plist changes needed")
PYEOF
}

resign() {
  # Ad-hoc re-sign so macOS will load the modified bundle again.
  codesign --force --deep -s - "$BUNDLE_ROOT" 2>/dev/null
  if codesign --verify --deep "$BUNDLE_ROOT" >/dev/null 2>&1; then
    echo "Bundle re-signed (ad hoc) and verifies OK"
  else
    echo "WARNING: bundle still fails signature verification:"
    codesign --verify --deep -v "$BUNDLE_ROOT" 2>&1 || true
  fi
}

[ -d "$APP_DIR" ] || { echo "ERROR: $APP_DIR not found"; exit 1; }
[ -f "$PLIST" ]  || { echo "ERROR: Hunspell plugin Info.plist not found at $PLIST"; exit 1; }

# Re-run with sudo if we can't write to the bundle
if [ ! -w "$BUNDLE" ]; then
  echo "Elevating with sudo..."
  exec sudo "$0" "$YEAR" "$ACTION"
fi

if pgrep -f "Adobe InDesign $YEAR.app/Contents/MacOS/Adobe InDesign" >/dev/null; then
  echo "NOTE: InDesign $YEAR is running — quit and relaunch it after this script finishes."
fi

if [ "$ACTION" = "--uninstall" ]; then
  if [ ! -d "$BACKUP_DIR" ] && [ -d "$LEGACY_BACKUP_DIR" ]; then
    BACKUP_DIR="$LEGACY_BACKUP_DIR"
  fi
  if [ -d "$BACKUP_DIR" ]; then
    cp "$BACKUP_DIR/Info.plist" "$PLIST"
    cp "$BACKUP_DIR/AdobeHunspellPlugin" "$BUNDLE/MacOS/AdobeHunspellPlugin"
    rm -rf "$BUNDLE/_CodeSignature"
    cp -R "$BACKUP_DIR/_CodeSignature" "$BUNDLE/_CodeSignature"
    rm -rf "$DICT_DEST" "$OLD_BACKUP"
    echo "Restored stock Info.plist, binary and Adobe signature; removed is_IS."
    if codesign --verify --deep "$BUNDLE_ROOT" >/dev/null 2>&1; then
      echo "Stock signature verifies OK."
    else
      echo "Signature still invalid after restore; re-signing ad hoc instead."
      resign
    fi
  elif [ -f "$OLD_BACKUP" ]; then
    cp "$OLD_BACKUP" "$PLIST"
    rm -rf "$DICT_DEST" "$OLD_BACKUP"
    echo "Restored stock Info.plist (no signature backup available); re-signing ad hoc."
    resign
  else
    echo "No backup found; removing is_IS entries individually."
    edit_plist remove
    rm -rf "$DICT_DEST"
    resign
  fi
  echo "Uninstall complete. Restart InDesign $YEAR."
  exit 0
fi

# ---- install (full or hyphenation-only) ----
[ -d "$SRC" ] || { echo "ERROR: $SRC not found (run from the project dir)"; exit 1; }

# One-time backup of everything the install (and re-signing) touches
if [ ! -d "$BACKUP_DIR" ] && [ -d "$LEGACY_BACKUP_DIR" ]; then
  mkdir -p "$(dirname "$BACKUP_DIR")"
  cp -R "$LEGACY_BACKUP_DIR" "$BACKUP_DIR"
  echo "Migrated existing backup -> $BACKUP_DIR"
fi
if [ ! -d "$BACKUP_DIR" ]; then
  mkdir -p "$BACKUP_DIR"
  # prefer the pristine plist saved by the earlier script version, if present
  if [ -f "$OLD_BACKUP" ]; then
    cp "$OLD_BACKUP" "$BACKUP_DIR/Info.plist"
  else
    cp "$PLIST" "$BACKUP_DIR/Info.plist"
  fi
  cp "$BUNDLE/MacOS/AdobeHunspellPlugin" "$BACKUP_DIR/AdobeHunspellPlugin"
  cp -R "$BUNDLE/_CodeSignature" "$BACKUP_DIR/_CodeSignature"
  echo "Backed up stock plist, binary and signature -> $BACKUP_DIR"
fi

# Copy dictionary folder
mkdir -p "$DICT_DEST"
if [ "$ACTION" = "--hyph-only" ]; then
  rm -f "$DICT_DEST/is_IS.aff" "$DICT_DEST/is_IS.dic"
  cp "$SRC/hyph_is_IS.dic" "$SRC/desc_is_IS.txt" "$SRC/desc_en_US.txt" "$SRC/README_is_IS.txt" "$DICT_DEST/"
  echo "Copied hyphenation-only dictionaries -> $DICT_DEST"
  edit_plist hyphonly
else
  cp "$SRC"/* "$DICT_DEST/"
  echo "Copied dictionaries -> $DICT_DEST"
  edit_plist add
fi

plutil -lint "$PLIST"
resign

echo
echo "Done. Restart InDesign $YEAR, then:"
echo "  1. Preferences > Dictionary: 'Icelandic' should list Hunspell as provider."
echo "  2. Set text language to Icelandic (Character panel) and enable hyphenation."

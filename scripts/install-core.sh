#!/bin/bash
# Install (or uninstall) Icelandic Hunspell hyphenation + spelling into one
# version of Adobe InDesign. Normally called by ../install.sh.
#
# Usage:
#   scripts/install-core.sh 2025              # install into InDesign 2025
#   scripts/install-core.sh 2025 --hyph-only  # register hyphenation only (no spellcheck)
#   scripts/install-core.sh 2025 --uninstall  # restore stock state in InDesign 2025
#
# IMPORTANT: any modification to the AdobeHunspellPlugin bundle (even adding a
# dictionary file) invalidates its code signature, and macOS then silently
# refuses to load the plugin — which kills hyphenation AND spelling for EVERY
# Hunspell language in InDesign. This script therefore re-signs the bundle
# (ad hoc) after changing it, also when it fails part way, and backs up the
# Adobe-signed originals so --uninstall can restore the exact stock state.
#
# Needs sudo (re-runs itself with sudo automatically).
set -euo pipefail

[ $# -ge 1 ] || { echo "Usage: $0 <YEAR> [--hyph-only|--uninstall]"; exit 1; }
YEAR="$1"
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
PB=/usr/libexec/PlistBuddy                     # ships with macOS; python3 needs the Command Line Tools

# Prints the entries of ALPlugInLanguages:<service>, one per line (nothing if absent).
plist_items() {
  local out
  out="$("$PB" -c "Print :ALPlugInLanguages:$1" "$PLIST" 2>/dev/null)" || return 0
  sed -e '1d' -e '$d' -e 's/^[[:space:]]*//' <<<"$out"
}

edit_plist() { # $1 = add|hyphonly|remove — sets each service to its desired state
  local svc want items n idx changed=0
  for svc in HyphenationService SpellingService UserDictionaryService; do
    case "$1:$svc" in
      add:*|hyphonly:HyphenationService) want=1 ;;
      *) want=0 ;;
    esac
    items="$(plist_items "$svc")"
    if [ "$want" = 1 ] && ! grep -qx 'is_IS' <<<"$items"; then
      if [ -z "$items" ]; then
        "$PB" -c "Print :ALPlugInLanguages:$svc" "$PLIST" >/dev/null 2>&1 \
          || "$PB" -c "Add :ALPlugInLanguages:$svc array" "$PLIST"
        n=0
      else
        n="$(grep -c '' <<<"$items")"
      fi
      "$PB" -c "Add :ALPlugInLanguages:$svc:$n string is_IS" "$PLIST"
      echo "Registered is_IS in $svc"; changed=1
    elif [ "$want" = 0 ] && grep -qx 'is_IS' <<<"$items"; then
      # delete from the highest index down so the remaining indices stay valid
      for idx in $(grep -nx 'is_IS' <<<"$items" | cut -d: -f1 | sort -rn); do
        "$PB" -c "Delete :ALPlugInLanguages:$svc:$((idx - 1))" "$PLIST"
      done
      echo "Removed is_IS from $svc"; changed=1
    fi
  done
  [ "$changed" = 1 ] || echo "No plist changes needed"
}

# True if $1 (a bundle or a Mach-O binary) carries a real Developer ID
# signature (Adobe's), not an ad-hoc one.
is_adobe_signed() {
  local info
  info="$(codesign -dv "$1" 2>&1)" || return 1
  ! grep -q '^Signature=adhoc' <<<"$info" && grep -q '^TeamIdentifier=[A-Z0-9]' <<<"$info"
}

# True if the bundle is exactly as Adobe shipped it: Adobe-signed and intact.
bundle_is_stock() {
  codesign --verify --deep "$1" >/dev/null 2>&1 && is_adobe_signed "$1"
}

resign() {
  # Ad-hoc re-sign so macOS will load the modified bundle again.
  local out
  if ! out="$(codesign --force --deep -s - "$BUNDLE_ROOT" 2>&1)"; then
    echo "ERROR: codesign failed:"; echo "$out"
    return 1
  fi
  if codesign --verify --deep "$BUNDLE_ROOT" >/dev/null 2>&1; then
    echo "Bundle re-signed (ad hoc) and verifies OK"
  else
    echo "ERROR: bundle still fails signature verification:"
    codesign --verify --deep -v "$BUNDLE_ROOT" 2>&1 || true
    return 1
  fi
}

# Puts the backed-up stock files into the bundle whose Contents dir is $1.
restore_backup_into() {
  cp "$BACKUP_DIR/Info.plist" "$1/Info.plist"
  cp "$BACKUP_DIR/AdobeHunspellPlugin" "$1/MacOS/AdobeHunspellPlugin"
  rm -rf "$1/_CodeSignature" "$1/SharedSupport/Dictionaries/is_IS" "$1/Info.plist.stock-backup"
  cp -R "$BACKUP_DIR/_CodeSignature" "$1/_CodeSignature"
}

# True if restoring the backup would give a bundle that verifies with Adobe's
# signature. Tried on an APFS clone first, so a backup from an older Adobe
# release is never put over a newer plugin.
backup_matches_bundle() {
  local tmp ok=1
  tmp="$(mktemp -d)"
  if cp -Rc "$BUNDLE_ROOT" "$tmp/b.bundle" 2>/dev/null \
     && restore_backup_into "$tmp/b.bundle/Contents" \
     && bundle_is_stock "$tmp/b.bundle"; then
    ok=0
  fi
  rm -rf "$tmp"
  return $ok
}

[ -d "$APP_DIR" ] || { echo "ERROR: $APP_DIR not found"; exit 1; }
[ -f "$PLIST" ]  || { echo "ERROR: Hunspell plugin Info.plist not found at $PLIST"; exit 1; }

# Re-run with sudo if we can't write to the bundle
if [ ! -w "$BUNDLE" ]; then
  echo "Elevating with sudo..."
  exec sudo "$0" "$YEAR" "$ACTION"
fi

# If anything fails after the bundle has been touched, re-sign it anyway so a
# half-finished run never leaves InDesign without hyphenation in every language.
BUNDLE_TOUCHED=0
on_exit() {
  local rc=$?
  if [ "$rc" -ne 0 ] && [ "$BUNDLE_TOUCHED" = 1 ]; then
    echo "Failed part way; re-signing the bundle so InDesign can still load it."
    resign || true
  fi
  exit "$rc"
}
trap on_exit EXIT

if pgrep -f "Adobe InDesign $YEAR.app/Contents/MacOS/Adobe InDesign" >/dev/null; then
  echo "NOTE: InDesign $YEAR is running — quit and relaunch it after this script finishes."
fi

if [ "$ACTION" = "--uninstall" ]; then
  if bundle_is_stock "$BUNDLE_ROOT"; then
    # e.g. an Adobe update replaced the bundle since the last install
    echo "Plugin is already in its stock Adobe-signed state; nothing to do."
    exit 0
  fi
  if [ ! -d "$BACKUP_DIR" ] && [ -d "$LEGACY_BACKUP_DIR" ]; then
    BACKUP_DIR="$LEGACY_BACKUP_DIR"
  fi
  if [ -d "$BACKUP_DIR" ] && backup_matches_bundle; then
    BUNDLE_TOUCHED=1
    restore_backup_into "$BUNDLE"
    echo "Restored stock Info.plist, binary and Adobe signature; removed is_IS."
    if bundle_is_stock "$BUNDLE_ROOT"; then
      echo "Stock signature verifies OK."
    else
      echo "Signature still invalid after restore; re-signing ad hoc instead."
      resign
    fi
  else
    if [ -d "$BACKUP_DIR" ]; then
      echo "Backup in $BACKUP_DIR doesn't match this InDesign build or isn't Adobe-signed; not restoring it."
    fi
    echo "Removing is_IS and re-signing ad hoc."
    BUNDLE_TOUCHED=1
    edit_plist remove
    rm -rf "$DICT_DEST" "$OLD_BACKUP"
    resign
    echo "Hyphenation works, but the plugin keeps an ad-hoc signature. Reinstall InDesign $YEAR from Creative Cloud to get Adobe's signature back."
  fi
  echo "Uninstall complete. Restart InDesign $YEAR."
  exit 0
fi

# ---- install (full or hyphenation-only) ----
[ -d "$SRC" ] || { echo "ERROR: $SRC not found (run from the project dir)"; exit 1; }
[ -x "$PB" ] || { echo "ERROR: $PB not found"; exit 1; }

# Back up the stock files whenever the bundle is still Adobe-signed and intact.
# This covers the first install and refreshes the backup after an Adobe update.
# A bundle we (or an older version of this script) already modified is never
# backed up, since restoring it would not bring back Adobe's signature.
if [ ! -d "$BACKUP_DIR" ] && [ -d "$LEGACY_BACKUP_DIR" ]; then
  mkdir -p "$(dirname "$BACKUP_DIR")"
  cp -R "$LEGACY_BACKUP_DIR" "$BACKUP_DIR"
  echo "Migrated existing backup -> $BACKUP_DIR"
fi
if bundle_is_stock "$BUNDLE_ROOT"; then
  mkdir -p "$(dirname "$BACKUP_DIR")"
  rm -rf "$BACKUP_DIR.new"
  mkdir "$BACKUP_DIR.new"
  cp "$PLIST" "$BACKUP_DIR.new/Info.plist"
  cp "$BUNDLE/MacOS/AdobeHunspellPlugin" "$BACKUP_DIR.new/AdobeHunspellPlugin"
  cp -R "$BUNDLE/_CodeSignature" "$BACKUP_DIR.new/_CodeSignature"
  rm -rf "$BACKUP_DIR"
  mv "$BACKUP_DIR.new" "$BACKUP_DIR"
  echo "Backed up stock plist, binary and Adobe signature -> $BACKUP_DIR"
elif [ ! -d "$BACKUP_DIR" ]; then
  echo "NOTE: plugin is already modified, so there is no stock copy to back up."
fi

BUNDLE_TOUCHED=1
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

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS installer that adds Icelandic hyphenation and spelling to Adobe InDesign by dropping dictionaries into InDesign's built-in Hunspell plugin bundle. No plugin and no build step. The code is two bash scripts plus data files. A static landing page lives in `docs/` (GitHub Pages).

## Commands

There is no build, lint or test suite. Running the installer modifies `/Applications/Adobe InDesign <YEAR>`, so it needs sudo and a real InDesign install:

```sh
sudo ./install.sh                  # all versions detected in /Applications
sudo ./install.sh 2026             # one version
sudo ./install.sh --hyph-only      # hyphenation only, no spellcheck
sudo ./install.sh 2025 --uninstall # restore stock Adobe state
for f in install.sh scripts/install-core.sh; do bash -n "$f"; done  # syntax check without touching InDesign
```

To verify in InDesign: set the text's language to Icelandic (a character attribute) and turn on Hyphenate. Left-aligned text also needs Hyphenation Zone 0, or no hyphens appear. Known-good breaks: `sjálfstæðisbarátt-una`, `alþjóðasamskipt-in`.

## Architecture

- `install.sh` is the entry point. It parses args (years, `--hyph-only`, `--uninstall`) and detects versions via `/Applications/Adobe InDesign 20*`, then calls `scripts/install-core.sh <YEAR> [MODE]` once per version. When it runs as `curl … | sudo bash`, `BASH_SOURCE` has no sibling `scripts/` directory, so it downloads the `main` tarball from GitHub into a temp dir. **This means the public one-liner always runs whatever is on `main`.**
- `scripts/install-core.sh` does the work for one version, inside `…/Plugins2/AdobeHunspellPlugin.bundle/Contents`:
  1. Whenever the bundle is still stock (verifies and is Adobe-signed, not ad hoc), backs up `Info.plist`, `MacOS/AdobeHunspellPlugin` and `_CodeSignature` to `/Users/Shared/is_IS-indesign/backups/<YEAR>/`. That covers the first install and refreshes the backup after an Adobe update. An already modified bundle is never backed up. It also migrates the legacy `<repo>/backups/` location; uninstall still deletes the legacy `Info.plist.stock-backup`. Keep these paths so older installs can still be uninstalled.
  2. Copies `dictionaries/is_IS/*` to `SharedSupport/Dictionaries/is_IS/`.
  3. Uses `/usr/libexec/PlistBuddy` (not python3, which needs the Command Line Tools) to edit `ALPlugInLanguages`, setting the `HyphenationService` / `SpellingService` / `UserDictionaryService` entries to a desired state (`add` / `hyphonly` / `remove`). It is idempotent.
  4. **Ad-hoc re-signs the bundle** (`codesign --force --deep -s -`). An EXIT trap also re-signs if the script fails after touching the bundle.
  - Uninstall does nothing if the bundle is already stock. Otherwise it restores the backup only after a trial restore on an APFS clone verifies with Adobe's signature, so a backup from another Adobe build is never applied. If the trial fails, it removes the entries and re-signs ad hoc.
- Both scripts must stay idempotent. Re-running repairs or updates an install, and users re-run them after every Adobe update.

### Critical invariant: code signing

Any change inside `AdobeHunspellPlugin.bundle`, even one added file, invalidates its signature. macOS then silently refuses to load the plugin, which breaks hyphenation in **every** language and can make text vanish into overset. Every code path that touches the bundle must end with `resign` or a restore of the original signature.

## Data files

- `sources/` holds the upstream LibreOffice `dictionaries/is/` files, **unmodified** (see `sources/PROVENANCE.md`). Never edit them.
- `dictionaries/is_IS/` holds what gets installed: byte-identical copies renamed to InDesign conventions (`hyph_is.dic`→`hyph_is_IS.dic`, `is.aff/.dic`→`is_IS.aff/.dic`), plus `desc_*.txt` stubs and `README_is_IS.txt` (a copy of `license.txt`). To refresh, re-download into `sources/` and re-copy with the renames.
- Licensing: hyphenation patterns are CC BY 4.0, the spelling wordlist is partly CC BY-SA 3.0, and the scripts are MIT.

## Landing page

- `docs/index.html` is a self-contained Icelandic page. The install one-liner is hard-coded twice: in the `<pre>` and in the `CMD` JS variable. Keep both in sync with the README.
- `docs/card.html` is the 1200×630 source for `docs/og.png`, the social share image. Re-capture the PNG after editing the card, using a headless Chromium (Playwright's `chrome-headless-shell` works; headless Brave hangs): `--window-size=1200,630 --force-device-scale-factor=1 --virtual-time-budget=5000 --screenshot=docs/og.png file://$PWD/docs/card.html`. The root `.gitignore` ignores only `/*.png`, so `docs/og.png` is committed.

## Conventions

- The README is bilingual: Icelandic first, then English. User-facing changes go into both sections.
- macOS only. Paths assume `/Applications/Adobe InDesign <YEAR>`.

# Íslensk orðskipting fyrir Adobe InDesign

**Icelandic hyphenation for Adobe InDesign** — [English below](#english)

Ókeypis og opið: bætir íslenskri orðskiptingu og stafsetningarleiðréttingu við
InDesign í gegnum innbyggða Hunspell-málstuðninginn — engin viðbót (plugin),
sama kerfi og InDesign notar fyrir ~50 önnur tungumál.

Orðskiptireglurnar eru opinberu íslensku reglurnar frá Stofnun Árna
Magnússonar í íslenskum fræðum (málföng.is, CC BY 4.0).

## Uppsetning

1. Lokaðu InDesign.
2. Opnaðu **Terminal** (Cmd+bilslá, skrifaðu „Terminal", Enter).
3. Límdu þessa skipun í gluggann og ýttu á Enter:

```sh
curl -fsSL https://raw.githubusercontent.com/arnorb/hunspell-is-indesign/main/install.sh | sudo bash
```

4. Sláðu inn lykilorðið þitt þegar beðið er um það (það sést ekki þegar
   það er slegið inn — það er eðlilegt).
5. Endurræstu InDesign.

Uppsetningin sækir allt sem þarf, finnur sjálfkrafa allar InDesign-útgáfur í
/Applications (2024 og nýrri) og setur íslenskuna upp í þeim öllum.

**ATH:** Þegar Adobe uppfærir InDesign hverfur íslenskan — keyrðu þá sömu
skipun einfaldlega aftur.

## Notkun

1. Veldu textann (eða allt með Cmd+A) og stilltu tungumálið á **Icelandic**
   í Character-spjaldinu — best er að stilla það í málsgreinarstílum
   (paragraph styles).
2. Kveiktu á **Hyphenate** í Paragraph-spjaldinu.
3. Í vinstrijöfnuðum texta: settu **Hyphenation Zone** á 0
   (Paragraph-valmynd → Hyphenation…) svo orðskipting sjáist almennilega.

Stafsetningarleiðrétting virkar sjálfkrafa þegar tungumál textans er íslenska
(Edit → Spelling).

## Fjarlæging

Sama skipun með `--uninstall` skilar InDesign nákvæmlega í upprunalegt horf
(öryggisafrit eru geymd í /Users/Shared/is_IS-indesign/):

```sh
curl -fsSL https://raw.githubusercontent.com/arnorb/hunspell-is-indesign/main/install.sh | sudo bash -s -- --uninstall
```

Fleiri möguleikar (t.d. ein útgáfa í einu): sjá
[Command line](#command-line) í enska hlutanum.

---

<a name="english"></a>
# English

Free and open: adds Icelandic hyphenation and spell checking to Adobe InDesign
through its built-in Hunspell linguistics provider — no plugin, the same
mechanism InDesign uses for its ~50 shipped languages. The hyphenation
patterns are the official Icelandic rules from the Árni Magnússon Institute
for Icelandic Studies (málföng.is, CC BY 4.0).

**Install:** quit InDesign, paste this into Terminal, enter your password,
restart InDesign:

```sh
curl -fsSL https://raw.githubusercontent.com/arnorb/hunspell-is-indesign/main/install.sh | sudo bash
```

It downloads everything it needs and installs into every InDesign version
found in /Applications. Re-run the same command after Adobe updates (they
restore the stock dictionaries). Running a script this way never triggers a
Gatekeeper warning — there is nothing to right-click or approve.

**Use:** set the text's language to *Icelandic* (Character panel or paragraph
style) and enable *Hyphenate*. In left-aligned text set the Hyphenation Zone
to 0 to see full hyphenation.

**Uninstall:** the same command with `--uninstall` restores the exact stock
Adobe state (from backups kept in /Users/Shared/is_IS-indesign/):

```sh
curl -fsSL https://raw.githubusercontent.com/arnorb/hunspell-is-indesign/main/install.sh | sudo bash -s -- --uninstall
```

<a name="command-line"></a>
## Command line options

From a clone/download of this repo you can also run the installer directly;
options work the same appended to the one-liner after `sudo bash -s --`:

```sh
sudo ./install.sh                  # install into every InDesign version found in /Applications
sudo ./install.sh 2026             # install into InDesign 2026 only
sudo ./install.sh --hyph-only      # install hyphenation without the spellcheck dictionary
sudo ./install.sh --uninstall      # remove Icelandic and restore stock Adobe state
sudo ./install.sh 2025 --uninstall # remove from InDesign 2025 only
```

The script is idempotent — running it again repairs or updates an existing
install. Quit InDesign before running, and restart it afterwards. Backups of
the stock Adobe files are kept in `/Users/Shared/is_IS-indesign/backups/`.

## How it works (technical)

InDesign's Hunspell plugin lives at:

```
/Applications/Adobe InDesign <YEAR>/Resources/Dictionaries/LILO/Linguistics/Providers/Plugins2/AdobeHunspellPlugin.bundle
```

Each language is a folder under `Contents/SharedSupport/Dictionaries/<locale>/`
— libhyphen hyphenation patterns (`hyph_is_IS.dic`) plus a Hunspell spelling
pair (`is_IS.aff`/`is_IS.dic`) — registered in the bundle's `Info.plist` under
`ALPlugInLanguages` → `HyphenationService` / `SpellingService` /
`UserDictionaryService`. Icelandic is simply missing from the stock set;
`scripts/install-core.sh` adds it.

### The code-signature gotcha (critical)

Any modification inside `AdobeHunspellPlugin.bundle` — even just adding a
dictionary file — invalidates the bundle's code signature, and macOS then
**silently refuses to load the plugin**. The symptoms are dramatic and
misleading: hyphenation stops working in *every* language (including English),
and languages with a registered spelling service can fail to compose at all
(text vanishes into overset). This is almost certainly the failure behind
Adobe-forum reports of custom dictionaries "breaking" modern InDesign.

The fix is to ad-hoc re-sign the bundle after modifying it
(`codesign --force --deep -s - <bundle>`). InDesign loads third-party plugins,
so it accepts an ad-hoc signature. The installer does this automatically, and
backs up the stock plist, plugin binary, and `_CodeSignature` so uninstall
restores the exact Adobe-signed state.

### Verification notes

Works with InDesign 2024 and later; verified on 2024 through 2027 (macOS): visual composition
tests show correct breaks (`sjálfstæðisbarátt-una`, `alþjóðasamskipt-in`);
the pattern file also validates against pyphen (same libhyphen format).
When testing, remember: language is a character attribute, and left-aligned
text needs Hyphenation Zone 0 (or justified text) for hyphens to appear.

## Sources & licensing

See [LICENSE.md](LICENSE.md). Dictionary files come from the LibreOffice
dictionaries collection (`github.com/LibreOffice/dictionaries`, `is/`),
stored unmodified in `sources/`:

- **Hyphenation patterns** (`hyph_is.dic`, 7,695 patterns) — Icelandic
  Language Institute / Árni Magnússon Institute, published at málföng.is
  under **CC BY 4.0**; lineage: Jörgen Pind's TeX patterns and Magnús
  Gíslason's Liang-algorithm work.
- **Spelling** (`is.aff`/`is.dic`) — Hunspell-is
  (`github.com/nifgraup/hunspell-is`); wordlist by Orðabók Háskólans (public
  domain) with Icelandic Wiktionary additions (**CC BY-SA 3.0**).

Installer scripts are MIT-licensed. Not affiliated with Adobe.

## Layout

```
dictionaries/is_IS/       files installed into InDesign
sources/                  upstream files, unmodified (see sources/PROVENANCE.md)
scripts/install-core.sh   per-version install/uninstall engine
install.sh                installer — self-bootstraps when run via curl | sudo bash
```

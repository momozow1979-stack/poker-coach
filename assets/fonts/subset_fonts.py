#!/usr/bin/env python3
"""Regenerate assets/fonts/NotoSansJP-{Regular,Bold}.ttf as a subsetted font.

Why this exists: the original Noto Sans JP TTFs cover the full multi-language
Noto repertoire (CJK Unified Ideographs in full, Cyrillic, Greek, etc.) at
~5.1MB each, which made every fresh page load download ~10MB of font data on
top of the CanvasKit/main.dart.js payload. This app only ever renders Japanese
+ basic Latin text, so the fonts are subsetted down to the characters that
repertoire actually needs (~2.2MB each, verified byte-for-byte glyph coverage
of every character used in lib/, test/, and assets/*.json).

Run this again only if the app starts using a character NOT covered by the
current subset (e.g. a rare kanji added to a quiz bank) and text starts
rendering as a tofu box (missing-glyph square). Requires the ORIGINAL,
un-subsetted Noto Sans JP TTFs as input (this script does not fetch them --
subsetting an already-subsetted font cannot recover glyphs that were already
dropped). Get the originals from the Noto CJK release
(https://github.com/notofonts/noto-cjk, "Sans" -> Japanese subset, OTF/TTF
build) or Google Fonts' Noto Sans JP.

Usage:
    pip install fonttools
    python3 subset_fonts.py <original-Regular.ttf> <original-Bold.ttf>

Writes NotoSansJP-Regular.ttf / NotoSansJP-Bold.ttf in this directory,
overwriting the current (already-subsetted) files.
"""
from __future__ import annotations

import glob
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
FONTS_DIR = Path(__file__).resolve().parent


def jis_repertoire() -> set[str]:
    """All characters reachable via Shift-JIS (JIS X 0201 + JIS X 0208 + common
    vendor extensions covered by Python's 'shift_jis' codec) -- i.e. the
    classic "Japanese common use" character set, derived losslessly instead
    of hand-copying a JIS code table."""
    chars: set[str] = set()
    for b in range(0x00, 0x100):
        try:
            chars.add(bytes([b]).decode("shift_jis"))
        except UnicodeDecodeError:
            pass
    for b1 in range(0x81, 0xFD):
        for b2 in range(0x40, 0x100):
            if b2 == 0x7F:
                continue
            try:
                chars.add(bytes([b1, b2]).decode("shift_jis"))
            except UnicodeDecodeError:
                pass
    return chars


def used_in_app() -> set[str]:
    """Every character actually appearing in app source/data, as a floor
    that must always be covered regardless of the JIS repertoire above."""
    chars: set[str] = set()
    for pattern in ("lib/**/*.dart", "assets/**/*.json", "test/**/*.dart"):
        for path in glob.glob(str(REPO_ROOT / pattern), recursive=True):
            chars.update(Path(path).read_text(encoding="utf-8"))
    return chars


def safety_margin_ranges() -> list[tuple[int, int]]:
    """Common Unicode blocks kept as a margin against future Japanese app
    content beyond what's in the source today (punctuation, symbols, suits,
    circled numbers, halfwidth/fullwidth forms)."""
    return [
        (0x2000, 0x206F),  # General Punctuation
        (0x2190, 0x21FF),  # Arrows
        (0x2200, 0x22FF),  # Mathematical Operators
        (0x2460, 0x24FF),  # Enclosed Alphanumerics
        (0x2600, 0x27BF),  # Misc Symbols + Dingbats (suits, stars, checks)
        (0x3000, 0x303F),  # CJK Symbols and Punctuation
        (0xFF00, 0xFFEF),  # Halfwidth and Fullwidth Forms
    ]


def build_charset() -> str:
    chars = jis_repertoire() | used_in_app()
    for lo, hi in safety_margin_ranges():
        chars.update(chr(cp) for cp in range(lo, hi + 1))
    return "".join(sorted(chars))


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    original_regular, original_bold = sys.argv[1], sys.argv[2]

    charset = build_charset()
    print(f"subsetting to {len(charset)} characters")
    charfile = FONTS_DIR / "_charset.tmp.txt"
    charfile.write_text(charset, encoding="utf-8")

    try:
        for original, name in ((original_regular, "Regular"), (original_bold, "Bold")):
            out = FONTS_DIR / f"NotoSansJP-{name}.ttf"
            subprocess.run(
                [
                    sys.executable, "-m", "fontTools.subset", original,
                    f"--text-file={charfile}",
                    f"--output-file={out}",
                    "--drop-tables+=GSUB,GPOS,BASE,STAT,vhea,vmtx,gasp",
                    "--no-recalc-timestamp",
                ],
                check=True,
            )
            print(f"wrote {out} ({out.stat().st_size / 1024 / 1024:.2f}MB)")
    finally:
        charfile.unlink(missing_ok=True)

    # Verify every character actually used in the app is covered -- a
    # subsetting bug here means real UI text renders as a tofu box.
    from fontTools.ttLib import TTFont

    covered = set(chr(cp) for cp in TTFont(FONTS_DIR / "NotoSansJP-Regular.ttf").getBestCmap())
    missing = sorted(c for c in used_in_app() if c not in covered and ord(c) > 0x20 and c not in "\n\r\t")
    if missing:
        print("MISSING GLYPHS for characters used in the app:", missing)
        sys.exit(1)
    print("OK: every character used in lib/, test/, assets/*.json is covered.")


if __name__ == "__main__":
    main()

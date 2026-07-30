#!/bin/bash

# Font Subsetting Script for The Wisdom Project
# Reduces font file sizes while keeping Sinhala, English, and Pali diacritics support
# Requires: pip install "fonttools[woff]"   (the [woff] extra pulls in brotli,
#                                            without which the woff2 compress
#                                            step below fails)
#
# Emits per face:
#   *-Subset.ttf    for the Flutter app  (pubspec assets must be ttf/otf)
#   *-Subset.woff2  for the static site  (the only format worth shipping to a
#                                         browser; ~40% smaller than the ttf) —
#                                         Sinhala families ONLY, see below
#
# The static site self-hosts these because browsers ship no fonts of their own.
# Only Android carries Noto Sans Sinhala — on Windows, macOS, iOS and most Linux
# the pages would otherwise render in a different face than the app, and the
# baked conjuncts are glyph-coverage-specific to Noto.
#
# Fonts are a build INPUT: run this by hand, commit the output, and the site
# generator copies the bytes. That keeps Python out of the build loop.

set -e  # Exit on error

echo "=== Font Subsetting Script ==="
echo ""

# Navigate to fonts directory
cd "$(dirname "$0")"

# Common Unicode ranges
BASIC_LATIN="U+0020-007F"           # English letters, numbers, punctuation
LATIN_1_SUPPLEMENT="U+00A0-00FF"    # Common symbols (©, §, etc.)
LATIN_EXTENDED_A="U+0100-017F"      # ā, ī, ū (long vowels)
LATIN_EXTENDED_ADD="U+1E00-1EFF"    # ṃ, ṇ, ṭ, ḍ, ḷ, ñ (Pali diacritics)
GENERAL_PUNCT="U+2000-206F"         # Smart quotes, dashes, bullets — and ZWJ
                                    # (U+200D), which every baked conjunct
                                    # depends on. Do not narrow this range.
SINHALA="U+0D80-0DFF"               # Sinhala script

# subset <directory> <filename-glob> <unicode-ranges> [woff2]
#
# --layout-features='*' keeps every GSUB/GPOS feature. That is not optional for
# Sinhala: the conjunct forms are produced by the font's shaping rules, so a
# default subset (which drops "unused" features) would strip exactly the
# behaviour the reading experience depends on.
#
# Pass `woff2` as the 4th argument for the two Sinhala families the static site
# self-hosts. The Latin-only families get the ttf only: the app bundles them for
# UI chrome the site does not have, and no @font-face rule the generator emits
# ever names them (see render/web_fonts.dart), so a woff2 there is a file
# nothing would ever request.
subset() {
    local dir="$1" glob="$2" ranges="$3" web="${4:-}"
    for font in $dir/$glob; do
        [[ -f "$font" && ! "$font" == *"-Subset"* ]] || continue
        local filename
        filename=$(basename "$font" .ttf)

        echo "  Subsetting: $font"
        # Subset once, then compress that result. Running pyftsubset twice over
        # the *original* would redo the whole glyph-and-feature pass to reach
        # the same set of outlines, and — worse — leave two subsets that could
        # drift apart if only one invocation were ever edited. woff2 is just a
        # container: same tables, brotli-compressed.
        pyftsubset "$font" \
            --output-file="$dir/${filename}-Subset.ttf" \
            --layout-features='*' \
            --unicodes="$ranges"

        local original_size ttf_size woff2_size
        original_size=$(du -k "$font" | cut -f1)
        ttf_size=$(du -k "$dir/${filename}-Subset.ttf" | cut -f1)

        if [[ "$web" != "woff2" ]]; then
            echo "    ${original_size}KB → ${ttf_size}KB ttf"
            continue
        fi

        fonttools ttLib.woff2 compress \
            -o "$dir/${filename}-Subset.woff2" \
            "$dir/${filename}-Subset.ttf"
        woff2_size=$(du -k "$dir/${filename}-Subset.woff2" | cut -f1)
        echo "    ${original_size}KB → ${ttf_size}KB ttf, ${woff2_size}KB woff2"
    done
}

SINHALA_RANGES="${BASIC_LATIN},${SINHALA},${GENERAL_PUNCT}"
SERIF_RANGES="${BASIC_LATIN},${LATIN_1_SUPPLEMENT},${LATIN_EXTENDED_A},${LATIN_EXTENDED_ADD},${GENERAL_PUNCT}"
SANS_RANGES="${BASIC_LATIN},${LATIN_1_SUPPLEMENT},${GENERAL_PUNCT}"

echo "Processing Noto Sans Sinhala (Sinhala UI, app + site)..."
subset noto-sans-sinhala "NotoSansSinhala-*.ttf" "$SINHALA_RANGES" woff2
echo ""

echo "Processing Noto Serif Sinhala (Pali + Sinhala content, app + site)..."
subset noto-serif-sinhala "NotoSerifSinhala-*.ttf" "$SINHALA_RANGES" woff2
echo ""

echo "Processing Noto Serif (romanized Pali & English, app only)..."
subset noto-serif "NotoSerif-*.ttf" "$SERIF_RANGES"
echo ""

echo "Processing Noto Sans (UI elements, app only)..."
subset noto-sans "NotoSans-*.ttf" "$SANS_RANGES"
echo ""

# ============================================
# Summary
# ============================================
echo "=== Summary ==="
echo ""
echo "Total original size:"
find . -name "*.ttf" ! -name "*-Subset.ttf" -exec du -c {} + | tail -1
echo ""
echo "Total subset size (ttf):"
find . -name "*-Subset.ttf" -exec du -c {} + 2>/dev/null | tail -1 || echo "0"
echo ""
echo "Total subset size (woff2):"
find . -name "*-Subset.woff2" -exec du -c {} + 2>/dev/null | tail -1 || echo "0"
echo ""
echo "=== Done! ==="
echo ""
echo "Next steps:"
echo "1. Test the subset fonts in your app"
echo "2. Commit the 8 Sinhala *-Subset.woff2 files — the site generator copies"
echo "   them verbatim, so they are a build input, not build output"
echo "3. To use the ttf subsets in the app, update pubspec.yaml filenames"

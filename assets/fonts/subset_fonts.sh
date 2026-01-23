#!/bin/bash

# Font Subsetting Script for The Wisdom Project
# Reduces font file sizes while keeping Sinhala, English, and Pali diacritics support
# Requires: pip install fonttools

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
GENERAL_PUNCT="U+2000-206F"         # Smart quotes, dashes, bullets
SINHALA="U+0D80-0DFF"               # Sinhala script

# ============================================
# 1. NOTO SANS SINHALA (Sinhala content)
# ============================================
echo "Processing Noto Sans Sinhala..."
SINHALA_RANGES="${BASIC_LATIN},${SINHALA},${GENERAL_PUNCT}"

for font in noto-sans-sinhala/NotoSansSinhala-*.ttf; do
    if [[ -f "$font" && ! "$font" == *"-Subset"* ]]; then
        filename=$(basename "$font" .ttf)
        output="noto-sans-sinhala/${filename}-Subset.ttf"

        echo "  Subsetting: $font"
        pyftsubset "$font" \
            --output-file="$output" \
            --layout-features='*' \
            --unicodes="$SINHALA_RANGES"

        original_size=$(du -k "$font" | cut -f1)
        new_size=$(du -k "$output" | cut -f1)
        echo "    ${original_size}KB → ${new_size}KB"
    fi
done
echo ""

# ============================================
# 2. NOTO SERIF (Romanized Pali & English)
# ============================================
echo "Processing Noto Serif..."
SERIF_RANGES="${BASIC_LATIN},${LATIN_1_SUPPLEMENT},${LATIN_EXTENDED_A},${LATIN_EXTENDED_ADD},${GENERAL_PUNCT}"

for font in noto-serif/NotoSerif-*.ttf; do
    if [[ -f "$font" && ! "$font" == *"-Subset"* ]]; then
        filename=$(basename "$font" .ttf)
        output="noto-serif/${filename}-Subset.ttf"

        echo "  Subsetting: $font"
        pyftsubset "$font" \
            --output-file="$output" \
            --layout-features='*' \
            --unicodes="$SERIF_RANGES"

        original_size=$(du -k "$font" | cut -f1)
        new_size=$(du -k "$output" | cut -f1)
        echo "    ${original_size}KB → ${new_size}KB"
    fi
done
echo ""

# ============================================
# 3. NOTO SANS (UI elements)
# ============================================
echo "Processing Noto Sans..."
SANS_RANGES="${BASIC_LATIN},${LATIN_1_SUPPLEMENT},${GENERAL_PUNCT}"

for font in noto-sans/NotoSans-*.ttf; do
    if [[ -f "$font" && ! "$font" == *"-Subset"* ]]; then
        filename=$(basename "$font" .ttf)
        output="noto-sans/${filename}-Subset.ttf"

        echo "  Subsetting: $font"
        pyftsubset "$font" \
            --output-file="$output" \
            --layout-features='*' \
            --unicodes="$SANS_RANGES"

        original_size=$(du -k "$font" | cut -f1)
        new_size=$(du -k "$output" | cut -f1)
        echo "    ${original_size}KB → ${new_size}KB"
    fi
done
echo ""

# ============================================
# Summary
# ============================================
echo "=== Summary ==="
echo ""
echo "Original fonts:"
du -sh noto-*/Noto*[^t].ttf 2>/dev/null | grep -v Subset || true
echo ""
echo "Subset fonts:"
du -sh noto-*/*-Subset.ttf 2>/dev/null || echo "No subset files found"
echo ""
echo "Total original size:"
find . -name "*.ttf" ! -name "*-Subset.ttf" -exec du -c {} + | tail -1
echo ""
echo "Total subset size:"
find . -name "*-Subset.ttf" -exec du -c {} + 2>/dev/null | tail -1 || echo "0"
echo ""
echo "=== Done! ==="
echo ""
echo "Next steps:"
echo "1. Test the subset fonts in your app"
echo "2. If everything works, replace originals with subset versions"
echo "3. Update pubspec.yaml to use the new filenames (or rename -Subset files)"

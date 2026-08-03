#!/bin/bash

# Emblem derivative for the static site's toolbar mark.
# Requires: sips (ships with macOS — no install, no Python, no Node).
#
# Emits:
#   emblem.png    200x200, ~47 KB  ->  copied to build/assets/emblem.png
#
# Why a derivative and not the source. assets/icons/app_logo.png is a
# 1024x1024, 634 KB master. The site ships one stylesheet, eight woff2 subsets
# and no rasters at all, so shipping the master would make it the single
# heaviest asset on the site — 13x the weight of everything else put together,
# to paint the 28px mark at the left of the toolbar.
#
# 200px is deliberately larger than any single use needs. It was first sized
# against a 100px landing-page hero (2x for retina); that hero was withdrawn
# with P3's nav rail, and the emblem now renders at 28px on every page instead.
# It is kept at 200 rather than re-cut to ~84: it is one request cached for the
# whole site, so the bytes are paid once, and P5's OG card wants a raster
# larger than the bar does. 256px was measured too (70,801 bytes against
# 47,115) and buys resolution nothing on the site asks for.
#
# Like the fonts, this is a build INPUT: run it by hand, commit the output, and
# the generator copies the bytes. That keeps image tooling out of the build
# loop, which stays pure Dart (D9).

set -euo pipefail

cd "$(dirname "$0")"

SOURCE="../../assets/icons/app_logo.png"
OUTPUT="emblem.png"
SIZE=200

if [ ! -f "$SOURCE" ]; then
  echo "error: $SOURCE not found — run this from the repo checkout." >&2
  exit 1
fi

sips -Z "$SIZE" "$SOURCE" --out "$OUTPUT" >/dev/null

echo "$OUTPUT  $(sips -g pixelWidth -g pixelHeight "$OUTPUT" \
  | awk '/pixel/ { printf "%s ", $2 }')px  $(wc -c < "$OUTPUT" | tr -d ' ') bytes"

#!/bin/bash

# Raster derivatives for the static site.
# Requires: sips (ships with macOS — no install, no Python, no Node).
#
# Emits:
#   emblem.png    200x200,  ~47 KB  ->  build/assets/emblem.png   (toolbar mark)
#   og-card.png   1200x630, ~197 KB ->  build/assets/og-card.png  (link previews)
#
# Why derivatives and not the source. assets/icons/app_logo.png is a
# 1024x1024, 634 KB master. The site ships one stylesheet, eight woff2 subsets
# and no rasters at all otherwise, so shipping the master would make it the
# single heaviest asset on the site — 13x the weight of everything else put
# together, to paint the 28px mark at the left of the toolbar.
#
# Like the fonts, these are build INPUTS: run this by hand, commit the output,
# and the generator copies the bytes. That keeps image tooling out of the build
# loop, which stays pure Dart (D9).

set -euo pipefail

cd "$(dirname "$0")"

SOURCE="../../assets/icons/app_logo.png"

# --- The toolbar mark -------------------------------------------------------
#
# 200px is larger than the one use needs. It was first sized against a 100px
# landing-page hero (2x for retina); that hero was withdrawn with P3's nav rail,
# and the emblem now renders at 28px on every page instead. 256px was measured
# too (70,801 bytes against 47,115) and buys resolution nothing on the site
# asks for.
#
# It stayed at 200 for two reasons, and P5 retired one of them: the bytes are
# paid once and cached site-wide, AND "P5's OG card wants a raster larger than
# the bar does". The card below is its own file now — an OG image wants ~1200x630
# and a 200px square is the wrong shape at any size — so the toolbar mark is
# subsidising nothing, and backlog B1's case for re-cutting it to 56px is
# unopposed. That is a shared-chrome change belonging with B2; it is not done
# here.
EMBLEM="emblem.png"
EMBLEM_SIZE=200

# --- The link-preview card --------------------------------------------------
#
# 1200x630 is the size every scraper documents and the one aspect ratio
# (1.91:1) Facebook, WhatsApp and X all crop to without cutting the subject.
#
# The logo is drawn at 440px and padded out to the card with the site's own page
# background (`colors.light.background` in theme_tokens.json), so a shared link
# previews in the same paper colour as the page it opens. Padded rather than
# stretched: the mark is square and the card is not.
#
# ~197 KB, and deliberately not compressed further. This file is fetched by
# link scrapers, never by a reader — it is on no page's critical path, appears
# in no page's byte count, and is the one raster on the site whose weight a
# visitor does not pay. Re-cutting it as JPEG would save ~150 KB — measured,
# not guessed: sips writes this card as a 48 KB JPEG — and ring the line art.
# Do not "optimise" it on the strength of the number alone.
CARD="og-card.png"
CARD_LOGO=440
CARD_WIDTH=1200
CARD_HEIGHT=630
# `colors.light.background` — #faf9f5. Spelled without the `#` because that is
# the form sips takes. If the theme's background moves, move this with it: the
# card is the only place on the site where a colour is baked into pixels rather
# than read from the generated tokens, which is a seam a stylesheet change
# cannot reach.
CARD_BACKGROUND="FAF9F5"

if [ ! -f "$SOURCE" ]; then
  echo "error: $SOURCE not found — run this from the repo checkout." >&2
  exit 1
fi

report() {
  echo "$1  $(sips -g pixelWidth -g pixelHeight "$1" \
    | awk '/pixel/ { printf "%s ", $2 }')px  $(wc -c < "$1" | tr -d ' ') bytes"
}

sips -Z "$EMBLEM_SIZE" "$SOURCE" --out "$EMBLEM" >/dev/null
report "$EMBLEM"

# Two passes, because sips resizes or pads in one invocation but not both: the
# first fixes how big the mark is, the second decides how much paper is around
# it. The intermediate is written into the system temp dir rather than beside
# the outputs — it is not a build input and must never be committed or copied.
#
# Two paths, one trap. `mktemp -t` does not print a name, it *creates a file*
# and prints that file's name; appending `.png` — which sips needs, to know what
# it is writing — makes a second, different path. Removing only the suffixed one
# left the empty original in the temp dir on every run.
TMP_STAMP="$(mktemp -t og-card)"
TMP_LOGO="$TMP_STAMP.png"
trap 'rm -f "$TMP_STAMP" "$TMP_LOGO"' EXIT

sips -Z "$CARD_LOGO" "$SOURCE" --out "$TMP_LOGO" >/dev/null
# sips echoes the parsed --padColor to stderr as a `<CGColor …>` line. It is
# chatter, not a failure; stderr is left alone rather than swallowed, because
# the next thing on it would be a real error.
sips "$TMP_LOGO" \
  --padToHeightWidth "$CARD_HEIGHT" "$CARD_WIDTH" \
  --padColor "$CARD_BACKGROUND" \
  --out "$CARD" >/dev/null
report "$CARD"

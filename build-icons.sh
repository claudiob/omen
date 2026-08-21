#!/bin/sh
# Renders every icon a browser, a phone or a social network asks for from icon.svg.
# Needs rsvg-convert and magick; run it after editing the SVG and commit what changes.
set -e
cd "$(dirname "$0")"

# iOS masks a bookmark and every avatar is shown round, so those render from square corners.
sed 's/rx="96"/rx="0"/' icon.svg > .square.svg
trap 'rm -f .square.svg' EXIT

rsvg-convert -w 96  -h 96  icon.svg     -o favicon-96x96.png
rsvg-convert -w 192 -h 192 icon.svg     -o web-app-manifest-192x192.png
rsvg-convert -w 512 -h 512 icon.svg     -o web-app-manifest-512x512.png
rsvg-convert -w 180 -h 180 .square.svg  -o apple-touch-icon.png
rsvg-convert -w 1024 -h 1024 .square.svg -o avatar.png

# one .ico holding the three sizes a browser reaches for when the page links nothing
for size in 16 32 48; do rsvg-convert -w $size -h $size icon.svg -o ".ico-$size.png"; done
magick .ico-16.png .ico-32.png .ico-48.png favicon.ico
rm -f .ico-16.png .ico-32.png .ico-48.png

echo 'icons rendered from icon.svg'

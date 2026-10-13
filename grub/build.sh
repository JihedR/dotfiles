#!/usr/bin/env bash
# Build the ctOS GRUB theme into grub/build/ctos/ (no root needed).
# Install with the commands in CLAUDE.md ("GRUB theme"); GRUB can't read files in $HOME,
# so the theme is copied to /boot/grub/themes/ctos, not stowed.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/build/ctos"
wallpaper="$here/../hyprpaper/.config/hypr/wallpapers/ctos-v2.png"
fonts=/usr/share/fonts/TTF

rm -rf "$out"
mkdir -p "$out"

cp "$here/theme.txt" "$out/"

# Background: ctos-v2 at 1920x1080, no alpha (GRUB wants 8-bit, non-interlaced PNG)
magick "$wallpaper" -resize '1920x1080^' -gravity center -extent 1920x1080 \
    -alpha off -interlace none PNG24:"$out/background.png"

# 1x1 9-slice pixmaps: <prefix> <center color> <border color>
slice() {
    local prefix=$1 center=$2 border=$3 part
    magick -size 1x1 "xc:$center" PNG24:"$out/${prefix}_c.png"
    for part in n ne e se s sw w nw; do
        magick -size 1x1 "xc:$border" PNG24:"$out/${prefix}_${part}.png"
    done
}
slice menu         '#0e0e0e' '#d9d9d9' # menu box: bg fill, 1px ctos border
slice term         '#0e0e0e' '#d9d9d9' # console/editor box
slice select       '#d9d9d9' '#d9d9d9' # selected item: solid ctos block
slice scroll_thumb '#d9d9d9' '#d9d9d9'
slice scroll_frame '#0e0e0e' '#0e0e0e' # invisible, but GRUB only draws a scrollbar with a frame

# Fonts: ASCII + box drawing + block elements
range=0x20-0x7E,0x2500-0x257F,0x25A0-0x25FF
# (grub-mkfont warns about OpenType features it ignores; harmless)
mkfont() {
    grub-mkfont -r "$range" -s "$2" -o "$out/$3.pf2" "${@:4}" "$fonts/$1" \
        2> >(grep -v 'unsupported font feature' >&2)
}
mkfont JetBrainsMonoNerdFontMono-Regular.ttf 12 jbm-regular-12
mkfont JetBrainsMonoNerdFontMono-Regular.ttf 18 jbm-regular-18
# Light reports itself as "Regular"; give it its own family so the name says Light
mkfont JetBrainsMonoNerdFontMono-Light.ttf   24 jbm-light-24 -n "JetBrainsMono NFM Light"

# Font names as GRUB sees them; theme.txt must use these exactly
for f in "$out"/*.pf2; do
    name=$(python3 -c '
import struct, sys
d = open(sys.argv[1], "rb").read()
i = d.index(b"NAME")
n = struct.unpack(">I", d[i+4:i+8])[0]
print(d[i+8:i+8+n].rstrip(b"\0").decode())' "$f")
    printf '%-20s %s\n' "$(basename "$f")" "$name"
done

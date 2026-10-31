#!/usr/bin/env bash
# Define o wallpaper.
# Coloque qualquer .jpg/.jpeg/.png em ~/.config/wallpapers/ e recarregue o i3
# (Mod+Shift+C). Sem imagem, usa cor solida preta.

set -u

WALL_DIR="${HOME}/.config/wallpapers"
FALLBACK_COLOR='#000000'

mkdir -p "$WALL_DIR"

IMG="$(find "$WALL_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' \) \
        | sort | head -n1)"

if [ -n "$IMG" ] && command -v feh >/dev/null 2>&1; then
    feh --no-fehbg --bg-fill "$IMG"
else
    xsetroot -solid "$FALLBACK_COLOR"
fi

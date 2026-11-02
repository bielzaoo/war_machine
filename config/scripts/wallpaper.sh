#!/usr/bin/env bash
# Define o wallpaper e prepara o fundo "vidro" do terminal.
#
# - Coloque qualquer .jpg/.jpeg/.png/.webp/.bmp em ~/.config/wallpapers/ e
#   recarregue o i3 (Mod+Shift+C). Havendo mais de uma, vale a primeira em
#   ordem alfabetica.
# - Sem imagem e com ImageMagick instalado, gera um padrao (preto + brilho
#   cyan) uma unica vez. Sem ImageMagick, fundo preto solido.
# - Fundo do terminal: versao desfocada e escurecida do wallpaper, gerada UMA
#   vez por imagem e cacheada. E isso que da o efeito de vidro sem compositor:
#   o blur e pago no momento da geracao, nao a cada frame.
# - Escurecimento automatico pelo brilho medio da imagem: wallpaper claro
#   escurece bem mais que um escuro, pra o texto continuar legivel. Manual:
#   echo 0-100 > ~/.config/war_machine/dim (apague o arquivo pra voltar ao auto).

set -u

WALL_DIR="${HOME}/.config/wallpapers"
CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}/war_machine"
DEFAULT_WALL="${CACHE}/default-wall.png"
TERM_BG="${CACHE}/term-bg.png"
TERM_SRC="${CACHE}/term-bg.src"
FALLBACK_COLOR='#000000'

# Escurecimento do fundo do terminal. Sem o arquivo dim: automatico (auto).
# Com ele (0-100, mais alto = mais escuro): fixo.  Depois: Mod+Shift+C
DIM="$(cat "${HOME}/.config/war_machine/dim" 2>/dev/null || true)"
case "$DIM" in ''|*[!0-9]*) DIM="auto" ;; esac
[ "$DIM" != "auto" ] && [ "$DIM" -gt 100 ] && DIM=100

# Auto: multiplica o brilho por TARGET/media, preso entre MIN e MAX.
# MAX 0.38 = os 62% fixos de antes (wallpaper escuro fica igual); MIN 0.15 =
# o branco de um wallpaper claro vira no maximo 15% de brilho.
AUTO_TARGET=0.10
AUTO_MIN=0.15
AUTO_MAX=0.38

mkdir -p "$WALL_DIR" "$CACHE"

IM=""
if command -v magick >/dev/null 2>&1; then
    IM="magick"
elif command -v convert >/dev/null 2>&1; then
    IM="convert"
fi

IMG="$(find "$WALL_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
           -o -iname '*.webp' -o -iname '*.bmp' \) \
        | sort | head -n1)"

# --- padrao gerado (so quando nao ha imagem do usuario) ----------------
if [ -z "$IMG" ] && [ -n "$IM" ]; then
    if [ ! -s "$DEFAULT_WALL" ]; then
        "$IM" -size 1920x1080 radial-gradient:'#0b4a52-#000000' \
              \( -size 1920x1080 xc:none -fill none -stroke '#00f0ff14' \
                 -draw "$(for y in $(seq 0 4 1080); do printf 'line 0,%d 1920,%d ' "$y" "$y"; done)" \) \
              -composite \
              "${DEFAULT_WALL}.tmp.png" 2>/dev/null \
            && mv "${DEFAULT_WALL}.tmp.png" "$DEFAULT_WALL"
    fi
    [ -s "$DEFAULT_WALL" ] && IMG="$DEFAULT_WALL"
fi

# --- wallpaper ---------------------------------------------------------
if [ -n "$IMG" ] && command -v feh >/dev/null 2>&1; then
    feh --no-fehbg --bg-fill "$IMG"
else
    xsetroot -solid "$FALLBACK_COLOR"
fi

# --- fundo do terminal (vidro fosco pre-renderizado) -------------------
if [ -n "$IMG" ] && [ -n "$IM" ]; then
    if [ ! -s "$TERM_BG" ] || [ "$IMG" -nt "$TERM_BG" ] \
       || [ "$(cat "$TERM_SRC" 2>/dev/null)" != "${IMG}:${DIM}:v2" ]; then
        if [ "$DIM" = "auto" ]; then
            # brilho medio percebido (0-1), medido numa miniatura: barato
            MEAN="$("$IM" "$IMG" -resize '64x64!' -colorspace Gray \
                    -format '%[fx:mean]' info: 2>/dev/null || true)"
            FACTOR="$(awk -v m="${MEAN:-0.5}" -v t="$AUTO_TARGET" \
                          -v lo="$AUTO_MIN" -v hi="$AUTO_MAX" 'BEGIN {
                f = (m > 0) ? t / m : hi
                if (f > hi) f = hi
                if (f < lo) f = lo
                printf "%.3f", f }')"
        else
            FACTOR="$(awk -v d="$DIM" 'BEGIN { printf "%.3f", 1 - d / 100 }')"
        fi
        # reduz -> desfoca -> amplia (blur pesado por uma fracao do custo),
        # tira 30% da saturacao (cor viva atras do texto cansa) e escurece
        "$IM" "$IMG" -resize '960x540^' -gravity center -extent 960x540 \
              -blur 0x10 -resize 1920x1080 \
              -modulate 100,70 -evaluate multiply "$FACTOR" \
              "${TERM_BG}.tmp.png" 2>/dev/null \
            && mv "${TERM_BG}.tmp.png" "$TERM_BG" \
            && printf '%s\n' "${IMG}:${DIM}:v2" > "$TERM_SRC"
    fi
elif [ -z "$IMG" ]; then
    rm -f "$TERM_BG" "$TERM_SRC"
fi

#!/usr/bin/env bash
# Abre o terminal padrao.
#
#   term.sh            kitty com fundo "vidro" (se instalado e ligado),
#                      senao alacritty solido
#   term.sh --solid    sempre alacritty solido (o mais leve)
#   term.sh --toggle   liga/desliga o vidro para os proximos terminais
#
# O estado do toggle fica em ~/.config/war_machine/solid (existe = desligado).

set -u

BG="${XDG_CACHE_HOME:-${HOME}/.cache}/war_machine/term-bg.png"
FLAG="${HOME}/.config/war_machine/solid"

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -t 1500 "$@" || true
}

case "${1:-}" in
    --solid)
        shift
        exec alacritty "$@"
        ;;
    --toggle)
        mkdir -p "$(dirname "$FLAG")"
        if [ -f "$FLAG" ]; then
            rm -f "$FLAG"
            notify "Terminal" "vidro ligado"
        else
            : > "$FLAG"
            notify "Terminal" "vidro desligado (solido)"
        fi
        exit 0
        ;;
esac

if command -v kitty >/dev/null 2>&1 && [ ! -f "$FLAG" ]; then
    if [ -s "$BG" ]; then
        exec kitty -o background_image="$BG" "$@"
    fi
    exec kitty "$@"
fi

exec alacritty "$@"

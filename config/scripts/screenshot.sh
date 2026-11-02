#!/usr/bin/env bash
# Screenshot -> arquivo em ~/Pictures/screenshots + area de transferencia
# Uso: screenshot.sh [region|full]

set -u

MODE="${1:-region}"
DIR="${HOME}/Pictures/screenshots"
# engagement ativo (engage <alvo>): screenshot vira evidencia na pasta dele
ACTIVE="${HOME}/.config/war_machine/engagement"
ENG_ROOT="${WAR_ENGAGEMENTS:-${HOME}/engagements}"
if [ -s "$ACTIVE" ] && [ -d "${ENG_ROOT}/$(cat "$ACTIVE")" ]; then
    DIR="${ENG_ROOT}/$(cat "$ACTIVE")/screens"
fi
mkdir -p "$DIR"
FILE="${DIR}/$(date +%Y-%m-%d_%H-%M-%S).png"

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send "$@" || true
}

case "$MODE" in
    region) maim --select --hidecursor "$FILE" 2>/dev/null ;;
    full)   maim --hidecursor "$FILE" ;;
    *)      echo "uso: $0 [region|full]" >&2; exit 1 ;;
esac

# maim retorna != 0 se a selecao for cancelada
if [ ! -s "$FILE" ]; then
    rm -f "$FILE"
    exit 0
fi

xclip -selection clipboard -t image/png -i "$FILE"
notify "Screenshot" "Salvo em ${FILE##*/} e copiado"

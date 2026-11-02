#!/usr/bin/env bash
# Abre o Thunar: na pasta do engagement ativo (engage <alvo>) se houver,
# senao no $HOME. Bind: Mod+F.
set -u
ACTIVE="${HOME}/.config/war_machine/engagement"
ENG_ROOT="${WAR_ENGAGEMENTS:-${HOME}/engagements}"
dir="$HOME"
if [ -s "$ACTIVE" ] && [ -d "${ENG_ROOT}/$(cat "$ACTIVE")" ]; then
    dir="${ENG_ROOT}/$(cat "$ACTIVE")"
fi
exec thunar "$dir"

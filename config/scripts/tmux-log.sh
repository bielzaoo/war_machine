#!/usr/bin/env bash
# Log de evidencia do tmux (chamado pelos hooks e pelo prefix L).
#
#   tmux-log.sh auto   <pane>   liga o log se o painel estiver dentro de
#                               ~/engagements/<alvo>; grava em <alvo>/logs/
#   tmux-log.sh toggle <pane>   liga/desliga na mao; fora de engagement grava
#                               em ~/.local/state/war_machine/tmux-logs/
#
# O log e a saida crua do painel (com cores): leia com `less -R`.

set -u

ENG_ROOT="${WAR_ENGAGEMENTS:-${HOME}/engagements}"
STATE_LOGS="${XDG_STATE_HOME:-${HOME}/.local/state}/war_machine/tmux-logs"

mode="${1:-}"
pane="${2:-}"
[ -n "$pane" ] || { echo "uso: $0 auto|toggle <pane_id>" >&2; exit 1; }

# pasta de logs do engagement em que o painel esta, se estiver em um
eng_logs() {
    local path rel
    path="$(tmux display -p -t "$pane" '#{pane_current_path}')"
    case "${path}/" in
        "${ENG_ROOT}"/?*/)
            rel="${path#"${ENG_ROOT}"/}"
            printf '%s/%s/logs' "$ENG_ROOT" "${rel%%/*}"
            ;;
    esac
}

start_log() {
    local dir="$1" name file
    # ja gravando: nao mexe (pipe-pane -o num painel com pipe o FECHA)
    [ "$(tmux display -p -t "$pane" '#{pane_pipe}')" = "1" ] && return 0
    mkdir -p "$dir"
    name="$(tmux display -p -t "$pane" '#{session_name}-w#{window_index}p#{pane_index}' | tr '/: ' '___')"
    file="${dir}/$(date +%Y-%m-%d_%H%M%S)_${name}.log"
    tmux pipe-pane -t "$pane" "exec cat >> '${file}'"
    tmux display -t "$pane" "log: ${file/#"$HOME"/\~}"
}

case "$mode" in
    auto)
        dir="$(eng_logs)"
        [ -n "$dir" ] && start_log "$dir"
        ;;
    toggle)
        if [ "$(tmux display -p -t "$pane" '#{pane_pipe}')" = "1" ]; then
            tmux pipe-pane -t "$pane"
            tmux display -t "$pane" "log parado"
        else
            dir="$(eng_logs)"
            start_log "${dir:-$STATE_LOGS}"
        fi
        ;;
    *)
        echo "uso: $0 auto|toggle <pane_id>" >&2
        exit 1
        ;;
esac
exit 0

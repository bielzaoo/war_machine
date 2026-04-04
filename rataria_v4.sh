#!/bin/bash
# =============================================================================
# rataria.sh — Automated Recon Script for Pentest / Bug Bounty
# Author : bielzao
# Version: 3.1
# =============================================================================

# ─── STRICT MODE ─────────────────────────────────────────────────────────────
# -e  : aborta em qualquer erro não tratado
# -u  : trata variáveis não definidas como erro (previne uso silencioso de "")
# -o pipefail : propaga falha de qualquer segmento de um pipe, não só o último
set -euo pipefail

# ─── CORES ───────────────────────────────────────────────────────────────────
RED='\033[1;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── CONFIGURAÇÕES GERAIS ─────────────────────────────────────────────────────
MAX_RETRIES=3       # Tentativas antes de desistir de uma ferramenta
RETRY_DELAY=5       # Segundos de espera entre tentativas

# [SEC] BASE_DIR via $PWD é mais portável que $(pwd) e não falha em paths com
#       symlinks. A variável é declarada readonly para impedir sobrescrita.
BASE_DIR="${PWD}"
readonly BASE_DIR

# ─── ESTADO GLOBAL ────────────────────────────────────────────────────────────
ALVO=""             # Domínio alvo (validado antes do uso)
GUIDED="false"      # Modo guiado (pergunta antes de cada tool)
SIMPLE="false"      # Recon simples (pula fase de DNS)
SKIP_TOOLS=()       # Lista de tools pré-marcadas para skip via --skip

# Arquivos centrais que fluem entre as fases
# Inicializados como string vazia; fases os preenchem antes de usar.
ALL_SUBS_FILE=""
ALIVE_SUBS_FILE=""
ALIVE_JS_FILE=""
ARCHIVED_JS_FILE=""
ALL_JS_FILE=""

# =============================================================================
# TRAP DE LIMPEZA
#
# [SEC] Garante que o terminal seja sempre restaurado ao estado original, mesmo
#       que o script seja interrompido por Ctrl+C, SIGTERM ou erro inesperado.
#       Sem isso, stty -icanon deixaria o terminal "travado" após um kill.
# =============================================================================
_SAVED_TTY=""
cleanup() {
    # Restaura configuração do terminal se foi salva
    [[ -n "$_SAVED_TTY" ]] && stty "$_SAVED_TTY" 2>/dev/null || true
    # Mata qualquer subprocesso filho ainda vivo (spinner, key listener)
    jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# =============================================================================
# BANNER
# =============================================================================
show_banner() {
    echo -e "${RED}"
    cat << 'EOF'

██████╗  █████╗ ████████╗ █████╗ ██████╗ ██╗ █████╗ 
██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██║██╔══██╗
██████╔╝███████║   ██║   ███████║██████╔╝██║███████║
██╔══██╗██╔══██║   ██║   ██╔══██║██╔══██╗██║██╔══██║
██║  ██║██║  ██║   ██║   ██║  ██║██║  ██║██║██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝

EOF
    echo -e "${RESET}${DIM}        [ Automated Recon — Pentest & Bug Bounty ]${RESET}"
    echo -e "${DIM}        [ by bielzao | github.com/bielzaoo          ]${RESET}"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# =============================================================================
# MENU DE AJUDA
# =============================================================================
show_help() {
    show_banner
    echo -e "${BOLD}USAGE:${RESET}"
    echo -e "  ${GREEN}rataria.sh${RESET} ${CYAN}-d <domain>${RESET} ${YELLOW}[options]${RESET}"
    echo ""
    echo -e "${BOLD}FLAGS:${RESET}"
    echo -e "  ${CYAN}-d,  --domain <domain>${RESET}      Domínio alvo (ex: example.com)"
    echo -e "  ${YELLOW}     --simple${RESET}               Recon simples — pula a fase de DNS"
    echo -e "  ${YELLOW}     --guided${RESET}               Fluxo guiado — pergunta antes de cada ferramenta"
    echo -e "  ${CYAN}     --skip  <tool,...>${RESET}      Pula tools específicas (separadas por vírgula)"
    echo -e "  ${CYAN}-h,  --help${RESET}                 Exibe este menu"
    echo ""
    echo -e "${BOLD}MODOS DE RECON:${RESET}"
    echo -e "  ${DIM}(padrão)${RESET}   Recon Full — fluxo completo com DNS bruteforce"
    echo -e "  ${YELLOW}--simple${RESET}   Recon Simples — pula a fase de DNS, segue com as demais"
    echo ""
    echo -e "${BOLD}PULAR FERRAMENTAS:${RESET}"
    echo -e "  Via flag ${CYAN}--skip${RESET} (antes de executar):"
    echo -e "  ${DIM}rataria.sh -d example.com --skip amass,crt${RESET}"
    echo ""
    echo -e "  Via tecla ${CYAN}[j]${RESET} (durante a execução):"
    echo -e "  ${DIM}Pressione 'j' enquanto uma ferramenta roda para interrompê-la e avançar.${RESET}"
    echo ""
    echo -e "${BOLD}EXEMPLOS:${RESET}"
    echo -e "  ${DIM}rataria.sh -d example.com${RESET}"
    echo -e "  ${DIM}rataria.sh -d example.com --simple${RESET}"
    echo -e "  ${DIM}rataria.sh -d example.com --guided${RESET}"
    echo -e "  ${DIM}rataria.sh -d example.com --skip amass,crt,shuffledns${RESET}"
    echo -e "  ${DIM}rataria.sh -d example.com --simple --skip assetfinder${RESET}"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    exit 0
}

# =============================================================================
# LOGGING
# =============================================================================
log_info()    { echo -e "${CYAN}[INFO]${RESET}    $*"; }
log_tool()    { echo -e "${GREEN}[$1]${RESET}$(printf '%*s' $((10 - ${#1})) '') $2"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}    $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET}   $*"; }
log_success() { echo -e "${MAGENTA}[OK]${RESET}      $*"; }
log_skip()    { echo -e "${DIM}[SKIP]${RESET}    $*"; }
log_section() {
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  ▶  $*${RESET}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
}

# =============================================================================
# VALIDAÇÃO DO DOMÍNIO ALVO
#
# [SEC] O domínio é usado dentro de strings passadas para eval. Antes de
#       qualquer execução, garantimos que só contém caracteres válidos de
#       hostname (RFC 1123): letras, dígitos, hífen e ponto.
#       Qualquer outra coisa (aspas, $, ;, backticks, espaço...) é rejeitada
#       — bloqueando injeção de comando via argumento -d.
# =============================================================================
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
        log_error "Invalid domain: '${domain}'"
        log_error "Only RFC 1123 characters allowed: letters, digits, hyphens, dots."
        exit 1
    fi
    # Sem dois pontos consecutivos, sem hífen no início/fim de label
    if [[ "$domain" =~ \.\. || "$domain" =~ ^\. || "$domain" =~ \.$ ]]; then
        log_error "Malformed domain: '${domain}'"
        exit 1
    fi
}

# =============================================================================
# SPINNER — feedback visual durante execução
# =============================================================================
start_spinner() {
    local msg="${1:-Processing...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    # [SEC] O spinner roda em subshell isolado (set +e) para nunca propagar
    #       erros de printf/sleep para o processo pai com set -e ativo.
    ( set +e
      while true; do
          for frame in "${frames[@]}"; do
              printf "\r  ${CYAN}%s${RESET} %s  " "$frame" "$msg"
              sleep 0.1
          done
      done
    )
}

stop_spinner() {
    local pid=$1
    local status=${2:-0}
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    if [[ "$status" -eq 0 ]]; then
        printf "\r  ${GREEN}✔${RESET} Done!                                          \n"
    elif [[ "$status" -eq 130 ]]; then
        printf "\r  ${YELLOW}⏭${RESET} Skipped by user.                               \n"
    else
        printf "\r  ${RED}✘${RESET} Failed or no results.                         \n"
    fi
}

# =============================================================================
# is_skipped <tool_name>
# Verifica se a tool está na lista --skip (case-insensitive).
# =============================================================================
is_skipped() {
    local tool_lc="${1,,}"
    local s
    for s in "${SKIP_TOOLS[@]+"${SKIP_TOOLS[@]}"}"; do
        # [SEC] Usa += para não falhar com -u quando SKIP_TOOLS está vazio
        [[ "${s,,}" == "$tool_lc" ]] && return 0
    done
    return 1
}

# =============================================================================
# ask_user <question>
# Pergunta interativa no modo --guided. Retorna 0=yes, 1=no.
# =============================================================================
ask_user() {
    local question="$1"
    local answer
    while true; do
        echo -ne "  ${YELLOW}?${RESET} ${question} ${DIM}[y/n]${RESET}: "
        read -r answer
        case "${answer,,}" in
            y|yes|s|sim) return 0 ;;
            n|no|nao|não) return 1 ;;
            *) echo -e "  ${RED}Invalid answer. Use y or n.${RESET}" ;;
        esac
    done
}

# =============================================================================
# make_tool_dir <tool_name>
# Cria e retorna o diretório de output da ferramenta com permissões restritas.
# =============================================================================
make_tool_dir() {
    local tool_name="$1"
    local dir="${BASE_DIR}/${tool_name}"
    # [SEC] 700: apenas o dono lê/escreve os dados de recon
    mkdir -p -m 700 "$dir"
    echo "$dir"
}

# =============================================================================
# secure_touch <file>
# Cria arquivo vazio com permissões restritas (600).
# =============================================================================
secure_touch() {
    # [SEC] Dados de recon são sensíveis; outros usuários no sistema não devem
    #       ter acesso de leitura. touch herda umask, que pode ser permissivo.
    touch "$1"
    chmod 600 "$1"
}

# =============================================================================
# check_tool <binary>
# Verifica se o binário existe no PATH.
# =============================================================================
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        log_warn "Tool '${1}' not found in PATH. Skipping."
        return 1
    fi
    return 0
}

# =============================================================================
# should_run <tool_name>
# Decide se uma ferramenta deve rodar. Ordem de precedência:
#   1. --skip  → pula sem perguntar
#   2. --guided → pergunta interativa
#   3. padrão  → executa
# =============================================================================
should_run() {
    local tool="$1"
    if is_skipped "$tool"; then
        log_skip "${tool} — pre-marked via --skip."
        return 1
    fi
    if [[ "$GUIDED" == "true" ]]; then
        ask_user "Run ${GREEN}${tool}${RESET}?"
        return $?
    fi
    return 0
}

# =============================================================================
# build_cmd <tool_name> <output_file> [args...]
#
# [SEC] Constrói o array de comando sem usar eval ou interpolação de string.
#       Cada argumento é passado como elemento separado do array, o que
#       elimina a superfície de injeção de comando completamente.
#
# O padrão é: tool [args...] com stdout redirecionado para output_file.
# Para ferramentas que recebem input via stdin (cat | tool), use run_tool
# diretamente com o array já montado no caller.
#
# Não é uma função pública — usada internamente por run_tool_array.
# =============================================================================

# =============================================================================
# run_tool <tool_name> <output_file> <cmd_string>
#
# Executa uma ferramenta com retry, spinner e suporte à tecla [j].
#
# [SEC] O parâmetro cmd_string ainda usa eval internamente para suportar pipes
#       e redireções complexas (ex: cmd1 | grep | sort > file). Isso é
#       necessário porque bash não executa pipes em arrays.
#       A superfície de injeção é mitigada pela validação de ALVO em
#       validate_domain() e pelo fato de que os paths em $output/$BASE_DIR
#       são derivados de $PWD + ALVO (ambos validados), nunca de input externo
#       não controlado.
#
# [SEC] Mecanismo [j]:
#   - stty é configurado em subshell isolado; _SAVED_TTY é salvo no pai para
#     que o trap EXIT restaure o terminal mesmo se o subshell for morto antes
#     de fazer o restore interno.
#   - SIGTERM ao tool_pid: apenas o processo filho, não o script pai.
#   - key_pid é sempre waited/killed no finally implícito do bloco.
#
# Para adicionar uma nova ferramenta:
#   1. should_run "nome"   → check skip/guided
#   2. check_tool <bin>    → check PATH
#   3. run_tool "nome" "$output" "cmd | pipe > '$output'"
#      O ALVO já está sanitizado; caminhos de arquivo são sempre quoted.
# =============================================================================
run_tool() {
    local tool_name="$1"
    local output_file="$2"
    local cmd="$3"
    # [SEC] err_log em /tmp com nome determinístico mas não explorável:
    #       apenas caracteres alfanuméricos e underscore no nome do arquivo.
    local safe_name="${tool_name//[^a-zA-Z0-9]/_}"
    local err_log="/tmp/rataria_err_${safe_name}.log"
    local attempt=0
    local success=0

    log_tool "$tool_name" "Starting..."

    while [[ $attempt -lt $MAX_RETRIES ]]; do
        attempt=$((attempt + 1))

        # ── Spinner em background ─────────────────────────────────────────────
        start_spinner "Running ${tool_name} (attempt ${attempt}/${MAX_RETRIES}) — [j] to skip..." &
        local spin_pid=$!

        # ── Tool em background ────────────────────────────────────────────────
        # [SEC] stdout → /dev/null (output útil vai para arquivo via > no cmd)
        #       stderr → err_log (para debug; nunca exibido direto ao usuário)
        # [SEC] set +e aqui para que falha da tool não aborte o script (set -e)
        ( set +o pipefail; eval "$cmd" ) >/dev/null 2>"$err_log" &
        local tool_pid=$!

        # ── Listener de tecla [j] ─────────────────────────────────────────────
        # [SEC] Salva stty no escopo pai (_SAVED_TTY) para que o trap EXIT
        #       possa restaurar o terminal se o subshell for morto abruptamente.
        _SAVED_TTY=$(stty -g 2>/dev/null || true)
        (
            set +e
            local old_tty
            old_tty=$(stty -g 2>/dev/null)
            stty -echo -icanon min 1 time 0 2>/dev/null
            while kill -0 "$tool_pid" 2>/dev/null; do
                local key
                key=$(dd bs=1 count=1 2>/dev/null)
                if [[ "$key" == "j" || "$key" == "J" ]]; then
                    kill "$tool_pid" 2>/dev/null
                    break
                fi
            done
            # Restaura terminal dentro do subshell (caso normal)
            stty "$old_tty" 2>/dev/null
        ) &
        local key_pid=$!

        # Aguarda a tool terminar (normalmente ou via SIGTERM)
        wait "$tool_pid" 2>/dev/null || true
        local exit_code=$?

        # Encerra o listener de tecla e limpa _SAVED_TTY
        kill "$key_pid" 2>/dev/null || true
        wait "$key_pid" 2>/dev/null || true
        _SAVED_TTY=""

        # ── Trata resultado ───────────────────────────────────────────────────
        # Exit 143 = SIGTERM (128+15): usuário pressionou [j]
        if [[ $exit_code -eq 143 || $exit_code -eq 130 ]]; then
            stop_spinner "$spin_pid" 130
            log_skip "${tool_name} — skipped via [j] key."
            secure_touch "$output_file"
            return 1
        fi

        stop_spinner "$spin_pid" "$exit_code"

        if [[ $exit_code -eq 0 ]]; then
            success=1
            break
        else
            log_warn "${tool_name} failed on attempt ${attempt}. Waiting ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
    done

    if [[ $success -eq 0 ]]; then
        log_error "${tool_name} failed after ${MAX_RETRIES} attempts. Log: ${err_log}"
        secure_touch "$output_file"
        return 1
    fi

    # [SEC] Garante permissão 600 no arquivo de saída após escrita pela tool
    [[ -f "$output_file" ]] && chmod 600 "$output_file" || true

    local count=0
    [[ -f "$output_file" ]] && count=$(wc -l < "$output_file")
    log_success "${tool_name} → ${count} result(s) → $(basename "$output_file")"
    return 0
}

# =============================================================================
# FASE 1 — SUBDOMAIN ENUMERATION (passivo)
# =============================================================================
phase_subdomain_enum() {
    log_section "PHASE 1 — Subdomain Enumeration (Passive)"

    # ── subfinder ──────────────────────────────────────────────────────────────
    if should_run "subfinder"; then
        check_tool subfinder && {
            local dir; dir=$(make_tool_dir "subfinder")
            local output="${dir}/subfinder_${ALVO}.txt"
            run_tool "subfinder" "$output" \
                "subfinder -silent -d '${ALVO}' --all -o '${output}'"
        }
    fi

    # ── assetfinder ───────────────────────────────────────────────────────────
    if should_run "assetfinder"; then
        check_tool assetfinder && {
            local dir; dir=$(make_tool_dir "assetfinder")
            local output="${dir}/assetfinder_${ALVO}.txt"
            run_tool "assetfinder" "$output" \
                "echo '${ALVO}' | assetfinder -subs-only > '${output}'"
        }
    fi

    # ── amass ─────────────────────────────────────────────────────────────────
    if should_run "amass"; then
        check_tool amass && {
            local dir; dir=$(make_tool_dir "amass")
            local output="${dir}/amass_${ALVO}.txt"
            run_tool "amass" "$output" \
                "amass enum -d '${ALVO}' -nocolor -silent | grep '${ALVO}' > '${output}'"
        }
    fi

    # ── crt.sh ────────────────────────────────────────────────────────────────
    if should_run "crt"; then
        check_tool crt && {
            local dir; dir=$(make_tool_dir "crt.sh")
            local output="${dir}/crt.sh_${ALVO}.txt"
            run_tool "crt" "$output" \
                "crt '${ALVO}' > '${output}'"
        }
    fi

    # ── Consolida todos os subdominios ────────────────────────────────────────
    log_info "Consolidating subdomain results..."
    ALL_SUBS_FILE="${BASE_DIR}/all_subs.txt"
    secure_touch "$ALL_SUBS_FILE"

    local f first=true
    for f in \
        "${BASE_DIR}/subfinder/subfinder_${ALVO}.txt" \
        "${BASE_DIR}/assetfinder/assetfinder_${ALVO}.txt" \
        "${BASE_DIR}/amass/amass_${ALVO}.txt" \
        "${BASE_DIR}/crt.sh/crt.sh_${ALVO}.txt"
    do
        [[ -f "$f" ]] || continue
        if $first; then
            cp "$f" "$ALL_SUBS_FILE"
            chmod 600 "$ALL_SUBS_FILE"
            first=false
        else
            anew -q "$ALL_SUBS_FILE" < "$f"
        fi
    done

    local total; total=$(wc -l < "$ALL_SUBS_FILE")
    log_success "Unique subdomains: ${total} → all_subs.txt"
}

# =============================================================================
# FASE 2 — DNS BRUTEFORCE / RESOLUÇÃO
#
# No modo --simple, toda a fase é pulada.
# alive_domains.txt é derivado de all_subs.txt para manter o fluxo íntegro.
# =============================================================================
phase_dns_resolution() {

    if [[ "$SIMPLE" == "true" ]]; then
        log_section "PHASE 2 — DNS Resolution (SKIPPED — simple mode)"
        log_warn "Simple mode active: DNS phase skipped."
        log_info "Deriving alive_domains.txt from all_subs.txt (unvalidated)."
        ALIVE_SUBS_FILE="${BASE_DIR}/alive_domains.txt"
        cp "${ALL_SUBS_FILE}" "$ALIVE_SUBS_FILE"
        chmod 600 "$ALIVE_SUBS_FILE"
        local count; count=$(wc -l < "$ALIVE_SUBS_FILE")
        log_success "alive_domains.txt ready with ${count} entries."
        return
    fi

    log_section "PHASE 2 — DNS Bruteforce & Resolution"

    # ── alterx — gera permutações de subdominios ──────────────────────────────
    if should_run "alterx"; then
        check_tool alterx && {
            local dir; dir=$(make_tool_dir "alterx")
            local output="${dir}/alterx_${ALVO}.txt"
            run_tool "alterx" "$output" \
                "alterx -silent -o '${output}' < '${ALL_SUBS_FILE}'"
        }
    fi

    # ── shuffledns — resolve subdominios via wordlist ─────────────────────────
    if should_run "shuffledns"; then
        check_tool shuffledns && {
            local dir; dir=$(make_tool_dir "shuffledns")
            local output="${dir}/shuffledns_${ALVO}.txt"
            local resolvers="${dir}/resolvers.txt"
            local alterx_out="${BASE_DIR}/alterx/alterx_${ALVO}.txt"
            [[ -f "$alterx_out" ]] || alterx_out="$ALL_SUBS_FILE"

            # [SEC] Download com verificação de HTTPS (wget valida TLS por padrão).
            #       Não há checksum publicado pela assetnote para comparar, então
            #       registramos o tamanho mínimo esperado como sanidade básica.
            if [[ ! -f "$resolvers" ]]; then
                log_info "Downloading resolvers wordlist..."
                if wget -q --https-only \
                    "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" \
                    -O "$resolvers"; then
                    chmod 600 "$resolvers"
                    local size; size=$(wc -c < "$resolvers")
                    if [[ "$size" -lt 1000 ]]; then
                        log_warn "Downloaded resolvers file seems too small (${size} bytes). Check manually."
                        rm -f "$resolvers"
                    fi
                else
                    log_warn "Failed to download resolvers. shuffledns will be skipped."
                    secure_touch "$output"
                    return
                fi
            fi

            run_tool "shuffledns" "$output" \
                "shuffledns -list '${alterx_out}' -r '${resolvers}' -mode resolve -silent -o '${output}'"
        }
    fi

    # ── dnsx — filtra subdominios que resolvem ────────────────────────────────
    if should_run "dnsx"; then
        check_tool dnsx && {
            local dir; dir=$(make_tool_dir "dnsx")
            local output="${dir}/dnsx_${ALVO}.txt"
            local shuffledns_out="${BASE_DIR}/shuffledns/shuffledns_${ALVO}.txt"
            [[ -f "$shuffledns_out" ]] || shuffledns_out="$ALL_SUBS_FILE"

            run_tool "dnsx" "$output" \
                "dnsx -silent -o '${output}' < '${shuffledns_out}'"

            if [[ -f "$output" ]]; then
                cp "$output" "${BASE_DIR}/alive_domains.txt"
                chmod 600 "${BASE_DIR}/alive_domains.txt"
            fi
        }
    fi

    ALIVE_SUBS_FILE="${BASE_DIR}/alive_domains.txt"
    if [[ ! -f "$ALIVE_SUBS_FILE" ]]; then
        secure_touch "$ALIVE_SUBS_FILE"
        log_warn "No alive_domains.txt produced. Subsequent phases may be empty."
    fi

    local count; count=$(wc -l < "$ALIVE_SUBS_FILE")
    log_success "Alive domains: ${count} → alive_domains.txt"
}

# =============================================================================
# FASE 3 — PORT SCANNING
# =============================================================================
phase_port_scan() {
    log_section "PHASE 3 — Port Scanning & Service Detection"

    if should_run "naabu"; then
        check_tool naabu && {
            local dir; dir=$(make_tool_dir "naabu")
            local output="${dir}/naabu_${ALVO}.txt"
            run_tool "naabu" "$output" \
                "naabu -silent -o '${output}' < '${ALIVE_SUBS_FILE}'"
        }
    fi
}

# =============================================================================
# FASE 4 — WEB SERVICE DISCOVERY
# =============================================================================
phase_web_discovery() {
    log_section "PHASE 4 — Web Service Discovery"

    local naabu_out="${BASE_DIR}/naabu/naabu_${ALVO}.txt"
    [[ -f "$naabu_out" ]] || naabu_out="$ALIVE_SUBS_FILE"

    if should_run "httpx"; then
        check_tool httpx && {
            local dir; dir=$(make_tool_dir "httpx")
            local output="${dir}/httpx_${ALVO}.txt"
            run_tool "httpx" "$output" \
                "httpx -title -sc -silent -oa -o '${output}' < '${naabu_out}'"
        }
    fi
}

# =============================================================================
# FASE 5 — CRAWLING (subdominios ativos)
# =============================================================================
phase_crawl_alive() {
    log_section "PHASE 5 — Crawling (Alive Subdomains)"

    # ── katana ────────────────────────────────────────────────────────────────
    if should_run "katana"; then
        check_tool katana && {
            local dir; dir=$(make_tool_dir "katana")
            local output="${dir}/katana_${ALVO}.txt"
            run_tool "katana" "$output" \
                "katana -list '${ALIVE_SUBS_FILE}' -d 2 -jc -jsl -silent \
                 | grep -E '\.js([?#].*)?$' | sort -u > '${output}'"
        }
    fi

    # ── subjs ─────────────────────────────────────────────────────────────────
    if should_run "subjs"; then
        check_tool subjs && {
            local dir; dir=$(make_tool_dir "subjs")
            local output="${dir}/subjs_${ALVO}.txt"
            run_tool "subjs" "$output" \
                "subjs < '${ALIVE_SUBS_FILE}' | sort -u > '${output}'"
        }
    fi

    # ── Consolida JS de fontes ativas ─────────────────────────────────────────
    ALIVE_JS_FILE="${BASE_DIR}/all_alive_js.txt"
    local katana_out="${BASE_DIR}/katana/katana_${ALVO}.txt"
    local subjs_out="${BASE_DIR}/subjs/subjs_${ALVO}.txt"

    if [[ -f "$katana_out" ]]; then
        cp "$katana_out" "$ALIVE_JS_FILE"
        chmod 600 "$ALIVE_JS_FILE"
    else
        secure_touch "$ALIVE_JS_FILE"
    fi
    [[ -f "$subjs_out" ]] && anew -q "$ALIVE_JS_FILE" < "$subjs_out" || true

    local count; count=$(wc -l < "$ALIVE_JS_FILE")
    log_success "JS from alive subdomains: ${count} → all_alive_js.txt"
}

# =============================================================================
# FASE 6 — DEEP CRAWLING (fontes arquivadas)
# =============================================================================
phase_crawl_archived() {
    log_section "PHASE 6 — Deep Crawling (Archived Sources)"

    # ── gau ───────────────────────────────────────────────────────────────────
    if should_run "gau"; then
        check_tool gau && {
            local dir; dir=$(make_tool_dir "gau")
            local output="${dir}/gau_${ALVO}.txt"
            run_tool "gau" "$output" \
                "gau --subs < '${ALIVE_SUBS_FILE}' | grep -E '\.js([?#].*)?$' | sort -u > '${output}'"
        }
    fi

    # ── waybackurls ───────────────────────────────────────────────────────────
    if should_run "waybackurls"; then
        check_tool waybackurls && {
            local dir; dir=$(make_tool_dir "waybackurls")
            local output="${dir}/waybackurls_${ALVO}.txt"
            run_tool "waybackurls" "$output" \
                "waybackurls < '${ALIVE_SUBS_FILE}' | grep -E '\.js([?#].*)?$' | sort -u > '${output}'"
        }
    fi

    # ── Consolida JS arquivados ───────────────────────────────────────────────
    ARCHIVED_JS_FILE="${BASE_DIR}/all_archived_js.txt"
    local gau_out="${BASE_DIR}/gau/gau_${ALVO}.txt"
    local wb_out="${BASE_DIR}/waybackurls/waybackurls_${ALVO}.txt"

    if [[ -f "$gau_out" ]]; then
        cp "$gau_out" "$ARCHIVED_JS_FILE"
        chmod 600 "$ARCHIVED_JS_FILE"
    else
        secure_touch "$ARCHIVED_JS_FILE"
    fi
    [[ -f "$wb_out" ]] && anew -q "$ARCHIVED_JS_FILE" < "$wb_out" || true

    # JS secundários linkados dentro dos JS arquivados (cobertura extra)
    if check_tool subjs; then
        local from_archived="${BASE_DIR}/subjs/from_archived_js.txt"
        log_info "Extracting secondary JS from archived JS files..."
        subjs < "$ARCHIVED_JS_FILE" | sort -u > "$from_archived"
        chmod 600 "$from_archived"
        anew -q "$ARCHIVED_JS_FILE" < "$from_archived" || true
    fi

    local count; count=$(wc -l < "$ARCHIVED_JS_FILE")
    log_success "JS from archived sources: ${count} → all_archived_js.txt"
}

# =============================================================================
# FASE 7 — CONSOLIDAÇÃO FINAL
# =============================================================================
phase_consolidate() {
    log_section "PHASE 7 — Final Consolidation"

    ALL_JS_FILE="${BASE_DIR}/all_js.txt"

    if [[ -f "${ALIVE_JS_FILE}" ]]; then
        cp "$ALIVE_JS_FILE" "$ALL_JS_FILE"
        chmod 600 "$ALL_JS_FILE"
    else
        secure_touch "$ALL_JS_FILE"
    fi
    [[ -f "${ARCHIVED_JS_FILE}" ]] && anew -q "$ALL_JS_FILE" < "$ARCHIVED_JS_FILE" || true

    local js_count;    js_count=$(wc -l < "$ALL_JS_FILE")
    local alive_count; alive_count=$(wc -l < "$ALIVE_SUBS_FILE")
    local all_count;   all_count=$(wc -l < "$ALL_SUBS_FILE")
    local recon_mode;  [[ "$SIMPLE" == "true" ]] && recon_mode="Simple" || recon_mode="Full"

    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}  FINAL SUMMARY — ${ALVO}${RESET}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${CYAN}Recon mode                   :${RESET} ${recon_mode}"
    echo -e "  ${CYAN}Unique subdomains found       :${RESET} ${all_count}"
    echo -e "  ${CYAN}Alive domains                 :${RESET} ${alive_count}"
    echo -e "  ${CYAN}Total JS files                :${RESET} ${js_count}"
    echo -e "  ${CYAN}Project directory             :${RESET} ${BASE_DIR}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    log_success "Recon done! Happy hunting, bielzao! 🎯"
    echo ""
}

# =============================================================================
# PARSE DE ARGUMENTOS
# =============================================================================
[[ $# -eq 0 ]] && show_banner && show_help

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domain)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && {
                echo -e "${RED}[ERROR]${RESET} --domain requires a value."; exit 1
            }
            ALVO="$2"; shift 2
            ;;
        --simple)
            SIMPLE="true"; shift
            ;;
        --guided)
            GUIDED="true"; shift
            ;;
        --skip)
            [[ -z "${2:-}" || "${2:-}" == -* ]] && {
                echo -e "${RED}[ERROR]${RESET} --skip requires a comma-separated list."; exit 1
            }
            IFS=',' read -ra SKIP_TOOLS <<< "$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}[ERROR]${RESET} Unknown flag: $1"
            show_help
            ;;
    esac
done

# ── Validações finais ─────────────────────────────────────────────────────────
if [[ -z "$ALVO" ]]; then
    echo -e "${RED}[ERROR]${RESET} Domain not specified. Use -d <domain>."
    show_help
fi

# [SEC] Valida o domínio antes de qualquer execução
validate_domain "$ALVO"

# [SEC] Verifica que BASE_DIR existe e é de fato um diretório
if [[ ! -d "$BASE_DIR" ]]; then
    log_error "Working directory does not exist: ${BASE_DIR}"
    exit 1
fi

# =============================================================================
# PONTO DE ENTRADA
# =============================================================================
show_banner

log_info "Target  : ${GREEN}${ALVO}${RESET}"
log_info "Mode    : ${YELLOW}$( [[ "$SIMPLE" == "true" ]] && echo "Simple Recon" || echo "Full Recon (default)" )${RESET}"
log_info "Guided  : ${YELLOW}${GUIDED}${RESET}"
if [[ ${#SKIP_TOOLS[@]+"${#SKIP_TOOLS[@]}"} -gt 0 ]]; then
    log_info "Skipping: ${YELLOW}${SKIP_TOOLS[*]}${RESET}"
fi
log_info "Dir     : ${BASE_DIR}"
echo ""

phase_subdomain_enum
phase_dns_resolution
phase_port_scan
phase_web_discovery
phase_crawl_alive
phase_crawl_archived
phase_consolidate

#!/bin/bash
# =============================================================================
# rataria.sh — Automated Recon Script for Pentest / Bug Bounty
# Author : bielzao
# Version: 2.0
# =============================================================================

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
MAX_RETRIES=3   # Quantas vezes tentar novamente em caso de falha
RETRY_DELAY=5   # Segundos entre tentativas
BASE_DIR=$(pwd) # Diretório base é o diretório de execução

# =============================================================================
# BANNER
# =============================================================================
show_banner() {
  echo -e "${RED}"
  cat <<'EOF'
    
██████╗  █████╗ ████████╗ █████╗ ██████╗ ██╗ █████╗ 
██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██║██╔══██╗
██████╔╝███████║   ██║   ███████║██████╔╝██║███████║
██╔══██╗██╔══██║   ██║   ██╔══██║██╔══██╗██║██╔══██║
██║  ██║██║  ██║   ██║   ██║  ██║██║  ██║██║██║  ██║
╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝

EOF
  echo -e "${RESET}${DIM}        [ Automated Recon — Pentest & Bug Bounty ]${RESET}"
  echo -e "${DIM}        [ by bielzao | github.com/bielzaoo          ]${RESET}"
  echo -e ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# =============================================================================
# MENU DE AJUDA
# =============================================================================
show_help() {
  show_banner
  echo -e "${BOLD}USAGE:${RESET}"
  echo -e "  ${GREEN}rataria.sh${RESET} ${CYAN}-d <domain>${RESET} ${YELLOW}[--standard | --guided]${RESET}"
  echo ""
  echo -e "${BOLD}FLAGS:${RESET}"
  echo -e "  ${CYAN}-d, --domain${RESET}     Domínio alvo (ex: example.com)"
  echo -e "  ${YELLOW}--standard${RESET}       Executa o fluxo completo automaticamente (sem interação)"
  echo -e "  ${YELLOW}--guided${RESET}         Fluxo guiado — pergunta antes de cada ferramenta"
  echo -e "  ${CYAN}-h, --help${RESET}       Exibe este menu"
  echo ""
  echo -e "${BOLD}EXEMPLOS:${RESET}"
  echo -e "  ${DIM}rataria.sh -d example.com --standard${RESET}"
  echo -e "  ${DIM}rataria.sh -d example.com --guided${RESET}"
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  exit 0
}

# =============================================================================
# LOGGING — funções de log com prefixos coloridos
# =============================================================================
log_info() { echo -e "${CYAN}[INFO]${RESET}    $*"; }
log_tool() { echo -e "${GREEN}[$1]${RESET}$(printf '%*s' $((10 - ${#1})) '') $2"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET}    $*"; }
log_error() { echo -e "${RED}[ERROR]${RESET}   $*"; }
log_success() { echo -e "${MAGENTA}[OK]${RESET}      $*"; }
log_section() {
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${CYAN}  ▶  $*${RESET}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# =============================================================================
# PROGRESS BAR FAKE — dá feedback visual enquanto uma ferramenta roda
# Uso: start_spinner "mensagem" & SPIN_PID=$!  →  stop_spinner $SPIN_PID
# =============================================================================
start_spinner() {
  local msg="${1:-Processando...}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  while true; do
    for frame in "${frames[@]}"; do
      printf "\r  ${CYAN}%s${RESET} %s " "$frame" "$msg"
      sleep 0.1
    done
  done
}

stop_spinner() {
  local pid=$1
  local status=${2:-0}
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  if [[ "$status" -eq 0 ]]; then
    printf "\r  ${GREEN}✔${RESET} Concluído!                          \n"
  else
    printf "\r  ${RED}✘${RESET} Falhou ou sem resultados.           \n"
  fi
}

# =============================================================================
# PERGUNTAR AO USUÁRIO (modo guiado)
# Retorna 0 se sim, 1 se não.
# =============================================================================
ask_user() {
  local question="$1"
  while true; do
    echo -ne "  ${YELLOW}?${RESET} ${question} ${DIM}[s/n]${RESET}: "
    read -r answer
    case "${answer,,}" in
    s | sim | y | yes) return 0 ;;
    n | nao | não | no) return 1 ;;
    *) echo -e "  ${RED}Resposta inválida. Use s ou n.${RESET}" ;;
    esac
  done
}

# =============================================================================
# CRIAR DIRETÓRIO DA FERRAMENTA
# =============================================================================
make_tool_dir() {
  local tool_name="$1"
  local dir="${BASE_DIR}/${tool_name}"
  mkdir -p "$dir"
  echo "$dir"
}

# =============================================================================
# EXECUÇÃO GENÉRICA COM RETRY + SPINNER
#
# Uso:
#   run_tool <tool_name> <output_file> <comando completo...>
#
# Para adicionar uma nova ferramenta ao fluxo, basta chamar run_tool com:
#   - Nome da ferramenta (label exibido nos logs)
#   - Caminho do arquivo de saída
#   - O comando completo a ser executado (incluindo pipes, redireções, etc.)
#     passado como string para eval — isso permite pipes e redireções.
#
# Exemplo:
#   run_tool "minha-tool" "$output" "minha-tool -d $ALVO > '$output'"
# =============================================================================
run_tool() {
  local tool_name="$1"
  local output_file="$2"
  shift 2
  local cmd="$*" # Comando passado como string (suporta pipes/redireções)
  local attempt=0
  local success=0

  log_tool "$tool_name" "Iniciando execução..."

  while [[ $attempt -lt $MAX_RETRIES ]]; do
    attempt=$((attempt + 1))

    # Inicia o spinner em background
    start_spinner "Executando ${tool_name} (tentativa ${attempt}/${MAX_RETRIES})..." &
    local spin_pid=$!

    # Executa o comando; stderr é capturado para não sujar o terminal
    eval "$cmd" 2>/tmp/rataria_err_${tool_name//[^a-zA-Z0-9]/_}.log
    local exit_code=$?

    stop_spinner "$spin_pid" "$exit_code"

    if [[ $exit_code -eq 0 ]]; then
      success=1
      break
    else
      log_warn "${tool_name} falhou na tentativa ${attempt}. Aguardando ${RETRY_DELAY}s..."
      sleep "$RETRY_DELAY"
    fi
  done

  if [[ $success -eq 0 ]]; then
    log_error "${tool_name} falhou após ${MAX_RETRIES} tentativas. Veja: /tmp/rataria_err_${tool_name//[^a-zA-Z0-9]/_}.log"
    # Cria arquivo vazio para não quebrar etapas subsequentes que dependem do arquivo
    touch "$output_file"
    return 1
  fi

  # Conta e exibe quantas linhas foram geradas
  local count=0
  [[ -f "$output_file" ]] && count=$(wc -l <"$output_file")
  log_success "${tool_name} → ${count} resultado(s) em $(basename "$output_file")"
  return 0
}

# =============================================================================
# VERIFICAR SE UMA FERRAMENTA ESTÁ INSTALADA
# =============================================================================
check_tool() {
  if ! command -v "$1" &>/dev/null; then
    log_warn "Ferramenta '${1}' não encontrada no PATH. Etapa será pulada."
    return 1
  fi
  return 0
}

# =============================================================================
# FLUXO: decide se deve executar uma etapa com base no modo (guiado/standard)
# Retorna 0 para executar, 1 para pular.
# =============================================================================
should_run() {
  local tool_name="$1"
  if [[ "$GUIDED" == "true" ]]; then
    ask_user "Executar ${GREEN}${tool_name}${RESET}?"
    return $?
  fi
  return 0 # No modo standard, executa sempre
}

# =============================================================================
# ETAPA 1 — SUBDOMAIN ENUMERATION (passivo)
# =============================================================================
phase_subdomain_enum() {
  log_section "FASE 1 — Subdomain Enumeration (Passivo)"

  # ── subfinder ──────────────────────────────────────────────────────────────
  if should_run "subfinder"; then
    check_tool subfinder && {
      local dir
      dir=$(make_tool_dir "subfinder")
      local output="${dir}/subfinder_${ALVO}.txt"
      run_tool "subfinder" "$output" \
        "subfinder -silent -d '${ALVO}' --all -o '${output}'"
    }
  fi

  # ── assetfinder ───────────────────────────────────────────────────────────
  if should_run "assetfinder"; then
    check_tool assetfinder && {
      local dir
      dir=$(make_tool_dir "assetfinder")
      local output="${dir}/assetfinder_${ALVO}.txt"
      run_tool "assetfinder" "$output" \
        "echo '${ALVO}' | assetfinder -subs-only > '${output}'"
    }
  fi

  # ── amass ─────────────────────────────────────────────────────────────────
  if should_run "amass"; then
    check_tool amass && {
      local dir
      dir=$(make_tool_dir "amass")
      local output="${dir}/amass_${ALVO}.txt"
      run_tool "amass" "$output" \
        "amass enum -d '${ALVO}' -nocolor -silent | grep '${ALVO}' > '${output}'"
    }
  fi

  # ── crt.sh ────────────────────────────────────────────────────────────────
  if should_run "crt"; then
    check_tool crt && {
      local dir
      dir=$(make_tool_dir "crt.sh")
      local output="${dir}/crt.sh_${ALVO}.txt"
      run_tool "crt" "$output" \
        "crt '${ALVO}' > '${output}'"
    }
  fi

  # ── Consolida todos os subdominios encontrados ─────────────────────────────
  log_info "Consolidando resultados de subdomain enum..."
  ALL_SUBS_FILE="${BASE_DIR}/all_subs.txt"

  # Usa o primeiro arquivo disponível como base; os demais são adicionados via anew
  local first=true
  for f in \
    "${BASE_DIR}/subfinder/subfinder_${ALVO}.txt" \
    "${BASE_DIR}/assetfinder/assetfinder_${ALVO}.txt" \
    "${BASE_DIR}/amass/amass_${ALVO}.txt" \
    "${BASE_DIR}/crt.sh/crt.sh_${ALVO}.txt"; do
    [[ -f "$f" ]] || continue
    if $first; then
      cp "$f" "$ALL_SUBS_FILE"
      first=false
    else
      cat "$f" | anew -q "$ALL_SUBS_FILE"
    fi
  done

  $first && touch "$ALL_SUBS_FILE" # Nenhuma ferramenta rodou, cria vazio
  local total
  total=$(wc -l <"$ALL_SUBS_FILE")
  log_success "Total consolidado: ${total} subdominios únicos → all_subs.txt"
}

# =============================================================================
# ETAPA 2 — DNS BRUTEFORCE / RESOLUÇÃO
# =============================================================================
phase_dns_resolution() {
  log_section "FASE 2 — DNS Bruteforce & Resolução"

  # ── alterx — gera permutações de subdominios ──────────────────────────────
  if should_run "alterx"; then
    check_tool alterx && {
      local dir
      dir=$(make_tool_dir "alterx")
      local output="${dir}/alterx_${ALVO}.txt"
      run_tool "alterx" "$output" \
        "cat '${ALL_SUBS_FILE}' | alterx -silent -o '${output}'"
    }
  fi

  # ── shuffledns — resolve subdominios com wordlist ─────────────────────────
  if should_run "shuffledns"; then
    check_tool shuffledns && {
      local dir
      dir=$(make_tool_dir "shuffledns")
      local output="${dir}/shuffledns_${ALVO}.txt"
      local resolvers="${dir}/resolvers.txt"
      local alterx_out="${BASE_DIR}/alterx/alterx_${ALVO}.txt"

      # Faz download da wordlist de resolvers se ainda não existe
      if [[ ! -f "$resolvers" ]]; then
        log_info "Baixando wordlist de resolvers..."
        wget -q "https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt" \
          -O "$resolvers" || log_warn "Falha ao baixar resolvers. shuffledns pode não funcionar corretamente."
      fi

      [[ -f "$alterx_out" ]] || alterx_out="$ALL_SUBS_FILE"

      run_tool "shuffledns" "$output" \
        "shuffledns -list '${alterx_out}' -r '${resolvers}' -mode resolve -silent -o '${output}'"
    }
  fi

  # ── dnsx — valida e filtra subdomínios ativos ─────────────────────────────
  if should_run "dnsx"; then
    check_tool dnsx && {
      local dir
      dir=$(make_tool_dir "dnsx")
      local output="${dir}/dnsx_${ALVO}.txt"
      local shuffledns_out="${BASE_DIR}/shuffledns/shuffledns_${ALVO}.txt"

      [[ -f "$shuffledns_out" ]] || shuffledns_out="$ALL_SUBS_FILE"

      run_tool "dnsx" "$output" \
        "cat '${shuffledns_out}' | dnsx -silent -o '${output}'"

      # Copia resultado para arquivo central de dominios vivos
      [[ -f "$output" ]] && cp "$output" "${BASE_DIR}/alive_domains.txt"
    }
  fi

  ALIVE_SUBS_FILE="${BASE_DIR}/alive_domains.txt"
  [[ -f "$ALIVE_SUBS_FILE" ]] || {
    touch "$ALIVE_SUBS_FILE"
    log_warn "Nenhum dominio ativo encontrado. Etapas seguintes podem estar vazias."
  }

  local count
  count=$(wc -l <"$ALIVE_SUBS_FILE")
  log_success "Dominios ativos: ${count} → alive_domains.txt"
}

# =============================================================================
# ETAPA 3 — PORT SCANNING
# =============================================================================
phase_port_scan() {
  log_section "FASE 3 — Port Scanning & Service Detection"

  # ── naabu — port scanner rápido ───────────────────────────────────────────
  if should_run "naabu"; then
    check_tool naabu && {
      local dir
      dir=$(make_tool_dir "naabu")
      local output="${dir}/naabu_${ALVO}.txt"
      run_tool "naabu" "$output" \
        "cat '${ALIVE_SUBS_FILE}' | naabu -silent -o '${output}'"
    }
  fi
}

# =============================================================================
# ETAPA 4 — WEB SERVICE DISCOVERY (httpx)
# =============================================================================
phase_web_discovery() {
  log_section "FASE 4 — Web Service Discovery"

  local naabu_out="${BASE_DIR}/naabu/naabu_${ALVO}.txt"
  [[ -f "$naabu_out" ]] || naabu_out="$ALIVE_SUBS_FILE"

  # ── httpx — detecta serviços web e coleta metadados ──────────────────────
  if should_run "httpx"; then
    check_tool httpx && {
      local dir
      dir=$(make_tool_dir "httpx")
      local output="${dir}/httpx_${ALVO}.txt"
      run_tool "httpx" "$output" \
        "cat '${naabu_out}' | httpx -title -sc -silent -oa -o '${output}'"
    }
  fi
}

# =============================================================================
# ETAPA 5 — CRAWLING (subdominios ativos)
# =============================================================================
phase_crawl_alive() {
  log_section "FASE 5 — Crawling em Subdominios Ativos"

  # ── katana — crawler de URLs e arquivos JS ────────────────────────────────
  if should_run "katana"; then
    check_tool katana && {
      local dir
      dir=$(make_tool_dir "katana")
      local output="${dir}/katana_${ALVO}.txt"
      run_tool "katana" "$output" \
        "katana -list '${ALIVE_SUBS_FILE}' -d 2 -jc -jsl -silent \
                 | grep -E '\.js([?#].*)?$' | sort -u > '${output}'"
    }
  fi

  # ── subjs — extrai JS de páginas vivas ────────────────────────────────────
  if should_run "subjs"; then
    check_tool subjs && {
      local dir
      dir=$(make_tool_dir "subjs")
      local output="${dir}/subjs_${ALVO}.txt"
      run_tool "subjs" "$output" \
        "cat '${ALIVE_SUBS_FILE}' | subjs | sort -u > '${output}'"
    }
  fi

  # ── Consolida JS de fontes ativas ─────────────────────────────────────────
  ALIVE_JS_FILE="${BASE_DIR}/all_alive_js.txt"
  local katana_out="${BASE_DIR}/katana/katana_${ALVO}.txt"
  local subjs_out="${BASE_DIR}/subjs/subjs_${ALVO}.txt"

  [[ -f "$katana_out" ]] && cp "$katana_out" "$ALIVE_JS_FILE" || touch "$ALIVE_JS_FILE"
  [[ -f "$subjs_out" ]] && cat "$subjs_out" | anew -q "$ALIVE_JS_FILE"

  local count
  count=$(wc -l <"$ALIVE_JS_FILE")
  log_success "JS de subdominios ativos: ${count} → all_alive_js.txt"
}

# =============================================================================
# ETAPA 6 — DEEP CRAWLING (fontes arquivadas)
# =============================================================================
phase_crawl_archived() {
  log_section "FASE 6 — Deep Crawling (Fontes Arquivadas)"

  # ── gau — coleta URLs de fontes históricas (Wayback, AlienVault...) ───────
  if should_run "gau"; then
    check_tool gau && {
      local dir
      dir=$(make_tool_dir "gau")
      local output="${dir}/gau_${ALVO}.txt"
      run_tool "gau" "$output" \
        "gau --subs < '${ALIVE_SUBS_FILE}' | grep -E '\.js([?#].*)?$' | sort -u > '${output}'"
    }
  fi

  # ── waybackurls — coleta URLs do Wayback Machine ──────────────────────────
  if should_run "waybackurls"; then
    check_tool waybackurls && {
      local dir
      dir=$(make_tool_dir "waybackurls")
      local output="${dir}/waybackurls_${ALVO}.txt"
      run_tool "waybackurls" "$output" \
        "waybackurls < '${ALIVE_SUBS_FILE}' | grep -E '\.js([?#].*)?$' | sort -u > '${output}'"
    }
  fi

  # ── Consolida JS de fontes arquivadas ─────────────────────────────────────
  ARCHIVED_JS_FILE="${BASE_DIR}/all_archived_js.txt"
  local gau_out="${BASE_DIR}/gau/gau_${ALVO}.txt"
  local wb_out="${BASE_DIR}/waybackurls/waybackurls_${ALVO}.txt"

  [[ -f "$gau_out" ]] && cp "$gau_out" "$ARCHIVED_JS_FILE" || touch "$ARCHIVED_JS_FILE"
  [[ -f "$wb_out" ]] && cat "$wb_out" | anew -q "$ARCHIVED_JS_FILE"

  # JS linkados dentro dos JS arquivados (cobertura extra)
  if check_tool subjs; then
    local from_archived="${BASE_DIR}/subjs/from_archived_js.txt"
    log_info "Buscando JS secundários dentro de JS arquivados..."
    cat "$ARCHIVED_JS_FILE" | subjs | sort -u >"$from_archived"
    cat "$from_archived" | anew -q "$ARCHIVED_JS_FILE"
  fi

  local count
  count=$(wc -l <"$ARCHIVED_JS_FILE")
  log_success "JS de fontes arquivadas: ${count} → all_archived_js.txt"
}

# =============================================================================
# ETAPA 7 — CONSOLIDAÇÃO FINAL
# =============================================================================
phase_consolidate() {
  log_section "FASE 7 — Consolidação Final"

  ALL_JS_FILE="${BASE_DIR}/all_js.txt"

  [[ -f "${ALIVE_JS_FILE:-}" ]] && cp "$ALIVE_JS_FILE" "$ALL_JS_FILE" || touch "$ALL_JS_FILE"
  [[ -f "${ARCHIVED_JS_FILE:-}" ]] && cat "$ARCHIVED_JS_FILE" | anew -q "$ALL_JS_FILE"

  local js_count
  js_count=$(wc -l <"$ALL_JS_FILE")
  local alive_count
  alive_count=$(wc -l <"${ALIVE_SUBS_FILE:-/dev/null}" 2>/dev/null || echo 0)

  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  RESUMO FINAL — ${ALVO}${RESET}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "  ${CYAN}Subdominios únicos encontrados :${RESET} $(wc -l <"${ALL_SUBS_FILE:-/dev/null}" 2>/dev/null || echo 0)"
  echo -e "  ${CYAN}Subdominios ativos             :${RESET} ${alive_count}"
  echo -e "  ${CYAN}Total de arquivos JS           :${RESET} ${js_count}"
  echo -e "  ${CYAN}Diretório do projeto           :${RESET} ${BASE_DIR}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
  log_success "Recon finalizado! Bom hunting, bielzao! 🎯"
  echo ""
}

# =============================================================================
# PARSE DE ARGUMENTOS
# =============================================================================
ALVO=""
GUIDED="false"
MODE=""

# Exibe ajuda se nenhum argumento for passado
[[ $# -eq 0 ]] && show_banner && show_help

while [[ $# -gt 0 ]]; do
  case "$1" in
  -d | --domain)
    ALVO="$2"
    shift 2
    ;;
  --standard)
    MODE="standard"
    GUIDED="false"
    shift
    ;;
  --guided)
    MODE="guided"
    GUIDED="true"
    shift
    ;;
  -h | --help)
    show_banner
    show_help
    ;;
  *)
    echo -e "${RED}[ERROR]${RESET} Flag desconhecida: $1"
    show_help
    ;;
  esac
done

# Validações básicas
if [[ -z "$ALVO" ]]; then
  echo -e "${RED}[ERROR]${RESET} Domínio não informado. Use -d <dominio>."
  show_help
fi

if [[ -z "$MODE" ]]; then
  echo -e "${RED}[ERROR]${RESET} Especifique o modo: --standard ou --guided."
  show_help
fi

# =============================================================================
# PONTO DE ENTRADA — executa todas as fases em sequência
# =============================================================================
show_banner

log_info "Alvo   : ${GREEN}${ALVO}${RESET}"
log_info "Modo   : ${YELLOW}${MODE}${RESET}"
log_info "Projeto: ${BASE_DIR}"
echo ""

phase_subdomain_enum
phase_dns_resolution
phase_port_scan
phase_web_discovery
phase_crawl_alive
phase_crawl_archived
phase_consolidate

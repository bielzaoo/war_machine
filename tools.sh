#!/bin/bash

# =========================
# 🔐 CHECAGEM DE ROOT
# =========================
if [ "$EUID" -ne 0 ]; then
  printf "[\e[1;31mERROR\e[0m] Execute este script como root (use sudo)\n"
  exit 1
fi

# =========================
# 🎨 CORES
# =========================
GREEN="\e[1;32m"
CYAN="\e[1;36m"
RED="\e[1;31m"
RESET="\e[0m"

# =========================
# 📁 LOG
# =========================
LOG_FILE="$HOME/install.log"

# =========================
# ⏳ SPINNER
# =========================
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'

  while ps -p $pid >/dev/null 2>&1; do
    local temp=${spinstr#?}
    printf " [%c] " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done

  printf "      \b\b\b\b\b\b"
}

# =========================
# 🔇 EXEC COM SPINNER
# =========================
run_with_spinner() {
  ("$@" >>"$LOG_FILE" 2>&1) &
  local pid=$!
  spinner $pid
  wait $pid
  return $?
}

# =========================
# 🔁 RETRY
# =========================
retry() {
  local retries=3
  local count=0
  local delay=2

  until "$@"; do
    exit_code=$?
    count=$((count + 1))

    if [ $count -lt $retries ]; then
      printf "[${CYAN}SETUP${RESET}] Tentando novamente ($count/$retries)...\n"
      sleep $delay
    else
      printf "[${RED}ERROR${RESET}] Falhou após $retries tentativas.\n"
      return $exit_code
    fi
  done
  return 0
}

# =========================
# 📢 MENSAGENS
# =========================
setup_msg() {
  printf "[${CYAN}SETUP${RESET}] %s\n" "$1"
}

install_msg() {
  printf "[${GREEN}INSTALL${RESET}] %s\n" "$1"
}

error_msg() {
  printf "[${RED}ERROR${RESET}] %s\n" "$1"
}

# =========================
# 🚀 INÍCIO
# =========================
setup_msg "Iniciando ambiente..."

# Atualizar pacotes
install_msg "Atualizando pacotes..."
if retry run_with_spinner apt update; then
  install_msg "apt update OK"
else
  error_msg "Falha no apt update (veja $LOG_FILE)"
fi

# Upgrade do sistema
install_msg "Atualizando sistema (upgrade)..."
if retry run_with_spinner apt upgrade -y; then
  install_msg "Sistema atualizado"
else
  error_msg "Falha no upgrade (veja $LOG_FILE)"
fi

# Criar diretório de tools
setup_msg "Criando diretório para as ferramentas..."
if retry run_with_spinner mkdir -p /opt/tools; then
  install_msg "/opt/tools pronto"
else
  error_msg "Erro ao criar /opt/tools"
fi

# Criar diretório de wordlists
setup_msg "Criando diretório de wordlists..."

if retry run_with_spinner mkdir -p /opt/wordlists; then
  install_msg "/opt/wordlists pronto"
else
  error_msg "Erro ao criar /opt/wordlists"
fi

# Detectar shell
shell_name=$(basename "$SHELL")
RC_FILE="$HOME/.${shell_name}rc"

setup_msg "Configurando PATH no $RC_FILE..."

# Adicionar Go bin ao PATH (evitar duplicação)
if ! grep -q 'export PATH=$HOME/go/bin:$PATH' "$RC_FILE" 2>/dev/null; then
  echo 'export PATH=$HOME/go/bin:$PATH' >>"$RC_FILE"
  install_msg "Adicionado Go bin ao PATH"
else
  setup_msg "Go bin já está no PATH"
fi

# Adicionar /opt/tools ao PATH (evitar duplicação)
if ! grep -q 'export PATH=/opt/tools:$PATH' "$RC_FILE" 2>/dev/null; then
  echo 'export PATH=/opt/tools:$PATH' >>"$RC_FILE"
  install_msg "Adicionado /opt/tools ao PATH"
else
  setup_msg "/opt/tools já está no PATH"
fi

# Instalar dependências
install_msg "Instalando dependências..."
if retry run_with_spinner apt install -y wget jq git curl build-essential golang libpcap-dev; then
  install_msg "Dependências OK"
else
  error_msg "Erro ao instalar dependências"
fi

# Instalar ferramenta httpx
install_msg "Instalando httpx..."
if retry run_with_spinner go install github.com/projectdiscovery/httpx/cmd/httpx@latest; then
  install_msg "httpx instalado"
else
  error_msg "Erro ao instalar httpx"
fi

# Instalar ferramenta subfinder
install_msg "Instalando subfinder..."
if retry run_with_spinner go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest; then
  install_msg "subfinder instalado"
else
  error_msg "Erro ao instalar subfinder"
fi

# Instalar assetfinder
install_msg "Instalando assetfinder..."

ASSET_URL="https://github.com/tomnomnom/assetfinder/releases/download/v0.1.1/assetfinder-linux-amd64-0.1.1.tgz"
TMP_FILE="/tmp/assetfinder.tgz"

if retry run_with_spinner wget -q "$ASSET_URL" -O "$TMP_FILE"; then
  if retry run_with_spinner tar xzf "$TMP_FILE" -C /tmp; then
    if retry run_with_spinner mkdir -p /opt/tools; then
      if retry run_with_spinner mv /tmp/assetfinder /opt/tools/; then
        install_msg "assetfinder instalado em /opt/tools"
      else
        error_msg "Erro ao mover assetfinder"
      fi
    else
      error_msg "Erro ao criar /opt/tools"
    fi
  else
    error_msg "Erro ao extrair assetfinder"
  fi
  rm -f "$TMP_FILE"
else
  error_msg "Erro ao baixar assetfinder"
fi

# Instalar Amass
install_msg "Instalando Amass..."
if retry run_with_spinner env CGO_ENABLED=0 go install github.com/owasp-amass/amass/v5/cmd/amass@main; then
  install_msg "Amass instalado"
else
  error_msg "Erro ao instalar Amass"
fi

# Instalar AlterX
install_msg "Instalando Alterx..."
if retry run_with_spinner go install github.com/projectdiscovery/alterx/cmd/alterx@latest; then
  install_msg "Alterx instalado"
else
  error_msg "Erro ao instalar Alterx"
fi

# Instalar dependências
install_msg "Instalando dependências para MassDNS..."
if retry run_with_spinner apt install -y git build-essential; then
  install_msg "Dependências OK"
else
  error_msg "Erro ao instalar dependências"
fi

# Instalar MassDNS
install_msg "Instalando MassDNS..."

if retry run_with_spinner git clone https://github.com/blechschmidt/massdns.git /tmp/massdns; then

  if retry run_with_spinner make -C /tmp/massdns; then

    if retry run_with_spinner mv /tmp/massdns/bin/massdns /opt/tools/; then
      install_msg "MassDNS instalado em /opt/tools"
    else
      error_msg "Erro ao mover MassDNS"
    fi

  else
    error_msg "Erro ao compilar MassDNS"
  fi

  rm -rf /tmp/massdns

else
  error_msg "Erro ao clonar MassDNS"
fi

# Instalar shuffleDNS
install_msg "Instalando shuffleDNS..."

if retry run_with_spinner go install github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest; then
  install_msg "shuffleDNS instalado"
else
  error_msg "Erro ao instalar shuffleDNS"
fi

# Instalar dnsx
install_msg "Instalando dnsx..."

if retry run_with_spinner go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest; then
  install_msg "dnsx instalado"
else
  error_msg "Erro ao instalar dnsx"
fi

# Instalar naabu
install_msg "Instalando naabu..."

if retry run_with_spinner go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest; then
  install_msg "naabu instalado"
else
  error_msg "Erro ao instalar naabu"
fi

# Instalando crt.sh
# Detectar diretório do script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_msg "Instalando script crt.sh..."

if retry run_with_spinner mv "$SCRIPT_DIR/scripts/crt.sh" /opt/tools/crt; then
  chmod +x /opt/tools/crt
  install_msg "crt instalado em /opt/tools"
else
  error_msg "Erro ao instalar crt"
fi

# Instalar katana
install_msg "Instalando katana..."

if retry run_with_spinner env CGO_ENABLED=1 go install github.com/projectdiscovery/katana/cmd/katana@latest; then
  install_msg "katana instalado"
else
  error_msg "Erro ao instalar katana"
fi

# Instalar gau
install_msg "Instalando gau..."

if retry run_with_spinner go install github.com/lc/gau/v2/cmd/gau@latest; then
  install_msg "gau instalado"
else
  error_msg "Erro ao instalar gau"
fi

# Instalar waybackurls
install_msg "Instalando waybackurls..."

if retry run_with_spinner go install github.com/tomnomnom/waybackurls@latest; then
  install_msg "waybackurls instalado"
else
  error_msg "Erro ao instalar waybackurls"
fi

# Instalar waybackurls
install_msg "Instalando waybackurls..."

if retry run_with_spinner go install github.com/tomnomnom/waybackurls@latest; then
  install_msg "waybackurls instalado"
else
  error_msg "Erro ao instalar waybackurls"
fi

# Instalar subjs
install_msg "Instalando subjs..."

SUBJS_URL="https://github.com/lc/subjs/releases/download/v1.0.1/subjs_1.0.1_linux_amd64.tar.gz"
TMP_FILE="/tmp/subjs.tar.gz"
TMP_DIR="/tmp/subjs"

# Criar diretório temporário
mkdir -p "$TMP_DIR"

if retry run_with_spinner wget -q "$SUBJS_URL" -O "$TMP_FILE"; then

  if retry run_with_spinner tar xzf "$TMP_FILE" -C "$TMP_DIR"; then

    if retry run_with_spinner mv "$TMP_DIR/subjs" /opt/tools/; then
      install_msg "subjs instalado em /opt/tools"
    else
      error_msg "Erro ao mover subjs"
    fi

  else
    error_msg "Erro ao extrair subjs"
  fi

  # Limpeza
  rm -rf "$TMP_FILE" "$TMP_DIR"

else
  error_msg "Erro ao baixar subjs"
fi

# Instalar getjs
install_msg "Instalando getjs..."

if retry run_with_spinner go install github.com/003random/getJS/v2@latest; then
  install_msg "getjs instalado"
else
  error_msg "Erro ao instalar getjs"
fi

# Instalar hakrawler
install_msg "Instalando hakrawler..."

if retry run_with_spinner go install github.com/hakluke/hakrawler@latest; then
  install_msg "hakrawler instalado"
else
  error_msg "Erro ao instalar hakrawler"
fi

# Instalar sqlmap
install_msg "Instalando sqlmap..."

if retry run_with_spinner git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git /opt/tools/sqlmap-dev; then
  install_msg "sqlmap clonado em /opt/tools/sqlmap-dev"
else
  error_msg "Erro ao clonar sqlmap"
fi
# Tornar executável e criar symlink
setup_msg "Configurando execução do sqlmap..."

if retry run_with_spinner chmod +x /opt/tools/sqlmap-dev/sqlmap.py; then

  if retry run_with_spinner ln -sf /opt/tools/sqlmap-dev/sqlmap.py /opt/tools/sqlmap; then
    install_msg "sqlmap pronto para uso"
  else
    error_msg "Erro ao criar symlink do sqlmap"
  fi

else
  error_msg "Erro ao aplicar permissão no sqlmap"
fi

# Instalar nuclei
install_msg "Instalando nuclei..."

if retry run_with_spinner go install github.com/003random/getJS/v2@latest; then
  install_msg "nuclei instalado"
else
  error_msg "Erro ao instalar nuclei"
fi

# Instalar dalfox (XSS)
install_msg "Instalando Dalfox (XSS)..."

if retry run_with_spinner go install github.com/hahwul/dalfox/v2@latest; then
  install_msg "Dalfox (XSS) instalado"
else
  error_msg "Erro ao instalar Dalfox (XSS)"
fi

# Instalar ou atualizar SecLists
install_msg "Instalando/Atualizando SecLists..."

if [ -d "/opt/wordlists/SecLists" ]; then
  setup_msg "SecLists já existe, atualizando..."

  if retry run_with_spinner git -C /opt/wordlists/SecLists pull; then
    install_msg "SecLists atualizado"
  else
    error_msg "Erro ao atualizar SecLists"
  fi

else
  if retry run_with_spinner git clone --depth 1 https://github.com/danielmiessler/SecLists.git /opt/wordlists/SecLists; then
    install_msg "SecLists instalado em /opt/wordlists/SecLists"
  else
    error_msg "Erro ao clonar SecLists"
  fi
fi

# =========================
# 🧹 LIMPEZA
# =========================
install_msg "Removendo pacotes desnecessários..."
retry run_with_spinner apt autoremove -y

# =========================
# ✅ FINAL
# =========================
setup_msg "Finalizado!"
setup_msg "Logs disponíveis em: $LOG_FILE"

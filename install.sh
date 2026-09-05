#!/usr/bin/env bash
# =====================================================================
#  Kali minimal VM - setup automatizado
#
#  Parte de uma instalacao Kali sem nenhum desktop environment
#  (todas as caixas desmarcadas em "Software selection") e entrega
#  i3 + Alacritty + tmux + zsh/starship, tema vanta black + cyan.
#
#  Uso:
#     ./install.sh              # tudo
#     ./install.sh --no-ssh     # pula o endurecimento do SSH
#     ./install.sh --no-font    # pula o download da Nerd Font
# =====================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${REPO_DIR}/config"
STAMP="$(date +%Y%m%d-%H%M%S)"

DO_SSH=1
DO_FONT=1
for arg in "$@"; do
    case "$arg" in
        --no-ssh)  DO_SSH=0 ;;
        --no-font) DO_FONT=0 ;;
        -h|--help)
            sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 1 ;;
    esac
done

# --- helpers ----------------------------------------------------------
C_OK=$'\033[38;2;0;240;255m'
C_WARN=$'\033[38;2;255;184;0m'
C_ERR=$'\033[38;2;255;59;92m'
C_OFF=$'\033[0m'

info() { printf '%s::%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
die()  { printf '%sXX%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

# Copia preservando backup se o destino existir e for diferente
install_config() {
    local src="$1" dst="$2"
    [ -f "$src" ] || die "arquivo de origem ausente: $src"
    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp "$dst" "${dst}.bak-${STAMP}"
        warn "backup: ${dst}.bak-${STAMP}"
    fi
    cp "$src" "$dst"
    info "config: $dst"
}

# Insere um bloco delimitado em um arquivo, substituindo se ja existir.
# Isso e o que torna o script idempotente em ~/.zshrc e ~/.zprofile.
ensure_block() {
    local file="$1" tag="$2" content="$3"
    local begin="# >>> ${tag} >>>"
    local end="# <<< ${tag} <<<"
    touch "$file"
    if grep -qF "$begin" "$file"; then
        # remove bloco antigo
        sed -i "/^${begin}\$/,/^${end}\$/d" "$file"
    fi
    {
        printf '%s\n' "$begin"
        printf '%s\n' "$content"
        printf '%s\n' "$end"
    } >> "$file"
    info "bloco '${tag}' aplicado em ${file}"
}

[ "$(id -u)" -eq 0 ] && die "rode como usuario normal, nao root (o script usa sudo onde precisa)"
command -v sudo >/dev/null 2>&1 || die "sudo nao encontrado"
[ -d "$CONFIG_SRC" ] || die "diretorio config/ nao encontrado ao lado do script"

# =====================================================================
#  1. Pacotes
# =====================================================================
info "atualizando indices do apt"
sudo apt-get update -qq

# Camada grafica. NAO usar --no-install-recommends aqui: no Debian/Kali
# varias libs sao carregadas via dlopen (libXcursor, libXi) e nao aparecem
# como dependencia rigida; cortar recommends quebra o X em runtime.
PKGS_X="
xserver-xorg-core
xserver-xorg-input-libinput
xserver-xorg-video-vesa
xinit
xkb-data
x11-xserver-utils
"

# Resto da stack: recommends cortado com seguranca
PKGS_MIN="
i3-wm
i3status
i3lock
dmenu
alacritty
tmux
zsh
dunst
libnotify-bin
feh
maim
xclip
xsel
network-manager
network-manager-gnome
fonts-jetbrains-mono
unzip
curl
wget
git
build-essential
dnsutils
spice-vdagent
firefox-esr
"

info "instalando camada grafica (com recommends)"
# shellcheck disable=SC2086
sudo apt-get install -y $PKGS_X

info "instalando stack principal"
# shellcheck disable=SC2086
sudo apt-get install -y --no-install-recommends $PKGS_MIN

# firefox-esr pode nao existir dependendo do momento do repo Kali
if ! command -v firefox-esr >/dev/null 2>&1 && ! command -v firefox >/dev/null 2>&1; then
    warn "firefox nao instalado pelo nome esperado; tentando 'firefox'"
    sudo apt-get install -y --no-install-recommends firefox || \
        warn "firefox indisponivel no repo - instale manualmente depois"
fi

# =====================================================================
#  2. Starship
# =====================================================================
if command -v starship >/dev/null 2>&1; then
    info "starship ja presente"
elif apt-cache policy starship 2>/dev/null | grep -q 'Candidate: [0-9]'; then
    info "instalando starship via apt"
    sudo apt-get install -y starship
else
    info "starship nao esta no repo; usando instalador oficial"
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
fi

# =====================================================================
#  3. JetBrainsMono Nerd Font
# =====================================================================
if [ "$DO_FONT" -eq 1 ]; then
    if fc-list 2>/dev/null | grep -qi 'jetbrains.*nerd'; then
        info "Nerd Font ja instalada"
    else
        info "baixando JetBrainsMono Nerd Font"
        FONT_DIR="${HOME}/.local/share/fonts/JetBrainsMono"
        mkdir -p "$FONT_DIR"
        TMP_ZIP="$(mktemp -d)/JetBrainsMono.zip"
        if curl -fsSL -o "$TMP_ZIP" \
            https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
        then
            unzip -oq "$TMP_ZIP" -d "$FONT_DIR"
            rm -rf "$(dirname "$TMP_ZIP")"
            fc-cache -f >/dev/null
            info "Nerd Font instalada"
        else
            warn "download da Nerd Font falhou - icones aparecerao como caixinhas"
        fi
    fi
else
    info "pulando Nerd Font (--no-font)"
fi

# =====================================================================
#  4. Configs
# =====================================================================
install_config "${CONFIG_SRC}/i3/config"                "${HOME}/.config/i3/config"
install_config "${CONFIG_SRC}/i3status/config"          "${HOME}/.config/i3status/config"
install_config "${CONFIG_SRC}/alacritty/alacritty.toml" "${HOME}/.config/alacritty/alacritty.toml"
install_config "${CONFIG_SRC}/dunst/dunstrc"            "${HOME}/.config/dunst/dunstrc"
install_config "${CONFIG_SRC}/starship.toml"            "${HOME}/.config/starship.toml"
install_config "${CONFIG_SRC}/tmux.conf"                "${HOME}/.tmux.conf"

mkdir -p "${HOME}/.config/scripts" "${HOME}/.config/wallpapers" "${HOME}/Pictures/screenshots"
for s in wallpaper.sh screenshot.sh; do
    install_config "${CONFIG_SRC}/scripts/${s}" "${HOME}/.config/scripts/${s}"
    chmod +x "${HOME}/.config/scripts/${s}"
done

cat > "${HOME}/.config/wallpapers/README" << 'EOF'
Coloque uma imagem (.jpg .jpeg .png .webp .bmp) neste diretorio e
recarregue o i3 com Mod+Shift+C.

Sem imagem aqui, o fundo fica preto solido (#000000).
Se houver mais de uma, a primeira em ordem alfabetica e usada.
EOF

# =====================================================================
#  5. Shell: zsh + starship
# =====================================================================
ensure_block "${HOME}/.zshrc" "kali-setup starship" \
'zmodload zsh/mathfunc   # evita "__starship_get_time: unknown function: int"
eval "$(starship init zsh)"'

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v zsh)" ]; then
    info "definindo zsh como shell padrao"
    sudo chsh -s "$(command -v zsh)" "$USER"
else
    info "zsh ja e o shell padrao"
fi

# =====================================================================
#  6. Autostart do i3 no tty1
# =====================================================================
echo "exec i3" > "${HOME}/.xinitrc"
info "config: ${HOME}/.xinitrc"

ensure_block "${HOME}/.zprofile" "kali-setup autostart i3" \
'if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi'

# =====================================================================
#  7. spice-vdagent
# =====================================================================
# O daemon e ativado por socket no Debian - nao tem secao [Install],
# entao "systemctl enable spice-vdagentd" falha. O alvo e o .socket.
if systemctl list-unit-files 2>/dev/null | grep -q '^spice-vdagentd.socket'; then
    sudo systemctl enable --now spice-vdagentd.socket >/dev/null 2>&1 || true
    info "spice-vdagentd.socket ativo (resolucao dinamica)"
fi

# =====================================================================
#  8. SSH
# =====================================================================
if [ "$DO_SSH" -eq 1 ]; then
    sudo apt-get install -y --no-install-recommends openssh-server
    sudo systemctl enable --now ssh >/dev/null 2>&1 || true

    AUTH_KEYS="${HOME}/.ssh/authorized_keys"
    if [ -s "$AUTH_KEYS" ]; then
        info "chave publica encontrada - endurecendo sshd"
        sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/'               /etc/ssh/sshd_config
        sudo systemctl restart ssh
        printf '   config efetiva: '
        sudo sshd -T | grep -iE '^(passwordauthentication|permitrootlogin)' | tr '\n' ' '
        printf '\n'
    else
        warn "sem ~/.ssh/authorized_keys - senha NAO foi desabilitada"
        warn "rode no host:  ssh-copy-id -i ~/.ssh/SUA_CHAVE.pub ${USER}@<ip-da-vm>"
        warn "e depois:      ./install.sh   (para aplicar o endurecimento)"
    fi
else
    info "pulando SSH (--no-ssh)"
fi

# =====================================================================
info "concluido"
cat << 'EOF'

  Reinicie a VM (ou saia e logue de novo no tty1) para o i3 subir sozinho.

  Atalhos principais (Mod = Super):
    Mod+Enter          terminal          Mod+D              dmenu
    Mod+Q              fechar janela     Mod+F              fullscreen
    Mod+H/J/K/L        foco              Mod+Shift+H/J/K/L  mover janela
    Mod+1..0           workspace         Mod+Shift+1..0     mover p/ workspace
    Mod+B / Mod+V      split h / v       Mod+R              modo resize
    Mod+Shift+S        screenshot area   Print              screenshot tela
    Mod+Shift+X        lock              Mod+Shift+E        sair
    Mod+Shift+C        recarregar        Mod+Shift+R        reiniciar i3

  Wallpaper: jogue uma imagem em ~/.config/wallpapers/ e Mod+Shift+C.

EOF

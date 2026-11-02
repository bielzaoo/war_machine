#!/usr/bin/env bash
# =====================================================================
#  war_machine - setup automatizado de VM Kali
#
#  Entrega i3 + kitty/Alacritty + tmux + zsh/starship + eza/zoxide/fzf,
#  tema vanta black + cyan. Funciona nas duas bases:
#    - ISO installer, sem nenhum desktop ("Software selection" vazio)
#    - imagem QEMU pronta (XFCE + lightdm): o i3 assume e o lightdm
#      e desligado (reversivel), liberando RAM
#
#  Uso:
#     ./install.sh              # tudo (sem ferramentas de pentest)
#     ./install.sh --tools      # + perfil de ferramentas AD/web (CRTP, Burp)
#     ./install.sh --dry-run    # so mostra o que faria, nao muda nada
#     ./install.sh --tz=ZONA    # fuso (padrao America/Sao_Paulo)
#     ./install.sh --no-tz      # nao mexe no fuso
#     ./install.sh --no-ssh     # pula o endurecimento do SSH
#     ./install.sh --no-font    # pula o download da Nerd Font
#     ./install.sh --no-glass   # sem kitty/vidro: so Alacritty solido
#     ./install.sh --keep-dm    # imagem QEMU: mantem o lightdm e
#                               # adiciona o i3 como sessao
# =====================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="${REPO_DIR}/config"
BIN_SRC="${REPO_DIR}/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"

DO_SSH=1
DO_FONT=1
DO_GLASS=1
DO_TOOLS=0
KEEP_DM=0
DRY=0
TZ_WANT="America/Sao_Paulo"
for arg in "$@"; do
    case "$arg" in
        --no-ssh)   DO_SSH=0 ;;
        --no-font)  DO_FONT=0 ;;
        --no-glass) DO_GLASS=0 ;;
        --tools)    DO_TOOLS=1 ;;
        --keep-dm)  KEEP_DM=1 ;;
        --dry-run)  DRY=1 ;;
        --tz=*)     TZ_WANT="${arg#--tz=}" ;;
        --no-tz)    TZ_WANT="" ;;
        -h|--help)
            sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 1 ;;
    esac
done

# --- helpers ----------------------------------------------------------
C_OK=$'\033[38;2;0;240;255m'
C_WARN=$'\033[38;2;255;184;0m'
C_ERR=$'\033[38;2;255;59;92m'
C_DIM=$'\033[38;2;90;101;103m'
C_OFF=$'\033[0m'

info() { printf '%s::%s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s!!%s %s\n' "$C_WARN" "$C_OFF" "$*"; }
die()  { printf '%sXX%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }

# Todo comando que altera o sistema passa por aqui: no --dry-run so imprime.
run() {
    if [ "$DRY" -eq 1 ]; then
        printf '%s[dry]%s %s\n' "$C_DIM" "$C_OFF" "$*"
    else
        "$@"
    fi
}

# Escreve um arquivo de root (conteudo no stdin) - sudo tee sem ruido
write_root() {
    local dst="$1" content
    content="$(cat)"
    if [ "$DRY" -eq 1 ]; then
        printf '%s[dry]%s escreveria %s:\n' "$C_DIM" "$C_OFF" "$dst"
        printf '%s\n' "$content" | sed 's/^/       /'
    else
        printf '%s\n' "$content" | sudo tee "$dst" >/dev/null
    fi
}

apt_install() {
    run sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# Copia preservando backup se o destino existir e for diferente
install_config() {
    local src="$1" dst="$2"
    [ -f "$src" ] || die "arquivo de origem ausente: $src"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        info "config: $dst (igual)"
        return 0
    fi
    if [ "$DRY" -eq 1 ]; then
        if [ -f "$dst" ]; then
            printf '%s[dry]%s atualizaria %s\n' "$C_DIM" "$C_OFF" "$dst"
        else
            printf '%s[dry]%s criaria %s\n' "$C_DIM" "$C_OFF" "$dst"
        fi
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ]; then
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
    if [ "$DRY" -eq 1 ]; then
        printf '%s[dry]%s bloco %s em %s\n' "$C_DIM" "$C_OFF" "'${tag}'" "$file"
        return 0
    fi
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
[ "$DRY" -eq 1 ] && warn "--dry-run: nada sera alterado, so listado"

# --- qual base? -------------------------------------------------------
# A imagem QEMU pronta vem com XFCE + lightdm; o ISO installer (sem nada
# marcado) nao tem display manager. O alias display-manager.service aponta
# para o DM ativo, se houver.
DM=""
if [ -L /etc/systemd/system/display-manager.service ]; then
    DM="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)")"
fi
if [ -n "$DM" ]; then
    info "base: imagem com desktop (display manager: ${DM})"
else
    info "base: instalacao minima (sem display manager)"
fi

# =====================================================================
#  1. Pacotes
# =====================================================================
info "atualizando indices do apt"
run sudo apt-get update -qq

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

# Resto da stack: recommends cortado com seguranca. Thunar sem recommends
# fica sem gvfs/volman (lixeira e montagem automatica): numa VM nao faz falta.
# tumbler gera as miniaturas (screenshots de evidencia).
PKGS_MIN="
i3-wm
i3status
i3lock
dmenu
alacritty
tmux
zsh
fzf
zoxide
eza
dunst
libnotify-bin
feh
maim
xclip
xsel
network-manager
fonts-jetbrains-mono
adwaita-icon-theme
gnome-themes-extra
xsettingsd
unzip
curl
wget
git
build-essential
dnsutils
spice-vdagent
firefox-esr
thunar
tumbler
"

info "instalando camada grafica (com recommends)"
# shellcheck disable=SC2086
apt_install $PKGS_X

# Vidro: kitty desenha imagem de fundo sem compositor; ImageMagick gera
# (uma vez) a versao desfocada do wallpaper que vai atras do texto.
PKGS_GLASS="
kitty
imagemagick
"

info "instalando stack principal"
# shellcheck disable=SC2086
apt_install --no-install-recommends $PKGS_MIN

if [ "$DO_GLASS" -eq 1 ]; then
    info "instalando terminal vidro (kitty + imagemagick)"
    # shellcheck disable=SC2086
    apt_install --no-install-recommends $PKGS_GLASS || \
        warn "falhou instalar kitty/imagemagick - segue com Alacritty solido"
else
    info "pulando terminal vidro (--no-glass)"
fi

# firefox-esr pode nao existir dependendo do momento do repo Kali
if [ "$DRY" -eq 0 ] && ! command -v firefox-esr >/dev/null 2>&1 && ! command -v firefox >/dev/null 2>&1; then
    warn "firefox nao instalado pelo nome esperado; tentando 'firefox'"
    apt_install --no-install-recommends firefox || \
        warn "firefox indisponivel no repo - instale manualmente depois"
fi

# =====================================================================
#  1b. Perfil de ferramentas (--tools)
# =====================================================================
# Foco: AD (trilha CRTP/CARTP) + web (Burp). Nada do metapacote gigante.
# Nome que nao existir no repo naquele momento e pulado com aviso, em vez
# de derrubar a instalacao inteira.
PKGS_TOOLS_AD="
nmap
netexec
impacket-scripts
python3-impacket
evil-winrm
bloodhound.py
certipy-ad
responder
enum4linux-ng
smbclient
smbmap
ldap-utils
krb5-user
kerbrute
hashcat
john
"
PKGS_TOOLS_WEB="
burpsuite
ffuf
feroxbuster
gobuster
sqlmap
whatweb
"
PKGS_TOOLS_BASE="
seclists
wordlists
proxychains4
chisel
ligolo-ng
socat
rlwrap
netcat-traditional
"

if [ "$DO_TOOLS" -eq 1 ]; then
    info "perfil --tools: AD + web"
    TOOLS_OK=()
    TOOLS_MISS=()
    for p in $PKGS_TOOLS_AD $PKGS_TOOLS_WEB $PKGS_TOOLS_BASE; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            TOOLS_OK+=("$p")
        else
            TOOLS_MISS+=("$p")
        fi
    done
    if [ "${#TOOLS_MISS[@]}" -gt 0 ]; then
        warn "fora do repo agora, pulados: ${TOOLS_MISS[*]}"
    fi
    # noninteractive: krb5-user pergunta o realm no debconf; ajuste depois
    # o /etc/krb5.conf conforme o lab
    if [ "${#TOOLS_OK[@]}" -gt 0 ]; then
        apt_install --no-install-recommends "${TOOLS_OK[@]}"
    fi
    info "BloodHound GUI (CE) fica de fora: roda melhor no host via docker compose"
fi

# =====================================================================
#  2. Starship
# =====================================================================
if command -v starship >/dev/null 2>&1; then
    info "starship ja presente"
elif apt-cache policy starship 2>/dev/null | grep -q 'Candidate: [0-9]'; then
    info "instalando starship via apt"
    apt_install starship
else
    info "starship nao esta no repo; usando instalador oficial"
    run sh -c 'curl -fsSL https://starship.rs/install.sh | sh -s -- --yes'
fi

# =====================================================================
#  3. JetBrainsMono Nerd Font
# =====================================================================
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
if [ "$DO_FONT" -eq 1 ]; then
    if fc-list 2>/dev/null | grep -qi 'jetbrains.*nerd'; then
        info "Nerd Font ja instalada"
    elif [ "$DRY" -eq 1 ]; then
        run curl -fsSL "$FONT_URL"
    else
        info "baixando JetBrainsMono Nerd Font"
        FONT_DIR="${HOME}/.local/share/fonts/JetBrainsMono"
        mkdir -p "$FONT_DIR"
        TMP_ZIP="$(mktemp -d)/JetBrainsMono.zip"
        if curl -fsSL -o "$TMP_ZIP" "$FONT_URL"; then
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
install_config "${CONFIG_SRC}/kitty/kitty.conf"         "${HOME}/.config/kitty/kitty.conf"
install_config "${CONFIG_SRC}/dunst/dunstrc"            "${HOME}/.config/dunst/dunstrc"
install_config "${CONFIG_SRC}/starship.toml"            "${HOME}/.config/starship.toml"
install_config "${CONFIG_SRC}/tmux.conf"                "${HOME}/.tmux.conf"

# --- tema escuro para apps GTK / X ---
install_config "${CONFIG_SRC}/gtk-3.0/settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
install_config "${CONFIG_SRC}/gtk-4.0/settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"
install_config "${CONFIG_SRC}/gtkrc-2.0"            "${HOME}/.gtkrc-2.0"
install_config "${CONFIG_SRC}/Xresources"           "${HOME}/.Xresources"
install_config "${CONFIG_SRC}/xsettingsd.conf"      "${HOME}/.config/xsettingsd/xsettingsd.conf"

# GTK tambem le a variavel de ambiente; garante o escuro em apps que
# ignoram o settings.ini
ensure_block "${HOME}/.zshenv" "kali-setup gtk dark" \
'export GTK_THEME=Adwaita:dark
export QT_QPA_PLATFORMTHEME=gtk2
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24'

run mkdir -p "${HOME}/.config/scripts" "${HOME}/.config/wallpapers" \
    "${HOME}/Pictures/screenshots" "${HOME}/.local/bin"
for s in wallpaper.sh screenshot.sh term.sh vm-autoresize.sh tmux-log.sh files.sh; do
    install_config "${CONFIG_SRC}/scripts/${s}" "${HOME}/.config/scripts/${s}"
    run chmod +x "${HOME}/.config/scripts/${s}"
done

# comandos do usuario: engage (pasta de engagement) e sessao (sessionizer)
for b in engage sessao; do
    install_config "${BIN_SRC}/${b}" "${HOME}/.local/bin/${b}"
    run chmod +x "${HOME}/.local/bin/${b}"
done

if [ "$DRY" -eq 0 ]; then
cat > "${HOME}/.config/wallpapers/README" << 'EOF'
Coloque uma imagem (.jpg .jpeg .png .webp .bmp) neste diretorio e
recarregue o i3 com Mod+Shift+C.

Sem imagem aqui, usa um padrao gerado (preto + brilho cyan) se o
ImageMagick estiver instalado, ou preto solido se nao.
Se houver mais de uma, a primeira em ordem alfabetica e usada.

O fundo do terminal kitty e a mesma imagem desfocada e escurecida,
gerada uma vez em ~/.cache/war_machine/term-bg.png. Para escurecer
mais/menos (0-100, padrao 62):
    echo 75 > ~/.config/war_machine/dim     e depois Mod+Shift+C
EOF
fi

# --no-glass depois de uma instalacao com vidro: desliga sem desinstalar
if [ "$DO_GLASS" -eq 0 ]; then
    run mkdir -p "${HOME}/.config/war_machine"
    run touch "${HOME}/.config/war_machine/solid"
fi

# --- Firefox: tema escuro no chrome do navegador ---
# O user.js so pode ser aplicado depois que o perfil existe. Se o Firefox
# ainda nao rodou, o perfil e criado no primeiro start - o script avisa
# para rodar novamente depois disso.
FF_DIR=""
for d in "${HOME}/.mozilla/firefox" "${HOME}/snap/firefox/common/.mozilla/firefox"; do
    [ -d "$d" ] && FF_DIR="$d" && break
done
if [ -n "$FF_DIR" ]; then
    FF_PROFILE="$(find "$FF_DIR" -maxdepth 1 -type d -name '*.default*' | head -n1)"
    if [ -n "$FF_PROFILE" ]; then
        install_config "${CONFIG_SRC}/firefox/user.js" "${FF_PROFILE}/user.js"
    else
        warn "perfil do Firefox nao encontrado - abra o Firefox uma vez e rode o script de novo"
    fi
else
    warn "Firefox ainda nao criou o perfil - abra ele uma vez e rode o script de novo"
fi

# =====================================================================
#  5. Shell: zsh + starship + eza/zoxide/fzf
# =====================================================================
ensure_block "${HOME}/.zshrc" "kali-setup starship" \
'zmodload zsh/mathfunc   # evita "__starship_get_time: unknown function: int"
eval "$(starship init zsh)"'

# Igual ao host: ls -> eza, cd -> zoxide (cd parte-do-nome pula pra pasta
# frequente, cdi escolhe no fzf; o cd original segue em `builtin cd`).
# Fica DEPOIS do bloco do starship: o zoxide precisa ser o ultimo init.
# shellcheck disable=SC2016  # conteudo literal do .zshrc, expande no zsh
ensure_block "${HOME}/.zshrc" "war_machine modern-cli" \
'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons=auto --group-directories-first"
    alias ll="eza -l --icons=auto --group-directories-first --git"
    alias la="eza -la --icons=auto --group-directories-first --git"
    alias l="la"
    alias lt="eza --tree --level=2 --icons=auto --group-directories-first"
fi

# fzf: Ctrl+R historico, Ctrl+T arquivo, Alt+C pasta. Tema vanta.
if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="--layout=reverse --height=40% --border=sharp --info=inline --color=bg+:#1a1a1a,fg:#c8d3d5,fg+:#ffffff,hl:#00f0ff,hl+:#00f0ff,pointer:#00f0ff,prompt:#00f0ff,info:#5a6567,border:#1a1a1a,marker:#ffb800"
    if fzf --zsh >/dev/null 2>&1; then
        source <(fzf --zsh)
    elif [ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
        source /usr/share/doc/fzf/examples/key-bindings.zsh
    fi
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)"'

ZSH_BIN="$(command -v zsh || echo /usr/bin/zsh)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_BIN" ]; then
    info "definindo zsh como shell padrao"
    run sudo chsh -s "$ZSH_BIN" "$USER"
else
    info "zsh ja e o shell padrao"
fi

# =====================================================================
#  6. Autostart do i3 no tty1
# =====================================================================
if [ "$(cat "${HOME}/.xinitrc" 2>/dev/null)" != "exec i3" ]; then
    run sh -c "echo 'exec i3' > \"\$HOME/.xinitrc\""
    info "config: ${HOME}/.xinitrc"
fi

# shellcheck disable=SC2016  # conteudo literal do .zprofile
ensure_block "${HOME}/.zprofile" "kali-setup autostart i3" \
'if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx
fi'

# --- imagem QEMU (lightdm + XFCE) --------------------------------------
# Padrao: desliga o display manager e boota em modo texto; o login no tty1
# sobe o i3 via startx (bloco acima). Sem lightdm + XFCE em memoria a VM
# fica bem mais leve. Nada e desinstalado: e reversivel com --keep-dm.
# Nao paramos o DM agora - isso derrubaria a sessao grafica de quem roda
# o script de dentro do XFCE. Vale a partir do proximo boot.
if [ -n "$DM" ]; then
    if [ "$KEEP_DM" -eq 1 ]; then
        run sudo systemctl enable "$DM" || true
        run sudo systemctl set-default graphical.target
        if [ "$DM" = "lightdm.service" ]; then
            run sudo mkdir -p /etc/lightdm/lightdm.conf.d
            printf '[Seat:*]\nuser-session=i3\n' | \
                write_root /etc/lightdm/lightdm.conf.d/60-war-machine.conf
        fi
        run sh -c "printf '[Desktop]\nSession=i3\n' > \"\$HOME/.dmrc\""
        info "${DM} mantido; i3 definido como sessao (confira no menu de sessao do login)"
    else
        run sudo systemctl disable "$DM" || true
        run sudo systemctl set-default multi-user.target
        info "${DM} desligado - proximo boot cai no tty1 e o i3 sobe sozinho"
        info "para voltar ao login grafico: ./install.sh --keep-dm"
    fi
fi

# =====================================================================
#  7. spice-vdagent
# =====================================================================
# O daemon e ativado por socket no Debian - nao tem secao [Install],
# entao "systemctl enable spice-vdagentd" falha. O alvo e o .socket.
if systemctl list-unit-files 2>/dev/null | grep -q '^spice-vdagentd.socket'; then
    run sudo systemctl enable --now spice-vdagentd.socket || true
    info "spice-vdagentd.socket ativo (resolucao dinamica)"
fi

# =====================================================================
#  8. Fuso horario
# =====================================================================
# Instalado sem rede ou com locale en_US, o Kali costuma ficar em UTC ou
# num fuso errado: o relogio da VM fica horas atras/a frente do host.
if [ -n "$TZ_WANT" ]; then
    if ! timedatectl list-timezones 2>/dev/null | grep -qxF "$TZ_WANT"; then
        warn "fuso '${TZ_WANT}' desconhecido - nao alterado (veja: timedatectl list-timezones)"
    elif [ "$(timedatectl show -p Timezone --value 2>/dev/null)" = "$TZ_WANT" ]; then
        info "fuso ja e ${TZ_WANT}"
    else
        run sudo timedatectl set-timezone "$TZ_WANT"
        run sudo timedatectl set-ntp true
        info "fuso: ${TZ_WANT} (NTP ligado)"
    fi
fi

# =====================================================================
#  9. SSH
# =====================================================================
# O endurecimento vai num drop-in, nao no sshd_config: o sshd usa o
# PRIMEIRO valor que le, e o "Include sshd_config.d/*.conf" fica no topo
# do arquivo. Um sed no corpo do sshd_config perde pra qualquer drop-in
# (ex.: cloud-init com PasswordAuthentication yes). O prefixo 00- garante
# que o nosso e lido antes dos outros.
SSHD_DROPIN=/etc/ssh/sshd_config.d/00-war-machine.conf
if [ "$DO_SSH" -eq 1 ]; then
    apt_install --no-install-recommends openssh-server
    run sudo systemctl enable --now ssh || true

    AUTH_KEYS="${HOME}/.ssh/authorized_keys"
    if [ -s "$AUTH_KEYS" ]; then
        info "chave publica encontrada - endurecendo sshd"
        if [ "$DRY" -eq 0 ] && ! sudo grep -qiE '^\s*Include\s+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config; then
            warn "sshd_config nao inclui sshd_config.d/ - drop-in nao teria efeito; endurecimento pulado"
        else
            run sudo mkdir -p /etc/ssh/sshd_config.d
            write_root "$SSHD_DROPIN" << 'EOF'
# war_machine: so chave, sem root
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
            if [ "$DRY" -eq 1 ]; then
                run sudo sshd -t
                run sudo systemctl restart ssh
            elif sudo sshd -t; then
                sudo systemctl restart ssh
                printf '   config efetiva: '
                sudo sshd -T | grep -iE '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) ' | tr '\n' ' '
                printf '\n'
            else
                sudo rm -f "$SSHD_DROPIN"
                warn "sshd -t falhou com o drop-in - removido, sshd intocado"
            fi
        fi
    else
        warn "sem ~/.ssh/authorized_keys - senha NAO foi desabilitada"
        warn "rode no host:  ssh-copy-id -i ~/.ssh/SUA_CHAVE.pub ${USER}@<ip-da-vm>"
        warn "e depois:      ./install.sh   (para aplicar o endurecimento)"
    fi
else
    info "pulando SSH (--no-ssh)"
fi

# =====================================================================
# --- senha padrao da imagem pronta ------------------------------------
# A imagem QEMU vem com kali/kali. Com SSH ligado isso e porta aberta.
if [ "$USER" = "kali" ]; then
    warn "usuario 'kali' detectado: se a senha ainda for a padrao (kali), troque com: passwd"
fi

if [ "$DRY" -eq 1 ]; then
    info "dry-run concluido - nada foi alterado"
    exit 0
fi

info "concluido"
cat << 'EOF'

  Reinicie a VM (ou saia e logue de novo no tty1) para o i3 subir sozinho.

  Atalhos principais (Mod = Super):
    Mod+Enter          terminal (vidro)  Mod+D              dmenu
    Mod+Shift+Enter    terminal solido   Mod+Shift+G        liga/desliga vidro
    Mod+Q              fechar janela     Mod+Shift+F        fullscreen
    Mod+F              arquivos (Thunar)
    Mod+H/J/K/L        foco              Mod+Shift+H/J/K/L  mover janela
    Mod+1..0           workspace         Mod+Shift+1..0     mover p/ workspace
    Mod+B / Mod+V      split h / v       Mod+R              modo resize
    Mod+Shift+S        screenshot area   Print              screenshot tela
    Mod+Shift+X        lock              Mod+Shift+E        sair
    Mod+Shift+C        recarregar        Mod+Shift+R        reiniciar i3

  tmux (prefix Ctrl+Space): igual ao host - Ctrl+Alt+setas paineis,
  Alt+1..9 janelas, prefix f sessionizer, prefix L log do painel.

  Engagement:  engage <alvo>   pasta + sessao tmux + log + screenshots

  Wallpaper: jogue uma imagem em ~/.config/wallpapers/ e Mod+Shift+C.

EOF

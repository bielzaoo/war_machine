# war_machine

[![lint](https://github.com/bielzaoo/war_machine/actions/workflows/lint.yml/badge.svg)](https://github.com/bielzaoo/war_machine/actions/workflows/lint.yml)

Bootstrap de uma VM Kali Linux enxuta: i3 + kitty/Alacritty + tmux +
zsh/starship + eza/zoxide/fzf, tema vanta black + cyan (`#00f0ff`), com terminal "vidro" sem
compositor (ver [Terminal vidro](#terminal-vidro-sem-picom)).

Resultado esperado na base mínima: **~2.5 GB em disco**, **~520 MB de RAM em
idle**, boot em torno de 6s — contra ~12 GB e ~1.2 GB de um Kali com XFCE padrão.

---

## Qual imagem usar

O site do Kali oferece duas, e o script funciona nas duas:

| | ISO **installer** (`*-installer-amd64.iso`) | Imagem **QEMU** (`*-qemu-amd64.7z`) |
|---|---|---|
| O que é | instalador; você escolhe o que entra | disco `qcow2` já instalado |
| Desktop | nenhum (se desmarcar tudo) | XFCE + lightdm |
| Ferramentas | nenhuma (instala sob demanda) | o pacote `default` inteiro |
| Disco | ~2.5 GB | ~15 GB descompactado |
| Tempo até usar | instalação de ~15 min | importar e bootar |
| Login | o que você criar | `kali` / `kali` — **troque** |
| O script faz | sobe i3 no tty1 | desliga o lightdm e sobe i3 no tty1 |

**Regra prática:** VM de longa duração e leve → installer. VM descartável pra
um lab/CTF, com as ferramentas já lá → QEMU.

Na imagem QEMU o script **não desinstala** o XFCE: só desliga o display
manager (`systemctl disable lightdm` + boot em `multi-user.target`). O ganho de
RAM é o mesmo, o disco não muda, e volta atrás com `./install.sh --keep-dm`
(que mantém o lightdm e põe o i3 como sessão no login gráfico).

## Pré-requisito (ISO installer): instalar o Kali sem nada

Na tela **Software selection** do instalador, **desmarque todas as caixas** —
inclusive `default -- recommended tools`, que é a que traz as centenas de
ferramentas e leva a instalação para os 12 GB.

O núcleo do sistema é instalado independentemente do que estiver marcado, então
deixar tudo vazio entrega uma base mínima funcional.

Use o ISO **installer**, não o live (o live já vem com XFCE embutido e não
oferece essa tela).

## Uso

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/bielzaoo/war_machine.git ~/war_machine
cd ~/war_machine
./install.sh
```

Reinicie. O i3 sobe sozinho no tty1 (logue no tty1 com seu usuário).

Precisa de um tarball em vez de clone? `git archive --format=tar.gz
--prefix=war_machine/ -o war_machine.tar.gz HEAD` gera um a partir do repo.

### Opções

| Flag | Efeito |
|---|---|
| `--tools` | instala o [perfil de ferramentas](#perfil---tools) AD + web |
| `--dry-run` | só lista o que faria (pacotes, arquivos, serviços); não altera nada |
| `--tz=ZONA` | fuso horário (padrão `America/Sao_Paulo`, NTP ligado) |
| `--no-tz` | não mexe no fuso |
| `--no-ssh` | não instala nem endurece o `sshd` |
| `--no-font` | pula o download da Nerd Font (~30 MB) |
| `--no-glass` | sem kitty/ImageMagick: só Alacritty sólido (o mais leve) |
| `--keep-dm` | imagem QEMU: mantém o lightdm e adiciona o i3 como sessão |

O script é **idempotente** — pode rodar quantas vezes quiser. Configs
existentes que difiram são salvas como `.bak-<timestamp>`, e os blocos em
`~/.zshrc` / `~/.zprofile` são delimitados por marcadores e substituídos, não
duplicados.

---

## Atalhos (Mod = Super)

| Tecla | Ação | | Tecla | Ação |
|---|---|---|---|---|
| `Mod+Enter` | terminal (vidro) | | `Mod+D` | dmenu |
| `Mod+Shift+Enter` | terminal sólido | | `Mod+Shift+G` | liga/desliga vidro |
| `Mod+Q` | fechar janela | | `Mod+F` | fullscreen |
| `Mod+H/J/K/L` | foco | | `Mod+Shift+H/J/K/L` | mover janela |
| `Mod+1..0` | workspace | | `Mod+Shift+1..0` | mover p/ workspace |
| `Mod+B` / `Mod+V` | split h / v | | `Mod+R` | modo resize |
| `Mod+S` / `Mod+W` | stacking / tabbed | | `Mod+Shift+Space` | flutuante |
| `Mod+Shift+S` | screenshot de área | | `Print` | screenshot da tela |
| `Mod+Shift+X` | lock | | `Mod+Shift+E` | sair |
| `Mod+Shift+C` | recarregar config | | `Mod+Shift+R` | reiniciar i3 |
| `Mod+Tab` | workspace anterior | | | |

Screenshots vão para `~/Pictures/screenshots/` **e** para a área de
transferência. Com um engagement ativo, vão para `<alvo>/screens/`.

### tmux (prefix `Ctrl+Space`, `Ctrl+a` também vale)

Mesmos atalhos do host (dotfiles, esquema Omarchy). O que é usado toda hora
não precisa de prefix:

| Tecla | Ação | | Tecla | Ação |
|---|---|---|---|---|
| `Ctrl+Alt+setas` | muda de painel | | `Ctrl+Alt+Shift+setas` | redimensiona painel |
| `Alt+1..9` | vai pra janela N | | `Alt+←/→` | janela anterior/próxima |
| `Alt+Shift+←/→` | move a janela | | `Alt+↑/↓` | sessão anterior/próxima |
| `prefix h` | divide (um embaixo do outro) | | `prefix v` | divide (lado a lado) |
| `prefix x` | fecha painel | | `prefix k` / `K` | fecha janela / sessão |
| `prefix c` / `C` | nova janela / sessão (mesma pasta) | | `prefix r` / `R` | renomeia janela / sessão |
| `prefix f` | sessionizer (pasta do zoxide vira sessão) | | `prefix L` | liga/desliga log do painel |
| `prefix [` | copy mode (`v` seleciona, `y` copia) | | `prefix q` | recarrega a config |

Cópia vai pro clipboard do X (`xclip`). Status no topo, `REC` em vermelho no
painel que está gravando.

> **virt-manager:** `Ctrl+Alt` é o atalho que solta o teclado da VM. Se
> `Ctrl+Alt+setas` soltar o mouse em vez de trocar de painel, troque o atalho
> em *Edit → Preferences → Console → Grab keys* (ex.: `Ctrl+Alt+Shift+F12`).

### Shell

`ls` é o `eza` (ícones, pastas primeiro; `ll`, `la`, `lt` em árvore) e `cd` é o
`zoxide`: `cd caminho` funciona igual, `cd parte-do-nome` pula pra pasta
frequente, `cdi` escolhe no fzf. O `cd` original segue em `builtin cd`. fzf no
`Ctrl+R` (histórico), `Ctrl+T` (arquivo) e `Alt+C` (pasta).

## Engagements

```bash
engage htb-certified     # cria/reabre ~/engagements/htb-certified e entra na sessão tmux
engage                   # mostra o ativo e lista os existentes
engage -x                # desmarca o ativo
```

Estrutura criada (pasta `700`: tem loot e credencial):

```
~/engagements/<alvo>/
├── nmap/  web/  loot/  screens/  logs/
├── notes/README.md    # escopo, credenciais, achados, timeline
└── targets.txt
```

O engagement ativo:

- aparece na barra do i3 (amarelo), ao lado do **IP da `tun0`** (VPN do
  HTB/THM/OSCP, o `LHOST` do reverse shell; some quando a VPN cai);
- recebe os screenshots (`Mod+Shift+S` / `Print`) em `screens/`;
- **grava todo painel tmux aberto dentro da pasta** em `logs/` (saída crua do
  terminal, leia com `less -R`). É a evidência pro relatório, sem depender de
  lembrar de ligar. Fora de engagement, `prefix L` grava em
  `~/.local/state/war_machine/tmux-logs/`.

## Wallpaper

Jogue uma imagem em `~/.config/wallpapers/` e recarregue o i3 (`Mod+Shift+C`).
Sem imagem, usa um padrão gerado na primeira vez (preto + brilho cyan com
scanlines). Nenhuma edição de config é necessária.

## Terminal vidro (sem picom)

Transparência de verdade no X precisa de compositor (picom). Numa VM sem
aceleração 3D o compositor roda na CPU (llvmpipe): cada frame da tela inteira
é recomposto em software, e blur é o pior caso. Daí a VM pesada.

O truque aqui é **não compor nada em tempo real**:

1. `wallpaper.sh` gera, **uma vez por imagem**, uma versão desfocada e
   escurecida do wallpaper em `~/.cache/war_machine/term-bg.png`
   (reduz → desfoca → amplia: blur pesado por uma fração do custo).
2. O kitty desenha essa imagem como fundo próprio (`background_image`). Custo
   em runtime: uma textura atrás do texto, sem compositor e sem blur por frame.
3. No i3 em tiling, atrás do terminal só existe o wallpaper — então o "vidro
   fosco" fica visualmente igual ao efeito real.

Ajustes:

| Quero | Faço |
|---|---|
| texto mais legível / fundo mais escuro | `echo 75 > ~/.config/war_machine/dim` + `Mod+Shift+C` (0-100, padrão 62) |
| desligar o vidro nos próximos terminais | `Mod+Shift+G` (de novo religa) |
| um terminal o mais leve possível agora | `Mod+Shift+Enter` (Alacritty sólido) |
| nunca instalar kitty/ImageMagick | `./install.sh --no-glass` |

O kitty vem afinado pra VM: `sync_to_monitor no`, cursor sem piscar (piscar
força redesenho constante) e `term xterm-256color` — o `xterm-kitty` padrão não
existe nos alvos, e ssh, shells reversos e `nc` quebram sem isso.

### Quero transparência real mesmo assim: virgl

Sem GPU dedicada ainda dá pra usar a **GPU integrada do host** pela VM com
virgl (OpenGL paravirtualizado). Só funciona com o viewer local
(virt-manager/virt-viewer na mesma máquina), não por SPICE remoto:

```bash
sudo virt-xml kali --edit --video model.type=virtio,model.acceleration.accel3d=yes
sudo virt-xml kali --edit --graphics type=spice,gl.enable=yes,listen=none
```

Na VM, `glxinfo -B | grep renderer` deve mostrar `virgl` em vez de `llvmpipe`.
Aí um picom com `backend = "glx"` e sem blur fica aceitável. É experimento,
não o padrão: se travar, volte com `accel3d=no` e `gl.enable=no`.

---

## O que o script instala

**Gráfico:** `xserver-xorg-core`, `xserver-xorg-input-libinput`, `xinit`,
`xkb-data`, `x11-xserver-utils`

**Stack:** `i3-wm`, `i3status`, `i3lock`, `dmenu`, `alacritty`, `tmux`, `zsh`,
`starship`, `eza`, `zoxide`, `fzf`, `dunst`, `feh`, `maim`, `xclip`, `network-manager`, `spice-vdagent`,
`firefox-esr`, `dnsutils`, `git`, `build-essential`

**Tema:** `adwaita-icon-theme`, `gnome-themes-extra`, `xsettingsd`

**Vidro** (pula com `--no-glass`): `kitty`, `imagemagick`

Rede é gerenciada por `nmtui` / `nmcli` — sem applet de bandeja, para não
arrastar dependências GTK do GNOME.

### Perfil `--tools`

Sem `--tools` nenhuma ferramenta de pentest entra. Com ele, um recorte focado
em **AD** (trilha CRTP/CARTP) e **web** (Burp), sem o metapacote de 12 GB:

| Grupo | Pacotes |
|---|---|
| AD | `nmap` `netexec` `impacket-scripts` `python3-impacket` `evil-winrm` `bloodhound.py` `certipy-ad` `responder` `enum4linux-ng` `smbclient` `smbmap` `ldap-utils` `krb5-user` `kerbrute` `hashcat` `john` |
| Web | `burpsuite` `ffuf` `feroxbuster` `gobuster` `sqlmap` `whatweb` |
| Base | `seclists` `wordlists` `proxychains4` `chisel` `ligolo-ng` `socat` `rlwrap` `netcat-traditional` |

Pacote que não estiver no repo naquele momento é pulado com aviso, sem
derrubar o resto. A GUI do BloodHound CE (Neo4j + Postgres) fica de fora: roda
melhor no host com `docker compose`, e o `bloodhound.py` da VM gera os JSON.
`krb5-user` entra sem perguntar o realm: ajuste o `/etc/krb5.conf` por lab.

Fora do perfil, sob demanda:

```bash
sudo apt install -y nikto wpscan masscan metasploit-framework exploitdb
```

---

## Tema

Tudo em vanta black + cyan (`#00f0ff`):

| Componente | Onde |
|---|---|
| i3 (bordas, gaps) | `config/i3/config` |
| i3bar + i3status | `config/i3/config`, `config/i3status/config` |
| kitty (vidro) | `config/kitty/kitty.conf` + `config/scripts/term.sh` |
| Alacritty (sólido) | `config/alacritty/alacritty.toml` |
| wallpaper + fundo do terminal | `config/scripts/wallpaper.sh` |
| tmux | `config/tmux.conf` |
| starship | `config/starship.toml` |
| dunst | `config/dunst/dunstrc` |
| dmenu | flags no bind `Mod+D` |
| apps GTK 2/3/4 | `config/gtk*`, `config/xsettingsd.conf` |
| cursor + cores do X | `config/Xresources` |
| Firefox | `config/firefox/user.js` |

Apps GTK (Firefox, diálogos de arquivo) usam `Adwaita-dark`, que já vem com
`gnome-themes-extra` — nenhum tema de terceiros é baixado.

O `user.js` do Firefox só pode ser aplicado depois que o perfil existe. Se você
nunca abriu o Firefox, o script avisa: abra uma vez e rode `./install.sh` de
novo.

---

## Notas de VM (libvirt/QEMU)

### Imagem QEMU pronta

```bash
sudo mkdir -p /var/lib/libvirt/images/kali
sudo chattr +C /var/lib/libvirt/images/kali    # desativa CoW do Btrfs
sudo 7z x ~/Downloads/kali-linux-VERSAO-qemu-amd64.7z -o/var/lib/libvirt/images/kali/
qemu-img info /var/lib/libvirt/images/kali/kali-linux-VERSAO-qemu-amd64.qcow2   # tamanho virtual

sudo virt-install \
  --name kali \
  --memory 8192 \
  --vcpus 6,sockets=1,cores=3,threads=2 \
  --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/kali/kali-linux-VERSAO-qemu-amd64.qcow2,format=qcow2,bus=virtio,discard=unmap \
  --import \
  --network network=default,model=virtio \
  --graphics spice --video virtio \
  --osinfo debian12 --memballoon virtio,freePageReporting=on --noautoconsole
```

Login `kali` / `kali`. Primeira coisa: `passwd`. Depois clone o repo e rode
`./install.sh` normalmente (de dentro do XFCE mesmo: o lightdm só sai no
próximo boot, a sessão atual não cai).

### ISO installer

Criação da VM no host:

```bash
sudo mkdir -p /var/lib/libvirt/images/kali
sudo chattr +C /var/lib/libvirt/images/kali    # desativa CoW do Btrfs

sudo virt-install \
  --name kali \
  --memory 8192 \
  --vcpus 6,sockets=1,cores=3,threads=2 \
  --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/kali/kali.qcow2,size=40,format=qcow2,bus=virtio,discard=unmap \
  --disk path=/var/lib/libvirt/images/kali-linux-VERSAO-installer-amd64.iso,device=cdrom,bus=sata,readonly=on \
  --boot cdrom,hd \
  --network network=default,model=virtio \
  --graphics spice --video virtio \
  --osinfo debian12 --memballoon virtio,freePageReporting=on --noautoconsole
```

Depois da instalação, **remova o ISO** ou a VM volta a bootar pelo CD:

```bash
sudo virsh change-media kali sda --eject --config
```

**Memória:** 8 GB dão folga pro Burp (heap de ~4 GB) + Firefox. Com
`freePageReporting=on` a VM devolve ao host o que libera: parada, custa ~600 MB
do host, não 8 GB. Se o `virt-install` recusar a opção, tire-a e ligue depois
com `sudo virsh edit kali` → `<memballoon model='virtio' freePageReporting='on'/>`.
Alternativa manual: `--memory 4096,maxmemory=8192` e `sudo virsh setmem kali 8G
--live` na hora de usar o Burp.

**vCPUs:** vCPU ociosa não custa nada ao host; 6 de 12 threads sobra bem.

**Abra o console antes do menu de boot.** Com `--noautoconsole` a tela não
abre sozinha, e o menu do instalador tem timer de ~30s: sem tecla, ele escolhe
a instalação **com síntese de voz**. Use
`virt-viewer -c qemu:///system kali` (ou o virt-manager) logo após criar a VM
e aperte uma seta no menu. Caiu na voz? `sudo virsh destroy kali` e
`sudo virsh start kali` — nada foi instalado ainda.

### Armadilhas encontradas

- **umask restritivo (ex.: `0027` de hardening) → `Permission denied` como
  `uid 960`.** `sudo mkdir` cria a pasta como `drwxr-x--- root`, e o QEMU roda
  como `libvirt-qemu`, que não entra nela. Idem para a ISO baixada como
  `rw-r-----`. Correção: `sudo chmod 755 /var/lib/libvirt/images/kali` e
  `sudo chmod 644` + `chown root:root` na ISO.
- **Firewall do host com `policy drop` → instalador "não acha a rede".** DHCP e
  DNS das VMs são servidos pelo dnsmasq **do host**: o pedido entra pela
  `virbr0` na chain `input`. E a saída para a internet passa pela `forward`.
  No nftables um `drop` em qualquer base chain do hook vence o `accept` das
  tabelas do libvirt. Liberar só o necessário:
  ```
  # chain input
  iifname "virbr0" udp dport { 53, 67 } accept
  iifname "virbr0" tcp dport 53 accept
  # chain forward
  iifname "virbr0" accept
  oifname "virbr0" ct state established,related accept
  ```
  E **não** usar `flush ruleset` no `/etc/nftables.conf`: apaga as tabelas do
  libvirt junto. Recriar só a própria tabela (`table inet filter` /
  `delete table inet filter` / `table inet filter { ... }`). Se já apagou:
  `sudo virsh net-destroy default && sudo virsh net-start default`. Com UFW o
  sintoma é o mesmo (`ufw allow in on virbr0` + `ufw route allow in on virbr0`).

- **ISO precisa estar em `/var/lib/libvirt/images/`.** O qemu não atravessa um
  home com permissão `700`; o sintoma é o instalador caindo no shell do
  initramfs.
- **`--no-install-recommends` na camada gráfica quebra o X.** No Debian/Kali,
  `libXcursor`, `libXi` e o driver de input são carregados via `dlopen` — não
  aparecem no `ldd` e só falham em runtime. Por isso o script instala
  `PKGS_X` **com** recommends e só corta no resto.
- **`--video virtio` em vez de QXL.** Com QXL o `spice-vdagent` procura
  `/dev/dri/card0` enquanto o dispositivo enumera como `card1`, e o
  redimensionamento dinâmico não funciona.
- **Com virtio-gpu, quem aplica a resolução nova é você, não o agente.** Ao
  redimensionar a janela do viewer, o QEMU muda o modo *preferido* do monitor
  virtual (`xrandr` mostra `1364x673 +` com `current 1280 x 800`) e dispara um
  hotplug no DRM. GNOME/KDE aplicam sozinhos; o i3 não, e o `spice-vdagent -d`
  nem vê pedido de resize. O `config/scripts/vm-autoresize.sh` escuta
  `udevadm monitor --subsystem-match=drm` e roda `xrandr --auto` (e redesenha o
  wallpaper). Sobe pelo i3; fora de VM sai na hora. No virt-manager, deixe
  ligado **View → Scale Display → Auto resize VM with window**.
- **`spice-vdagentd` é ativado por socket.** `systemctl enable spice-vdagentd`
  falha por não haver seção `[Install]` — o alvo correto é
  `spice-vdagentd.socket`.
- **Relógio da VM fora do host.** Instalado com locale `en_US` ou sem rede, o
  Kali fica em UTC ou num fuso errado. O script ajusta pra `--tz` (padrão
  `America/Sao_Paulo`) e liga o NTP.
- **starship no zsh** precisa de `zmodload zsh/mathfunc` antes do `init`, senão
  cada comando imprime `__starship_get_time: unknown function: int`.

### IP fixo por reserva DHCP

```bash
sudo virsh domiflist kali                    # pega o MAC
sudo EDITOR=nvim virsh net-edit default      # $EDITOR importa: virsh usa 'vi'
```

Dentro do bloco `<dhcp>`, após o `<range>`:

```xml
<host mac='52:54:00:xx:xx:xx' name='kali' ip='192.168.122.138'/>
```

Aplicar exige recriar a rede (derruba a conectividade — desligue a VM antes):

```bash
sudo virsh shutdown kali
sudo virsh net-destroy default && sudo virsh net-start default
sudo virsh start kali
```

---

## SSH

O script **não** distribui chaves — isso seria um furo de segurança num repo.
O fluxo correto:

1. No host: `ssh-keygen -t ed25519 -f ~/.ssh/kali_ed25519`
2. No host: `ssh-copy-id -i ~/.ssh/kali_ed25519.pub usuario@<ip-da-vm>`
3. **Teste a conexão por chave antes de qualquer outra coisa**
4. Rode `./install.sh` novamente — ele detecta o `authorized_keys` e só então
   desabilita a autenticação por senha

O endurecimento vai em `/etc/ssh/sshd_config.d/00-war-machine.conf`, não no
`sshd_config`. O sshd fica com o **primeiro** valor que lê, e o `Include` do
`sshd_config.d/` está no topo do arquivo: editar o corpo do `sshd_config` com
`sed` perde pra qualquer drop-in que diga `PasswordAuthentication yes`. O
script valida com `sshd -t` antes do restart e, se falhar, remove o drop-in.

Se não houver `~/.ssh/authorized_keys`, o script avisa e **não** desabilita a
senha, para não se trancar do lado de fora.

`~/.ssh/config` no host:

```
Host kali
    HostName 192.168.122.138
    User SEU_USUARIO
    IdentityFile ~/.ssh/kali_ed25519
```

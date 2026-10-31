# war_machine

Bootstrap de uma VM Kali Linux enxuta: i3 + kitty/Alacritty + tmux +
zsh/starship, tema vanta black + cyan (`#00f0ff`), com terminal "vidro" sem
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
transferência.

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
`starship`, `dunst`, `feh`, `maim`, `xclip`, `network-manager`, `spice-vdagent`,
`firefox-esr`, `dnsutils`, `git`, `build-essential`

**Tema:** `adwaita-icon-theme`, `gnome-themes-extra`, `xsettingsd`

**Vidro** (pula com `--no-glass`): `kitty`, `imagemagick`

Rede é gerenciada por `nmtui` / `nmcli` — sem applet de bandeja, para não
arrastar dependências GTK do GNOME.

**Ferramentas de pentest ficam de fora por escolha** — instale sob demanda.
Todas estão no repositório oficial do Kali:

```bash
sudo apt install -y sqlmap nikto ffuf wpscan masscan netexec metasploit-framework exploitdb
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
  --vcpus 4,sockets=1,cores=2,threads=2 \
  --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/kali/kali-linux-VERSAO-qemu-amd64.qcow2,format=qcow2,bus=virtio,discard=unmap \
  --import \
  --network network=default,model=virtio \
  --graphics spice --video virtio \
  --osinfo debian12 --memballoon virtio --noautoconsole
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
  --vcpus 4,sockets=1,cores=2,threads=2 \
  --cpu host-passthrough \
  --disk path=/var/lib/libvirt/images/kali/kali.qcow2,size=40,format=qcow2,bus=virtio,discard=unmap \
  --disk path=/var/lib/libvirt/images/kali-linux-VERSAO-installer-amd64.iso,device=cdrom,bus=sata,readonly=on \
  --boot cdrom,hd \
  --network network=default,model=virtio \
  --graphics spice --video virtio \
  --osinfo debian12 --memballoon virtio --noautoconsole
```

Depois da instalação, **remova o ISO** ou a VM volta a bootar pelo CD:

```bash
sudo virsh change-media kali sda --eject --config
```

### Armadilhas encontradas

- **ISO precisa estar em `/var/lib/libvirt/images/`.** O qemu não atravessa um
  home com permissão `700`; o sintoma é o instalador caindo no shell do
  initramfs.
- **`--no-install-recommends` na camada gráfica quebra o X.** No Debian/Kali,
  `libXcursor`, `libXi` e o driver de input são carregados via `dlopen` — não
  aparecem no `ldd` e só falham em runtime. Por isso o script instala
  `PKGS_X` **com** recommends e só corta no resto.
- **`--video virtio` em vez de QXL.** Com QXL o `spice-vdagent` procura
  `/dev/dri/card0` enquanto o dispositivo enumera como `card1`, e o
  redimensionamento dinâmico não funciona. Com virtio-gpu funciona sem
  `xrandr` fixo.
- **`spice-vdagentd` é ativado por socket.** `systemctl enable spice-vdagentd`
  falha por não haver seção `[Install]` — o alvo correto é
  `spice-vdagentd.socket`.
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

Se não houver `~/.ssh/authorized_keys`, o script avisa e **não** desabilita a
senha, para não se trancar do lado de fora.

`~/.ssh/config` no host:

```
Host kali
    HostName 192.168.122.138
    User SEU_USUARIO
    IdentityFile ~/.ssh/kali_ed25519
```

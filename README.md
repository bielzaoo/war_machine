# kali-setup

Bootstrap de uma VM Kali Linux mínima: i3 + Alacritty + tmux + zsh/starship,
tema vanta black + cyan (`#00f0ff`).

Resultado esperado: **~2.5 GB em disco**, **~520 MB de RAM em idle**, boot em
torno de 6s — contra ~12 GB e ~1.2 GB de um Kali com XFCE padrão.

---

## Pré-requisito: instalar o Kali sem nada

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
git clone <url-do-repo> ~/kali-setup
cd ~/kali-setup
./install.sh
```

Reinicie. O i3 sobe sozinho no tty1.

### Opções

| Flag | Efeito |
|---|---|
| `--no-ssh` | não instala nem endurece o `sshd` |
| `--no-font` | pula o download da Nerd Font (~30 MB) |

O script é **idempotente** — pode rodar quantas vezes quiser. Configs
existentes que difiram são salvas como `.bak-<timestamp>`, e os blocos em
`~/.zshrc` / `~/.zprofile` são delimitados por marcadores e substituídos, não
duplicados.

---

## Atalhos (Mod = Super)

| Tecla | Ação | | Tecla | Ação |
|---|---|---|---|---|
| `Mod+Enter` | terminal | | `Mod+D` | dmenu |
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
Sem imagem, o fundo fica preto sólido. Nenhuma edição de config é necessária.

---

## O que o script instala

**Gráfico:** `xserver-xorg-core`, `xserver-xorg-input-libinput`, `xinit`,
`xkb-data`, `x11-xserver-utils`

**Stack:** `i3-wm`, `i3status`, `i3lock`, `dmenu`, `alacritty`, `tmux`, `zsh`,
`starship`, `dunst`, `feh`, `maim`, `xclip`, `network-manager`, `spice-vdagent`,
`firefox-esr`, `dnsutils`, `git`, `build-essential`

**Ferramentas de pentest ficam de fora por escolha** — instale sob demanda.
Todas estão no repositório oficial do Kali:

```bash
sudo apt install -y sqlmap nikto ffuf wpscan masscan netexec metasploit-framework exploitdb
```

---

## Notas de VM (libvirt/QEMU)

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

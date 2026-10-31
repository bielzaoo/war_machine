#!/usr/bin/env bash
# Resolucao automatica em VM com virtio-gpu (QEMU/libvirt + SPICE).
#
# Ao redimensionar a janela do viewer (virt-manager / virt-viewer), o QEMU
# muda o modo PREFERIDO do monitor virtual e dispara um hotplug no DRM
# (uevent "change"). GNOME/KDE aplicam o modo novo sozinhos; o i3 nao.
# Este loop escuta esses eventos e aplica o modo preferido (xrandr --auto).
#
# O spice-vdagent continua necessario (clipboard), mas com virtio-gpu NAO e
# ele quem recebe o tamanho da janela - por isso so ele nao basta.
#
# Custo: um udevadm parado esperando evento. Zero CPU em idle.

set -u

# so em VM, e so com o que precisamos
command -v systemd-detect-virt >/dev/null 2>&1 && ! systemd-detect-virt -q && exit 0
command -v xrandr  >/dev/null 2>&1 || exit 0
command -v udevadm >/dev/null 2>&1 || exit 0

# uma instancia por sessao (reload/restart do i3 nao duplica)
LOCK="${XDG_RUNTIME_DIR:-/tmp}/vm-autoresize.${DISPLAY//[^0-9]/}.lock"
exec 9>"$LOCK"
flock -n 9 || exit 0

apply() {
    local out
    for out in $(xrandr | awk '/ connected/ {print $1}'); do
        xrandr --output "$out" --auto
    done
    # o wallpaper e desenhado no tamanho antigo: redesenha (imagem ja cacheada)
    [ -x "${HOME}/.config/scripts/wallpaper.sh" ] && "${HOME}/.config/scripts/wallpaper.sh"
}

apply

udevadm monitor --udev --subsystem-match=drm 2>/dev/null | while read -r line; do
    case "$line" in
        *change*) ;;
        *) continue ;;
    esac
    # arrastar a borda da janela gera uma rajada de eventos: espera acalmar
    while read -r -t 0.5 _; do :; done
    apply
done

#!/bin/bash
# Messa a punto presa da CachyOS: zram = RAM con zstd, swappiness 100, ecc.
# Gli scheduler sched-ext restano installati ma spenti (prova manuale).
source "$(dirname "$0")/vars.sh"

dnf5 -y copr enable "${CACHYOS_ADDONS_COPR}"
dnf5 -y swap zram-generator-defaults cachyos-settings
dnf5 -y install scx-scheds scx-tools
dnf5 -y copr disable "${CACHYOS_ADDONS_COPR}"

for unit in scx.service scx_loader.service; do
    systemctl disable "$unit" 2>/dev/null || true
done
# cachyos-settings porta ananicy-cpp solo come suggerimento: non deve esserci
! rpm -q ananicy-cpp

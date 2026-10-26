#!/bin/bash
# Unico step che tocca kernel e moduli (la variante :cachy cambierà solo questo file).
source "$(dirname "$0")/vars.sh"

KVER=$(ls /usr/lib/modules | head -1)

# Wi-Fi interno BCM4360: driver proprietario wl, precompilato per questo kernel
dnf5 install -y \
    /tmp/akmods-rpms/common/broadcom-wl-*.rpm \
    /tmp/akmods-rpms/kmods/kmod-wl-"${KVER}"-*.rpm

# Il modulo deve esistere per il kernel dell'immagine, altrimenti build rossa
modinfo -k "$KVER" wl >/dev/null

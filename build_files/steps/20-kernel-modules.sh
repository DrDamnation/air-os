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

# Webcam FaceTime HD: compilata qui dai sorgenti. Non uso il COPR perché il suo
# pacchetto obbliga a installare il firmware Apple (vietato nell'immagine pubblica)
# e carica il modulo all'avvio. Il modulo resta in blacklist: si carica con `ujust camera`.
dnf5 install -y gcc make "/tmp/kernel-rpms/kernel-devel-${KVER}.rpm"
src=$(mktemp -d)
curl -fsSL -o "$src/ft.tgz" \
    "https://github.com/patjak/facetimehd/archive/refs/tags/${FACETIMEHD_VERSION}.tar.gz"
echo "${FACETIMEHD_SHA256}  $src/ft.tgz" | sha256sum -c -
tar -xzf "$src/ft.tgz" -C "$src"
make -C "/usr/src/kernels/${KVER}" M="$src/facetimehd-${FACETIMEHD_VERSION}" modules
install -Dm644 "$src/facetimehd-${FACETIMEHD_VERSION}/facetimehd.ko" \
    "/usr/lib/modules/${KVER}/extra/facetimehd/facetimehd.ko"
depmod -a "$KVER"
modinfo -k "$KVER" facetimehd >/dev/null
rm -rf "$src"
dnf5 remove -y gcc make kernel-devel

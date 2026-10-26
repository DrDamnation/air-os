#!/usr/bin/env bash
# Controlli dentro l'immagine costruita (CI) o sul sistema installato.
# Uso: podman run --rm <image> bash /usr/share/air-os/tests/image-checks.sh
set -u
source "$(dirname "$0")/lib.sh"

KVER=$(ls /usr/lib/modules | head -1)

# Repo COPR attivi, esclusi quelli che la base ublue tiene accesi di suo.
copr_attivi() {
    grep -l '^enabled=1' /etc/yum.repos.d/_copr*.repo 2>/dev/null \
        | grep -v '_copr_ublue-os-akmods.repo'
}

section "Base"
check "Fedora 44" grep -q 'VERSION_ID=44' /etc/os-release
check "nessun repo COPR nostro attivo" ! copr_attivi
check "niente GNOME (non Bazzite)" ! rpm -q gnome-shell
check "timer bootc update spento" ! systemctl is-enabled bootc-fetch-apply-updates.timer
check "timer rpm-ostree automatico spento" ! systemctl is-enabled rpm-ostreed-automatic.timer
check "build info" test -s /usr/share/air-os/build-info

section "Firma"
check "chiave pubblica air-os" test -s /etc/pki/containers/air-os.pub
check "policy firma air-os" jq -e '.transports.docker["ghcr.io/drdamnation/air-os"][0].type == "sigstoreSigned"' /etc/containers/policy.json
check "sigstore attachments air-os" grep -q 'ghcr.io/drdamnation/air-os' /etc/containers/registries.d/air-os.yaml

finish

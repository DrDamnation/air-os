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

section "Hardware Mac"
check "wl per il kernel dell'immagine ($KVER)" modinfo -k "$KVER" wl
check "rtw88_8822bu presente" modinfo -k "$KVER" rtw88_8822bu
check "r8152 presente" modinfo -k "$KVER" r8152
check "karg reboot=pci" grep -q 'reboot=pci' /usr/lib/bootc/kargs.d/10-air.toml
check "unit sveglie abilitata" systemctl is-enabled air-disable-wakeup.service
check "regola thunderbolt" test -f /usr/lib/udev/rules.d/90-air-thunderbolt.rules
check "tuned-ppd presente" rpm -q tuned-ppd
check "tuned abilitato" systemctl is-enabled tuned.service
check "niente TLP" ! rpm -q tlp

section "Webcam"
check "facetimehd per il kernel" modinfo -k "$KVER" facetimehd
check "facetimehd in blacklist" grep -q '^blacklist facetimehd' /usr/lib/modprobe.d/air-facetimehd.conf
firmware_apple() { find /usr/lib/firmware -path '*facetimehd*' | grep -q .; }
check "firmware Apple NON nell'immagine" ! firmware_apple
check "ricette ujust air importate" grep -q '60-custom.just' /usr/share/ublue-os/justfile
check "ricetta camera" grep -q '^camera:' /usr/share/ublue-os/just/60-custom.just
check "ricetta camera-firmware" grep -q '^camera-firmware:' /usr/share/ublue-os/just/60-custom.just
check "path firmware nei kargs" grep -q 'firmware_class.path=/var/lib/air-os/firmware' /usr/lib/bootc/kargs.d/10-air.toml
check "niente akmod/kernel-devel rimasti" ! rpm -q akmod-facetimehd kernel-devel

section "Tuning CachyOS"
check "cachyos-settings" rpm -q cachyos-settings
check "zram-generator-defaults rimosso" ! rpm -q zram-generator-defaults
check "zram zstd" grep -Eq '^compression-algorithm *= *zstd' /usr/lib/systemd/zram-generator.conf
check "zram = RAM" grep -Eq '^zram-size *= *ram$' /usr/lib/systemd/zram-generator.conf
check "swappiness 100" grep -rEq '^vm.swappiness *= *100' /usr/lib/sysctl.d/
check "page-cluster 0" grep -rEq '^vm.page-cluster *= *0' /usr/lib/sysctl.d/
check "scx installato" rpm -q scx-scheds
scx_attivo() { systemctl is-enabled scx.service || systemctl is-enabled scx_loader.service; }
check "scx spento" ! scx_attivo
check "niente ananicy" ! rpm -q ananicy-cpp
check "SATA in risparmio (dopo la regola CachyOS)" grep -q 'med_power_with_dipm' /usr/lib/udev/rules.d/51-air-sata.rules

section "Desktop"
for p in niri dms dms-greeter quickshell matugen greetd foot Thunar xwayland-satellite xdg-desktop-portal-gnome gnome-keyring; do
    check "pacchetto $p" rpm -q "$p"
done
check "niente cava" ! rpm -q cava
check "greetd abilitato" systemctl is-enabled greetd.service
check "greeter avvia niri" grep -q 'dms-greeter --command niri' /etc/greetd/config.toml
check "dms utente attivo per i nuovi utenti" test -L /etc/skel/.config/systemd/user/graphical-session.target.wants/dms.service
check "cava spento in DMS" grep -q 'DMS_DISABLE_CAVA=1' /usr/lib/environment.d/50-air-dms.conf
check "app-id nuovo nelle regole niri" grep -Eq 'app-id=.*dev.*duxlabs.*shell' /etc/skel/.config/niri/config.kdl
check "touchpad configurato" grep -q 'touchpad' /etc/skel/.config/niri/config.kdl
check "scorciatoia contrasto" grep -q 'air-contrast' /etc/skel/.config/niri/config.kdl
check "air-contrast eseguibile" test -x /usr/bin/air-contrast
check "config niri valida" niri validate -c /etc/skel/.config/niri/config.kdl

section "Kit da campo"
for p in openssh-clients nmap arp-scan iperf3 mtr iw wavemon ethtool tcpdump wireshark-cli picocom tio minicom tailscale git bats; do
    check "pacchetto $p" rpm -q "$p"
done
check "campo eseguibile" test -x /usr/bin/campo
check "campo risponde" bash -c '/usr/bin/campo --help | grep -q "Uso:"'
check "regola seriale" grep -q 'dialout' /usr/lib/udev/rules.d/90-air-serial.rules
check "tailscaled abilitato" systemctl is-enabled tailscaled.service
check "repo tailscale spento" ! grep -q '^enabled=1' /etc/yum.repos.d/tailscale.repo
check "ricetta campo-setup" grep -q '^campo-setup:' /usr/share/ublue-os/just/60-custom.just
check "air-config eseguibile" test -x /usr/bin/air-config
check "air-config risponde" bash -c '/usr/bin/air-config boh 2>&1 | grep -q "uso: air-config"'
check "ssh-keygen per la deploy key" command -v ssh-keygen
check "ricetta air-config" grep -q '^air-config:' /usr/share/ublue-os/just/60-custom.just

section "RustDesk solo locale"
RD=/usr/share/air-os/rustdesk/RustDesk2.toml
check "rustdesk installato" rpm -q rustdesk
check "accesso IP diretto" grep -q "^direct-server = 'Y'" "$RD"
check "porta diretta 21118" grep -q "^direct-access-port = '21118'" "$RD"
check "niente rendezvous pubblico" grep -q "^custom-rendezvous-server = '127.0.0.1'" "$RD"
check "niente relay pubblico" grep -q "^relay-server = '127.0.0.1'" "$RD"
for net in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 100.64.0.0/10; do
    check "whitelist $net" grep -q "^whitelist = '.*$net" "$RD"
done
check "config utente da skel" cmp -s "$RD" /etc/skel/.config/rustdesk/RustDesk2.toml
check "config root via tmpfiles" grep -q "$RD" /usr/lib/tmpfiles.d/air-rustdesk.conf
check "porta aperta solo da reti private/Tailscale" bash -c "firewall-offline-cmd --zone=public --list-rich-rules | grep -c 'rustdesk-direct' | grep -qx 4"
check "porta NON aperta a tutti" bash -c "! firewall-offline-cmd --zone=public --list-services | grep -qw rustdesk-direct"
rd_ha_password() { grep -Eqi "^(password|permanent-password|salt|key) *= *'[^']+'" "$RD"; }
check "toml RustDesk presente" test -s "$RD"
check "nessuna password nel toml" ! rd_ha_password
check "ricetta rustdesk-password" grep -q '^rustdesk-password:' /usr/share/ublue-os/just/60-custom.just
check "niente /opt rotto" bash -c "test ! -e /opt/rustdesk || test -x /usr/bin/rustdesk"

finish

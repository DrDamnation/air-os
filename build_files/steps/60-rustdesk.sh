#!/bin/bash
# RustDesk solo locale: IP diretto su LAN e Tailscale, nessun server pubblico.
source "$(dirname "$0")/vars.sh"

rpm=/tmp/rustdesk.rpm
curl -fsSL -o "$rpm" \
    "https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_VERSION}/rustdesk-${RUSTDESK_VERSION}-0.x86_64.rpm"
echo "${RUSTDESK_SHA256}  $rpm" | sha256sum -c -
dnf5 -y install "$rpm"
rm -f "$rpm"

# Configurazione: la stessa per l'utente (skel) e per il servizio di sistema (root)
install -Dm644 /usr/share/air-os/rustdesk/RustDesk2.toml /etc/skel/.config/rustdesk/RustDesk2.toml

# Porta 21118 aperta solo verso reti private e Tailscale
for net in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 100.64.0.0/10; do
    firewall-offline-cmd --zone=public \
        --add-rich-rule="rule family=ipv4 source address=${net} service name=rustdesk-direct accept"
done

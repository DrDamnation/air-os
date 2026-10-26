#!/bin/bash
# Kit da campo: rete, seriale, Tailscale. Tutto pronto, niente da installare sul tetto.
source "$(dirname "$0")/vars.sh"

dnf5 -y install --setopt=install_weak_deps=False \
    openssh-clients nmap arp-scan iperf3 mtr iw wavemon ethtool tcpdump wireshark-cli \
    picocom tio minicom git bats

# Tailscale dal repo ufficiale, poi repo spento (l'immagine si aggiorna in blocco)
curl -fsSL -o /etc/yum.repos.d/tailscale.repo \
    "https://pkgs.tailscale.com/stable/fedora/tailscale.repo"
dnf5 -y install tailscale
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/tailscale.repo
systemctl enable tailscaled.service

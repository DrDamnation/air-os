#!/bin/bash
# Sistemazioni del MacBook Air: energia e sveglie.
source "$(dirname "$0")/vars.sh"

# Gestione energia: tuned con l'interfaccia power-profiles (niente TLP)
dnf5 install -y tuned tuned-ppd
systemctl enable tuned.service

systemctl enable air-disable-wakeup.service
systemctl enable air-wifi-libera.path

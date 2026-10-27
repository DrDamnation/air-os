# Ricette air-os (ujust <nome>)

# Scarica il firmware della webcam FaceTime HD dall'aggiornamento macOS di Apple (una volta sola)
[group('air-os')]
camera-firmware:
    #!/usr/bin/bash
    set -euo pipefail
    dest=/var/lib/air-os/firmware/facetimehd
    if [[ -s "$dest/firmware.bin" ]]; then
        echo "Firmware già presente in $dest"; exit 0
    fi
    work=$(mktemp -d)
    echo "Scarico ed estraggo il firmware (serve Internet, ~100 MB scaricati a pezzi)..."
    podman run --rm -v "$work:/out:Z" registry.fedoraproject.org/fedora:44 bash -euc '
        dnf -y -q install make curl xz git cpio perl-interpreter which >/dev/null
        git clone -q https://github.com/patjak/facetimehd-firmware /src
        cd /src && git checkout -q 60ee21228d9ca00a7bd84fdaefaff00a81f1db91
        make
        cp firmware.bin /out/
        cp *.dat /out/ 2>/dev/null || true
    '
    sudo install -d "$dest"
    sudo install -m644 "$work"/* "$dest/"
    rm -rf "$work"
    echo "Fatto. Ora: ujust camera"

# Accende o spegne la webcam FaceTime HD (modulo caricato solo quando serve)
[group('air-os')]
camera:
    #!/usr/bin/bash
    set -euo pipefail
    if lsmod | grep -q '^facetimehd '; then
        sudo modprobe -r facetimehd && echo "Webcam spenta"
    else
        if [[ ! -s /var/lib/air-os/firmware/facetimehd/firmware.bin ]]; then
            echo "Manca il firmware: lancia prima 'ujust camera-firmware'"; exit 2
        fi
        sudo modprobe facetimehd && echo "Webcam accesa"
    fi

# Prepara l'utente per il campo: accesso alle porte seriali USB (serve un nuovo login)
[group('air-os')]
campo-setup:
    #!/usr/bin/bash
    set -euo pipefail
    if ! grep -q '^dialout:' /etc/group; then
        grep '^dialout:' /usr/lib/group | sudo tee -a /etc/group >/dev/null
    fi
    sudo usermod -aG dialout "$USER"
    echo "Fatto: $USER è nel gruppo dialout. Esci e rientra per usare picocom/tio/minicom."

# Imposta la password permanente di RustDesk (non è mai nel repository)
[group('air-os')]
rustdesk-password:
    #!/usr/bin/bash
    set -euo pipefail
    read -rsp "Nuova password RustDesk: " p1; echo
    read -rsp "Ripetila: " p2; echo
    [[ "$p1" == "$p2" && ${#p1} -ge 8 ]] || { echo "Non coincidono o meno di 8 caratteri"; exit 2; }
    sudo rustdesk --password "$p1" >/dev/null
    echo "Password impostata. Dal PC: RustDesk → IP del Mac (Tailscale 100.x o LAN)."

# Config personali dal repo privato air-config (la prima volta crea la chiave da aggiungere su GitHub)
[group('air-os')]
air-config:
    #!/usr/bin/bash
    set -euo pipefail
    if [[ ! -f ~/.ssh/air-config ]]; then
        air-config chiave
        read -rp "Aggiunta su GitHub? Invio per continuare " _
    fi
    air-config aggiorna

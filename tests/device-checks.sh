#!/usr/bin/env bash
# Verifiche sul MacBook Air installato. Dal PC:
#   ssh daniele@macbook-air 'bash -s' < tests/device-checks.sh
# (porta con sé tests/lib.sh, già presente nell'immagine)
set -u
source /usr/share/air-os/tests/lib.sh

skip() { echo "SKIP  $*"; }
driver_of() { basename "$(readlink -f "/sys/class/net/$1/device/driver" 2>/dev/null)"; }

section "Wi-Fi interno (wl)"
check "modulo wl caricato" grep -q '^wl ' /proc/modules
WL_IF=""
for i in /sys/class/net/*; do [[ "$(driver_of "${i##*/}")" == wl ]] && WL_IF=${i##*/}; done
check "interfaccia wl presente (${WL_IF:-nessuna})" test -n "$WL_IF"
check "Wi-Fi interno collegato" bash -c "nmcli -t -f DEVICE,STATE dev | grep -qx '${WL_IF}:connected'"

section "Accessori USB"
if lsusb -d 2001:331c >/dev/null 2>&1; then
    check "D-Link DWA-182 → rtw88_8822bu" grep -q '^rtw88_8822bu ' /proc/modules
else skip "D-Link DWA-182 non collegata"; fi
if lsusb -d 0bda:8153 >/dev/null 2>&1; then
    check "adattatore Ethernet → r8152" grep -q '^r8152 ' /proc/modules
else skip "adattatore Ethernet RTL8153 non collegato"; fi

section "Memoria (tuning CachyOS)"
check "zram con zstd" bash -c "zramctl --noheadings --output ALGORITHM | grep -q zstd"
mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
zram_b=$(zramctl --noheadings --bytes --output DISKSIZE 2>/dev/null | head -1 | tr -d ' ')
check "zram ≈ RAM (${zram_b:-0} B)" test "${zram_b:-0}" -ge $(( mem_kb * 1024 * 9 / 10 ))
check "swappiness 150 (cachyos-settings con zram)" test "$(cat /proc/sys/vm/swappiness)" -eq 150

section "Sospensione e sveglie"
check "sospensione profonda [deep]" grep -q '\[deep\]' /sys/power/mem_sleep
for dev in LID0 XHC1; do
    check "sveglia $dev disabilitata" grep -Eq "^${dev}[[:space:]].*\*disabled" /proc/acpi/wakeup
done

section "Immagine"
check "segue ghcr.io/drdamnation/air-os:stable" bash -c "sudo bootc status --format json | jq -e '.status.booted.image.image.image == \"ghcr.io/drdamnation/air-os:stable\"'"
check "firma verificata (policy)" bash -c "sudo bootc status --format json | jq -e '.status.booted.image.image.signature != null'"
check "aggiornamenti automatici spenti" bash -c "! systemctl is-enabled rpm-ostreed-automatic.timer"
check "kargs air-os attivi" bash -c "grep -q reboot=pci /proc/cmdline && grep -q firmware_class.path=/var/lib/air-os/firmware /proc/cmdline"

section "Avvio (riferimento Ubuntu: 2,0 s kernel + 17,3 s userspace)"
# initrd include il tempo per scrivere la password LUKS: si confronta lo userspace
userspace=$(systemd-analyze 2>/dev/null | grep -oE '[0-9.]+s \(userspace\)' | grep -oE '^[0-9.]+')
systemd-analyze 2>/dev/null | head -1
check "userspace < 17,3 s (${userspace:-?} s)" awk -v u="${userspace:-999}" 'BEGIN{exit !(u < 17.3)}'

section "Desktop e servizi"
check "greetd attivo" systemctl is-active greetd.service
check "tailscaled attivo" systemctl is-active tailscaled.service
check "rustdesk attivo" systemctl is-active rustdesk.service
check "campo stato" campo stato

finish

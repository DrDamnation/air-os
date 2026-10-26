#!/usr/bin/env bats
# Test di /usr/bin/campo con un finto /sys/class/net e nmcli in dry-run.

CAMPO=system_files/usr/bin/campo

# fake_iface <nome> <driver> [wireless]
fake_iface() {
    mkdir -p "$SYS/$1/device" "$DRV/$2"
    ln -s "$DRV/$2" "$SYS/$1/device/driver"
    [[ "${3:-}" == wireless ]] && mkdir -p "$SYS/$1/wireless"
    return 0
}

setup() {
    T=$(mktemp -d)
    SYS="$T/net"; DRV="$T/drivers"
    mkdir -p "$SYS" "$DRV"
    export CAMPO_SYSFS="$SYS" CAMPO_DRY_RUN=1 CAMPO_DEFAULT_IFACE=wlp3s0
    fake_iface wlp3s0 wl wireless
}
teardown() { rm -rf "$T"; }

@test "ip statico su adattatore USB: profilo senza route di default" {
    fake_iface enxAA r8152
    run bash "$CAMPO" ip 192.168.188.10/24 enxAA
    [ "$status" -eq 0 ]
    [[ "$output" == *"nmcli con add type ethernet ifname enxAA con-name campo-enxAA ipv4.method manual ipv4.addresses 192.168.188.10/24"* ]]
    [[ "$output" == *"ipv4.never-default yes"* ]]
    [[ "$output" == *"connection.autoconnect no"* ]]
    [[ "$output" == *"nmcli con up campo-enxAA"* ]]
}

@test "ip statico: adattatore scelto da solo se è l'unico enx" {
    fake_iface enxBB r8152
    run bash "$CAMPO" ip 10.0.0.2/24
    [ "$status" -eq 0 ]
    [[ "$output" == *"ifname enxBB"* ]]
}

@test "indirizzo non valido: exit 2" {
    fake_iface enxAA r8152
    run bash "$CAMPO" ip 999.1.1.1/24 enxAA
    [ "$status" -eq 2 ]
    [[ "$output" == *"indirizzo non valido"* ]]
}

@test "indirizzo senza /prefisso: exit 2" {
    fake_iface enxAA r8152
    run bash "$CAMPO" ip 192.168.1.5 enxAA
    [ "$status" -eq 2 ]
    [[ "$output" == *"indirizzo non valido"* ]]
}

@test "dhcp senza adattatore USB collegato: exit 2 con messaggio chiaro" {
    run bash "$CAMPO" dhcp
    [ "$status" -eq 2 ]
    [[ "$output" == *"nessun adattatore USB Ethernet collegato"* ]]
}

@test "dhcp: profilo automatico senza route di default" {
    fake_iface enxAA r8152
    run bash "$CAMPO" dhcp enxAA
    [ "$status" -eq 0 ]
    [[ "$output" == *"ipv4.method auto"* ]]
    [[ "$output" == *"ipv4.never-default yes"* ]]
}

@test "interfaccia inesistente: exit 2" {
    fake_iface enxAA r8152
    run bash "$CAMPO" ip 10.0.0.2/24 enxZZ
    [ "$status" -eq 2 ]
    [[ "$output" == *"interfaccia enxZZ non trovata"* ]]
}

@test "condividi sul Wi-Fi interno: rifiuto exit 3" {
    export CAMPO_DEFAULT_IFACE=enxAA
    fake_iface enxAA r8152
    run bash "$CAMPO" condividi wlp3s0
    [ "$status" -eq 3 ]
    [[ "$output" == *"non condivido il Wi-Fi interno"* ]]
}

@test "condividi sull'interfaccia che porta Internet: rifiuto exit 3" {
    fake_iface enxAA r8152
    export CAMPO_DEFAULT_IFACE=enxAA
    run bash "$CAMPO" condividi enxAA
    [ "$status" -eq 3 ]
    [[ "$output" == *"porta Internet"* ]]
}

@test "condividi su adattatore via cavo: ipv4.method shared" {
    fake_iface enxAA r8152
    run bash "$CAMPO" condividi enxAA
    [ "$status" -eq 0 ]
    [[ "$output" == *"type ethernet ifname enxAA con-name campo-enxAA ipv4.method shared"* ]]
}

@test "condividi sulla chiavetta Wi-Fi: hotspot con password generata, mai fissa" {
    fake_iface wlx4086 rtw88_8822bu wireless
    run bash "$CAMPO" condividi wlx4086
    [ "$status" -eq 0 ]
    [[ "$output" == *"type wifi ifname wlx4086 con-name campo-wlx4086"* ]]
    [[ "$output" == *"ipv4.method shared"* ]]
    [[ "$output" == *"802-11-wireless.mode ap"* ]]
    p1=$(grep -o 'wifi-sec.psk [^ ]*' <<<"$output")
    run bash "$CAMPO" condividi wlx4086
    p2=$(grep -o 'wifi-sec.psk [^ ]*' <<<"$output")
    [ -n "$p1" ] && [ "$p1" != "$p2" ]
}

@test "ip su interfaccia Wi-Fi: exit 2 (ci si collega dal pannello reti)" {
    fake_iface wlx4086 rtw88_8822bu wireless
    run bash "$CAMPO" ip 192.168.1.5/24 wlx4086
    [ "$status" -eq 2 ]
}

@test "spegni: giù e cancellato il profilo campo" {
    fake_iface enxAA r8152
    run bash "$CAMPO" spegni enxAA
    [ "$status" -eq 0 ]
    [[ "$output" == *"nmcli con delete campo-enxAA"* ]]
}

@test "comando sconosciuto: exit 2 con aiuto" {
    run bash "$CAMPO" boh
    [ "$status" -eq 2 ]
    [[ "$output" == *"Uso:"* ]]
}

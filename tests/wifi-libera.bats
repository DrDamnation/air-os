#!/usr/bin/env bats
# air-wifi-libera: le reti Wi-Fi salvate non restano legate a una scheda.

setup() {
    T=$(mktemp -d)
    cat > "$T/nmcli" <<'F'
#!/bin/bash
echo "$*" >> "$T/chiamate"
case "$*" in
  "-t -f UUID,TYPE con show") printf 'u1:802-11-wireless\nu2:802-3-ethernet\nu3:802-11-wireless\n' ;;
  "-g connection.interface-name con show uuid u1") echo wlp0s20u1u1u1 ;;
  "-g connection.interface-name con show uuid u3") echo "" ;;
esac
F
    sed -i "s#\$T#$T#" "$T/nmcli"; chmod +x "$T/nmcli"
    export NMCLI="$T/nmcli"
    CMD="$BATS_TEST_DIRNAME/../system_files/usr/libexec/air-wifi-libera"
}
teardown() { rm -rf "$T"; }

@test "slega solo le reti Wi-Fi legate a una scheda" {
    run bash "$CMD"
    [ "$status" -eq 0 ]
    grep -qx 'con modify uuid u1 connection.interface-name ' "$T/chiamate"
    ! grep -q 'modify uuid u3' "$T/chiamate"
    ! grep -q 'modify uuid u2' "$T/chiamate"
}

@test "senza reti da slegare non modifica niente" {
    sed -i 's/echo wlp0s20u1u1u1/echo ""/' "$T/nmcli"
    run bash "$CMD"
    [ "$status" -eq 0 ]
    ! grep -q modify "$T/chiamate"
}

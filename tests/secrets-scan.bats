#!/usr/bin/env bats

setup() { D=$(mktemp -d); }
teardown() { rm -rf "$D"; }

@test "file pulito: passa" {
    echo "direct-server = 'Y'" > "$D/ok.toml"
    echo "password = ''" >> "$D/ok.toml"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 0 ]
}

@test "psk wifi: fallisce" {
    printf '[wifi-security]\npsk=supersegreta\n' > "$D/x.nmconnection"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
    [[ "$output" != *supersegreta* ]]
}

@test "auth key tailscale: fallisce" {
    echo "TS_AUTHKEY=tskey-auth-abc123" > "$D/env"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "chiave privata: fallisce" {
    echo "-----BEGIN OPENSSH PRIVATE KEY-----" > "$D/id"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "password con valore: fallisce" {
    echo 'password = "ciao"' > "$D/r.toml"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "variabile di shell, non un valore: passa" {
    printf 'psk=$(genera)\necho "password: $psk"\n' > "$D/script"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 0 ]
}

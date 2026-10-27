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
    printf '[wifi-security]\npsk=supersegreta\n' > "$D/x.nmconnection"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
    [[ "$output" != *supersegreta* ]]
}

@test "auth key tailscale: fallisce" {
    echo "TS_AUTHKEY=tskey-auth-abc123" > "$D/env"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "chiave privata: fallisce" {
    echo "-----BEGIN OPENSSH PRIVATE KEY-----" > "$D/id"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "password con valore: fallisce" {
    echo 'password = "ciao"' > "$D/r.toml"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "variabile di shell, non un valore: passa" {
    printf 'psk=$(genera)\necho "password: $psk"\n' > "$D/script"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 0 ]
}

@test "email personale: fallisce" {
    echo "contatto = mario.rossi@gmail.com" > "$D/n.txt"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
    [[ "$output" != *mario.rossi* ]]
}

@test "codice fiscale: fallisce" {
    echo "cf RSSMRA80A01H501U" > "$D/n.txt"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "iban: fallisce" {
    echo "IT60X0542811101000000123456" > "$D/n.txt"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "telefono: fallisce" {
    echo "cell +39 333 1234567" > "$D/n.txt"  # secrets-scan: ok
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
}

@test "valore personale da SECRETS_SCAN_EXTRA: fallisce senza mostrarlo" {
    echo "server 203.0.113.77" > "$D/n.txt"
    SECRETS_SCAN_EXTRA='203\.0\.113\.77' run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 1 ]
    [[ "$output" != *203.0.113.77* ]]
}

@test "eccezione esplicita a fine riga: passa" {
    echo "esempio mario.rossi@gmail.com # secrets-scan: ok" > "$D/n.txt"
    run bash tests/secrets-scan.sh "$D"
    [ "$status" -eq 0 ]
}

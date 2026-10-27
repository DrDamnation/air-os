#!/usr/bin/env bats
# air-config: scarica il repo privato delle config e lo applica.
# Usa un repo git locale al posto di GitHub.

setup() {
    T=$(mktemp -d)
    export HOME="$T/home" && mkdir -p "$HOME"
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    git init -q -b main "$T/src"
    printf '#!/bin/sh\necho applicato >> "$HOME/segno"\n' > "$T/src/applica.sh"
    chmod +x "$T/src/applica.sh"
    git -C "$T/src" add . && git -C "$T/src" commit -qm uno
    export AIR_CONFIG_URL="$T/src"
    CMD="$BATS_TEST_DIRNAME/../system_files/usr/bin/air-config"
}
teardown() { rm -rf "$T"; }

@test "aggiorna: la prima volta clona e applica" {
    run bash "$CMD" aggiorna
    [ "$status" -eq 0 ]
    [ -f "$HOME/air-config/applica.sh" ]
    [ "$(cat "$HOME/segno")" = applicato ]
}

@test "aggiorna: le volte dopo scarica le novità" {
    bash "$CMD" aggiorna
    echo nuovo > "$T/src/nuovo.txt"
    git -C "$T/src" add . && git -C "$T/src" commit -qm due
    run bash "$CMD" aggiorna
    [ "$status" -eq 0 ]
    [ -f "$HOME/air-config/nuovo.txt" ]
}

@test "senza argomenti fa aggiorna" {
    run bash "$CMD"
    [ "$status" -eq 0 ]
    [ -f "$HOME/segno" ]
}

@test "repo non raggiungibile: errore che suggerisce la chiave" {
    AIR_CONFIG_URL="$T/non-esiste" run bash "$CMD" aggiorna
    [ "$status" -ne 0 ]
    [[ "$output" == *"air-config chiave"* ]]
}

@test "chiave: crea la chiave e la voce ssh, mostra solo la pubblica" {
    run bash "$CMD" chiave
    [ "$status" -eq 0 ]
    [ -f "$HOME/.ssh/air-config" ]
    [[ "$output" == *"ssh-ed25519 "* ]]
    [[ "$output" != *"PRIVATE KEY"* ]]
    grep -q '^Host github-air-config$' "$HOME/.ssh/config"
    grep -q 'IdentityFile ~/.ssh/air-config' "$HOME/.ssh/config"
}

@test "chiave: due volte non duplica né sovrascrive" {
    bash "$CMD" chiave
    prima=$(cat "$HOME/.ssh/air-config.pub")
    run bash "$CMD" chiave
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/.ssh/air-config.pub")" = "$prima" ]
    [ "$(grep -c '^Host github-air-config$' "$HOME/.ssh/config")" -eq 1 ]
}

@test "comando sconosciuto: uso, esce 2" {
    run bash "$CMD" boh
    [ "$status" -eq 2 ]
}

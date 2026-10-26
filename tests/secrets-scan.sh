#!/usr/bin/env bash
# Fallisce se nei file del repo che finiscono nell'immagine c'è qualcosa
# con la forma di un segreto. Uso: secrets-scan.sh [cartelle...]
set -u
dirs=("$@")
(( ${#dirs[@]} )) || dirs=(system_files build_files disk_config)

pattern='(psk|password|passwd|secret)[[:space:]]*[=:][[:space:]]*["'"'"']?[^"'"'"'[:space:]]|tskey-|BEGIN [A-Z ]*PRIVATE KEY|github_pat_|gh[pousr]_[A-Za-z0-9]{20,}'

if hits=$(grep -rInEi "$pattern" "${dirs[@]}" 2>/dev/null); then
    echo "Possibili segreti trovati:"
    # mostra solo file e riga, non il valore
    cut -d: -f1,2 <<<"$hits"
    exit 1
fi
echo "Nessun segreto trovato in: ${dirs[*]}"

#!/bin/bash
# Le immagini air-os si accettano solo se firmate con la nostra chiave cosign.
source "$(dirname "$0")/vars.sh"

policy=/etc/containers/policy.json
tmp=$(mktemp)
jq '.transports.docker["ghcr.io/drdamnation/air-os"] = [{
      "type": "sigstoreSigned",
      "keyPath": "/etc/pki/containers/air-os.pub",
      "signedIdentity": {"type": "matchRepository"}
    }]' "$policy" > "$tmp"
mv "$tmp" "$policy"
chmod 644 "$policy"

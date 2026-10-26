# air-os

Immagine bootc personale per un MacBook Air 13" 2017 da campo: Fedora 44 atomica
(base Universal Blue `base-main`), Niri + Dux Shell, messa a punto della memoria
presa da CachyOS, kit di rete da campo.

- Immagine: `ghcr.io/drdamnation/air-os:stable` (firmata con cosign, chiave in `cosign.pub`)
- Progetto: [`docs/superpowers/specs/2026-10-25-air-os-design.md`](docs/superpowers/specs/2026-10-25-air-os-design.md)
- Piano: [`docs/superpowers/plans/2026-10-26-air-os-stable.md`](docs/superpowers/plans/2026-10-26-air-os-stable.md)

## Struttura

- `build_files/build.sh` copia `system_files/` su `/` ed esegue `build_files/steps/NN-*.sh` in ordine.
  `20-kernel-modules.sh` è l'unico step che tocca kernel e moduli.
- `tests/image-checks.sh` gira in CI dentro l'immagine appena costruita (e sul Mac installato).
- `tests/*.bats` e `tests/secrets-scan.sh` girano in CI sul checkout.

## Aggiornare il Mac

Gli aggiornamenti automatici sono spenti. Prima di uscire: `sudo bootc upgrade` e riavvio.
Per tornare indietro: `sudo bootc rollback` e riavvio.

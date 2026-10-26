# air-os :stable — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un'immagine bootc `ghcr.io/drdamnation/air-os:stable` costruita ogni giorno su GitHub, installata in dual boot cifrato sul MacBook Air 2017 di Daniele, accanto a un macOS ristretto al minimo.

**Architecture:** Repo creato da `ublue-os/image-template`. Base `ghcr.io/ublue-os/base-main:44`; `build_files/build.sh` chiama script piccoli in `build_files/steps/` (uno per area); i file di configurazione stanno in `system_files/` e vengono copiati su `/`. I test sono script shell: `tests/image-checks.sh` gira in CI dentro l'immagine appena costruita, `tests/device-checks.sh` gira via SSH sul Mac installato, `tests/campo.bats` testa lo script di rete.

**Tech Stack:** bootc/Fedora 44, dnf5, COPR, GitHub Actions, cosign, bootc-image-builder (anaconda-iso), bash, bats, NetworkManager (nmcli).

**Spec:** `docs/superpowers/specs/2026-10-25-air-os-design.md`

## Global Constraints

- Repo pubblico `DrDamnation/air-os` (account `gh` attivo); immagine `ghcr.io/drdamnation/air-os`, tag `stable` (DEFAULT_TAG).
- Base: `ghcr.io/ublue-os/base-main:44`. Mai Bazzite, mai GNOME/NVIDIA.
- Solo fase 1: kernel Fedora stock. Ma `build.sh` diviso in step comuni + `steps/20-kernel-modules.sh`, così il tag `:cachy` si aggiunge dopo senza ristrutturare.
- Ogni COPR abilitato in build va disabilitato alla fine dello stesso step; URL del COPR Dux Labs in una sola variabile `DMS_COPR` in `build_files/steps/vars.sh`.
- Nessun segreto nel repo: niente password, PSK Wi-Fi, auth key Tailscale, password RustDesk. Chiave privata cosign solo come segreto GitHub `SIGNING_SECRET` + copia locale fuori dal repo.
- Firmware Apple della webcam mai nel repo né nell'immagine: scaricato sul Mac da `ujust camera-firmware`.
- Timer `bootc-fetch-apply-updates.timer` disabilitato; aggiornamento manuale.
- macOS non va cancellato: solo ristretto, dall'interno di macOS.
- Su Mac e PC nessuna azione distruttiva (partizioni, cancellazioni) senza ok esplicito di Daniele in quel momento.

## Review Focus

1. Modulo `wl` compilato per un kernel diverso da quello dell'immagine → Mac senza Wi-Fi. Atteso: build rossa. Test in Task 2 (`modinfo -k <kernel immagine> wl`).
2. `campo condividi` lanciato sul Wi-Fi interno (driver `wl`) o sull'interfaccia che porta Internet → Internet persa sul tetto. Atteso: rifiuto con messaggio. Test in Task 6.
3. `campo` senza adattatore USB collegato o con nome interfaccia sbagliato → atteso messaggio chiaro ed exit 2, non un errore criptico di nmcli. Test in Task 6.
4. COPR sparito/rinominato (migrazione Dux Labs) o lasciato abilitato → atteso build rossa nel primo caso, nessun `.repo` COPR attivo nell'immagine nel secondo. Test in Task 1 (check generico) + Task 5.
5. Segreto finito in `system_files/` → atteso CI rossa. Test in Task 1 (scansione per forma: `psk=`, `password=`, `tskey-`, chiavi private).

---

### Task 1: Repo, CI firmata e scheletro dei test

**Files:**
- Create (da template): tutto il repo `DrDamnation/air-os`
- Modify: `Containerfile` (FROM), `image-template.env`, `build_files/build.sh`, `.github/workflows/build.yml` (step test dopo la build)
- Create: `build_files/steps/vars.sh`, `tests/image-checks.sh`, `tests/lib.sh`, `cosign.pub`
- Move: `docs/superpowers/**` dal folder locale attuale dentro il repo

**Interfaces:**
- Produces: `tests/lib.sh` con `check "<descrizione>" <comando...>` (stampa PASS/FAIL, accumula, `finish` esce 1 se un check fallisce). `tests/image-checks.sh` si lancia come `podman run --rm <image> bash /usr/share/air-os/tests/image-checks.sh`; i task successivi **aggiungono sezioni** a questo file. `build.sh` esegue in ordine `build_files/steps/[0-9][0-9]-*.sh`.

- [ ] **Step 1:** Spostare la cartella locale `C:\Users\danie\projects\air-os` in `air-os.docs-tmp`, poi `gh repo create DrDamnation/air-os --template ublue-os/image-template --public --clone` in `C:\Users\danie\projects`. Riportare `docs/` nel repo. Atteso: `git log` mostra il commit iniziale del template.
- [ ] **Step 2: Scrivere i check che falliscono** in `tests/image-checks.sh` (copiato in `/usr/share/air-os/tests/` da `system_files`):
  - `check "Fedora 44" grep -q 'VERSION_ID=44' /etc/os-release`
  - `check "nessun repo COPR attivo" ! grep -rlq '^enabled=1' /etc/yum.repos.d/_copr*`
  - `check "niente Bazzite/GNOME" ! rpm -q gnome-shell`
  - `check "update timer spento" ! systemctl is-enabled bootc-fetch-apply-updates.timer`
  - `check "build info" test -f /usr/share/air-os/build-info`
  - scansione segreti: script `tests/secrets-scan.sh` lanciato in CI sul checkout: fallisce se `system_files/` o `build_files/` contengono `psk=`, `password=` con valore, `tskey-`, `BEGIN .*PRIVATE KEY`.
- [ ] **Step 3:** Aggiungere a `build.yml`, dopo la build e prima del push, lo step `podman run --rm <image> bash /usr/share/air-os/tests/image-checks.sh` e lo step `bash tests/secrets-scan.sh`. Pushare su branch, aprire PR: atteso **CI rossa** (immagine ancora Bazzite, timer attivo, build-info assente).
- [ ] **Step 4:** Implementare: `FROM ghcr.io/ublue-os/base-main:44`; `image-template.env` con `IMAGE_NAME=air-os`, `REPO_ORGANIZATION=drdamnation`, `DEFAULT_TAG="stable"`, `IMAGE_DESC="air-os: MacBook Air 2017 da campo"`; `build.sh` = copia `system_files` + loop sugli step; `steps/90-finalize.sh` scrive `/usr/share/air-os/build-info` (data, commit), disabilita il timer, `dnf5 clean all`.
- [ ] **Step 5:** Generare chiavi cosign (`cosign generate-key-pair`, da WSL o container `cgr.dev/chainguard/cosign`), committare `cosign.pub`, `gh secret set SIGNING_SECRET < cosign.key`, salvare `cosign.key` in `C:\Users\danie\Documents\air-os-secrets\` (fuori repo). Atteso: CI verde, immagine firmata su ghcr.io con tag `stable`, pacchetto ghcr reso pubblico.
- [ ] **Step 6: Commit + merge** `feat: base-main 44, test immagine, firma`.

### Task 2: Hardware Mac (Wi-Fi wl, sveglie, kernel args, Thunderbolt)

**Files:**
- Create: `build_files/steps/20-kernel-modules.sh`, `system_files/usr/lib/bootc/kargs.d/10-air.toml`, `system_files/usr/lib/systemd/system/air-disable-wakeup.service`, `system_files/usr/lib/udev/rules.d/90-air-thunderbolt.rules`
- Modify: `Containerfile` (stage `COPY --from=ghcr.io/ublue-os/akmods:main-44` per i RPM), `tests/image-checks.sh`

**Interfaces:**
- Consumes: loop step e `check` (Task 1).
- Produces: `20-kernel-modules.sh` è l'unico file che tocca kernel/moduli (in futuro: variante cachy).

- [ ] **Step 1: Check che falliscono:**
  - `KVER=$(ls /usr/lib/modules | head -1)`; `check "wl per il kernel dell'immagine" modinfo -k "$KVER" wl`
  - `check "rtw88_8822bu presente" modinfo -k "$KVER" rtw88_8822bu`
  - `check "r8152 presente" modinfo -k "$KVER" r8152`
  - `check "karg reboot=pci" grep -q 'reboot=pci' /usr/lib/bootc/kargs.d/10-air.toml`
  - `check "unit sveglie abilitata" systemctl is-enabled air-disable-wakeup.service`
  - `check "tuned-ppd presente" rpm -q tuned-ppd` e `check "niente TLP" ! rpm -q tlp`
- [ ] **Step 2:** CI rossa sui check nuovi.
- [ ] **Step 3:** Installare `kmod-wl` dai RPM dell'immagine akmods (tag allineato al kernel di base-main:44; se il tag generico non coincide, usare il tag con la versione del kernel). `air-disable-wakeup.service` (oneshot, all'avvio): per `LID0` e `XHC1` scrive in `/proc/acpi/wakeup` solo se la riga risulta `*enabled` (scrivere fa da toggle). kargs: `reboot=pci`. Regola udev: autorizzazione Thunderbolt spenta di default (risparmio ~2 W); può essere riattivata a mano.
- [ ] **Step 4:** CI verde.
- [ ] **Step 5: Commit** `feat: driver wl, fix Mac (sveglie, reboot, thunderbolt)`.

### Task 3: Webcam su richiesta

**Files:**
- Modify: `build_files/steps/20-kernel-modules.sh`, `tests/image-checks.sh`
- Create: `system_files/usr/lib/modprobe.d/air-facetimehd.conf` (blacklist), `system_files/usr/share/ublue-os/just/60-air.just` (ricette `camera-firmware`, `camera`)

**Interfaces:**
- Produces: file `60-air.just` dove i task successivi aggiungono le loro ricette `ujust`. Percorso firmware runtime: `/var/lib/air-os/firmware/facetimehd/firmware.bin`, passato al kernel via `firmware_class.path=/var/lib/air-os/firmware` (karg aggiunto a `10-air.toml`).

- [ ] **Step 1: Check che falliscono:** `check "facetimehd per il kernel" modinfo -k "$KVER" facetimehd`; `check "facetimehd in blacklist" grep -q 'blacklist facetimehd' /usr/lib/modprobe.d/air-facetimehd.conf`; `check "ricetta camera" grep -q '^camera:' /usr/share/ublue-os/just/60-air.just`; `check "path firmware" grep -q firmware_class.path /usr/lib/bootc/kargs.d/10-air.toml`.
- [ ] **Step 2:** CI rossa.
- [ ] **Step 3:** Compilare `facetimehd` in build dal COPR `mulderje/facetimehd-kmod` (akmod dentro il container, con i controlli di Margine OS: cercare `*.failed.log`, fallire se presenti). `camera-firmware`: scarica ed estrae il firmware con lo script ufficiale di `patjak/facetimehd-firmware` in `/var/lib/air-os/firmware/facetimehd/`. `camera`: `modprobe facetimehd` / `modprobe -r` (alternanza on/off). **Se il COPR non ha build per F44:** fermarsi, segnare il task "rimandato" nel README e passare al Task 4 (la webcam non blocca il resto).
- [ ] **Step 4:** CI verde.
- [ ] **Step 5: Commit** `feat: webcam facetimehd caricata a richiesta`.

### Task 4: Messa a punto CachyOS

**Files:**
- Create: `build_files/steps/30-tuning.sh`
- Modify: `tests/image-checks.sh`

- [ ] **Step 1: Check che falliscono:** `check "cachyos-settings" rpm -q cachyos-settings`; `check "zram-generator-defaults rimosso" ! rpm -q zram-generator-defaults`; `check "zram zstd" grep -q 'compression-algorithm *= *zstd' /usr/lib/systemd/zram-generator.conf`; `check "swappiness 100" grep -rq 'vm.swappiness *= *100' /usr/lib/sysctl.d/`; `check "scx installato" rpm -q scx-scheds`; `check "scx spento" ! systemctl is-enabled scx.service scx_loader.service 2>/dev/null`; `check "niente ananicy" ! rpm -q ananicy-cpp`.
- [ ] **Step 2:** CI rossa.
- [ ] **Step 3:** COPR `bieszczaders/kernel-cachyos-addons`: `dnf5 swap zram-generator-defaults cachyos-settings`, `dnf5 install scx-scheds scx-tools`, disabilitare i servizi scx, disabilitare il COPR.
- [ ] **Step 4:** CI verde.
- [ ] **Step 5: Commit** `feat: tuning memoria CachyOS, scx installato spento`.

### Task 5: Desktop Niri + Dux Shell

**Files:**
- Create: `build_files/steps/40-desktop.sh`, `system_files/etc/greetd/config.toml`, `system_files/etc/skel/.config/niri/config.kdl`, `system_files/etc/skel/.config/systemd/user/default.target.wants/dms.service` (symlink a `/usr/lib/systemd/user/dms.service`), `system_files/usr/lib/environment.d/50-air-dms.conf`
- Modify: `build_files/steps/vars.sh` (`DMS_COPR`), `tests/image-checks.sh`

**Interfaces:**
- Consumes: `DMS_COPR` da `vars.sh`.

- [ ] **Step 1: Check che falliscono:** `rpm -q niri dms dms-greeter quickshell matugen greetd foot thunar`; `check "greetd abilitato" systemctl is-enabled greetd`; `check "greeter avvia niri" grep -q 'dms-greeter --command niri' /etc/greetd/config.toml`; `check "dms utente" test -L /etc/skel/.config/systemd/user/default.target.wants/dms.service`; `check "cava spento" grep -q 'DMS_DISABLE_CAVA=1' /usr/lib/environment.d/50-air-dms.conf`; `check "app-id nuovo" grep -q 'dev.duxlabs.shell' /etc/skel/.config/niri/config.kdl`; `check "gesture touchpad" grep -q 'touchpad' /etc/skel/.config/niri/config.kdl`.
- [ ] **Step 2:** CI rossa.
- [ ] **Step 3:** `niri` dai repo Fedora; `dms`, `dms-greeter`, `quickshell`, `matugen` da `$DMS_COPR` (prima verificare quale tra `avengemedia/dms` e `duxlabs/*` ha build 2.x per F44, e scriverlo in `vars.sh`); `foot` come terminale, `thunar` come file manager. greetd: `command = "dms-greeter --command niri"`, utente greeter creato dal pacchetto (sysusers). `config.kdl`: tap-to-click e natural scroll sul touchpad, gesture attive, `Mod+Shift+L` → script `air-contrast` che passa DMS al tema chiaro ad alto contrasto (aggiunto in `/usr/bin/air-contrast`), regola finestra con app-id `dev.duxlabs.shell`, niente blur/animazioni.
- [ ] **Step 4:** CI verde.
- [ ] **Step 5: Commit** `feat: desktop niri + dux shell leggero`.

### Task 6: Kit da campo e comando `campo`

**Files:**
- Create: `build_files/steps/50-field.sh`, `system_files/usr/bin/campo`, `system_files/usr/lib/udev/rules.d/90-air-serial.rules`, `tests/campo.bats`
- Modify: `tests/image-checks.sh`, `.github/workflows/build.yml` (step bats prima della build)

**Interfaces:**
- Produces: `campo ip <CIDR> [IFACE]`, `campo dhcp [IFACE]`, `campo condividi [IFACE]`, `campo stato`, `campo spegni [IFACE]`. Connessioni NM chiamate `campo-<IFACE>`, `autoconnect=no`. IFACE di default: la prima interfaccia ethernet USB (`enx*`). Variabile `CAMPO_DRY_RUN=1`: stampa i comandi `nmcli` invece di eseguirli. Variabile `CAMPO_SYSFS` (default `/sys/class/net`) per i test. Exit code: 0 ok, 2 errore d'uso/interfaccia, 3 rifiuto di sicurezza.

- [ ] **Step 1: Test bats che falliscono** (`tests/campo.bats`, con finto sysfs in una cartella temporanea):
  - `campo ip 192.168.188.10/24 enxAA` in dry-run stampa `nmcli con add type ethernet ifname enxAA con-name campo-enxAA ipv4.method manual ipv4.addresses 192.168.188.10/24` e `ipv4.never-default yes` → exit 0
  - `campo ip 999.1.1.1/24 enxAA` → exit 2, messaggio "indirizzo non valido"
  - `campo dhcp` senza nessuna `enx*` nel finto sysfs → exit 2, messaggio "nessun adattatore USB Ethernet collegato"
  - `campo ip 10.0.0.2/24 enxZZ` con `enxZZ` assente → exit 2, "interfaccia enxZZ non trovata"
  - `campo condividi wlp3s0` con driver finto `wl` → exit 3, "non condivido il Wi-Fi interno"
  - `campo condividi enxAA` quando `enxAA` porta la route di default (simulata via `CAMPO_DEFAULT_IFACE=enxAA`) → exit 3
  - `campo condividi wlx4086` (driver `rtw88_8822bu`) in dry-run → `ipv4.method shared`, exit 0
- [ ] **Step 2:** `bats tests/campo.bats` → tutti FAIL (script assente).
- [ ] **Step 3:** Scrivere `/usr/bin/campo` (bash). Le route Internet restano sul Wi-Fi interno: ogni profilo campo ha `ipv4.never-default yes`. `campo stato` stampa interfacce, IP, gateway, test `ping -c1 -W2 1.1.1.1` (Internet sì/no), `tailscale status --peers=false`.
- [ ] **Step 4:** `bats tests/campo.bats` → PASS.
- [ ] **Step 5: Check immagine:** `rpm -q openssh-clients nmap arp-scan iperf3 mtr iw wavemon ethtool tcpdump wireshark-cli picocom tio minicom tailscale git bats`; `check "campo eseguibile" test -x /usr/bin/campo`; `check "regola seriale" test -f /usr/lib/udev/rules.d/90-air-serial.rules`; `check "tailscaled abilitato" systemctl is-enabled tailscaled`. Implementare `50-field.sh` (pacchetti; i mancanti in Fedora 44 vanno segnalati e sostituiti, non ignorati). Regola udev: `ttyUSB*`/`ttyACM*` → gruppo `dialout`, mode 0660; l'utente va in `dialout` (ricetta `ujust campo-setup` in `60-air.just` che fa `usermod -aG dialout $USER`).
- [ ] **Step 6:** CI verde. **Commit** `feat: kit da campo e comando campo`.

### Task 7: RustDesk solo locale

**Files:**
- Create: `build_files/steps/60-rustdesk.sh`, `system_files/etc/skel/.config/rustdesk/RustDesk2.toml`, `system_files/usr/lib/firewalld/services/rustdesk-direct.xml` (se firewalld è nell'immagine)
- Modify: `build_files/steps/vars.sh` (`RUSTDESK_VERSION`), `tests/image-checks.sh`

- [ ] **Step 1: Check che falliscono:** `check "rustdesk" rpm -q rustdesk`; nel file skel: `direct-server = 'Y'`, `custom-rendezvous-server = ''`, `relay-server = ''`, `whitelist` contenente `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`, `100.64.0.0/10`; `check "nessuna password nel toml" ! grep -qi 'password' /etc/skel/.config/rustdesk/RustDesk2.toml`.
- [ ] **Step 2:** CI rossa.
- [ ] **Step 3:** RPM ufficiale da GitHub releases RustDesk alla versione `RUSTDESK_VERSION` (pinnata, verificata con checksum se pubblicato). Porta 21118/tcp aperta solo verso le reti della whitelist (servizio firewalld o, se assente, nessuna regola: RustDesk filtra già con whitelist). Password permanente da impostare a mano sul Mac (`ujust rustdesk-password` che chiama `rustdesk --password` leggendo da prompt).
- [ ] **Step 4:** CI verde. **Commit** `feat: rustdesk solo IP diretto su LAN/Tailscale`.

### Task 8: ISO di installazione

**Files:**
- Create: `disk_config/iso-air.toml`
- Modify: `.github/workflows/build-disk.yml` (usa `iso-air.toml`, solo `anaconda-iso`, solo amd64)

- [ ] **Step 1:** `iso-air.toml`: kickstart `%post` con `bootc switch --mutate-in-place --enforce-container-sigpolicy --transport registry ghcr.io/drdamnation/air-os:stable`; moduli Anaconda abilitati: Storage, Runtime, **Users**, **Timezone**, **Security**; disabilitati: Network, Services, Subscription. Nessuna password o utente nel kickstart.
- [ ] **Step 2:** `gh workflow run build-disk.yml -f platform=amd64`, `gh run watch`. Atteso: run verde, artifact ISO presente. Scaricarlo con `gh run download` in `F:\air-os-iso\`. Verificare dimensione > 1 GB e checksum registrato.
- [ ] **Step 3: Prova in VM** (Hyper-V o QEMU in WSL, sola UEFI): l'installer parte, mostra le schermate disco e utente, installa su disco virtuale con cifratura, riavvia nel greeter DMS. Atteso: login → niri + barra DMS; `bash /usr/share/air-os/tests/image-checks.sh` PASS anche sul sistema installato.
- [ ] **Step 4: Commit** `feat: ISO anaconda per air-os`.

### Task 9: Installazione sul Mac (con Daniele)

Ogni passo distruttivo richiede l'ok di Daniele in quel momento.

- [ ] **Step 1 (Daniele, in macOS):** avvio di macOS (tasto Option), poi nel Terminale: `sw_vers`, `tmutil listlocalsnapshots /`, `diskutil apfs list`. Claude legge l'output e calcola la dimensione: spazio occupato + ~8 GB liberi, arrotondato per eccesso al GB.
- [ ] **Step 2 (Daniele, in macOS):** `sudo tmutil deletelocalsnapshots /` (se ce ne sono), poi `sudo diskutil apfs resizeContainer disk0s2 <N>g`. Atteso: `diskutil list` mostra il contenitore ridotto e spazio libero dopo. Riavvio in macOS per controllare che parta.
- [ ] **Step 3:** Scrivere l'ISO su chiavetta dal PC (Rufus in modalità DD o Fedora Media Writer). Collegarla al Mac con il riduttore USB-A.
- [ ] **Step 4 (Daniele, con Claude che guida):** boot con Option → "EFI Boot". In Anaconda: tastiera italiana, fuso Europa/Roma; disco → **personalizzato**: eliminare la partizione Ubuntu (sda3), creare btrfs **cifrato** in tutto lo spazio libero (ex APFS + ex Ubuntu), `/boot` ext4 1 GB, montare la EFI esistente (sda1) su `/boot/efi` **senza formattarla**; utente `daniele` amministratore. Installare.
- [ ] **Step 5:** Primo avvio: password LUKS → greeter → niri. Wi-Fi (`jona6`, WPA2) via DMS. `sudo tailscale up --ssh` con login da browser; poi rimuovere dal pannello Tailscale il vecchio nodo `macbook-air` (Ubuntu) e dare il nome `macbook-air` al nuovo. Installare la chiave SSH di Claude in `~/.ssh/authorized_keys`. Claude Code con l'installer nativo.
- [ ] **Step 6:** Verificare che macOS parta ancora (Option → Macintosh HD).

### Task 10: Verifiche sul Mac installato

**Files:**
- Create: `tests/device-checks.sh` (lanciato via `ssh daniele@macbook-air 'bash -s' < tests/device-checks.sh`)

- [ ] **Step 1:** Scrivere i check (usano `tests/lib.sh`): `wl` caricato e `wlp3s0` connesso; `lsusb` D-Link → `rtw88_8822bu` caricato; `r8152` per l'adattatore; `zramctl` algoritmo `zstd` e dimensione ≈ RAM; `/sys/power/mem_sleep` contiene `[deep]`; righe `LID0`/`XHC1` in `/proc/acpi/wakeup` = `*disabled`; `bootc status` mostra `ghcr.io/drdamnation/air-os:stable` firmato; `systemd-analyze` totale < 19,3 s (riferimento Ubuntu); `campo stato` esce 0.
- [ ] **Step 2:** Eseguire. Atteso: tutto PASS; i FAIL diventano issue nel repo con l'output.
- [ ] **Step 3: Misure a mano** (risultati in `docs/misure-2026-10.md`): CPU media di `qs` e `niri` a riposo per 10 minuti (`top -b -d 10 -n 60`), soglia di allarme 5%; RAM di `qs` a inizio e fine giornata; sospensione e ripresa con coperchio, Wi-Fi che riparte; `campo condividi` su un apparato vero; RustDesk dal PC verso il Mac via Tailscale (controllo mouse/tastiera: se non funziona, annotarlo, come previsto nella spec §6.6); `ujust camera-firmware` + `ujust camera`; ore di batteria in uso reale.
- [ ] **Step 4: Commit** `test: verifiche sul dispositivo e misure`.

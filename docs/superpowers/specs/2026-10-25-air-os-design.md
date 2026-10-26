# air-os — OS personale per MacBook Air 13" 2017 

Stato: **approvata** (Daniele, 2026-10-26: "poi vai"). Data: 2026-10-25.
Ricerca di supporto: `C:\Users\danie\projects\reports\CachyOS e Fedora atomica ibrido.md` (+ note in `research_notes/CachyOS e Fedora atomica ibrido/`).
Origine: conversazioni del 5/10 (Morro OS, Omarchy) e del 25/10.

## 1. Perché

Daniele vuole ridare vita a un MacBook Air 13" 2017 (oggi con Ubuntu) facendolo diventare un **coltellino svizzero da campo**: va in giro con lui, serve per programmare in emergenza e per configurare antenne e router sui tetti. Deve essere **scattante** e affidabile: sul tetto non c'è tempo per riparare il sistema.

Vuole farlo "alla Morro OS": un repository GitHub tutto suo, che costruisce un'immagine di sistema dedicata solo a questo Mac.

## 2. Obiettivi, non-obiettivi, anti-obiettivi

**Obiettivi**
- Accensione e ripresa dalla sospensione rapide; interfaccia reattiva su 2 core / 8 GB.
- Batteria il più lunga possibile.
- Due vie verso l'apparato da configurare: **cavo** (adattatore USB-Ethernet) e **Wi-Fi**, contemporaneamente a una connessione Internet.
- Kit da campo pronto all'uso, senza installare niente sul posto.
- Aggiornamenti che non possono lasciarlo rotto: si torna indietro con un riavvio.
- **RustDesk solo locale** (vedi §6.6).
- Tastiera **e** touchpad entrambi comodi.

**Non-obiettivi**
- Giochi, NVIDIA, Docker pesante, carichi da PC principale.
- Supportare altre macchine: l'immagine è solo per questo Mac.
- Pacchetti x86-64-v3 di sistema (Fedora non li produce).

**Anti-obiettivi** (fallimento anche se "funziona")
- Sul campo il Wi-Fi interno smette di funzionare dopo un aggiornamento e non c'è un'alternativa.
- La shell grafica consuma CPU a riposo e scalda/scarica il Mac.
- Password, chiavi o dati personali finiscono nel repository pubblico.
- RustDesk raggiungibile da Internet o dipendente dai server pubblici RustDesk.

## 3. Hardware (fatti dalla ricerca)

- MacBookAir7,2 (A1466), i5-5350U Broadwell 2C/4T (supporta x86-64-v3), 8 GB, Intel HD 6000 (i915 + Mesa iris), schermo 1440x900 a scala 100%.
- Wi-Fi Broadcom **BCM4360** (14e4:43a0): solo driver proprietario `wl`, **niente WPA3**.
- Webcam FaceTime HD: modulo esterno `facetimehd` + firmware Apple estratto da macOS 10.12.6.
- Niente porta Ethernet. Niente T1/T2. Secure Boot: presumibilmente assente (da verificare).
- Tastiera, touchpad, audio, retroilluminazioni, Bluetooth: funzionano col kernel standard.

## 4. Decisioni prese

| Tema | Decisione | Di chi |
|---|---|---|
| Approccio | Immagine bootc (Fedora atomica) costruita su GitHub Actions, come Morro OS | Daniele (5/10), confermato dalla ricerca |
| Ibrido CachyOS | "Fedora per la struttura, CachyOS per la messa a punto" | proposta Claude dopo ricerca, Daniele ha detto "procediamo" |
| Interfaccia | Niri + Dux Shell (ex DankMaterialShell), greetd + dms-greeter | Daniele |
| Input | Touchpad con gesture + tastiera | Daniele |
| Collegamento campo | Cavo e Wi-Fi, entrambi | Daniele |
| Marche apparati | Non importanti: strumenti generici | Daniele |
| RustDesk | Sì, configurato solo locale | Daniele |

## 5. Architettura

**Repository**: pubblico su GitHub (account di Daniele), nome provvisorio `air-os` *(scelta Claude)*. Creato da `ublue-os/image-template` (Containerfile, `build_files/build.sh`, `system_files/`, Justfile, `image-template.env`, workflow giornaliero, firma cosign, push su ghcr.io).

**Base**: `ghcr.io/ublue-os/base-main` (Fedora 44, senza desktop). Non Bazzite (default del template, troppo pesante).

**Due tag dallo stesso repo**

| Tag | Kernel | Wi-Fi / webcam | Ruolo |
|---|---|---|---|
| `:stable` | Fedora stock | `kmod-wl` precompilato da `ghcr.io/ublue-os/akmods` (`main-44`) | Uso quotidiano e campo |
| `:cachy` | `kernel-cachyos` GCC (non LTO), COPR `bieszczaders/kernel-cachyos` | `akmod-wl` (RPM Fusion) e `facetimehd` compilati in build, controlli alla Margine OS (cercare `*.failed.log`) | Sperimentale; `bootc switch` per andarci, riavvio per tornare |

`:cachy` è **fase 2**: si costruisce solo dopo che `:stable` gira bene sul Mac. *(Scelta Claude)* Il piano copre solo `:stable`, ma `build.sh` è diviso fin da subito in parte comune + parte "kernel/moduli", così aggiungere il secondo tag non richiede di ristrutturare.

**Repo, ghcr e firma** *(scelta Claude)*: li crea Claude con `gh` sull'account di Daniele, generando la chiave cosign e salvandola come segreto del repo; la parte privata della chiave resta solo nel segreto GitHub e in una copia locale fuori dal repo. La policy di verifica della firma entra già nella prima immagine.

## 6. Contenuto dell'immagine

### 6.1 Desktop
- `niri` (repo Fedora); `dms`, `dms-greeter`, `quickshell`, `matugen` da COPR Dux Labs. URL del COPR in **una sola variabile** (migrazione `avengemedia/*` → `duxlabs/*` in corso).
- `/etc/greetd/config.toml` con `dms-greeter --command niri`; greetd abilitato.
- `dms.service` utente abilitato via `/etc/skel/.config/systemd/user/` o preset.
- Default "leggeri": `DMS_DISABLE_CAVA=1`, niente blur, niente animazioni continue, pochi widget che fanno polling.
- Regole finestre niri con il nuovo app-id `dev.duxlabs.shell`.
- Tema chiaro ad alto contrasto attivabile con una scorciatoia (leggibilità al sole) *(idea Claude)*.
- Gesture touchpad di niri attive; terminale e file manager leggeri *(scelta lasciata al builder, preferire app native non Electron)*.

### 6.2 Messa a punto (da CachyOS)
- `cachyos-settings` dalla COPR `bieszczaders/kernel-cachyos-addons` al posto di `zram-generator-defaults`: zram = RAM, zstd, swappiness 100, page-cluster 0, NMI watchdog off, regole I/O.
- `scx-scheds` + `scx-tools` installati, **spenti** di default.
- Niente ananicy-cpp all'inizio.

### 6.3 Hardware Mac
- `facetimehd` in blacklist, caricato a richiesta (`ujust camera`), perché tenerlo caricato può rompere la sospensione.
- Firmware webcam **non** nel repo pubblico: un comando `ujust` lo scarica/estrae sul Mac *(proposta Claude; la fattibilità dipende dal percorso firmware scrivibile, vedi §9)*.
- Unità systemd che disabilita la sveglia da LID0/XHC1; `reboot=pci`; Thunderbolt spento se non serve (risparmio ~2 W).
- Gestione energia: tuned-ppd (niente TLP).
- `applesmc` per ventole/retroilluminazione; mbpfan solo se la verifica lo richiede.

### 6.4 Rete da campo
- **Cavo**: profili NetworkManager per l'adattatore USB-Ethernet con IP statico, `autoconnect=false`, senza segreti. Comando unico con tre modalità *(scelta Claude)*: `campo ip <indirizzo/subnet>` (IP fisso), `campo dhcp` (il Mac riceve l'indirizzo dall'apparato), `campo condividi` (NetworkManager `shared`: il Mac dà l'indirizzo a un apparato appena uscito di fabbrica e gli condivide Internet; solo sull'interfaccia via cavo o sulla chiavetta, mai sul Wi-Fi interno che va verso Internet). Nomi dei comandi: scelta builder.
- **Wi-Fi doppio**: interno (`wl`, WPA2) per Internet/hotspot telefono; **chiavetta USB con driver nel kernel** (famiglia mt76) per l'apparato, compatibile WPA3. Le due connessioni devono convivere (route di default su quella Internet).
- **Schermata stato campo** *(idea Claude)*: comando/widget che mostra interfacce, IP, gateway, Internet raggiungibile sì/no, Tailscale collegato.

### 6.5 Kit da campo
- `openssh-clients`, `nmap`, `arp-scan`, `iperf3`, `mtr`, `iw`, `wavemon`, `ethtool`, `tcpdump`, `wireshark-cli`, `picocom`/`tio`/`minicom` (+ gruppo `dialout` e regole udev per adattatori seriali USB), `tailscale`, `git`.
- Strumento di puntamento Zyxel eseguibile anche in locale *(da capire dove sta oggi sul NAS e come impacchettarlo; può stare fuori dall'immagine)*.
- Fuori dall'immagine: Claude Code (installer nativo in `~/.local/bin`), dotfile in repo chezmoi separato, distrobox Ubuntu (e opzionale Arch/CachyOS) per strumenti extra.

### 6.6 RustDesk solo locale
- Significato *(interpretazione Claude, da confermare)*: nessun server pubblico RustDesk né relay; connessioni solo per **IP diretto** su LAN o Tailscale.
- Il Mac fa sia da **client** (controlla un PC sul posto) sia da **host** (lo controlli da casa via Tailscale).
- Configurazione: accesso IP diretto attivo (porta 21118), server di rendezvous/relay vuoti, whitelist IP limitata a reti private + 100.64.0.0/10 (Tailscale), password permanente **non** nel repo (impostata a mano o da segreto locale).
- Installazione: RPM ufficiale o Flatpak *(scelta builder)*.
- **Rischio noto**: come host su Wayland/niri lo schermo si condivide via portale, ma il controllo remoto di mouse/tastiera richiede il portale RemoteDesktop, che niri potrebbe non offrire. Se non va, il ruolo host si ripiega su ssh + condivisione solo visione, o si valuta un'alternativa; il ruolo client funziona comunque. Da verificare presto.

### 6.7 Aggiornamenti
- Timer automatico `bootc-fetch-apply-updates` **spento**; aggiornamento manuale `bootc upgrade` (o `ujust update`) prima di uscire, così non consuma dati in tethering né CPU nei primi minuti.
- Rollback: Shift al boot o `bootc rollback`.
- La build giornaliera su GitHub fallisce in modo visibile se un pacchetto/COPR sparisce (es. `kmod-wl`, COPR Dux Labs): va controllato che il workflow verifichi la presenza di `wl` nell'immagine.

## 7. Installazione sul Mac
- Generare una ISO dall'immagine (bootc-image-builder / workflow del template) e installare da chiavetta, sostituendo Ubuntu *(approccio di default; in alternativa installare una Fedora atomica ufficiale e fare `bootc switch`)*.
- **macOS resta ma ridotto al minimo** (decisione Daniele, 2026-10-26: "prendi più spazio possibile da macOS"): dual boot. Il contenitore APFS (sda2, 56 GB) si restringe **da macOS** con `diskutil apfs resizeContainer` (Linux non sa ridimensionare APFS), lasciando a macOS lo spazio occupato + un margine minimo per funzionare *(scelta Claude: ~8 GB liberi oltre all'occupato; dimensione esatta da decidere leggendo `diskutil apfs list` e `sw_vers`, dopo aver tolto le istantanee locali con `tmutil`)*. Lo spazio liberato è contiguo a sda3, quindi air-os prende spazio liberato + sda3 in un'unica partizione. Riusa la EFI esistente. Scelta del sistema col tasto Option all'avvio (o boot order EFI). Partizionamento quindi **manuale/guidato** in Anaconda sulla sola sda3, non automatico sull'intero disco.
- **Disco cifrato con LUKS** (decisione Daniele): password a ogni avvio, niente TPM. btrfs + LUKS sulla sola sda3 dall'installer Anaconda della ISO; utente e password creati interattivamente all'installazione (niente segreti in kickstart nel repo).
- Prima di cancellare Ubuntu: salvare eventuali dati presenti.

## 7b. Verifiche preliminari (prima di costruire)
Claude si collega via SSH al Mac mentre ha ancora Ubuntu (decisione Daniele) e fa in sola lettura i controlli del §9 possibili da lì: Secure Boot, x86-64-v3, `mem_sleep`, PCI ID Wi-Fi, Thunderbolt, comportamento `wl` dopo sospensione, dati da salvare. I risultati possono cambiare §6.3 prima del piano.

**Risultati (2026-10-25, via SSH su Ubuntu 24.04.4, kernel 7.0.0-30):**
- Modello MacBookAir7,2, firmware 489.0.0.0.0. **Secure Boot non supportato** → moduli non firmati OK.
- **x86-64-v3 supportato** (anche v4 elencato dal loader).
- RAM 7,7 GiB. Sospensione: `s2idle [deep]` (deep attivo). Sveglie ACPI abilitate: LID0, XHC1, RP01-06.
- Wi-Fi interno BCM4360 `14e4:43a0` con `wl`, collegato a WPA2 su 5 GHz senza problemi.
- Webcam `14e4:1570` presente (nessun driver caricato su Ubuntu).
- Thunderbolt 2 (Falcon Ridge) con modulo `thunderbolt` caricato.
- Adattatore Ethernet = **Realtek RTL8153 (`0bda:8153`), driver `r8152`**: nel kernel, funziona.
- D-Link DWA-182 D1 = `2001:331c`, driver **`rtw88_8822bu`** (nel kernel), vede le reti a 2,4 e 5 GHz.
- Disco: SSD Apple SATA 113 GB (scheduler mq-deadline): EFI 200 MB + **APFS 56 GB (macOS ancora presente)** + ext4 56 GB Ubuntu. Home Ubuntu 122 MB, cartelle vuote (niente da salvare in pratica).
- Batteria: 134 cicli, salute ~88% (6,30/7,15 Ah).
- Avvio Ubuntu: 2,0 s kernel + 17,3 s userspace (riferimento da battere).
- sudo senza password, Tailscale 1.102.3 attivo (nodo `macbook-air`, taggato).

## 7c. Accessori
- **Ethernet**: il Mac ha solo USB-A (+ Thunderbolt 2). L'adattatore USB-C Ethernet di Daniele, collegato con un riduttore a USB-A, **sembra funzionare** su Ubuntu (Daniele, 2026-10-25). Chip e driver da leggere via SSH (`lsusb`, `ethtool -i`) per assicurarsi che il driver sia nel kernel Fedora.
- **Wi-Fi USB**: D-Link DWA-182 AC1300 **H/W Ver D1** → chip Realtek RTL8812BU *(da conoscenza, confermare con `lsusb`)*, driver `rtw88_8822bu` nel kernel mainline dal 6.2, quindi niente moduli esterni; WPA3 gestito da wpa_supplicant. Da provare sul campo stabilità e velocità (i driver rtw88 USB in passato erano meno solidi dei mt76); se delude, si compra una chiavetta mt76.

## 8. Lasciato al builder
Nome definitivo del repo e dei comandi `ujust`, scelta terminale/file manager/editor leggeri, struttura interna di `build.sh`, se usare BlueBuild o il Containerfile del template (preferenza: template, come Morro), dettagli della firma cosign.

## 9. Punti aperti da verificare sulla macchina (dal report)
1. Secure Boot assente / moduli non firmati accettati.
2. Supporto x86-64-v3 (prima di `:cachy`).
3. `wl`: 2,4/5 GHz, dopo sospensione, WPA2 vs WPA3/misto.
4. Chiavetta Wi-Fi USB e adattatore USB-Ethernet: modelli da comprare/testare.
5. `kmod-wl` presente in `akmods main-44` a ogni cambio di versione Fedora.
6. `facetimehd`: build COPR per F44/F45, percorso firmware alternativo scrivibile.
7. Sospensione: `deep` vs `s2idle`, sveglia da coperchio.
8. CPU/RAM a riposo di Dux Shell e niri; leak Quickshell su una giornata.
9. Stabilità grafica su HD 6000 con Mesa F44.
10. zram effettivamente zstd.
11. Quali scheduler scx partono (fase 2).
12. Ore reali di batteria.
13. Tempo/dimensione della build, spazio runner per `:cachy`.
14. Quale COPR Dux Labs è vivo.
15. Tailscale già in `base-main`? percorso dei `.just` personalizzati.
16. RustDesk host su niri: il controllo remoto funziona?

#!/usr/bin/env bats
# Kickstart dell'ISO (disk_config/iso-air.toml).

ISO="$BATS_TEST_DIRNAME/../disk_config/iso-air.toml"

# estrae una sezione %nome ... %end dal kickstart
sezione() { sed -n "/^%$1\$/,/^%end\$/p" "$ISO" | sed '1d;$d'; }

@test "la chiave SSH di daniele viene installata" {
    run sezione post
    [[ "$output" == *"authorized_keys"* ]]
    grep -q 'ssh-ed25519 AAAA' "$ISO"
}

@test "pre-install: sposta il grub.cfg di un'altra distro fuori da EFI/" {
    R=$(mktemp -d)
    mkdir -p "$R/boot/efi/EFI/ubuntu" "$R/boot/efi/EFI/APPLE" "$R/boot/efi/EFI/BOOT"
    touch "$R/boot/efi/EFI/ubuntu/grub.cfg" "$R/boot/efi/EFI/BOOT/BOOTX64.EFI"
    sezione pre-install | sed "s#/mnt/sysimage#$R#g" > "$R/pre.sh"
    run bash "$R/pre.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$R/boot/efi/EFI/ubuntu" ]
    [ -f "$R/boot/efi/vecchi-bootloader/ubuntu/grub.cfg" ]
    [ -d "$R/boot/efi/EFI/APPLE" ]
    [ -f "$R/boot/efi/EFI/BOOT/BOOTX64.EFI" ]
    rm -rf "$R"
}

@test "pre-install: senza altre distro non tocca niente" {
    R=$(mktemp -d)
    mkdir -p "$R/boot/efi/EFI/APPLE"
    sezione pre-install | sed "s#/mnt/sysimage#$R#g" > "$R/pre.sh"
    run bash "$R/pre.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$R/boot/efi/vecchi-bootloader" ]
    rm -rf "$R"
}

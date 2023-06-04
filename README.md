Archlinux install script
===

*An opinionated, optimistic installer for the Archlinux operating system.*

**Never use scripts you found on the internet blindly!**

## 1. What it does?

The purpose of this script is to make Archlinux installation a breeze in my preferred way. It consist of two scripts, the `disks.bash` and `installer.bash`.

**This script is not designed for dual-boot!**

## 2. Scripts

### 2.1 disks.bash

The `disks.bash` script is for formatting the partitions to be used for the installation. It is expected to be run on already created, but empty partitions. It will do the following:
- Prompt for the partition to be used as EFI and root (/).
- Prompt if you would like to encrypt the root partition.
- Formats the EFI partition to FAT32.
- Formats the root partition (with LUKS if enccryption was chosen).
- Sets up btrfs subvolumes for the root partition
    - @ (/)
    - @home (/home)
    - @var (/var)
- Mounts everything under `/mnt`

        / (@)
        -> /boot/efi (EFI)
        -> /home (@home)
        -> /var (@var)

### 2.2 installer.bash

The `installer.bash` script will create the Archlinux installation. It assumes the necessary partitions are mounted under `/mnt`, and the EFI partition is mounted under `/boot/efi`. The steps are the following:
- Install the `jq` package for the live environment.
- Detect the root and EFI partitions.
- Prompt the user for install options.
    - Prompt which kernels the user would like to install (kernels from the Archlinux repositories).
    - Prompt for username and password.
    - Prompt for hostname.
    - Prompt additinal features.
        - `snapper` Set up snapper for automatic backups on system upgrades.
        - `recovery` Copies the booted Archlinux live iso into the EFI partition, and creates an entry for it in systemd-boot.
        - `iwd` For connecting to WI-FI networks from the terminal.
        - `linger` Set up user lingering.
        - `bluetooth` Set up bluetooth support and cli.
- Does all the prompted steps, and additionally it will:
    - Set up locale according to the following:
        - en_US.UTF-8 for locale.gen.
        - us-acentos for KEYMAP.
        - en_US.UTF-8 for LANG, LANGUAGE, LC_ALL.
        - Sets timezone to UTC.
    - Configures networking (systemd-resolved and systemd-networkd, ufw)
        - DNSSEC, DNSOverTLS, Cloudflare DNS.
        - DHCP for any network other than virtual ethernet.
        - ufw firewall (deny incoming, allow outgoing and routed).
    - Configures systemd-boot
    - Configures mkinitcpio with UKIs (Unified Kernel Image).
    - Enables services:
        - systemd-boot-update
        - systemd-timesyncd
        - systemd-oomd
        - systemd-resolved
        - systemd-networkd

After the script finished, the installed system represents my ideal default configuration, but it is most likely not 100% what you want. Do some adjusting by hand, for the repository, or use Ansible to do any additional steps you require.

### 3. How to use?

```bash
bash <(curl -sL https://raw.githubusercontent.com/mortyr45/archlinux-installer/master/src/disks.bash)
bash <(curl -sL https://raw.githubusercontent.com/mortyr45/archlinux-installer/master/src/installer.bash)
```

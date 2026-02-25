#!/usr/bin/sh

init() {
    # Vars
    USERNAME='me'
    HOSTNAME='hadal'

    # Colors
    NORMAL=$(tput sgr0)
    YELLOW=$(tput setaf 7)
    BLACK=$(tput setaf 0)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    BRIGHT=$(tput bold)
    UNDERLINE=$(tput smul)
}

confirm() {
    echo -en "[${GREEN}y${NORMAL}/${RED}n${NORMAL}]: "
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        exit 0
    fi
}

print_header() {
    clear
    echo -E "$BRIGHT
     ____ ___      .__           ______  __         .__
    |    |   \____ |__| _____   /  __  \/  |________|__|__  ___
    |    |   /    \|  |/     \  >      <   __\_  __ \  \  \/  /
    |    |  /   |  \  |  Y Y  \/   --   \  |  |  | \/  |>    <
    |______/|___|__/__|__|_|__/\________/__|  |__|  |__/__/\__\

                $WHITE https://github.com/Unim8trix $NORMAL
"
}

install() {
    echo -e "\n${YELLOW}Phase 1: setting up disk structure and install base system${NORMAL}\n"
    echo -en "\n${RED}The NVMEN1 Disk will now be WIPED and all data will be destroyed! Are your sure to continue?${NORMAL}\n"
    confirm

    echo -e "${YELLOW}Erase existing luks partition NVME0n1p3${NORMAL}\n"
    cryptsetup erase /dev/nvme0n1p3
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Wipe and delete old partition layout${NORMAL}\n"
    wipefs -af /dev/nvme0n1
    sgdisk --zap-all --clear /dev/nvme0n1
    partprobe /dev/nvme0n1
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.2

    echo -e "${YELLOW}Create new disk layout${NORMAL}\n"
    sgdisk -n 0:0:+1024MiB -t 0:ef00 -c 0:esp /dev/nvme0n1
    sgdisk -n 0:0:+65536MiB -t 0:8200 -c 0:swap /dev/nvme0n1
    sgdisk -n 0:0:0 -t 0:8309 -c 0:luks /dev/nvme0n1
    partprobe /dev/nvme0n1
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.2

    echo -e "${YELLOW}Format EFI partition${NORMAL}\n"
    mkfs.vfat -F 32 -n ESP /dev/nvme0n1p1
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.2

    echo -e "${YELLOW}Create crypted partition for root${NORMAL}\n"
    cryptsetup luksFormat /dev/nvme0n1p3
    echo -e "${YELLOW}Open luks partion, type in your new password${NORMAL}\n"
    cryptsetup open /dev/nvme0n1p3 cryptsys
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Create BTRFS filesystem and subvolumes${NORMAL}\n"
    mkfs.btrfs -L ARCH -f /dev/mapper/cryptsys
    mount /dev/mapper/cryptsys /mnt
    btrfs sub create /mnt/@
    btrfs sub create /mnt/@home
    btrfs sub create /mnt/@cache
    btrfs sub create /mnt/@log
    btrfs sub create /mnt/@tmp
    btrfs sub create /mnt/@pkg
    sleep 1
    umount /mnt
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Remount root volume with btrfs subvolume options${NORMAL}\n"
    mount -o noatime,space_cache=v2,discard=async,compress=zstd:1,subvol=@ /dev/mapper/cryptsys /mnt
    mount --mkdir -o noatime,space_cache=v2,discard=async,compress=zstd:1,subvol=@home /dev/mapper/cryptsys /mnt/home
    mount --mkdir -o noatime,space_cache=v2,discard=async,compress=zstd:1,subvol=@log /dev/mapper/cryptsys /mnt/var/log
    mount --mkdir -o noatime,space_cache=v2,discard=async,compress=zstd:1,subvol=@tmp /dev/mapper/cryptsys /mnt/var/tmp
    mount --mkdir -o noatime,space_cache=v2,discard=async,compress=zstd:1,subvol=@cache /dev/mapper/cryptsys /mnt/var/cache
    mkdir -p /mnt/var/cache/pacman/pkg
    mount -o noatime,space_cache=v2,discard=async,compress=zstd:1,subvol=@pkg /dev/mapper/cryptsys /mnt/var/cache/pacman/pkg
    mount --mkdir /dev/nvme0n1p1 /mnt/boot

    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 5
    clear

    echo -e "${YELLOW}Install minimal base system with pacstrap${NORMAL}\n"
    sleep 2
    pacstrap /mnt base base-devel linux-zen linux-firmware btrfs-progs amd-ucode networkmanager zsh git-lfs curl wget man-db mlocate reflector nano-syntax-highlighting
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 2

    echo -e "${YELLOW}Generate filesystem table${NORMAL}\n"
    genfstab -p -L /mnt >> /mnt/etc/fstab
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Copy zsh profiles to /mnt/root${NORMAL}\n"
    cp /etc/zsh/zprofile /mnt/root/.zprofile
    cp /etc/zsh/zshrc /mnt/root/.zshrc
    cp /root/HyprElite/chroot.sh /mnt/root && chmod +x /mnt/root/chroot.sh
    echo -e "${YELLOW}Set you new root password${NORMAL}\n"
    arch-chroot /mnt /bin/passwd root
    sleep 0.5
    arch-chroot /mnt /bin/chsh -s /bin/zsh
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Chroot into new system and create initial settings${NORMAL}\n"
    sleep 3
    arch-chroot /mnt /bin/zsh -c "/root/chroot.sh"
    echo -e "${GREEN}Done${NORMAL}\n"
    echo -e "${GREEN}Back in normal environment${NORMAL}\n"
    sleep 3

    echo -e "${YELLOW}Copy dotfiles${NORMAL}\n"
    cp -R /root/HyprElite/config/* /mnt/home/${USERNAME}/.config/
    arch-chroot /mnt sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.config
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Copy fonts${NORMAL}\n"
    cp -R /root/HyprElite/fonts/* /mnt/home/${USERNAME}/.local/share/fonts/
    arch-chroot /mnt sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.local/share/fonts
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Copy wallpapers${NORMAL}\n"
    cp -R /root/HyprElite/wallpaper/* /mnt/home/${USERNAME}/Bilder/Wallpaper/
    arch-chroot /mnt sudo chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/Bilder
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 0.5

    echo -e "${YELLOW}Unmounting filesystems${NORMAL}\n"
    rm /mnt/root/chroot.sh
    rm -rf /mnt/home/${USERNAME}/yay
    umount -R /mnt
    echo -e "${GREEN}Finished${NORMAL}\n"
    echo -e "${YELLOW}System can now be rebooted${NORMAL}\n"
}

main() {
    init
    print_header

    install
}

main && exit 0

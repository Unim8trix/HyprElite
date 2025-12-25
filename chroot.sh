#!/usr/bin/sh

init() {
    # Vars
    USERNAME='me'
    HOSTNAME='hadal'

    # Colors
    NORMAL=$(tput sgr0)
    WHITE=$(tput setaf 7)
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
    echo -E "$BLUE
     ____ ___      .__           ______  __         .__
    |    |   \____ |__| _____   /  __  \/  |________|__|__  ___
    |    |   /    \|  |/     \  >      <   __\_  __ \  \  \/  /
    |    |  /   |  \  |  Y Y  \/   --   \  |  |  | \/  |>    <
    |______/|___|__/__|__|_|__/\________/__|  |__|  |__/__/\__\

                $WHITE https://github.com/Unim8trix $NORMAL
"
}

install() {
    clear
    echo -e "${YELLOW}Phase 2: Configure system and install software${NORMAL}\n"
    echo -e "${YELLOW}Ready?${NORMAL}\n"
    confirm
    cd

    echo -e "${YELLOW}Set hostname${NORMAL}\n"
    echo "${HOSTNAME}" > /etc/hostname

    echo -e "${YELLOW}Set locales${NORMAL}\n"
    echo "LANG=de_DE.UTF-8" > /etc/locale.conf
    echo "LANGUAGE=de_DE" >> /etc/locale.conf

    echo -e "${YELLOW}Set keymap and font in vcsonole${NORMAL}\n"
    echo "KEYMAP=de-latin1-nodeadkeys" > /etc/vconsole.conf
    echo "FONT=sun12x22" >> /etc/vconsole.conf

    echo -e "${YELLOW}Set symlink to timezone${NORMAL}\n"
    ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

    echo -e "${YELLOW}Set localhost informations in hosts${NORMAL}\n"
    echo "127.0.0.1 localhost" >> /etc/hosts
    echo "127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

    echo -e "${YELLOW}Set UTF-8 locales${NORMAL}\n"
    echo "de_DE.UTF-8 UTF-8" >> /etc/locale.gen
    echo "de_DE ISO-8859-1" >> /etc/locale.gen
    echo "de_DE@euro ISO-8859-15" >> /etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Disable powersaving for WLAN card${NORMAL}\n"
    echo "[connection]" > /etc/NetworkManager/conf.d/wifi-powersave-off.conf
    echo "wifi.powersave=2" >> /etc/NetworkManager/conf.d/wifi-powersave-off.conf
    echo "options iwlwifi power_save=0" > /etc/modprobe.d/iwlwifi.conf
    echo "options iwlwifi uapsd_disable=0" >> /etc/modprobe.d/iwlwifi.conf
    echo "options iwlmvm power_scheme=1" >> /etc/modprobe.d/iwlwifi.conf
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Creating new local user${NORMAL}\n"
    useradd -m -G users,wheel,lp,power,audio -s /bin/zsh ${USERNAME}
    echo "%wheel ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
    echo -e "${YELLOW}Set password for your new user${NORMAL}\n"
    passwd ${USERNAME}
    echo "export EDITOR='nano'" > /home/${USERNAME}/.zshrc
    echo "autoload -Uz compinit promptinit" >> /home/${USERNAME}/.zshrc
    echo "compinit" >> /home/${USERNAME}/.zshrc
    echo "promptinit" >> /home/${USERNAME}/.zshrc
    echo "prompt suse" >> /home/${USERNAME}/.zshrc
    echo "alias ll='ls -lah'" >> /home/${USERNAME}/.zshrc
    echo "alias cls='clear'" >> /home/${USERNAME}/.zshrc
    chown ${USERNAME}:users /home/${USERNAME}/.zshrc
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Update pacman mirrorlist${NORMAL}\n"
    reflector --country Germany --latest 5 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Install systemd bootloader${NORMAL}\n"
    bootctl --path=/boot install
    sleep 1
    echo -e "${YELLOW}Configure bootloader entries${NORMAL}\n"
    sleep 0.5
    echo "default arch.conf" > /boot/loader/loader.conf
    echo "timeout 2" >> /boot/loader/loader.conf
    echo "editor 0" >> /boot/loader/loader.conf
    echo "title Arch Linux" > /boot/loader/entries/arch.conf
    echo "linux /vmlinuz-linux-zen" >> /boot/loader/entries/arch.conf
    echo "initrd /initramfs-linux-zen.img" >> /boot/loader/entries/arch.conf
    echo "options rd.luks.name=$(blkid -s UUID -o value /dev/nvme0n1p3)=cryptsys rd.luks.options=password-echo=no root=/dev/mapper/cryptsys rootflags=subvol=@ ipv6.disable=1 rw" >> /boot/loader/entries/arch.conf
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1


    echo -e "${YELLOW}Add crypted swap partition${NORMAL}\n"
    sleep 1
    echo "cryptswap  /dev/nvme0n1p2  /dev/urandom  swap,cipher=aes-xts-plain64,size=256" >> /etc/crypttab
    echo "/dev/mapper/cryptswap  none  swap  defaults  0 0" >> /etc/fstab
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Enable NetworkManager and timesync services${NORMAL}\n"
    systemctl enable NetworkManager
    systemctl enable systemd-timesyncd
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Install YAY package manager from AUR${NORMAL}\n"
    sed -i 's/debug/!debug/' /etc/makepkg.conf
    su ${USERNAME} -c "git clone https://aur.archlinux.org/yay.git /home/${USERNAME}/yay"
    su ${USERNAME} -c "makepkg -D /home/${USERNAME}/yay -is --noconfirm"
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Install Window manager and tools${NORMAL}\n"
    sleep 2
    su ${USERNAME} -c "yay --noconfirm -Sy vulkan-radeon mesa hyprland ghostty waybar firefox-developer-edition-i18n-de \
      swww wofi dunst xdg-desktop-portal-hyprland plymouth plymouth-theme-arch-charge \
      tumbler nordic-theme nordzy-cursors papirus-icon-theme papirus-folders-nordic \
      brightnessctl mc thunar polkit-gnome pamixer pavucontrol \
      bluez-utils blueman network-manager-applet gvfs modemmanager usb_modeswitch \
      thunar-archive-plugin file-roller btop pacman-contrib power-profiles-daemon \
      noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-dejavu cantarell-fonts \
      nwg-look xfce4-settings sof-firmware alsa-firmware fzf jq yq \
      pipewire-alsa pipewire-pulse pipewire-jack xdg-user-dirs starship fastfetch \
      grim slurp otf-font-awesome wl-clipboard xsensors swappy"
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 5

    echo -e "${YELLOW}Setup autologin${NORMAL}\n"
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    echo "[Service]" > /etc/systemd/system/getty@tty1.service.d/override.conf
    echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/override.conf
    echo "ExecStart=-/usr/bin/agetty --autologin ${USERNAME} --noclear %I $TERM" >> /etc/systemd/system/getty@tty1.service.d/override.conf
    sudo systemctl daemon-reload
    sudo systemctl enable getty@tty1
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Enable Plymouth Arch-Charge theme${NORMAL}\n"
    plymouth-set-default-theme -R arch-charge
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Configure ramdisk for plymouth${NORMAL}\n"
    sed -i 's/MODULES=()/MODULES=(amdgpu)/' /etc/mkinitcpio.conf
    sed -i 's/HOOKS=.*/HOOKS=(systemd plymouth keyboard autodetect microcode modconf kms block sd-vconsole sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
    mkinitcpio -P
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Modify systemd boot entry for plymouth${NORMAL}\n"
    sudo sed -i '/^options/ s/$/ quiet splash loglevel=3 rd.udev.log_priority=3 vt.global_cursor_default=0/' /boot/loader/entries/arch.conf
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1

    echo -e "${YELLOW}Create user directories${NORMAL}\n"
    su ${USERNAME} -c "mkdir -p /home/${USERNAME}/{.cache/nano/backups,.local/share/fonts,Bilder/Wallpapers,Bilder/Screenshots}"
    echo -e "${GREEN}Done${NORMAL}\n"
    sleep 1
}


main() {
    init
    print_header

    install
}

main && exit 0

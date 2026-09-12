#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/utils.sh"
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$SCRIPT_DIR/../core/detect_distro.sh"
[[ -z "${GPU_VENDOR:-}" ]]    && source "$SCRIPT_DIR/../core/detect_gpu.sh"

log_step "Activation du support 32-bit (Steam/Wine)"
case "$DISTRO_FAMILY" in
    arch)
        if grep -qE '^\[multilib\]' /etc/pacman.conf; then
            log_info "Dépôt multilib déjà activé"
        else
            sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
            sudo pacman -Sy
            log_success "Dépôt multilib activé"
        fi
        ;;
    debian)
        if dpkg --print-foreign-architectures | grep -q '^i386$'; then
            log_info "Architecture i386 déjà activée"
        else
            sudo dpkg --add-architecture i386
            sudo apt-get update
            log_success "Architecture i386 activée"
        fi
        ;;
    rhel|suse)
        log_info "Non nécessaire sur cette famille (paquets 32-bit déjà disponibles nativement)"
        ;;
esac

log_step "Installation des pilotes GPU ($GPU_VENDOR sur $DISTRO_FAMILY)"
IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
case "$DISTRO_FAMILY:$GPU_VENDOR" in
    arch:amd)
        "${_install_cmd[@]}" vulkan-radeon lib32-vulkan-radeon
        ;;
    arch:nvidia)
        "${_install_cmd[@]}" nvidia-open lib32-nvidia-utils
        ;;
    arch:intel)
        "${_install_cmd[@]}" vulkan-intel lib32-vulkan-intel
        ;;
    debian:amd|debian:intel)
        "${_install_cmd[@]}" mesa-vulkan-drivers
        ;;
    debian:nvidia)
        "${_install_cmd[@]}" nvidia-driver firmware-misc-nonfree 2>/dev/null \
            || log_warn "Pilote NVIDIA : échec — active d'abord contrib/non-free (profil Workstation) ou installe-le manuellement"
        ;;
    rhel:amd|rhel:intel)
        "${_install_cmd[@]}" mesa-vulkan-drivers
        ;;
    rhel:nvidia)
        if rpm -q rpmfusion-nonfree-release &>/dev/null; then
            sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda \
                && log_success "Pilote NVIDIA (akmod) installé" \
                || log_warn "Échec installation akmod-nvidia"
        else
            log_warn "RPM Fusion nonfree absent — lance d'abord le profil Workstation, ou installe le pilote NVIDIA manuellement"
        fi
        ;;
    suse:amd|suse:intel)
        "${_install_cmd[@]}" Mesa-vulkan-drivers
        ;;
    suse:nvidia)
        log_warn "Pilote NVIDIA non automatisé sur openSUSE — voir https://en.opensuse.org/SDB:NVIDIA_drivers"
        ;;
    *)
        log_warn "Pilotes GPU non automatisés pour $DISTRO_FAMILY/$GPU_VENDOR — voir la doc officielle de la distribution"
        ;;
esac
log_success "Pilotes GPU configurés"

log_step "Installation de Steam, Lutris, Heroic"
if [[ "$DISTRO_FAMILY" == "arch" ]]; then
    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    "${_install_cmd[@]}" steam lutris
    if [[ -n "$AUR_HELPER" ]]; then
        cmd_exists heroic || "$AUR_HELPER" -S --noconfirm heroic-games-launcher-bin \
            && log_success "Heroic installé" \
            || log_warn "Échec installation Heroic via $AUR_HELPER"
    else
        log_warn "Aucun AUR helper — Heroic ignoré (installe yay/paru, ou utilise le Flatpak com.heroicgameslauncher.hgl)"
    fi
else
    if cmd_exists flatpak; then
        for app in com.valvesoftware.Steam:Steam net.lutris.Lutris:Lutris com.heroicgameslauncher.hgl:Heroic; do
            id="${app%%:*}"; label="${app##*:}"
            if flatpak list --app | grep -q "$id"; then
                log_info "$label déjà installé"
            else
                flatpak install -y flathub "$id" \
                    && log_success "$label installé" \
                    || log_warn "Échec installation $label"
            fi
        done
    else
        log_warn "Flatpak absent — lance d'abord packages/install_packages.sh"
    fi
fi

log_step "Installation de la stack Wine"
case "$DISTRO_FAMILY" in
    arch)
        IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
        "${_install_cmd[@]}" wine-staging wine-gecko wine-mono winetricks
        if [[ -n "$AUR_HELPER" ]]; then
            cmd_exists protontricks || "$AUR_HELPER" -S --noconfirm protontricks \
                && log_success "protontricks installé" \
                || log_warn "Échec installation protontricks via $AUR_HELPER"
        fi
        ;;
    debian)
        if cmd_exists wine; then
            log_info "Wine déjà présent"
        else
            _wine_key="/etc/apt/keyrings/winehq-archive.key"
            _codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
            if sudo mkdir -p /etc/apt/keyrings \
                && curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | sudo tee "$_wine_key" > /dev/null \
                && curl -fsSL "https://dl.winehq.org/wine-builds/debian/dists/${_codename}/winehq-${_codename}.sources" \
                    | sudo tee /etc/apt/sources.list.d/winehq.sources > /dev/null \
                && sudo apt-get update \
                && sudo apt-get install -y --install-recommends winehq-staging
            then
                log_success "Wine (WineHQ) installé"
            else
                log_warn "Wine : échec de l'installation via le dépôt WineHQ"
            fi
        fi
        IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
        "${_install_cmd[@]}" winetricks
        cmd_exists protontricks || (pipx install protontricks && log_success "protontricks installé via pipx") \
            || log_warn "protontricks : échec de l'installation via pipx"
        ;;
    rhel)
        IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
        "${_install_cmd[@]}" wine winetricks
        cmd_exists protontricks || (pipx install protontricks && log_success "protontricks installé via pipx") \
            || log_warn "protontricks : échec de l'installation via pipx"
        ;;
    suse)
        IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
        "${_install_cmd[@]}" wine winetricks 2>/dev/null \
            || log_warn "wine/winetricks non disponibles — active d'abord Packman (profil Workstation)"
        cmd_exists protontricks || (pipx install protontricks && log_success "protontricks installé via pipx") \
            || log_warn "protontricks : échec de l'installation via pipx"
        ;;
esac

log_step "Installation de GameMode et MangoHud"
IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
case "$DISTRO_FAMILY" in
    arch)
        "${_install_cmd[@]}" gamemode lib32-gamemode mangohud lib32-mangohud
        ;;
    debian|rhel|suse)
        "${_install_cmd[@]}" gamemode mangohud 2>/dev/null \
            || log_warn "gamemode/mangohud non disponibles nativement sur cette version de $DISTRO_FAMILY"
        ;;
esac
log_success "GameMode et MangoHud configurés"

log_step "Installation du gestionnaire de versions Proton"
if [[ "$DISTRO_FAMILY" == "arch" && -n "$AUR_HELPER" ]]; then
    cmd_exists protonplus || "$AUR_HELPER" -S --noconfirm protonplus \
        && log_success "ProtonPlus installé" \
        || log_warn "Échec installation protonplus via $AUR_HELPER"
else
    if cmd_exists flatpak; then
        if flatpak list --app | grep -q net.davidotek.pupgui2; then
            log_info "ProtonUp-Qt déjà installé"
        else
            flatpak install -y flathub net.davidotek.pupgui2 \
                && log_success "ProtonUp-Qt installé" \
                || log_warn "Échec installation ProtonUp-Qt"
        fi
    else
        log_warn "Flatpak absent — gestionnaire Proton ignoré"
    fi
fi

log_success "Profil Gaming configuré"

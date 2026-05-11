#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

if [[ ! -f /etc/os-release ]]; then
    log_error "/etc/os-release introuvable — distribution non reconnue"
    exit 1
fi

# shellcheck source=/dev/null
source /etc/os-release
DISTRO_ID="${ID:-unknown}"
DISTRO_ID_LIKE="${ID_LIKE:-}"

_detect_family() {
    case "$1" in
        arch|endeavouros|manjaro|garuda|cachyos)   echo "arch"   ;;
        debian|ubuntu|pop|linuxmint|elementary|kali|zorin) echo "debian" ;;
        fedora)                                     echo "rhel"   ;;
        opensuse*|sles|sled)                        echo "suse"   ;;
        *)                                          echo ""       ;;
    esac
}

DISTRO_FAMILY=$(_detect_family "$DISTRO_ID")

if [[ -z "$DISTRO_FAMILY" && -n "$DISTRO_ID_LIKE" ]]; then
    for _like in $DISTRO_ID_LIKE; do
        DISTRO_FAMILY=$(_detect_family "$_like")
        [[ -n "$DISTRO_FAMILY" ]] && break
    done
fi

if [[ -z "$DISTRO_FAMILY" ]]; then
    log_error "Distribution non reconnue : $DISTRO_ID"
    exit 1
fi

AUR_HELPER=""
PKG_MANAGER=""
PKG_INSTALL=""
PKG_UPDATE=""

case "$DISTRO_FAMILY" in
    arch)
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm --needed"
        PKG_UPDATE="sudo pacman -Syu --noconfirm"
        if cmd_exists yay; then   AUR_HELPER="yay"
        elif cmd_exists paru; then AUR_HELPER="paru"
        fi
        ;;
    debian)
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt install -y"
        PKG_UPDATE="sudo apt update && sudo apt upgrade -y"
        ;;
    rhel)
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y"
        PKG_UPDATE="sudo dnf upgrade -y"
        ;;
    suse)
        PKG_MANAGER="zypper"
        PKG_INSTALL="sudo zypper install -y"
        PKG_UPDATE="sudo zypper update -y"
        ;;
esac

export DISTRO_ID DISTRO_FAMILY PKG_MANAGER PKG_INSTALL PKG_UPDATE AUR_HELPER

log_info "Distribution : $DISTRO_ID (famille : $DISTRO_FAMILY, manager : $PKG_MANAGER)"

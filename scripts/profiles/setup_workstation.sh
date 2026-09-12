#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/../core/utils.sh"
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$SCRIPT_DIR/../core/detect_distro.sh"

if [[ "$DISTRO_ID" != "fedora" ]]; then
    log_warn "Ce script est spécifique à Fedora — distribution détectée : $DISTRO_ID"
    log_info "Rien à faire, sortie."
    exit 0
fi

log_step "Activation de RPM Fusion (free + nonfree)"
FEDORA_VERSION="$(rpm -E %fedora)"
if ! rpm -q rpmfusion-free-release &>/dev/null; then
    sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"
    log_success "RPM Fusion free activé"
else
    log_info "RPM Fusion free déjà activé"
fi
if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
    sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
    log_success "RPM Fusion nonfree activé"
else
    log_info "RPM Fusion nonfree déjà activé"
fi

log_step "Installation de Docker (moby-engine)"
if ! cmd_exists docker; then
    sudo dnf install -y moby-engine docker-compose
    log_success "Docker (moby-engine) installé"
else
    log_info "Docker déjà présent"
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
log_success "Docker activé — re-login requis pour l'utiliser sans sudo"

log_step "Installation de kubectl"
if ! cmd_exists kubectl; then
    sudo dnf install -y kubernetes-client
    log_success "kubectl installé"
else
    log_info "kubectl déjà présent"
fi

log_step "Installation de yazi (remplace ranger)"
if ! cmd_exists yazi; then
    sudo dnf copr enable -y lihaohong/yazi
    sudo dnf install -y yazi
    log_success "yazi installé"
else
    log_info "yazi déjà présent"
fi
if cmd_exists ranger; then
    sudo dnf remove -y ranger
    log_info "ranger désinstallé (remplacé par yazi)"
fi

log_step "Installation de lynis + rkhunter"
sudo dnf install -y lynis rkhunter
sudo rkhunter --propupd
log_success "lynis + rkhunter installés, base de référence rkhunter créée"

log_step "OnlyOffice par défaut pour les formats bureautiques"
ONLYOFFICE_DESKTOP="org.onlyoffice.desktopeditors.desktop"
if flatpak list --app 2>/dev/null | grep -q org.onlyoffice.desktopeditors; then
    for mime in \
        application/vnd.openxmlformats-officedocument.wordprocessingml.document \
        application/vnd.openxmlformats-officedocument.spreadsheetml.sheet \
        application/vnd.openxmlformats-officedocument.presentationml.presentation \
        application/vnd.oasis.opendocument.text \
        application/vnd.oasis.opendocument.spreadsheet \
        application/vnd.oasis.opendocument.presentation
    do
        xdg-mime default "$ONLYOFFICE_DESKTOP" "$mime"
    done
    log_success "OnlyOffice défini par défaut (docx/xlsx/pptx/odt/ods/odp)"
else
    log_warn "OnlyOffice (Flatpak) non installé — lance d'abord install_packages.sh"
fi

if rpm -qa | grep -q '^libreoffice'; then
    sudo dnf remove -y 'libreoffice*'
    log_success "LibreOffice désinstallé"
else
    log_info "LibreOffice non présent"
fi

log_step "Disposition clavier : Verr Maj → chiffres (AZERTY)"
if cmd_exists gsettings; then
    gsettings set org.gnome.desktop.input-sources xkb-options "['caps:digits_row']"
    log_success "Option XKB caps:digits_row appliquée"
else
    log_warn "gsettings absent — option XKB non appliquée (nécessite GNOME)"
fi

log_step "Snapshots Btrfs automatiques (snapper + dnf5)"
if [[ "$(findmnt -no FSTYPE / 2>/dev/null)" != "btrfs" ]]; then
    log_warn "La racine (/) n'est pas en Btrfs — snapshots snapper ignorés"
else
    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    "${_install_cmd[@]}" snapper libdnf5-plugin-actions

    if ! sudo snapper list-configs 2>/dev/null | grep -q '^root '; then
        sudo snapper --config root create-config /
        log_success "Config snapper 'root' créée"
    else
        log_info "Config snapper 'root' déjà présente"
    fi

    sudo sed -i \
        -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="2"/' \
        -e 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="2"/' \
        -e 's/^NUMBER_MIN_AGE=.*/NUMBER_MIN_AGE="1800"/' \
        /etc/snapper/configs/root

    sudo install -m 755 "$REPO_ROOT/snapper/dnf5/snapper-dnf5-pre"  /usr/local/bin/snapper-dnf5-pre
    sudo install -m 755 "$REPO_ROOT/snapper/dnf5/snapper-dnf5-post" /usr/local/bin/snapper-dnf5-post

    sudo mkdir -p /etc/dnf/libdnf5-plugins/actions.d
    sudo install -m 644 "$REPO_ROOT/snapper/dnf5/snapper.actions" /etc/dnf/libdnf5-plugins/actions.d/snapper.actions

    sudo systemctl enable --now snapper-cleanup.timer
    log_success "Snapshots Btrfs automatiques configurés (snapper + libdnf5-plugin-actions)"
fi

log_step "Correctif barre de titre Spotify (GNOME/Wayland)"
if flatpak list --app 2>/dev/null | grep -q com.spotify.Client; then
    flatpak override --user --nosocket=wayland --socket=x11 com.spotify.Client
    log_success "Spotify forcé en XWayland (corrige la barre de titre GNOME)"
else
    log_warn "Spotify (Flatpak) non installé — correctif ignoré"
fi

log_success "Extras Fedora configurés"

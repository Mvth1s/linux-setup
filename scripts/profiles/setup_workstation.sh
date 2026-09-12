#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/../core/utils.sh"
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$SCRIPT_DIR/../core/detect_distro.sh"

log_step "Activation des dépôts de paquets non-libres / codecs"
case "$DISTRO_FAMILY" in
    rhel)
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
        ;;
    debian)
        _sources_file="/etc/apt/sources.list"
        [[ -f /etc/apt/sources.list.d/debian.sources ]] && _sources_file="/etc/apt/sources.list.d/debian.sources"
        if grep -qE "non-free-firmware|non-free\b" "$_sources_file" 2>/dev/null; then
            log_info "Composants contrib/non-free déjà activés"
        else
            log_warn "Composants contrib/non-free/non-free-firmware non détectés dans $_sources_file"
            log_warn "Active-les manuellement si besoin (codecs, pilotes propriétaires) : https://wiki.debian.org/SourcesList"
        fi
        ;;
    suse)
        if sudo zypper lr 2>/dev/null | grep -qi packman; then
            log_info "Dépôt Packman déjà activé"
        else
            _suse_id="$(. /etc/os-release && echo "$ID")"
            if [[ "$_suse_id" == *tumbleweed* ]]; then
                _packman_url="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/"
            else
                _suse_version="$(. /etc/os-release && echo "$VERSION_ID")"
                _packman_url="https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_${_suse_version}/"
            fi
            if sudo zypper ar -cfp 90 "$_packman_url" packman \
                && sudo zypper --gpg-auto-import-keys refresh
            then
                log_success "Dépôt Packman activé"
            else
                log_warn "Échec activation du dépôt Packman — voir https://packman.links2linux.org/"
            fi
        fi
        ;;
    arch)
        log_info "AUR couvre déjà les paquets non-libres — rien à faire"
        ;;
esac

log_step "Installation de Docker"
if ! cmd_exists docker; then
    case "$DISTRO_FAMILY" in
        arch)
            IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
            "${_install_cmd[@]}" docker docker-compose
            ;;
        debian)
            if curl -fsSL https://get.docker.com | sudo sh; then
                sudo apt install -y docker-compose-plugin
            else
                log_warn "Docker : échec de l'installation via get.docker.com"
            fi
            ;;
        rhel)
            sudo dnf install -y moby-engine docker-compose
            ;;
        suse)
            sudo zypper install -y docker docker-compose
            ;;
    esac
fi
if cmd_exists docker; then
    log_success "Docker installé"
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    log_success "Docker activé — re-login requis pour l'utiliser sans sudo"
else
    log_warn "Docker : installation incomplète"
fi

log_step "Installation de kubectl"
if cmd_exists kubectl; then
    log_info "kubectl déjà présent"
else
    case "$DISTRO_FAMILY" in
        rhel) sudo dnf install -y kubernetes-client ;;
        suse) sudo zypper install -y kubernetes-client ;;
        arch)
            IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
            if ! "${_install_cmd[@]}" kubectl 2>/dev/null && [[ -n "$AUR_HELPER" ]]; then
                "$AUR_HELPER" -S --noconfirm kubectl-bin \
                    || log_warn "kubectl : échec de l'installation (officiel et AUR)"
            fi
            ;;
        debian)
            # Dépôt officiel Kubernetes — bump la version mineure (v1.31) périodiquement.
            if sudo mkdir -p -m 755 /etc/apt/keyrings \
                && curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
                    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
                && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" \
                    | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null \
                && sudo apt-get update \
                && sudo apt-get install -y kubectl
            then
                : # succès, log_success générique ci-dessous
            else
                log_warn "kubectl : échec de l'installation via le dépôt officiel Kubernetes"
            fi
            ;;
    esac
    cmd_exists kubectl && log_success "kubectl installé" || log_warn "kubectl : installation incomplète"
fi

log_step "Installation de yazi (remplace ranger)"
if cmd_exists yazi; then
    log_info "yazi déjà présent"
else
    case "$DISTRO_FAMILY" in
        rhel)
            sudo dnf copr enable -y lihaohong/yazi
            sudo dnf install -y yazi
            ;;
        arch)
            IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
            "${_install_cmd[@]}" yazi
            ;;
        debian|suse)
            _yazi_url="$(curl -fsS https://api.github.com/repos/sxyazi/yazi/releases/latest 2>/dev/null \
                | grep 'browser_download_url.*yazi-x86_64-unknown-linux-musl.zip' \
                | cut -d'"' -f4 || true)"
            if [[ -n "$_yazi_url" ]]; then
                _tmp_dir="$(mktemp -d)"
                if curl -fLo "$_tmp_dir/yazi.zip" "$_yazi_url" \
                    && unzip -q "$_tmp_dir/yazi.zip" -d "$_tmp_dir" \
                    && sudo install -m 755 "$_tmp_dir"/yazi-*/yazi /usr/local/bin/yazi \
                    && sudo install -m 755 "$_tmp_dir"/yazi-*/ya /usr/local/bin/ya
                then
                    : # succès, log_success générique ci-dessous
                else
                    log_warn "yazi : échec de l'extraction du binaire"
                fi
                rm -rf "$_tmp_dir"
            else
                log_warn "yazi : impossible de récupérer l'URL de la dernière release GitHub"
            fi
            ;;
    esac
    cmd_exists yazi && log_success "yazi installé" || log_warn "yazi : installation incomplète, ranger conservé"
fi
if cmd_exists ranger && cmd_exists yazi; then
    case "$DISTRO_FAMILY" in
        arch)   sudo pacman -Rns --noconfirm ranger ;;
        debian) sudo apt remove -y ranger ;;
        rhel)   sudo dnf remove -y ranger ;;
        suse)   sudo zypper remove -y ranger ;;
    esac
    log_info "ranger désinstallé (remplacé par yazi)"
fi

log_step "Installation de lynis + rkhunter"
IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
"${_install_cmd[@]}" lynis rkhunter
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
    log_warn "OnlyOffice (Flatpak) non installé — lance d'abord packages/install_packages.sh"
fi

if cmd_exists libreoffice || cmd_exists soffice; then
    case "$DISTRO_FAMILY" in
        arch)   sudo pacman -Rns --noconfirm libreoffice-fresh libreoffice-still 2>/dev/null || true ;;
        debian) sudo apt remove -y 'libreoffice*' ;;
        rhel)   sudo dnf remove -y 'libreoffice*' ;;
        suse)   sudo zypper remove -y 'libreoffice*' ;;
    esac
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

log_step "Snapshots Btrfs automatiques"
if [[ "$(findmnt -no FSTYPE / 2>/dev/null)" != "btrfs" ]]; then
    log_warn "La racine (/) n'est pas en Btrfs — snapshots snapper ignorés"
else
    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    case "$DISTRO_FAMILY" in
        rhel)  "${_install_cmd[@]}" snapper libdnf5-plugin-actions ;;
        arch)  "${_install_cmd[@]}" snapper snap-pac ;;
        debian) "${_install_cmd[@]}" snapper ;;
        suse)
            "${_install_cmd[@]}" snapper
            "${_install_cmd[@]}" snapper-zypp-plugin 2>/dev/null \
                || log_info "snapper-zypp-plugin non trouvé séparément — probablement déjà inclus avec snapper sur cette version d'openSUSE"
            ;;
    esac

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

    case "$DISTRO_FAMILY" in
        rhel)
            sudo install -m 755 "$REPO_ROOT/snapper/dnf5/snapper-dnf5-pre"  /usr/local/bin/snapper-dnf5-pre
            sudo install -m 755 "$REPO_ROOT/snapper/dnf5/snapper-dnf5-post" /usr/local/bin/snapper-dnf5-post
            sudo mkdir -p /etc/dnf/libdnf5-plugins/actions.d
            sudo install -m 644 "$REPO_ROOT/snapper/dnf5/snapper.actions" /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
            log_success "Snapshots automatiques configurés (snapper + libdnf5-plugin-actions)"
            ;;
        arch)
            log_success "Snapshots automatiques configurés (snapper + snap-pac, hooks pacman natifs)"
            ;;
        debian)
            sudo install -m 755 "$REPO_ROOT/snapper/apt/snapper-apt-pre"  /usr/local/bin/snapper-apt-pre
            sudo install -m 755 "$REPO_ROOT/snapper/apt/snapper-apt-post" /usr/local/bin/snapper-apt-post
            sudo install -m 644 "$REPO_ROOT/snapper/apt/80snapper" /etc/apt/apt.conf.d/80snapper
            log_success "Snapshots automatiques configurés (snapper + hooks apt)"
            ;;
        suse)
            log_success "Snapshots automatiques configurés (snapper — plugin zypp natif sur openSUSE)"
            ;;
    esac

    sudo systemctl enable --now snapper-cleanup.timer
fi

log_step "Correctif barre de titre Spotify (GNOME/Wayland)"
if flatpak list --app 2>/dev/null | grep -q com.spotify.Client; then
    flatpak override --user --nosocket=wayland --socket=x11 com.spotify.Client
    log_success "Spotify forcé en XWayland (corrige la barre de titre GNOME)"
else
    log_warn "Spotify (Flatpak) non installé — correctif ignoré"
fi

log_success "Extras Workstation configurés"

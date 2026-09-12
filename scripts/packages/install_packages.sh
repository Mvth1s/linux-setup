#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/utils.sh"
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$SCRIPT_DIR/../core/detect_distro.sh"

log_step "Mise à jour du système"
if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt-get update 2>&1 | grep -v "^W:" | grep -v "^N:" || true
    sudo apt-get upgrade -y
else
    eval "$PKG_UPDATE"
fi
log_success "Système à jour"

log_step "Installation des paquets communs"
PACKAGES=(
    zsh curl wget git htop btop tree unzip zip
    ripgrep fzf eza bat tmux neofetch
    xclip wl-clipboard jq neovim ranger rsync
    net-tools nmap pipx imagemagick
)

case "$DISTRO_FAMILY" in
    debian) PACKAGES+=(openssh-client) ;;
    arch)   PACKAGES+=(openssh) ;;
    rhel)   PACKAGES+=(openssh-clients) ;;
    suse)   PACKAGES+=(openssh-clients) ;;
esac

IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
"${_install_cmd[@]}" "${PACKAGES[@]}"
log_success "Paquets communs installés"

# Symlink batcat → bat sur Debian/Ubuntu
if [[ "$DISTRO_FAMILY" == "debian" ]] && cmd_exists batcat && ! cmd_exists bat; then
    log_info "Création du symlink bat → batcat"
    sudo ln -sf "$(which batcat)" /usr/local/bin/bat
    log_success "Symlink /usr/local/bin/bat créé"
fi

# ── Fastfetch ──────────────────────────────────────────────
install_fastfetch() {
    if cmd_exists fastfetch; then
        log_info "fastfetch déjà présent"
        return
    fi

    log_step "Installation de Fastfetch"

    local arch
    case "$(uname -m)" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="aarch64" ;;
        *)       arch="amd64" ;;
    esac

    case "$DISTRO_FAMILY" in
        arch)
            IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
            "${_install_cmd[@]}" fastfetch
            ;;
        debian|rhel|suse)
            local tmp_dir
            tmp_dir=$(mktemp -d)
            local url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${arch}.tar.gz"
            if curl -fLo "$tmp_dir/fastfetch.tar.gz" "$url" \
                && { sudo tar xf "$tmp_dir/fastfetch.tar.gz" \
                        --strip-components=3 \
                        -C /usr/local/bin \
                        "fastfetch-linux-${arch}/usr/bin/fastfetch" 2>/dev/null \
                    || sudo tar xf "$tmp_dir/fastfetch.tar.gz" \
                        --wildcards \
                        -O '*/fastfetch' | sudo tee /usr/local/bin/fastfetch > /dev/null; }
            then
                sudo chmod +x /usr/local/bin/fastfetch
            else
                log_warn "fastfetch : échec du téléchargement/extraction du binaire"
            fi
            rm -rf "$tmp_dir"
            ;;
    esac

    cmd_exists fastfetch \
        && log_success "fastfetch installé" \
        || log_warn "fastfetch : échec, installation manuelle requise"
}

# ── Ghostty ────────────────────────────────────────────────
install_ghostty() {
    if cmd_exists ghostty; then
        log_info "ghostty déjà présent"
        return
    fi

    log_step "Installation de Ghostty"

    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    case "$DISTRO_FAMILY" in
        arch)
            "${_install_cmd[@]}" ghostty
            ;;
        debian)
            if sudo apt-get install -y ghostty 2>/dev/null; then
                log_success "ghostty installé via apt"
            elif cmd_exists snap; then
                log_info "ghostty non disponible via apt — tentative via snap..."
                sudo snap install ghostty --classic \
                    && log_success "ghostty installé via snap" \
                    || log_warn "ghostty : échec snap — voir https://ghostty.org/docs/install/binary"
            else
                log_warn "ghostty non disponible — voir https://ghostty.org/docs/install/binary"
            fi
            ;;
        rhel)
            "${_install_cmd[@]}" ghostty 2>/dev/null \
                || log_warn "ghostty non disponible — voir https://ghostty.org/docs/install"
            ;;
        suse)
            "${_install_cmd[@]}" ghostty 2>/dev/null \
                || log_warn "ghostty non disponible — voir https://ghostty.org/docs/install"
            ;;
    esac

    cmd_exists ghostty \
        && log_success "ghostty installé" \
        || log_warn "ghostty : échec, voir https://ghostty.org/docs/install"
}

# ── GitHub CLI (gh) ──────────────────────────────────────────
install_gh() {
    if cmd_exists gh; then
        log_info "gh déjà présent"
        return
    fi

    log_step "Installation de GitHub CLI (gh)"

    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    case "$DISTRO_FAMILY" in
        arch)
            "${_install_cmd[@]}" github-cli
            ;;
        debian)
            if ! sudo apt-get install -y gh 2>/dev/null; then
                log_info "gh non disponible via apt — ajout du dépôt officiel..."
                if sudo mkdir -p -m 755 /etc/apt/keyrings \
                    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
                    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
                    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages/deb stable main" \
                        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
                    && sudo apt-get update \
                    && sudo apt-get install -y gh
                then
                    :
                else
                    log_warn "gh : échec de l'ajout du dépôt officiel"
                fi
            fi
            ;;
        rhel)
            if ! sudo dnf install -y gh 2>/dev/null; then
                log_info "gh non disponible via dnf — ajout du dépôt officiel..."
                if sudo dnf install -y 'dnf-command(config-manager)' \
                    && sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo \
                    && sudo dnf install -y gh --repo gh-cli
                then
                    :
                else
                    log_warn "gh : échec de l'ajout du dépôt officiel"
                fi
            fi
            ;;
        suse)
            "${_install_cmd[@]}" gh 2>/dev/null \
                || log_warn "gh non disponible — voir https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
            ;;
    esac

    cmd_exists gh \
        && log_success "gh installé : $(gh --version | head -1)" \
        || log_warn "gh : échec, voir https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
}

install_fastfetch
install_ghostty
install_gh

log_step "Installation de Brave Browser"
if ! cmd_exists brave-browser; then
    log_info "Installation de Brave via le script officiel..."
    if curl -fsS https://dl.brave.com/install.sh | sh; then
        log_success "Brave Browser installé"
    else
        log_warn "Brave : échec de l'installation (réseau ?)"
    fi
else
    log_info "Brave Browser déjà présent"
fi

log_step "Installation de Flatpak"
if ! cmd_exists flatpak; then
    log_info "Installation de Flatpak..."
    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    "${_install_cmd[@]}" flatpak
    log_success "Flatpak installé"
else
    log_info "Flatpak déjà présent"
fi

log_info "Ajout du dépôt Flathub..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
log_success "Flathub configuré"

declare -A FLATPAK_APPS=(
    [im.riot.Riot]="Element"
    [io.appflowy.AppFlowy]="AppFlowy"
    [org.localsend.localsend_app]="LocalSend"
    [org.onlyoffice.desktopeditors]="OnlyOffice"
)

# Installe nativement via AUR sur Arch si un AUR_HELPER est disponible,
# sinon programme un repli Flatpak (ajouté à FLATPAK_APPS ci-dessus).
install_native_or_flatpak() {
    local aur_pkg="$1" flatpak_id="$2" label="$3"

    if [[ "$DISTRO_FAMILY" == "arch" && -n "$AUR_HELPER" ]]; then
        if pacman -Qi "$aur_pkg" &>/dev/null; then
            log_info "$label déjà présent (AUR : $aur_pkg)"
        else
            "$AUR_HELPER" -S --noconfirm "$aur_pkg" \
                && log_success "$label installé (AUR : $aur_pkg)" \
                || log_warn "Échec installation $label via $AUR_HELPER"
        fi
        return
    fi

    if [[ -z "$flatpak_id" ]]; then
        log_warn "$label : pas de Flatpak disponible sur Flathub — installation manuelle requise (AUR uniquement pour l'instant)"
        return
    fi

    [[ "$DISTRO_FAMILY" == "arch" ]] && log_warn "Aucun AUR helper disponible — $label sera installé via Flatpak"
    FLATPAK_APPS["$flatpak_id"]="$label"
}

log_step "Installation de Spotify, Discord et la suite Proton"
install_native_or_flatpak spotify              com.spotify.Client      "Spotify"
install_native_or_flatpak discord              com.discordapp.Discord  "Discord"
install_native_or_flatpak proton-vpn-gtk-app   com.protonvpn.www       "ProtonVPN"
install_native_or_flatpak proton-mail          me.proton.Mail          "Proton Mail"
install_native_or_flatpak proton-authenticator ""                      "Proton Authenticator"

log_step "Installation des applications Flatpak"
for app_id in "${!FLATPAK_APPS[@]}"; do
    if flatpak list --app | grep -q "$app_id"; then
        log_info "${FLATPAK_APPS[$app_id]} déjà installé"
    else
        log_info "Installation de ${FLATPAK_APPS[$app_id]}..."
        flatpak install -y flathub "$app_id"
        log_success "${FLATPAK_APPS[$app_id]} installé"
    fi
done

log_success "Paquets système et applications installés"

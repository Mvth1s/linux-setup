#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$SCRIPT_DIR/detect_distro.sh"

BACKUP_TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_DIR="$HOME/.dotfiles_backup/$BACKUP_TIMESTAMP"

link_config() {
    local src_rel="$1"
    local dest="$2"
    local src_abs="$REPO_ROOT/$src_rel"

    mkdir -p "$(dirname "$dest")"

    if [[ -e "$dest" ]] && [[ ! -L "$dest" ]]; then
        log_warn "Backup : $dest → $BACKUP_DIR/"
        mkdir -p "$BACKUP_DIR"
        cp -r "$dest" "$BACKUP_DIR/"
    fi

    ln -sf "$src_abs" "$dest"
    log_success "Symlink : $dest"
}

log_step "Installation de fish"
if ! cmd_exists fish; then
    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    "${_install_cmd[@]}" fish
    log_success "fish installé"
else
    log_info "fish déjà présent"
fi

FISH_PATH="$(command -v fish)"

log_step "Installation de Fisher"
if fish -c "functions -q fisher" 2>/dev/null; then
    log_info "Fisher déjà présent"
else
    fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
    log_success "Fisher installé"
fi

log_step "Installation du plugin nvm.fish"
if fish -c "functions -q nvm" 2>/dev/null; then
    log_info "nvm.fish déjà présent"
else
    fish -c "fisher install jorgebucaran/nvm.fish"
    log_success "nvm.fish installé"
fi

log_step "Installation de Tide"
if fish -c "functions -q tide" 2>/dev/null; then
    log_info "Tide déjà présent"
else
    fish -c "fisher install ilancosman/tide@v6"
    log_success "Tide installé"
fi

log_step "Configuration de Tide (Classic, icônes activées, deux lignes)"
if fish -c 'set -q __linux_setup_tide_configured' 2>/dev/null; then
    log_info "Tide déjà configuré"
else
    if fish -c "tide configure --auto \
        --style=Classic \
        --prompt_colors='True color' \
        --classic_prompt_color=Dark \
        --show_time=No \
        --classic_prompt_separators=Angled \
        --prompt_spacing=Sparse \
        --icons='Many icons' \
        --transient=No \
        --finish='Overwrite your current tide config'" 2>/dev/null
    then
        fish -c 'set -U __linux_setup_tide_configured 1'
        log_success "Tide configuré (Classic, icônes activées, deux lignes)"
    else
        log_warn "Configuration automatique de Tide échouée — lance 'tide configure' manuellement dans fish"
    fi
fi

log_step "Création des symlinks de configuration fish"
link_config "fish/config.fish"        "$HOME/.config/fish/config.fish"
link_config "fish/conf.d/aliases.fish" "$HOME/.config/fish/conf.d/aliases.fish"

log_step "Shell par défaut"
if [[ "$SHELL" == "$FISH_PATH" ]]; then
    log_info "fish est déjà le shell par défaut"
elif confirm "Définir fish comme shell par défaut ?"; then
    if ! grep -qxF "$FISH_PATH" /etc/shells 2>/dev/null; then
        log_info "Ajout de $FISH_PATH à /etc/shells"
        echo "$FISH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi

    if chsh -s "$FISH_PATH" 2>/dev/null; then
        log_success "Shell par défaut changé en fish (actif à la prochaine connexion)"
    elif sudo chsh -s "$FISH_PATH" "$USER" 2>/dev/null; then
        log_success "Shell par défaut changé en fish via sudo (actif à la prochaine connexion)"
    elif sudo usermod -s "$FISH_PATH" "$USER" 2>/dev/null; then
        log_success "Shell par défaut changé en fish via usermod (actif à la prochaine connexion)"
    else
        log_warn "Impossible de changer le shell automatiquement."
        log_warn "Lance manuellement : sudo chsh -s $FISH_PATH \$USER"
    fi
fi

log_success "fish configuré"

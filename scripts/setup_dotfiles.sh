#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/utils.sh"

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

log_step "Création des symlinks de configuration"
link_config "fastfetch"    "$HOME/.config/fastfetch"
link_config "ghostty"      "$HOME/.config/ghostty"
link_config "zed"          "$HOME/.config/zed"
link_config "zsh/.zshrc"   "$HOME/.zshrc"
link_config "zsh/.aliases" "$HOME/.aliases"

log_step "Installation des plugins zsh"
ZSH_PLUGIN_DIR="$HOME/.zsh"
mkdir -p "$ZSH_PLUGIN_DIR"

if [[ ! -d "$ZSH_PLUGIN_DIR/zsh-autosuggestions" ]]; then
    log_info "Clonage zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_PLUGIN_DIR/zsh-autosuggestions"
    log_success "zsh-autosuggestions installé"
else
    log_info "zsh-autosuggestions déjà présent"
fi

if [[ ! -d "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting" ]]; then
    log_info "Clonage zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting"
    log_success "zsh-syntax-highlighting installé"
else
    log_info "zsh-syntax-highlighting déjà présent"
fi

log_step "Installation de Starship"
if ! cmd_exists starship; then
    log_info "Installation de Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    log_success "Starship installé"
else
    log_info "Starship déjà présent"
fi

log_step "Shell par défaut"
if [[ "$SHELL" != "$(which zsh 2>/dev/null || true)" ]]; then
    if confirm "Définir zsh comme shell par défaut ?"; then
        chsh -s "$(which zsh)"
        log_success "Shell par défaut changé en zsh (actif à la prochaine connexion)"
    fi
else
    log_info "zsh est déjà le shell par défaut"
fi

log_success "Dotfiles configurés"

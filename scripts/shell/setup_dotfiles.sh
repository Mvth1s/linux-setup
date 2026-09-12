#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/../core/utils.sh"

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
        # Un vrai dossier n'est pas remplacé par `ln -sf` : le lien serait créé
        # à l'intérieur. Il faut le supprimer explicitement après le backup.
        rm -rf "$dest"
    fi

    ln -sf "$src_abs" "$dest"
    log_success "Symlink : $dest"
}

log_step "Création des symlinks de configuration"

# Nettoyage d'un éventuel fichier config.ghostty vide qui traînerait à côté
# du fichier "config" principal (mauvais nom de fichier ignoré par ghostty)
GHOSTTY_STRAY="$HOME/.config/ghostty/config.ghostty"
if [[ -e "$GHOSTTY_STRAY" ]] && [[ ! -L "$GHOSTTY_STRAY" ]]; then
    if [[ ! -s "$GHOSTTY_STRAY" ]]; then
        rm -f "$GHOSTTY_STRAY"
        log_info "config.ghostty vide supprimé (fichier attendu par ghostty : config)"
    else
        log_warn "$GHOSTTY_STRAY existe et n'est pas vide — non supprimé, vérifie son contenu manuellement"
    fi
fi

link_config "fastfetch"    "$HOME/.config/fastfetch"
link_config "ghostty"      "$HOME/.config/ghostty"
link_config "zed"          "$HOME/.config/zed"
link_config "zsh/.zshrc"   "$HOME/.zshrc"
link_config "zsh/.aliases" "$HOME/.aliases"

log_step "Installation de oh-my-posh"
if ! cmd_exists oh-my-posh; then
    log_info "Installation de oh-my-posh..."
    if curl -s https://ohmyposh.dev/install.sh | bash -s; then
        log_success "oh-my-posh installé"
    else
        log_warn "oh-my-posh : échec de l'installation (réseau ?)"
    fi
else
    log_info "oh-my-posh déjà présent"
fi

LOCAL_BIN_LINE='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -qxF "$LOCAL_BIN_LINE" "$HOME/.zshenv" 2>/dev/null; then
    echo "$LOCAL_BIN_LINE" >> "$HOME/.zshenv"
    log_success "~/.local/bin ajouté au PATH de façon permanente (~/.zshenv)"
fi
export PATH="$HOME/.local/bin:$PATH"

log_step "Installation des Nerd Fonts (JetBrainsMono)"
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
    log_info "Installation de JetBrainsMono Nerd Font via oh-my-posh..."
    oh-my-posh font install JetBrainsMono
    fc-cache -f
    log_success "JetBrainsMono Nerd Font installée"
else
    log_info "JetBrainsMono Nerd Font déjà présente"
fi

log_step "Installation de zinit"
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    log_info "Installation de zinit..."
    mkdir -p "$(dirname "$ZINIT_HOME")"
    if git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"; then
        log_success "zinit installé"
    else
        log_warn "zinit : échec du clone (réseau ?)"
    fi
else
    log_info "zinit déjà présent"
fi

log_step "Shell par défaut"
_zsh_path="$(which zsh 2>/dev/null || true)"

if [[ -z "$_zsh_path" ]]; then
    log_warn "zsh introuvable — shell par défaut non modifié"
elif [[ "$SHELL" == "$_zsh_path" ]]; then
    log_info "zsh est déjà le shell par défaut"
elif confirm "Définir zsh comme shell par défaut ?"; then
    if chsh -s "$_zsh_path" 2>/dev/null; then
        log_success "Shell par défaut changé en zsh (actif à la prochaine connexion)"
    elif sudo chsh -s "$_zsh_path" "$USER" 2>/dev/null; then
        log_success "Shell par défaut changé en zsh via sudo (actif à la prochaine connexion)"
    else
        log_warn "Impossible de changer le shell automatiquement."
        log_warn "Lance manuellement : sudo chsh -s $_zsh_path \$USER"
    fi
fi

log_success "Dotfiles configurés"

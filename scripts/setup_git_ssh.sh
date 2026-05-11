#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

log_step "Configuration Git"

current_name="$(git config --global user.name 2>/dev/null || true)"
current_email="$(git config --global user.email 2>/dev/null || true)"

printf "Nom Git [%s] : " "${current_name:-}"
read -r git_name
git_name="${git_name:-$current_name}"

printf "Email Git [%s] : " "${current_email:-}"
read -r git_email
git_email="${git_email:-$current_email}"

git config --global user.name        "$git_name"
git config --global user.email       "$git_email"
git config --global init.defaultBranch main
git config --global pull.rebase      false
git config --global color.ui         auto

log_success "Git configuré (nom : $git_name, email : $git_email)"

log_step "Génération de la clé SSH"

SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

_generate_key() {
    ssh-keygen -t ed25519 -C "$git_email" -f "$SSH_KEY"
    chmod 600 "$SSH_KEY"
    chmod 644 "${SSH_KEY}.pub"
    log_success "Clé SSH générée : $SSH_KEY"
}

if [[ -f "$SSH_KEY" ]]; then
    log_warn "La clé $SSH_KEY existe déjà."
    if confirm "Écraser la clé existante ?"; then
        _generate_key
    else
        log_info "Génération annulée — clé existante conservée"
    fi
else
    _generate_key
fi

log_step "Ajout de la clé au ssh-agent"
eval "$(ssh-agent -s)"
ssh-add "$SSH_KEY"
log_success "Clé ajoutée au ssh-agent"

log_step "Clé publique SSH"
printf "\n"
cat "${SSH_KEY}.pub"
printf "\n"

if cmd_exists wl-copy; then
    wl-copy < "${SSH_KEY}.pub"
    log_success "Clé publique copiée dans le presse-papiers (wl-copy)"
elif cmd_exists xclip; then
    xclip -selection clipboard < "${SSH_KEY}.pub"
    log_success "Clé publique copiée dans le presse-papiers (xclip)"
else
    log_warn "wl-copy et xclip absents — copiez manuellement la clé ci-dessus"
fi

log_info "Ajoutez la clé sur GitHub : https://github.com/settings/ssh/new"

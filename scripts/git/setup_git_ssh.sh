#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# ── Identités ──────────────────────────────────────────────────
PERSO_NAME="Mvth1s"
PERSO_EMAIL="mag.d3v+github@pm.me"
PERSO_GITDIR="$HOME/Documents/Dev/"
PERSO_GITCONFIG="$HOME/.gitconfig-perso"

ETNA_NAME="Mathis Aguado"
ETNA_EMAIL="aguado_m@etna-alternance.net"
ETNA_GITDIR="$HOME/Documents/ETNA/"
ETNA_GITCONFIG="$HOME/.gitconfig-etna"

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
GITHUB_KEY="$SSH_DIR/id_ed25519_github"
GITLAB_ETNA_KEY="$SSH_DIR/id_ed25519_gitlab_etna"

log_step "Configuration Git globale"

git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global color.ui auto

# Pas de user.name/user.email global : chaque identité vient des
# fichiers ci-dessous, sélectionnés automatiquement via includeIf
# selon le répertoire du dépôt.
git config --file "$PERSO_GITCONFIG" user.name  "$PERSO_NAME"
git config --file "$PERSO_GITCONFIG" user.email "$PERSO_EMAIL"
log_success "Identité perso : $PERSO_GITCONFIG ($PERSO_NAME <$PERSO_EMAIL>)"

git config --file "$ETNA_GITCONFIG" user.name  "$ETNA_NAME"
git config --file "$ETNA_GITCONFIG" user.email "$ETNA_EMAIL"
log_success "Identité ETNA : $ETNA_GITCONFIG ($ETNA_NAME <$ETNA_EMAIL>)"

add_include_if() {
    local gitdir="$1"
    local path="$2"
    local marker="[includeIf \"gitdir:$gitdir\"]"

    if [[ -f "$HOME/.gitconfig" ]] && grep -qF "$marker" "$HOME/.gitconfig"; then
        log_info "includeIf déjà présent pour $gitdir"
        return
    fi

    {
        echo ""
        echo "$marker"
        echo "    path = $path"
    } >> "$HOME/.gitconfig"
    log_success "includeIf ajouté : $gitdir → $path"
}

add_include_if "$PERSO_GITDIR" "$PERSO_GITCONFIG"
add_include_if "$ETNA_GITDIR"  "$ETNA_GITCONFIG"

mkdir -p "$PERSO_GITDIR" "$ETNA_GITDIR"

log_step "Génération des clés SSH"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

_prompt_passphrase() {
    local label="$1" pass1 pass2
    while true; do
        read -rsp "Passphrase pour $label : " pass1; echo >&2
        if [[ -z "$pass1" ]]; then
            log_warn "La passphrase ne peut pas être vide — réessaie"
            continue
        fi
        read -rsp "Confirme la passphrase : " pass2; echo >&2
        if [[ "$pass1" != "$pass2" ]]; then
            log_warn "Les passphrases ne correspondent pas — réessaie"
            continue
        fi
        printf '%s' "$pass1"
        return
    done
}

_generate_key() {
    local key_path="$1" email="$2" label="$3"

    if [[ -f "$key_path" ]]; then
        log_warn "La clé $key_path existe déjà."
        confirm "Écraser la clé existante ($label) ?" || { log_info "Génération annulée pour $label"; return; }
    fi

    local passphrase
    passphrase="$(_prompt_passphrase "$label")"
    ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N "$passphrase"
    chmod 600 "$key_path"
    chmod 644 "${key_path}.pub"
    log_success "Clé SSH générée : $key_path"
}

_generate_key "$GITHUB_KEY"      "$PERSO_EMAIL" "GitHub (perso)"
_generate_key "$GITLAB_ETNA_KEY" "$ETNA_EMAIL"  "GitLab ETNA"

log_step "Configuration de ~/.ssh/config"

touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

add_ssh_host_block() {
    local host_alias="$1" hostname="$2" identity_file="$3"

    if grep -qE "^Host[[:space:]]+$host_alias\$" "$SSH_CONFIG"; then
        log_info "Entrée SSH config déjà présente : $host_alias"
        return
    fi

    {
        echo ""
        echo "Host $host_alias"
        echo "    HostName $hostname"
        echo "    User git"
        echo "    IdentityFile $identity_file"
        echo "    IdentitiesOnly yes"
    } >> "$SSH_CONFIG"
    log_success "Entrée SSH config ajoutée : $host_alias"
}

add_ssh_host_block "github.com"   "github.com"                       "$GITHUB_KEY"
add_ssh_host_block "gitlab-etna"  "rendu-git.etna-alternance.net"     "$GITLAB_ETNA_KEY"

log_step "Ajout des clés au ssh-agent"
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$GITHUB_KEY" 2>/dev/null || log_warn "Impossible d'ajouter $GITHUB_KEY à l'agent (passphrase incorrecte ?)"
ssh-add "$GITLAB_ETNA_KEY" 2>/dev/null || log_warn "Impossible d'ajouter $GITLAB_ETNA_KEY à l'agent (passphrase incorrecte ?)"
log_success "Clés ajoutées au ssh-agent"

log_step "Clés publiques SSH"
printf "\n${BOLD}GitHub (perso) — %s${RESET}\n" "$PERSO_EMAIL"
cat "${GITHUB_KEY}.pub"
printf "\n${BOLD}GitLab ETNA — %s${RESET}\n" "$ETNA_EMAIL"
cat "${GITLAB_ETNA_KEY}.pub"
printf "\n"

log_info "Ajoutez la clé GitHub sur : https://github.com/settings/ssh/new"
log_info "Ajoutez la clé GitLab ETNA dans les paramètres SSH de votre profil sur rendu-git.etna-alternance.net"

log_success "Git & SSH configurés (deux identités)"

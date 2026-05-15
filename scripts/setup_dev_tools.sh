#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$SCRIPT_DIR/detect_distro.sh"

check_disk_space() {
    local required_gb="$1"
    local label="$2"
    local available_kb
    available_kb=$(df / --output=avail 2>/dev/null | tail -1)
    local available_gb=$(( available_kb / 1024 / 1024 ))
    if (( available_gb < required_gb )); then
        log_warn "Espace disque insuffisant pour $label"
        log_warn "  Disponible : ${available_gb} Go — Recommandé : ${required_gb} Go"
        log_warn "  Lance 'sudo apt-get autoremove && docker system prune -f' pour libérer de l'espace"
        return 1
    fi
}

log_step "Installation de nvm + Node.js LTS"

if [[ ! -d "$HOME/.nvm" ]]; then
    log_info "Récupération de la dernière version de nvm..."
    nvm_version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)
    log_info "Installation de nvm $nvm_version..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
    log_success "nvm installé"
else
    log_info "nvm déjà présent"
fi

# Désactiver nounset le temps de sourcer et d'utiliser nvm (incompatible avec set -u)
set +u
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

if ! nvm ls lts/* 2>/dev/null | grep -q "lts/"; then
    log_info "Installation de Node.js LTS..."
    nvm install --lts
    nvm use --lts
    log_success "Node.js LTS installé : $(node --version)"
else
    log_info "Node.js LTS déjà installé : $(node --version)"
fi
set -u

log_step "Installation de pnpm"
if ! cmd_exists pnpm; then
    log_info "Installation de pnpm..."
    npm install -g pnpm
    log_success "pnpm installé : $(pnpm --version)"
else
    log_info "pnpm déjà présent"
fi

log_step "Installation de Docker"
if check_disk_space 5 "Docker"; then
    if ! cmd_exists docker; then
        log_info "Installation de Docker..."
        case "$DISTRO_FAMILY" in
            arch)
                IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
                "${_install_cmd[@]}" docker docker-compose
                ;;
            debian)
                curl -fsSL https://get.docker.com | sudo sh
                sudo apt install -y docker-compose-plugin
                ;;
            rhel)
                sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                ;;
            suse)
                sudo zypper install -y docker docker-compose
                ;;
        esac
        log_success "Docker installé"
    else
        log_info "Docker déjà présent"
    fi
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    log_success "Docker activé — re-login requis pour l'utiliser sans sudo"
else
    log_warn "Docker ignoré — espace insuffisant"
fi

log_step "Installation d'Ollama"
if check_disk_space 8 "Ollama"; then
    if ! cmd_exists ollama; then
        log_info "Installation d'Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh
        log_success "Ollama installé"
    else
        log_info "Ollama déjà présent"
    fi
else
    log_warn "Ollama ignoré — espace insuffisant"
fi

log_step "Installation de Zed"
if check_disk_space 1 "Zed"; then
    if ! cmd_exists zed; then
        log_info "Installation de Zed..."
        curl -fsSL https://zed.dev/install.sh | sh
        log_success "Zed installé"
    else
        log_info "Zed déjà présent"
    fi
else
    log_warn "Zed ignoré — espace insuffisant"
fi

log_success "Outils de développement installés"

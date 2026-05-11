#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/utils.sh"
source "$SCRIPT_DIR/scripts/detect_distro.sh"

show_banner() {
    printf "${BOLD}${CYAN}"
    printf "╔══════════════════════════════════════════════╗\n"
    printf "║              linux-setup                    ║\n"
    printf "║   Configuration automatisée Linux           ║\n"
    printf "║   %s                       ║\n" "$(date '+%d/%m/%Y')"
    printf "╚══════════════════════════════════════════════╝\n"
    printf "${RESET}\n"
}

show_menu() {
    printf "${BOLD}Que souhaitez-vous installer ?${RESET}\n\n"
    printf "  [1] Tout installer\n"
    printf "  [2] Paquets système + Flatpak\n"
    printf "  [3] Dotfiles\n"
    printf "  [4] Git & SSH\n"
    printf "  [5] Sécurité\n"
    printf "  [6] Outils dev\n"
    printf "  [q] Quitter\n\n"
    printf "Votre choix : "
}

run_script() {
    bash "$SCRIPT_DIR/scripts/$1"
}

show_final_message() {
    log_step "Installation terminée"
    log_warn "Actions manuelles requises :"
    printf "  • Re-login pour activer Docker : newgrp docker\n"
    printf "  • Ajouter la clé SSH sur GitHub : https://github.com/settings/ssh/new\n"
    printf "  • Redémarrer le terminal pour activer zsh\n"
}

show_banner

while true; do
    show_menu
    read -r choice
    case "$choice" in
        1)
            run_script install_packages.sh
            run_script setup_dotfiles.sh
            run_script setup_git_ssh.sh
            run_script setup_security.sh
            run_script setup_dev_tools.sh
            show_final_message
            break
            ;;
        2) run_script install_packages.sh ;;
        3) run_script setup_dotfiles.sh ;;
        4) run_script setup_git_ssh.sh ;;
        5) run_script setup_security.sh ;;
        6) run_script setup_dev_tools.sh ;;
        q|Q)
            log_info "Au revoir !"
            exit 0
            ;;
        *)
            log_warn "Choix invalide : '$choice'"
            ;;
    esac
done

#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/scripts/utils.sh"
source "$REPO_ROOT/scripts/detect_distro.sh"

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
    printf "  [4] Git & SSH (identités perso/ETNA)\n"
    printf "  [5] Sécurité\n"
    printf "  [6] Outils dev\n"
    printf "  [7] Shell fish + Tide\n"
    printf "  [8] Extras Fedora (RPM Fusion, Docker, snapper…)\n"
    printf "  [q] Quitter\n\n"
    printf "Votre choix : "
}

run_script() {
    bash "$REPO_ROOT/scripts/$1"
}

show_final_message() {
    log_step "Installation terminée"
    log_warn "Actions manuelles requises :"
    printf "  • Re-login pour activer Docker : newgrp docker\n"
    printf "  • Ajouter la clé GitHub sur : https://github.com/settings/ssh/new\n"
    printf "  • Ajouter la clé GitLab ETNA sur rendu-git.etna-alternance.net\n"
    printf "  • Redémarrer le terminal pour activer fish (shell par défaut)\n"
    printf "  • Vérifier que les dépôts clonés sous ~/Documents/Dev/ ou ~/Documents/ETNA/\n"
    printf "    utilisent la bonne identité git (voir includeIf dans ~/.gitconfig)\n"
}

show_banner

while true; do
    show_menu
    read -r choice
    case "$choice" in
        1)
            run_script install_packages.sh
            run_script setup_dotfiles.sh
            run_script setup_fish.sh
            run_script setup_git_ssh.sh
            run_script setup_security.sh
            run_script setup_dev_tools.sh
            if [[ "$DISTRO_ID" == "fedora" ]]; then
                run_script setup_fedora.sh
            fi
            show_final_message
            break
            ;;
        2) run_script install_packages.sh ;;
        3) run_script setup_dotfiles.sh ;;
        4) run_script setup_git_ssh.sh ;;
        5) run_script setup_security.sh ;;
        6) run_script setup_dev_tools.sh ;;
        7) run_script setup_fish.sh ;;
        8) run_script setup_fedora.sh ;;
        q|Q)
            log_info "Au revoir !"
            exit 0
            ;;
        *)
            log_warn "Choix invalide : '$choice'"
            ;;
    esac
done

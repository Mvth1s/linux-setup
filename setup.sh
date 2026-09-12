#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/scripts/core/utils.sh"
source "$REPO_ROOT/scripts/core/detect_distro.sh"

show_banner() {
    printf "${BOLD}${CYAN}"
    printf "╔══════════════════════════════════════════════╗\n"
    printf "║              linux-setup                    ║\n"
    printf "║   Configuration automatisée Linux           ║\n"
    printf "║   %s                       ║\n" "$(date '+%d/%m/%Y')"
    printf "╚══════════════════════════════════════════════╝\n"
    printf "${RESET}\n"
}

PROFILE_SCRIPT=""
PROFILE_LABEL=""

select_profile() {
    printf "${BOLD}Quel profil pour cette machine ?${RESET}\n\n"
    printf "  [1] Workstation (travail)\n"
    printf "  [2] Gaming\n"
    printf "  [q] Quitter\n\n"
    printf "Votre choix : "
    read -r profile_choice
    case "$profile_choice" in
        1)
            PROFILE_SCRIPT="profiles/setup_workstation.sh"
            PROFILE_LABEL="Extras Workstation"
            ;;
        2)
            PROFILE_SCRIPT="profiles/setup_gaming.sh"
            PROFILE_LABEL="Profil Gaming"
            ;;
        q|Q)
            log_info "Au revoir !"
            exit 0
            ;;
        *)
            log_warn "Choix invalide : '$profile_choice'"
            select_profile
            ;;
    esac
}

show_menu() {
    printf "${BOLD}Que souhaitez-vous installer ? (profil : %s)${RESET}\n\n" "$PROFILE_LABEL"
    printf "  [1] Tout installer\n"
    printf "  [2] Paquets système + Flatpak\n"
    printf "  [3] Dotfiles\n"
    printf "  [4] Git & SSH (identités perso/ETNA)\n"
    printf "  [5] Sécurité\n"
    printf "  [6] Outils dev\n"
    printf "  [7] Shell fish + Tide\n"
    printf "  [8] %s\n" "$PROFILE_LABEL"
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
select_profile

while true; do
    show_menu
    read -r choice
    case "$choice" in
        1)
            run_script packages/install_packages.sh
            run_script shell/setup_dotfiles.sh
            run_script shell/setup_fish.sh
            run_script git/setup_git_ssh.sh
            run_script security/setup_security.sh
            run_script dev/setup_dev_tools.sh
            run_script "$PROFILE_SCRIPT"
            show_final_message
            break
            ;;
        2) run_script packages/install_packages.sh ;;
        3) run_script shell/setup_dotfiles.sh ;;
        4) run_script git/setup_git_ssh.sh ;;
        5) run_script security/setup_security.sh ;;
        6) run_script dev/setup_dev_tools.sh ;;
        7) run_script shell/setup_fish.sh ;;
        8) run_script "$PROFILE_SCRIPT" ;;
        q|Q)
            log_info "Au revoir !"
            exit 0
            ;;
        *)
            log_warn "Choix invalide : '$choice'"
            ;;
    esac
done

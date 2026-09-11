# ~/.config/fish/config.fish
set -g fish_greeting ""

if status is-interactive
    command -q fastfetch; and fastfetch

    # ── Agent SSH : démarrage auto + chargement des deux identités ──
    # Garde-fou : ne s'exécute qu'une fois par session fish (set -g,
    # donc réinitialisé à chaque nouveau processus fish).
    if not set -q __linux_setup_ssh_agent_loaded
        set -g __linux_setup_ssh_agent_loaded 1

        if not set -q SSH_AUTH_SOCK
            eval (ssh-agent -c) > /dev/null
        end

        ssh-add ~/.ssh/id_ed25519_github 2>/dev/null
        ssh-add ~/.ssh/id_ed25519_gitlab_etna 2>/dev/null
    end
end

# PATH
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.lmstudio/bin

# Variables d'environnement
set -gx DOCKER_BUILDKIT 1
set -gx EDITOR nvim

# Historique
set -g fish_history_max 10000

# ── Thème (couleurs de coloration syntaxique + pager) ──────────
# Portées ici depuis conf.d/fish_frozen_theme.fish (fichier généré par
# fish lors d'une migration de version, non versionné — voir .gitignore)
# pour que le thème soit reproductible sur une nouvelle machine.
set -g fish_color_autosuggestion 555 brblack
set -g fish_color_cancel -r
set -g fish_color_command blue
set -g fish_color_comment red
set -g fish_color_cwd green
set -g fish_color_cwd_root red
set -g fish_color_end green
set -g fish_color_error brred
set -g fish_color_escape brcyan
set -g fish_color_history_current --bold
set -g fish_color_host normal
set -g fish_color_host_remote yellow
set -g fish_color_normal normal
set -g fish_color_operator brcyan
set -g fish_color_param cyan
set -g fish_color_quote yellow
set -g fish_color_redirection cyan --bold
set -g fish_color_search_match --background=111
set -g fish_color_selection white --bold --background=brblack
set -g fish_color_status red
set -g fish_color_user brgreen
set -g fish_color_valid_path --underline
set -g fish_pager_color_completion normal
set -g fish_pager_color_description B3A06D yellow -i
set -g fish_pager_color_prefix cyan --bold --underline
set -g fish_pager_color_progress brwhite --background=cyan
set -g fish_pager_color_selected_background -r

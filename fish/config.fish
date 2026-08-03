# ~/.config/fish/config.fish
# Chargé à chaque démarrage de fish (interactif ou non)

fish_add_path -g "$HOME/.local/bin"

set -gx EDITOR nvim
set -gx DOCKER_BUILDKIT 1

if status is-interactive
    # Pas de message d'accueil natif de fish
    set -g fish_greeting

    command -q fastfetch; and fastfetch

    # ── Agent SSH : démarrage auto + chargement des deux identités ──
    # Garde-fou : ne s'exécute qu'une fois par session fish (set -g,
    # donc réinitialisé à chaque nouveau processus fish).
    if not set -q __linux_setup_ssh_agent_loaded
        set -g __linux_setup_ssh_agent_loaded 1

        ssh-add -l >/dev/null 2>&1
        if test $status -eq 2
            eval (ssh-agent -c) >/dev/null
        end

        for key_name in id_ed25519_github id_ed25519_gitlab_etna
            set -l key_path "$HOME/.ssh/$key_name"
            if test -f "$key_path"
                if not ssh-add -l 2>/dev/null | string match -q "*$key_path*"
                    ssh-add "$key_path" >/dev/null 2>&1
                end
            end
        end
    end
end

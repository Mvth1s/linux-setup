# linux-setup

Configuration automatisée d'une nouvelle machine Linux en une seule commande.

## Distributions supportées

| Distribution | Famille | Package manager |
|---|---|---|
| Arch, EndeavourOS, Manjaro, Garuda, CachyOS | arch | pacman |
| Debian, Ubuntu, Pop!_OS, Linux Mint, Elementary, Kali, Zorin | debian | apt |
| Fedora | rhel | dnf |
| openSUSE, SLES, SLED | suse | zypper |

## Arborescence

```
linux-setup/
├── setup.sh                  # Point d'entrée principal
├── scripts/
│   ├── utils.sh              # Fonctions log_*, cmd_exists, confirm
│   ├── detect_distro.sh      # Détection distro + variables PKG_*
│   ├── install_packages.sh   # Paquets système + Brave + Spotify + Flatpak
│   ├── setup_dotfiles.sh     # Symlinks config + zinit + oh-my-posh
│   ├── setup_fish.sh         # fish + Fisher + Tide + nvm.fish
│   ├── setup_git_ssh.sh      # Git (identités perso/ETNA) + 2 clés SSH ed25519
│   ├── setup_security.sh     # UFW + DNS Quad9
│   ├── setup_dev_tools.sh    # nvm/Node, pnpm, Docker, Ollama, Zed
│   └── setup_fedora.sh       # Extras Fedora uniquement (voir plus bas)
├── fastfetch/                # Config fastfetch
├── ghostty/                  # Config terminal Ghostty + shader curseur
│   ├── config
│   └── shaders/
├── fedora/                   # Ressources spécifiques Fedora (snapper/dnf5)
├── zed/                      # Config éditeur Zed
├── zsh/
│   ├── .zshrc                # Config zsh (zinit + oh-my-posh)
│   └── .aliases              # Aliases shell (zsh)
└── fish/
    ├── config.fish           # Config fish (PATH, agent SSH, greeting)
    └── conf.d/aliases.fish   # Aliases shell (fish)
```

## Démarrage rapide

```bash
git clone https://github.com/Mvth1s/linux-setup.git
chmod +x linux-setup/setup.sh linux-setup/scripts/*.sh
./linux-setup/setup.sh
```

## Ce qui est installé

### Paquets système
`zsh` `curl` `wget` `git` `htop` `btop` `tree` `ripgrep` `fzf` `eza` `bat` `tmux` `neofetch` `jq` `neovim` `ranger` `rsync` `nmap` `pipx` `imagemagick`

### Applications natives
- **Brave Browser** — navigateur axé vie privée (script officiel)
- **fastfetch**, **Ghostty**, **gh** (GitHub CLI) — paquet natif si disponible, sinon méthode d'installation officielle par distribution

### Applications Flatpak
| Application | Description |
|---|---|
| **Discord** | Messagerie communautaire |
| **ProtonVPN** | VPN chiffré |
| **Spotify** | Lecteur de musique en streaming |
| **Element** | Client Matrix (messagerie chiffrée) |
| **AppFlowy** | Notes et gestion de projets |
| **Proton Mail** | Messagerie chiffrée |
| **LocalSend** | Partage de fichiers en réseau local |
| **OnlyOffice** | Suite bureautique compatible Office |

### Outils développeur
- **nvm** + Node.js LTS + **pnpm**
- **Docker** + Compose
- **Ollama** — modèles LLM en local
- **Zed** — éditeur de code performant

### Shell & terminal
- **zsh** — **zinit** (gestionnaire de plugins) + **oh-my-posh** (prompt) + zsh-autosuggestions/zsh-syntax-highlighting/zsh-completions
- **fish** — shell par défaut proposé à l'installation, avec **Fisher** (gestionnaire de plugins), **Tide** (prompt, style Classic/icônes/deux lignes) et **nvm.fish** (gestion de Node, remplace nvm classique incompatible avec fish)
- **Ghostty** — thème Everforest Dark Hard, police JetBrainsMono Nerd Font, shader de curseur `cursor_smear_fade` ([KroneCorylus/ghostty-shader-playground](https://github.com/KroneCorylus/ghostty-shader-playground)), lancé directement sur fish

### Git & SSH — double identité perso / ETNA
- Deux clés SSH ed25519 dédiées, **chacune protégée par une passphrase demandée à la génération** :
  - `~/.ssh/id_ed25519_github` → GitHub (identité perso, `mag.d3v+github@pm.me`)
  - `~/.ssh/id_ed25519_gitlab_etna` → `rendu-git.etna-alternance.net` (identité ETNA, `aguado_m@etna-alternance.net`)
- `~/.ssh/config` route chaque host vers la bonne clé (`IdentitiesOnly yes`)
- fish charge automatiquement l'agent SSH et les deux clés à l'ouverture d'un terminal
- Git n'a **pas** d'identité globale : `~/.gitconfig` sélectionne `~/.gitconfig-perso` ou `~/.gitconfig-etna` via `includeIf` selon que le dépôt se trouve sous `~/Documents/Dev/` ou `~/Documents/ETNA/`

### Sécurité
- **UFW** — pare-feu (entrée bloquée, SSH autorisé)
- **DNS Quad9** — résolveur sécurisé avec DNSSEC

### Extras Fedora uniquement
Activés par `scripts/setup_fedora.sh` (ignoré automatiquement sur les autres distributions) :
- RPM Fusion (free + nonfree)
- Docker via `moby-engine` (paquet officiel Fedora)
- `kubectl` (paquet `kubernetes-client`)
- `yazi` via le COPR `lihaohong/yazi`, à la place de `ranger`
- `lynis` + `rkhunter` (avec base de référence `rkhunter --propupd`)
- OnlyOffice (Flatpak) défini par défaut pour docx/xlsx/pptx/odt/ods/odp, LibreOffice désinstallé
- Disposition clavier AZERTY : Verr Maj donne accès à la rangée de chiffres (`caps:digits_row`)
- Snapshots Btrfs automatiques avant/après chaque transaction `dnf5`, via `snapper` + `libdnf5-plugin-actions` (uniquement si `/` est en Btrfs — le paquet `python3-dnf-plugin-snapper` ne fonctionne pas sous dnf5)
- Correctif de la barre de titre Spotify sous GNOME/Wayland (bascule en XWayland)

## Actions manuelles restantes

- **Passphrases SSH** : `setup_git_ssh.sh` est interactif et demande une passphrase (obligatoire, jamais vide) pour chacune des deux clés générées.
- **Shell par défaut** : le script demande confirmation avant de changer de shell (`chsh`, avec repli automatique sur `sudo chsh` puis `usermod -s` si nécessaire) — un redémarrage du terminal ou une reconnexion est nécessaire pour l'activer.
- **Docker** : `newgrp docker` ou reconnexion pour l'utiliser sans `sudo`.
- **Clés SSH sur les forges** : ajouter la clé GitHub sur https://github.com/settings/ssh/new, et la clé ETNA dans les paramètres SSH du profil sur `rendu-git.etna-alternance.net`.
- **Extras Fedora** : à lancer explicitement (menu `[8]` ou option 1 « Tout installer » sur une machine Fedora) — sans effet sur les autres distributions.

## Personnalisation

**Ajouter un paquet système** : modifier le tableau `PACKAGES` dans `scripts/install_packages.sh`.

**Ajouter une application Flatpak** : ajouter l'ID dans le tableau `FLATPAK_APPS` de `scripts/install_packages.sh`.

**Modifier les aliases** : éditer `zsh/.aliases` (zsh) ou `fish/conf.d/aliases.fish` (fish) — les symlinks sont mis à jour automatiquement.

**Ajouter une identité Git** : dupliquer un bloc `includeIf` dans `scripts/setup_git_ssh.sh` (variables `*_NAME`/`*_EMAIL`/`*_GITDIR`) et relancer le script.

# linux-setup

Configuration automatisée d'une nouvelle machine Linux en une seule commande, avec un choix de profil au lancement — **Workstation** (poste de travail) ou **Gaming** — chacun fonctionnel sur les 4 familles de distros ci-dessous.

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
├── setup.sh                       # Point d'entrée principal (choix de profil + menu)
├── scripts/
│   ├── core/
│   │   ├── utils.sh               # Fonctions log_*, cmd_exists, confirm
│   │   ├── detect_distro.sh       # Détection distro + variables PKG_*
│   │   └── detect_gpu.sh          # Détection vendeur GPU (amd/nvidia/intel)
│   ├── packages/
│   │   └── install_packages.sh    # Paquets système + Brave + Spotify/Discord/Proton + Flatpak
│   ├── shell/
│   │   ├── setup_dotfiles.sh      # Symlinks config + zinit + oh-my-posh
│   │   └── setup_fish.sh          # fish + Fisher + Tide + nvm.fish
│   ├── security/
│   │   └── setup_security.sh      # UFW + DNS Quad9
│   ├── git/
│   │   └── setup_git_ssh.sh       # Git (identités perso/ETNA) + 2 clés SSH ed25519
│   ├── dev/
│   │   └── setup_dev_tools.sh     # nvm/Node, pnpm, Docker, Ollama, Zed
│   └── profiles/
│       ├── setup_workstation.sh   # Profil Workstation — 4 familles (voir plus bas)
│       └── setup_gaming.sh        # Profil Gaming — 4 familles (voir plus bas)
├── fastfetch/                     # Config fastfetch
├── ghostty/                       # Config terminal Ghostty + shader curseur
│   ├── config
│   └── shaders/
├── snapper/                       # Ressources snapshots Btrfs par famille (dnf5, apt)
├── zed/                           # Config éditeur Zed
├── zsh/
│   ├── .zshrc                     # Config zsh (zinit + oh-my-posh)
│   └── .aliases                   # Aliases shell (zsh)
└── fish/
    ├── config.fish                # Config fish (PATH, agent SSH, greeting)
    └── conf.d/aliases.fish        # Aliases shell (fish)
```

## Démarrage rapide

```bash
git clone https://github.com/Mvth1s/linux-setup.git
chmod +x linux-setup/setup.sh
find linux-setup/scripts -name '*.sh' -exec chmod +x {} \;
./linux-setup/setup.sh
```

## Choix du profil

Au lancement, `setup.sh` demande le profil de la machine :

```
[1] Workstation (travail)
[2] Gaming
```

Ce choix détermine quel script d'extras accompagne l'option `[8]` du menu et « Tout installer » — le reste (paquets système, dotfiles, shells, Git & SSH, sécurité, outils dev) est commun aux deux profils. Les deux scripts de profil fonctionnent sur les 4 familles de distros ci-dessus : pas besoin d'être sur Fedora pour le profil Workstation, ni sur Arch pour le profil Gaming.

## Ce qui est installé

### Paquets système
`zsh` `curl` `wget` `git` `htop` `btop` `tree` `ripgrep` `fzf` `eza` `bat` `tmux` `neofetch` `jq` `neovim` `ranger` `rsync` `nmap` `pipx` `imagemagick`

### Applications natives
- **Brave Browser** — navigateur axé vie privée (script officiel)
- **fastfetch**, **Ghostty**, **gh** (GitHub CLI) — paquet natif si disponible, sinon méthode d'installation officielle par distribution

### Spotify, Discord, suite Proton — natif ou Flatpak selon la machine
Sur Arch avec un helper AUR (`yay`/`paru`) disponible, ces applications sont installées nativement via AUR. Ailleurs (autres distros, ou Arch sans helper AUR), elles basculent automatiquement en Flatpak :

| Application | Paquet AUR | ID Flatpak (repli) |
|---|---|---|
| Spotify | `spotify` | `com.spotify.Client` |
| Discord | `discord` | `com.discordapp.Discord` |
| ProtonVPN | `proton-vpn-gtk-app` | `com.protonvpn.www` |
| Proton Mail | `proton-mail` | `me.proton.Mail` |
| Proton Authenticator | `proton-authenticator` | *(aucun Flatpak — AUR uniquement)* |

### Applications Flatpak (toujours installées ainsi)
| Application | Description |
|---|---|
| **Element** | Client Matrix (messagerie chiffrée) |
| **AppFlowy** | Notes et gestion de projets |
| **LocalSend** | Partage de fichiers en réseau local |
| **OnlyOffice** | Suite bureautique compatible Office |

### Outils développeur
- **nvm** + Node.js LTS + **pnpm**
- **Docker** + Compose
- **Ollama** — modèles LLM en local
- **Zed** — éditeur de code performant

### Shell & terminal
- **zsh** — **zinit** (gestionnaire de plugins) + **oh-my-posh** (prompt) + zsh-autosuggestions/zsh-syntax-highlighting/zsh-completions
- **fish** — shell par défaut proposé à l'installation, avec **Fisher** (gestionnaire de plugins), **Tide** (prompt, style Classic encadré/icônes/deux lignes) et **nvm.fish** (gestion de Node, remplace nvm classique incompatible avec fish)
- **Ghostty** — thème Everforest Dark Hard, police JetBrainsMono Nerd Font, curseur `block` en permanence, shader de curseur `cursor_smear_fade` ([KroneCorylus/ghostty-shader-playground](https://github.com/KroneCorylus/ghostty-shader-playground)), lancé directement sur fish

### Git & SSH — double identité perso / ETNA
- Deux clés SSH ed25519 dédiées, **chacune protégée par une passphrase demandée à la génération** (transmise à `ssh-keygen` sans jamais apparaître dans la liste des process) :
  - `~/.ssh/id_ed25519_github` → GitHub (identité perso, `mag.d3v+github@pm.me`)
  - `~/.ssh/id_ed25519_gitlab_etna` → `rendu-git.etna-alternance.net` (identité ETNA, `aguado_m@etna-alternance.net`)
- `~/.ssh/config` route chaque host vers la bonne clé (`IdentitiesOnly yes`)
- fish charge automatiquement l'agent SSH (réutilisé s'il existe déjà) et les deux clés à l'ouverture d'un terminal
- Git n'a **pas** d'identité globale : `~/.gitconfig` sélectionne `~/.gitconfig-perso` ou `~/.gitconfig-etna` via `includeIf` selon que le dépôt se trouve sous `~/Documents/Dev/` ou `~/Documents/ETNA/`

### Sécurité
- **UFW** — pare-feu (entrée bloquée, SSH autorisé)
- **DNS Quad9** — résolveur sécurisé avec DNSSEC

### Profil Workstation
Activés par `scripts/profiles/setup_workstation.sh`, fonctionnel sur les 4 familles :
- Dépôts non-libres : RPM Fusion (Fedora), Packman (openSUSE), détection contrib/non-free (Debian — informatif, pas d'édition automatique), rien à faire sur Arch (AUR)
- Docker (moby-engine sur Fedora, natif ailleurs)
- `kubectl` (paquet natif, AUR, ou dépôt officiel `pkgs.k8s.io` selon la distro)
- `yazi` à la place de `ranger` (COPR sur Fedora, paquet officiel sur Arch, binaire GitHub ailleurs)
- `lynis` + `rkhunter` (avec base de référence `rkhunter --propupd`)
- OnlyOffice (Flatpak) défini par défaut pour docx/xlsx/pptx/odt/ods/odp, LibreOffice désinstallé
- Disposition clavier AZERTY : Verr Maj donne accès à la rangée de chiffres (`caps:digits_row`)
- Snapshots Btrfs automatiques avant/après chaque transaction de paquets (uniquement si `/` est en Btrfs) : plugin `libdnf5-plugin-actions` sur Fedora, `snap-pac` sur Arch, hooks apt sur Debian/Ubuntu, plugin zypp natif sur openSUSE
- Correctif de la barre de titre Spotify sous GNOME/Wayland (bascule en XWayland)

### Profil Gaming
Activés par `scripts/profiles/setup_gaming.sh`, fonctionnel sur les 4 familles :
- Support 32-bit (multilib Arch, i386 Debian — non nécessaire sur Fedora/openSUSE)
- Pilotes GPU selon le vendeur détecté (`lspci`) : AMD/Intel (Mesa/Vulkan natifs) ou NVIDIA (propriétaire, avec garde-fous selon la distro)
- Steam, Lutris, Heroic Games Launcher (natif sur Arch, Flatpak ailleurs)
- Wine (staging sur Arch, dépôt officiel WineHQ sur Debian, paquets natifs Fedora/openSUSE) + Winetricks + Protontricks
- GameMode + MangoHud
- Gestionnaire de versions Proton : ProtonPlus (AUR) ou ProtonUp-Qt (Flatpak)

## Actions manuelles restantes

- **Passphrases SSH** : `setup_git_ssh.sh` est interactif et demande une passphrase (obligatoire, jamais vide) pour chacune des deux clés générées.
- **Shell par défaut** : le script demande confirmation avant de changer de shell (`chsh`, avec repli automatique sur `sudo chsh` puis `usermod -s` si nécessaire) — un redémarrage du terminal ou une reconnexion est nécessaire pour l'activer.
- **Docker** : `newgrp docker` ou reconnexion pour l'utiliser sans `sudo`.
- **Clés SSH sur les forges** : ajouter la clé GitHub sur https://github.com/settings/ssh/new, et la clé ETNA dans les paramètres SSH du profil sur `rendu-git.etna-alternance.net`.
- **Dépôts non-libres sur Debian/Ubuntu** : le profil Workstation détecte contrib/non-free mais ne les active pas automatiquement (édition des sources APT jugée trop risquée sans confirmation exacte du format) — à activer manuellement si besoin.

## Personnalisation

**Ajouter un paquet système** : modifier le tableau `PACKAGES` dans `scripts/packages/install_packages.sh`.

**Ajouter une application Flatpak toujours-installée** : ajouter l'ID dans le tableau `FLATPAK_APPS` de `scripts/packages/install_packages.sh`. Pour une app avec repli AUR/Flatpak, utiliser `install_native_or_flatpak` à la place.

**Modifier les aliases** : éditer `zsh/.aliases` (zsh) ou `fish/conf.d/aliases.fish` (fish) — les symlinks sont mis à jour automatiquement.

**Ajouter une identité Git** : dupliquer un bloc `includeIf` dans `scripts/git/setup_git_ssh.sh` (variables `*_NAME`/`*_EMAIL`/`*_GITDIR`) et relancer le script.

**Ajouter un profil** : dupliquer `scripts/profiles/setup_workstation.sh` ou `setup_gaming.sh` comme modèle, ajouter une entrée dans `select_profile()` et le `case` du menu dans `setup.sh`.

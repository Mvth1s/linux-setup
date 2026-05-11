# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Objectif

Créer un système de scripts bash de configuration automatisée pour Linux.
Les scripts doivent permettre de configurer n'importe quelle nouvelle machine Linux en une seule commande.

---

## État actuel du dépôt

### Fichiers déjà présents (ne pas modifier)

```
fastfetch/config.jsonc          ← chemin logo hardcodé /home/mathis/... à garder tel quel
fastfetch/Chibi-Anime-PNG-Transparent-Image.png
ghostty/config.ghostty
zed/settings.json
zsh/.zshrc                      ← utilise oh-my-posh + zinit (voir note ci-dessous)
```

### Note importante sur zsh/.zshrc

Le `.zshrc` existant **diverge de la spec** : il utilise **oh-my-posh** (pas starship) et **zinit** (pas de clonage manuel des plugins). Il inclut aussi `PATH lmstudio` et `DOCKER_BUILDKIT=1`. **Ne pas écraser ce fichier** — créer `zsh/.aliases` en complément uniquement.

### Fichiers à créer

```
setup.sh
scripts/utils.sh
scripts/detect_distro.sh
scripts/install_packages.sh
scripts/setup_dotfiles.sh
scripts/setup_git_ssh.sh
scripts/setup_security.sh
scripts/setup_dev_tools.sh
zsh/.aliases
.gitignore
README.md
```

---

## Architecture et dépendances entre scripts

```
setup.sh
 ├── source scripts/utils.sh          (fonctions log_*, cmd_exists, confirm)
 ├── source scripts/detect_distro.sh  (exporte DISTRO_FAMILY, PKG_INSTALL, etc.)
 └── bash scripts/<module>.sh         (chaque module source utils + detect si besoin)

scripts/utils.sh          ← aucune dépendance, chargé en premier
scripts/detect_distro.sh  ← dépend de utils.sh (pour log_error)
scripts/install_packages.sh  ← dépend de detect_distro.sh
scripts/setup_dotfiles.sh    ← indépendant (git clone, ln -sf)
scripts/setup_git_ssh.sh     ← indépendant
scripts/setup_security.sh    ← dépend de detect_distro.sh (pour installer ufw)
scripts/setup_dev_tools.sh   ← dépend de detect_distro.sh (pour docker)
```

Chaque sous-script doit recharger `detect_distro.sh` si `DISTRO_FAMILY` n'est pas défini :
```bash
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$(dirname "$0")/detect_distro.sh"
```

---

## Tester les scripts

```bash
# Vérification syntaxique sans exécution
bash -n scripts/utils.sh
bash -n scripts/detect_distro.sh

# Lint statique (si shellcheck installé)
shellcheck scripts/*.sh setup.sh

# Tester la détection de distro seule
bash scripts/detect_distro.sh && echo "DISTRO_FAMILY=$DISTRO_FAMILY"

# Tester le menu setup sans rien installer (lecture seule)
bash -x setup.sh 2>&1 | head -50
```

---

## Règles communes à tous les scripts

- Shebang : `#!/usr/bin/env bash`
- `set -euo pipefail` dans chaque script
- Toujours vérifier si un outil est déjà installé avant de l'installer (`cmd_exists`)
- Jamais d'`echo` brut : tous les messages passent par les fonctions de `utils.sh`
- Permissions finales : `setup.sh` et `scripts/*.sh` → `755`, dotfiles → `644`

---

## scripts/utils.sh

| Fonction | Comportement |
|---|---|
| `log_info <msg>` | `[INFO]` en bleu |
| `log_success <msg>` | `[OK]` en vert |
| `log_warn <msg>` | `[WARN]` en jaune |
| `log_error <msg>` | `[ERROR]` en rouge sur stderr |
| `log_step <msg>` | séparateur visuel bold/cyan pour marquer une étape |
| `cmd_exists <cmd>` | `command -v "$1" &>/dev/null` |
| `confirm <prompt>` | demande `[y/N]`, retourne 0 si oui |

Variables couleurs ANSI : `RED GREEN YELLOW BLUE CYAN BOLD RESET`

---

## scripts/detect_distro.sh

Détection via `/etc/os-release` (`ID` puis `ID_LIKE` en fallback).

| Famille | Distros reconnues | Package manager |
|---|---|---|
| `arch` | arch, endeavouros, manjaro, garuda, cachyos | pacman |
| `debian` | debian, ubuntu, pop, linuxmint, elementary, kali, zorin | apt |
| `rhel` | fedora | dnf |
| `suse` | opensuse*, sles, sled | zypper |

Variables exportées : `DISTRO_ID`, `DISTRO_FAMILY`, `PKG_MANAGER`, `PKG_INSTALL`, `PKG_UPDATE`, `AUR_HELPER`

- `PKG_INSTALL` inclut les flags silencieux (`--noconfirm`, `-y`, etc.)
- `AUR_HELPER` : détecter `yay` puis `paru` (Arch uniquement)
- Distribution non reconnue → `log_error` explicite + `exit 1`

---

## scripts/install_packages.sh

**Étape 1 — Mise à jour système**
```bash
eval "$PKG_UPDATE"
```

**Étape 2 — Paquets communs**
```
zsh curl wget git htop btop tree unzip zip
ripgrep fzf eza bat tmux neofetch openssh xclip wl-clipboard
```
Cas particulier Debian/Ubuntu : `bat` s'appelle `batcat` → créer un lien symbolique `/usr/local/bin/bat → batcat` si `bat` n'existe pas déjà.

**Étape 3 — Flatpak**
1. Installer Flatpak s'il est absent (via le package manager natif)
2. Ajouter Flathub : `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
3. Installer chaque app seulement si absente (`flatpak list --app | grep -q <id>`) :
   - `com.brave.Browser`
   - `com.vscodium.codium`
   - `org.onlyoffice.desktopeditors`

---

## scripts/setup_dotfiles.sh

**Fonction `link_config <src> <dest>`** :
1. Créer le répertoire parent de `<dest>` si nécessaire
2. Si `<dest>` existe et n'est **pas** déjà un symlink → backup dans `~/.dotfiles_backup/<timestamp>/`
3. Créer le symlink : `ln -sf "<src_absolu>" "<dest>"`

**Symlinks à créer** :

| Source (dans le repo) | Destination |
|---|---|
| `fastfetch/` | `~/.config/fastfetch` |
| `ghostty/` | `~/.config/ghostty` |
| `zed/` | `~/.config/zed` |
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.aliases` | `~/.aliases` |

**Plugins zsh** — cloner dans `~/.zsh/` avec `--depth=1`, vérifier si le dossier existe déjà :
- `https://github.com/zsh-users/zsh-autosuggestions`
- `https://github.com/zsh-users/zsh-syntax-highlighting`

**Starship** : installer si absent avec `curl -sS https://starship.rs/install.sh | sh -s -- --yes`

**Shell par défaut** : si `$SHELL` n'est pas zsh, proposer via `confirm` de lancer `chsh -s "$(which zsh)"`

---

## scripts/setup_git_ssh.sh

**Configuration Git (interactive)**
- Lire les valeurs actuelles avec `git config --global user.name/email` (les afficher comme défaut)
- Configurer : `user.name`, `user.email`, `init.defaultBranch=main`, `pull.rebase=false`, `color.ui=auto`

**Clé SSH**
- Type : `ed25519`, chemin : `~/.ssh/id_ed25519`
- Si la clé existe déjà → `log_warn` + `confirm` avant d'écraser
- Permissions : `700` sur `~/.ssh/`, `600` clé privée, `644` clé publique
- Ajouter au ssh-agent : `eval "$(ssh-agent -s)"` puis `ssh-add`
- Copier dans le presse-papiers : priorité `wl-copy` (Wayland), sinon `xclip`
- Afficher le lien : `https://github.com/settings/ssh/new`

---

## scripts/setup_security.sh

**UFW**
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
```
Installer UFW si absent via `$PKG_INSTALL`.

**DNS Quad9**
- Si `systemd-resolved` est actif → créer `/etc/systemd/resolved.conf.d/quad9.conf` :
  ```ini
  [Resolve]
  DNS=9.9.9.9 149.112.112.112
  FallbackDNS=1.1.1.1 1.0.0.1
  DNSSEC=yes
  DNSOverTLS=opportunistic
  ```
  Puis `sudo systemctl restart systemd-resolved`
- Sinon → backup de `/etc/resolv.conf` puis écriture directe avec les nameservers Quad9

**Services de crash-report** (ne pas faire échouer le script si absents) :
```bash
sudo systemctl disable --now apport.service  2>/dev/null || true
sudo systemctl disable --now whoopsie.service 2>/dev/null || true
```

---

## scripts/setup_dev_tools.sh

**nvm + Node LTS**
```bash
nvm_version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install --lts && nvm use --lts
```

**Docker**

| Famille | Commande |
|---|---|
| arch | `pacman -S docker docker-compose` |
| debian | `curl -fsSL https://get.docker.com \| sudo sh` + `apt install docker-compose-plugin` |
| rhel | `dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin` |
| suse | `zypper install docker docker-compose` |

Puis : `sudo systemctl enable --now docker` + `sudo usermod -aG docker "$USER"`

**Ollama** : `curl -fsSL https://ollama.com/install.sh | sh`

**Zed** : `curl -fsSL https://zed.dev/install.sh | sh`

Vérifier avec `cmd_exists` avant chaque installation.

---

## zsh/.aliases

```bash
# Navigation
alias ..="cd .."
alias ...="cd ../.."

# ls → eza (fallback ls)
if command -v eza &>/dev/null; then
  alias ls="eza --icons"
  alias ll="eza -l --icons --git"
  alias la="eza -la --icons --git"
  alias lt="eza --tree --icons --level=2"
else
  alias ls="ls --color=auto"
  alias ll="ls -lhF"
  alias la="ls -lhAF"
fi

# cat → bat (fallback)
command -v bat &>/dev/null && alias cat="bat --paging=never"

# Git
alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias glog="git log --oneline --graph --decorate"
alias gco="git checkout"
alias gb="git branch"

# Docker
alias d="docker"
alias dc="docker compose"
alias dps="docker ps"
alias dpsa="docker ps -a"
alias dclean="docker system prune -f"

# Système
alias myip="curl -s https://api.ipify.org && echo"
alias ports="ss -tulnp"
alias df="df -h"
alias du="du -sh"
alias free="free -h"

# Misc
alias reload="source ~/.zshrc"
alias please="sudo"
mkcd() { mkdir -p "$1" && cd "$1"; }
```

---

## setup.sh

1. Sourcer `scripts/utils.sh` puis `scripts/detect_distro.sh`
2. Afficher une bannière ASCII simple avec le nom du projet et la date
3. Menu interactif :
   ```
   [1] Tout installer
   [2] Paquets système + Flatpak
   [3] Dotfiles
   [4] Git & SSH
   [5] Sécurité
   [6] Outils dev
   [q] Quitter
   ```
4. Option 1 : enchaîner dans l'ordre `install → dotfiles → git_ssh → security → dev_tools`
5. Options 2-6 : lancer via `bash "$SCRIPT_DIR/scripts/<script>.sh"`
6. Message de fin avec rappel des **actions manuelles** :
   - Re-login pour Docker (`newgrp docker`)
   - Ajouter la clé SSH sur GitHub
   - Redémarrer le terminal pour zsh

---

## .gitignore

```
.env
*.pem
*.key
*.log
.dotfiles_backup/
```

---

## README.md

Sections :
1. Description courte (une ligne)
2. Tableau des distributions supportées
3. Arborescence du projet
4. Démarrage rapide (3 commandes : clone, chmod, ./setup.sh)
5. Ce qui est installé (paquets système, Flatpak, outils dev, sécurité)
6. Personnalisation (modifier les dotfiles, ajouter un paquet)

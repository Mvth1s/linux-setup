# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Objectif

Système de scripts bash de configuration automatisée pour Linux.
Les scripts permettent de configurer n'importe quelle nouvelle machine Linux en une seule commande, avec des extras spécifiques à Fedora derrière une détection d'OS.

---

## Arborescence du dépôt

```
setup.sh                        ← menu principal
scripts/
  utils.sh                      ← log_*, cmd_exists, confirm — aucune dépendance
  detect_distro.sh               ← dépend de utils.sh
  install_packages.sh            ← dépend de detect_distro.sh
  setup_dotfiles.sh               ← indépendant
  setup_fish.sh                   ← dépend de detect_distro.sh
  setup_git_ssh.sh                ← indépendant (double identité perso/ETNA)
  setup_security.sh               ← dépend de detect_distro.sh
  setup_dev_tools.sh              ← dépend de detect_distro.sh
  setup_fedora.sh                 ← dépend de detect_distro.sh, no-op si DISTRO_ID != fedora
fastfetch/config.jsonc           ← logo désactivé ("type": "none")
fastfetch/Chibi-Anime-PNG-Transparent-Image.png  ← inutilisée (logo off), gardée telle quelle
ghostty/config                   ← nom exact attendu par ghostty (PAS config.ghostty)
ghostty/shaders/cursor_smear_fade.glsl  ← récupéré de KroneCorylus/ghostty-shader-playground
fedora/                          ← ressources copiées par setup_fedora.sh (snapper + libdnf5-plugin-actions)
  snapper-dnf5-pre
  snapper-dnf5-post
  snapper.actions
zed/settings.json
zed/themes/
zsh/.zshrc                       ← oh-my-posh + zinit (voir note ci-dessous)
zsh/.aliases
fish/config.fish                 ← PATH, greeting off, agent SSH auto
fish/conf.d/aliases.fish         ← alias fish (port de zsh/.aliases)
```

### Note importante sur zsh/.zshrc

Le `.zshrc` utilise **oh-my-posh** (pas starship) et **zinit** (gère automatiquement zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions). Il inclut aussi `PATH lmstudio` et `DOCKER_BUILDKIT=1`. **Ne pas écraser ce fichier.**

### Deux shells cohabitent

- **zsh** reste configuré (`setup_dotfiles.sh`, oh-my-posh + zinit) — non retiré.
- **fish** est le shell proposé comme défaut (`setup_fish.sh`, Fisher + Tide + nvm.fish). C'est fish, pas zsh, qui est lancé directement par Ghostty (`command = fish` dans `ghostty/config`).
- Les deux ont leur propre fichier d'alias (`zsh/.aliases` / `fish/conf.d/aliases.fish`) qu'il faut garder synchronisés fonctionnellement lors de tout ajout d'alias.

---

## Architecture et dépendances entre scripts

```
setup.sh
 ├── source scripts/utils.sh
 ├── source scripts/detect_distro.sh
 └── bash scripts/<module>.sh
```

Chaque sous-script recharge `detect_distro.sh` si `DISTRO_FAMILY` n'est pas défini :
```bash
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$(dirname "$0")/detect_distro.sh"
```

`scripts/setup_fedora.sh` sort immédiatement (`exit 0`) si `$DISTRO_ID != fedora` — il peut être invoqué sans condition depuis `setup.sh`.

---

## Règles communes à tous les scripts

- Shebang : `#!/usr/bin/env bash`
- `set -euo pipefail` dans chaque script
- Toujours vérifier si un outil est déjà installé avant de l'installer (`cmd_exists`)
- Jamais d'`echo` brut : tous les messages passent par les fonctions de `utils.sh`
- Permissions finales : `setup.sh`, `scripts/*.sh` et `fedora/snapper-dnf5-*` → `755` ; dotfiles → `644`
- Idempotence : relancer n'importe quel script ne doit rien casser (vérifications `cmd_exists`, marqueurs de config, `grep` avant ajout dans un fichier partagé, etc.)

---

## scripts/utils.sh

| Fonction | Comportement |
|---|---|
| `log_info <msg>` | `[INFO]` en bleu |
| `log_success <msg>` | `[OK]` en vert |
| `log_warn <msg>` | `[WARN]` en jaune |
| `log_error <msg>` | `[ERROR]` en rouge sur stderr |
| `log_step <msg>` | séparateur visuel bold/cyan |
| `cmd_exists <cmd>` | `command -v "$1" &>/dev/null` |
| `confirm <prompt>` | demande `[y/N]`, retourne 0 si oui |

Variables couleurs ANSI : `RED GREEN YELLOW BLUE CYAN BOLD RESET`

`link_config <src_relatif_repo> <dest>` (backup si `<dest>` existe et n'est pas un symlink, puis `ln -sf`) est redéfinie localement dans chaque script qui en a besoin (`setup_dotfiles.sh`, `setup_fish.sh`) plutôt que factorisée dans `utils.sh` — garder cette convention si un nouveau script a besoin de symlinker des fichiers.

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

### Étape 1 — Mise à jour système
Sur Debian/Ubuntu, utilise `apt-get update`/`upgrade` directement (avec filtrage des lignes `W:`/`N:`) plutôt que `eval "$PKG_UPDATE"`, pour rester résilient aux warnings apt non bloquants. Les autres familles utilisent `eval "$PKG_UPDATE"`.

### Étape 2 — Paquets communs
```
zsh curl wget git htop btop tree unzip zip
ripgrep fzf eza bat tmux neofetch
xclip wl-clipboard jq neovim ranger rsync
net-tools nmap pipx imagemagick
```
`openssh` est résolu par famille (pas un nom de paquet unique) : `openssh-client` (debian), `openssh` (arch), `openssh-clients` (rhel/suse).

Cas particulier Debian/Ubuntu : `bat` s'appelle `batcat` → créer un lien `/usr/local/bin/bat → batcat` si `bat` n'existe pas déjà.

### Fastfetch et Ghostty (installés ici, pas dans un script dédié)
- **fastfetch** : paquet natif sur Arch ; sur les autres familles, binaire récupéré depuis la dernière release GitHub (`fastfetch-linux-<arch>.tar.gz`) et installé dans `/usr/local/bin`.
- **ghostty** : paquet natif sur Arch/RHEL/SUSE ; sur Debian/Ubuntu, tente `apt-get install`, puis `snap install --classic` en repli, sinon `log_warn` avec lien vers la doc d'install binaire.

### Étape 3 — Brave Browser (⚠️ PAS via Flatpak)
```bash
if ! cmd_exists brave-browser; then
  curl -fsS https://dl.brave.com/install.sh | sh
fi
```

### Étape 4 — Spotify
- **Debian/Ubuntu** :
  ```bash
  curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg \
    | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
  echo "deb http://repository.spotify.com stable non-free" \
    | sudo tee /etc/apt/sources.list.d/spotify.list
  sudo apt update && sudo apt install -y spotify-client
  ```
- **Arch** : `$AUR_HELPER -S spotify` (si AUR_HELPER disponible, sinon `log_warn`)
- **Autres familles** : installé via Flatpak (étape 5)

### Étape 5 — Flatpak
1. Installer Flatpak si absent (via le package manager natif)
2. Ajouter Flathub : `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
3. Installer chaque app seulement si absente (`flatpak list --app | grep -q <id>`)

**Liste des apps Flatpak :**
```
com.discordapp.Discord          # Discord
com.protonvpn.www               # ProtonVPN
com.spotify.Client               # Spotify (non-Arch, ou pas d'AUR helper)
im.riot.Riot                    # Element (client Matrix)
io.appflowy.AppFlowy            # AppFlowy (notes / gestion de projets)
me.proton.Mail                  # Proton Mail
org.localsend.localsend_app     # LocalSend (partage fichiers local)
org.onlyoffice.desktopeditors   # OnlyOffice
```

> ⚠️ VSCodium n'est PAS à installer — Zed est l'éditeur principal.

---

## scripts/setup_dotfiles.sh

**Fonction `link_config <src> <dest>`** :
1. Créer le répertoire parent si nécessaire
2. Si `<dest>` existe et n'est pas un symlink → backup dans `~/.dotfiles_backup/<timestamp>/`
3. `ln -sf "<src_absolu>" "<dest>"`

Avant de créer les symlinks, nettoie un éventuel `~/.config/ghostty/config.ghostty` vide qui traînerait à côté du vrai fichier `config` (mauvais nom historique, ignoré par ghostty) ; s'il n'est pas vide, `log_warn` sans le supprimer.

**Symlinks créés** :

| Source (dans le repo) | Destination |
|---|---|
| `fastfetch/` | `~/.config/fastfetch` |
| `ghostty/` | `~/.config/ghostty` |
| `zed/` | `~/.config/zed` |
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.aliases` | `~/.aliases` |

> ⚠️ Ne PAS cloner manuellement zsh-autosuggestions, zsh-syntax-highlighting ou zsh-completions.
> Zinit les gère automatiquement au premier lancement de zsh.

**oh-my-posh** — installé si absent (`curl -s https://ohmyposh.dev/install.sh | bash -s`). ⚠️ Ne PAS installer Starship.

**zinit** — pré-installé si absent dans `~/.local/share/zinit/zinit.git` (s'auto-installe aussi via `.zshrc` au premier lancement).

**PATH** : `export PATH="$HOME/.local/bin:$PATH"` ajouté de façon permanente dans `~/.zshenv` (idempotent, `grep -qxF` avant ajout).

**Nerd Font** : JetBrainsMono Nerd Font installée via `oh-my-posh font install JetBrainsMono` si absente (`fc-list | grep -qi`).

**Shell par défaut (zsh)** : si `$SHELL` n'est pas zsh, propose via `confirm` de lancer `chsh -s zsh`, avec repli `sudo chsh -s zsh "$USER"` si `chsh` échoue (contraintes PAM sur certaines distros).

---

## scripts/setup_fish.sh

Shell alternatif proposé comme défaut, en plus de zsh (voir « Deux shells cohabitent » plus haut).

1. **fish** : installé via `$PKG_INSTALL` si absent.
2. **Fisher** (gestionnaire de plugins fish) : installé via le script officiel si `functions -q fisher` échoue dans `fish -c`.
3. **`jorgebucaran/nvm.fish`** : remplace nvm classique (incompatible avec fish). Installé via `fisher install`.
4. **Tide (`ilancosman/tide@v6`)** : installé via `fisher install`, puis configuré de façon **non interactive** via `tide configure --auto --style=Classic --prompt_colors='True color' --classic_prompt_color=Dark --show_time=No --classic_prompt_separators=Angled --prompt_spacing=Sparse --icons='Many icons' --transient=No --finish='Overwrite your current tide config'`. Un marqueur universel `__linux_setup_tide_configured` évite de relancer la configuration à chaque exécution. En cas d'échec, `log_warn` invite à lancer `tide configure` manuellement plutôt que de bloquer le script.
5. **Symlinks** (via un `link_config` local, identique à celui de `setup_dotfiles.sh`) :
   - `fish/config.fish` → `~/.config/fish/config.fish`
   - `fish/conf.d/aliases.fish` → `~/.config/fish/conf.d/aliases.fish`

   `~/.config/fish/conf.d/` reste un vrai répertoire (pas symlinké dans son ensemble) : Fisher y écrit ses propres fichiers de plugins (tide.fish, nvm.fish…) et ne doit pas polluer le dépôt git.
6. **Shell par défaut** : `confirm` puis `chsh -s fish` → repli `sudo chsh -s fish "$USER"` → repli `sudo usermod -s fish "$USER"`. Ajoute d'abord le chemin de fish à `/etc/shells` si absent (sinon `chsh` le refuse).

### fish/config.fish
Chargé à chaque démarrage (interactif ou non) : `fish_add_path` pour `~/.local/bin`, `$EDITOR`, `$DOCKER_BUILDKIT`. En session interactive : `fish_greeting` vidé, `fastfetch` lancé, et démarrage/chargement automatique de l'agent SSH (voir section Git & SSH ci-dessous) avec garde-fou `set -g __linux_setup_ssh_agent_loaded` pour ne s'exécuter qu'une fois par session.

### fish/conf.d/aliases.fish
Port fonctionnel de `zsh/.aliases` en syntaxe fish (`alias`, `command -q`, `and`/`&&`) : navigation, ls→eza, cat→bat, git, docker, système, `mkcd`. Toute modification d'alias doit être répercutée dans les deux fichiers (zsh et fish) si elle doit s'appliquer aux deux shells.

---

## scripts/setup_git_ssh.sh — double identité perso / ETNA

Pas d'identité Git globale : `user.name`/`user.email` ne sont **jamais** définis dans `~/.gitconfig`. Seuls `init.defaultBranch=main`, `pull.rebase=false`, `color.ui=auto` le sont.

**Deux identités, sélectionnées par répertoire via `includeIf` :**

| Identité | Fichier | Nom | Email | `gitdir` |
|---|---|---|---|---|
| perso | `~/.gitconfig-perso` | Mvth1s | `mag.d3v+github@pm.me` | `~/Documents/Dev/` |
| ETNA | `~/.gitconfig-etna` | Mathis Aguado | `aguado_m@etna-alternance.net` | `~/Documents/ETNA/` |

Ajout idempotent dans `~/.gitconfig` (vérifie la présence du bloc `[includeIf "gitdir:..."]` avant d'ajouter) :
```
[includeIf "gitdir:~/Documents/Dev/"]
    path = ~/.gitconfig-perso
[includeIf "gitdir:~/Documents/ETNA/"]
    path = ~/.gitconfig-etna
```
Pour ajouter une identité supplémentaire : dupliquer ce bloc et le pattern `_generate_key`/`add_ssh_host_block` dans le script.

**Deux clés SSH ed25519, jamais générées sans passphrase** (prompt interactif avec confirmation, boucle si vide ou différente — implémenté via `_prompt_passphrase`, pas via le prompt natif de `ssh-keygen` qui accepte une passphrase vide) :
- `~/.ssh/id_ed25519_github` (commentaire = email perso)
- `~/.ssh/id_ed25519_gitlab_etna` (commentaire = email ETNA)

Permissions : `700` sur `~/.ssh/`, `600` sur chaque clé privée et sur `~/.ssh/config`, `644` sur chaque `.pub`.

**`~/.ssh/config`** (ajout idempotent par bloc, `grep -qE "^Host <alias>\$"` avant d'ajouter) :
```
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_github
    IdentitiesOnly yes

Host gitlab-etna
    HostName rendu-git.etna-alternance.net
    User git
    IdentityFile ~/.ssh/id_ed25519_gitlab_etna
    IdentitiesOnly yes
```

Les deux clés sont ajoutées au ssh-agent en fin de script, et rechargées automatiquement à chaque nouvelle session fish (voir `fish/config.fish`) — pas de copie presse-papiers automatique ici (ambigu avec deux clés) : les deux clés publiques sont juste affichées avec les liens/instructions pour GitHub et le GitLab ETNA.

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
- Si `systemd-resolved` actif → créer `/etc/systemd/resolved.conf.d/quad9.conf` :
  ```ini
  [Resolve]
  DNS=9.9.9.9 149.112.112.112
  FallbackDNS=1.1.1.1 1.0.0.1
  DNSSEC=yes
  DNSOverTLS=opportunistic
  ```
  Puis `sudo systemctl restart systemd-resolved`
- Sinon → backup + écriture directe dans `/etc/resolv.conf`

**Services crash-report** (avec `|| true`) :
```bash
sudo systemctl disable --now apport.service  2>/dev/null || true
sudo systemctl disable --now whoopsie.service 2>/dev/null || true
```

---

## scripts/setup_dev_tools.sh

Chaque installation (Docker, Ollama, Zed) est précédée d'un `check_disk_space <go_requis> <label>` : si l'espace disponible sur `/` est insuffisant, `log_warn` et l'étape est ignorée plutôt que d'échouer bruyamment.

### nvm + Node LTS
```bash
nvm_version=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install --lts && nvm use --lts
```
`set +u`/`set -u` autour du sourcing de `nvm.sh`, qui est incompatible avec `nounset`. Ce nvm classique reste utilisé pour les scripts bash/zsh ; `fish/setup_fish.sh` installe séparément `nvm.fish` pour l'usage interactif sous fish (voir plus haut).

### pnpm (après Node, obligatoire)
```bash
if ! cmd_exists pnpm; then
  npm install -g pnpm
fi
```

### Docker

| Famille | Commande |
|---|---|
| arch | `pacman -S docker docker-compose` |
| debian | `curl -fsSL https://get.docker.com \| sudo sh` + `apt install docker-compose-plugin` |
| rhel | `dnf install -y moby-engine docker-compose` |
| suse | `zypper install docker docker-compose` |

Puis : `sudo systemctl enable --now docker` + `sudo usermod -aG docker "$USER"`

> Sur RHEL/Fedora, `moby-engine` (paquet officiel Fedora) est utilisé plutôt que le dépôt `docker-ce` — non officiellement supporté sur Fedora, et en conflit avec l'installation faite par `scripts/setup_fedora.sh`.

### Ollama / Zed
Installés via leurs scripts officiels (`ollama.com/install.sh`, `zed.dev/install.sh`) si absents, chacun derrière son propre `check_disk_space`.

---

## scripts/setup_fedora.sh — extras Fedora uniquement

Sort immédiatement (`exit 0` + `log_warn`) si `$DISTRO_ID != fedora`. Peut donc être appelé sans condition depuis le menu ou depuis « Tout installer ».

| Étape | Détail |
|---|---|
| RPM Fusion | free + nonfree, installés via l'URL `rpmfusion-{free,nonfree}-release-$(rpm -E %fedora).noarch.rpm`, idempotent via `rpm -q` |
| Docker | `moby-engine` + `docker-compose`, `systemctl enable --now docker`, `usermod -aG docker` (même approche que `setup_dev_tools.sh` sur rhel — volontairement dupliqué pour permettre un usage autonome de ce script) |
| kubectl | paquet `kubernetes-client` |
| yazi | via COPR `lihaohong/yazi`, **remplace `ranger`** (désinstallé si présent) |
| lynis + rkhunter | installés puis `sudo rkhunter --propupd` (base de référence, relancé à chaque exécution) |
| OnlyOffice par défaut | `xdg-mime default org.onlyoffice.desktopeditors.desktop <mime>` pour docx/xlsx/pptx/odt/ods/odp, seulement si le Flatpak OnlyOffice est déjà installé (dépend de `install_packages.sh`) ; LibreOffice désinstallé (`dnf remove -y 'libreoffice*'`) si présent |
| Clavier AZERTY | `gsettings set org.gnome.desktop.input-sources xkb-options "['caps:digits_row']"` (nécessite GNOME/gsettings, sinon `log_warn`) |
| Snapshots Btrfs | uniquement si `findmnt -no FSTYPE /` = `btrfs`. Installe `snapper` + `libdnf5-plugin-actions` (le paquet dnf4 `python3-dnf-plugin-snapper` **ne fonctionne pas** sous dnf5). Voir `fedora/` ci-dessous. |
| Spotify Wayland | `flatpak override --user --nosocket=wayland --socket=x11 com.spotify.Client` (corrige un bug de barre de titre GNOME/Wayland), seulement si le Flatpak est installé |

### fedora/ — snapshots Btrfs automatiques via dnf5

- `fedora/snapper.actions` → copié dans `/etc/dnf/libdnf5-plugins/actions.d/snapper.actions`. Déclare les hooks `pre_transaction`/`post_transaction` du plugin `libdnf5-plugin-actions`, au format `callback:package_filter:direction:options:command`.
- `fedora/snapper-dnf5-pre` → copié dans `/usr/local/bin/`. Crée un snapshot `pre` et renvoie son numéro à l'engine libdnf5 via `echo "tmp.snapper_pre_number=<n>"` (mécanisme de substitution de variables propre au plugin actions, capturé depuis stdout de la commande `pre_transaction`).
- `fedora/snapper-dnf5-post` → copié dans `/usr/local/bin/`. Reçoit ce numéro en `$1` (substitué par l'engine via `'${tmp.snapper_pre_number}'` dans `snapper.actions`) et crée le snapshot `post` correspondant.
- Config snapper `root` : `NUMBER_LIMIT=2`, `NUMBER_LIMIT_IMPORTANT=2`, `NUMBER_MIN_AGE=1800` (appliqués par `sed -i` sur `/etc/snapper/configs/root`), et `snapper-cleanup.timer` activé.

Si l'un de ces trois fichiers dans `fedora/` doit changer de comportement, l'équivalent installé dans `/etc/` et `/usr/local/bin/` ne sera mis à jour qu'au prochain lancement de `setup_fedora.sh` (le script fait un `install -m` à chaque exécution, donc idempotent et toujours à jour après relance).

---

## zsh/.aliases et fish/conf.d/aliases.fish

Les deux fichiers doivent rester équivalents fonctionnellement :
- Navigation : `..`, `...`
- ls → eza avec fallback ls classique
- cat → bat avec fallback
- Git : `g, gs, ga, gc, gp, gl, gd, glog, gco, gb`
- Docker : `d, dc, dps, dpsa, dclean`
- Système : `myip, ports, df, du, free`
- Misc : `reload`, `please`, `mkcd`

---

## ghostty/config

Fichier attendu par ghostty sous le nom exact `config` (pas `config.ghostty` — piège historique : le fichier n'était jamais chargé car symlinké sous le mauvais nom). Points notables :
- `cursor-style = block` (obligatoire pour que `custom-shader` s'applique)
- `custom-shader = shaders/cursor_smear_fade.glsl` (chemin relatif au dossier de config ghostty, donc au dossier `ghostty/` du repo une fois symlinké)
- `command = fish` : lance fish directement au démarrage du terminal, sans dépendre du changement de shell par défaut (`chsh`) qui ne prend effet qu'à la reconnexion
- `window-width = 169`, `window-height = 42` (~70 % d'un écran 1920×1080 en JetBrainsMono Nerd Font Mono 13)
- `background-opacity = 0.85`

---

## setup.sh (menu principal)

1. Sourcer `scripts/utils.sh` puis `scripts/detect_distro.sh`
2. Afficher une bannière ASCII avec le nom du projet et la date
3. Menu interactif :
   ```
   [1] Tout installer
   [2] Paquets système + Flatpak
   [3] Dotfiles
   [4] Git & SSH (identités perso/ETNA)
   [5] Sécurité
   [6] Outils dev
   [7] Shell fish + Tide
   [8] Extras Fedora (RPM Fusion, Docker, snapper…)
   [q] Quitter
   ```
4. Option 1 : enchaîne `install_packages → setup_dotfiles → setup_fish → setup_git_ssh → setup_security → setup_dev_tools`, puis `setup_fedora` **seulement si** `$DISTRO_ID == fedora`.
5. Options 2-8 : lancent le script correspondant directement (`setup_fedora.sh` gère lui-même le no-op hors Fedora).
6. Message de fin avec rappel des actions manuelles : re-login Docker, ajout des deux clés SSH (GitHub + GitLab ETNA), redémarrage du terminal pour fish, vérification de l'identité git utilisée selon le dossier du dépôt.

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

Sections : description courte, distributions supportées, arborescence, démarrage rapide, ce qui est installé (paquets système, Brave, Spotify, apps Flatpak, shells zsh/fish, Git & SSH double identité, sécurité, extras Fedora), actions manuelles restantes (passphrases SSH, shell par défaut, liens SSH GitHub/GitLab ETNA), personnalisation.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Objectif

Système de scripts bash de configuration automatisée pour Linux.
Les scripts permettent de configurer n'importe quelle nouvelle machine Linux en une seule commande, sur 4 familles de distros (Arch, Debian/Ubuntu, Fedora/RHEL, openSUSE), avec un choix de **profil** au lancement — **Workstation** (poste de travail) ou **Gaming** — chacun fonctionnel quelle que soit la distro détectée.

---

## Arborescence du dépôt

```
setup.sh                        ← menu principal (sélection de profil + menu d'installation)
scripts/
  core/
    utils.sh                    ← log_*, cmd_exists, confirm — aucune dépendance
    detect_distro.sh             ← dépend de utils.sh
    detect_gpu.sh                 ← dépend de utils.sh, détection amd/nvidia/intel, non fatale
  packages/
    install_packages.sh          ← dépend de core/detect_distro.sh
  shell/
    setup_dotfiles.sh             ← dépend de core/utils.sh
    setup_fish.sh                  ← dépend de core/detect_distro.sh
  security/
    setup_security.sh              ← dépend de core/detect_distro.sh
  git/
    setup_git_ssh.sh                ← dépend de core/utils.sh (double identité perso/ETNA)
  dev/
    setup_dev_tools.sh               ← dépend de core/detect_distro.sh
  profiles/
    setup_workstation.sh              ← dépend de core/detect_distro.sh, fonctionnel sur les 4 familles
    setup_gaming.sh                    ← dépend de core/detect_distro.sh + core/detect_gpu.sh, fonctionnel sur les 4 familles
fastfetch/config.jsonc           ← logo auto-détecté ("type": "auto")
fastfetch/Chibi-Anime-PNG-Transparent-Image.png  ← inutilisée, gardée telle quelle
ghostty/config                   ← nom exact attendu par ghostty (PAS config.ghostty)
ghostty/shaders/cursor_smear_fade.glsl  ← récupéré de KroneCorylus/ghostty-shader-playground
snapper/                         ← ressources copiées par setup_workstation.sh pour les snapshots Btrfs
  dnf5/                          ← Fedora : plugin libdnf5-plugin-actions
    snapper-dnf5-pre
    snapper-dnf5-post
    snapper.actions
  apt/                           ← Debian/Ubuntu : hooks DPkg::Pre-Invoke/Post-Invoke
    snapper-apt-pre
    snapper-apt-post
    80snapper
zed/settings.json
zed/themes/
zsh/.zshrc                       ← oh-my-posh + zinit (voir note ci-dessous)
zsh/.aliases
fish/config.fish                 ← PATH, greeting off, agent SSH auto, thème (fish_color_*)
fish/conf.d/aliases.fish         ← alias fish (port de zsh/.aliases)
```

> Arch (`snap-pac`) et openSUSE (plugin zypp natif) n'ont besoin d'aucun fichier de ressource pour les snapshots Btrfs — le paquet système s'en charge (voir la section `profiles/setup_workstation.sh` plus bas).

> ⚠️ `fish/` ne doit contenir QUE `config.fish` et `conf.d/aliases.fish` (les deux fichiers symlinkés par `setup_fish.sh`). Tout le reste (`functions/`, `completions/`, `fish_variables*`, `fish_plugins`, `conf.d/_tide_init.fish`, `conf.d/nvm.fish`, `conf.d/fish_frozen_*.fish`) est écrit automatiquement par Fisher ou par fish lui-même sur une machine donnée — jamais à committer (voir `.gitignore` et la section `scripts/shell/setup_fish.sh` ci-dessous).

### Note importante sur zsh/.zshrc

Le `.zshrc` utilise **oh-my-posh** (pas starship) et **zinit** (gère automatiquement zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions). Il inclut aussi `PATH lmstudio` et `DOCKER_BUILDKIT=1`. **Ne pas écraser ce fichier.**

### Deux shells cohabitent

- **zsh** reste configuré (`setup_dotfiles.sh`, oh-my-posh + zinit) — non retiré.
- **fish** est le shell proposé comme défaut (`setup_fish.sh`, Fisher + Tide + nvm.fish). C'est fish, pas zsh, qui est lancé directement par Ghostty (`command = fish` dans `ghostty/config`).
- Les deux ont leur propre fichier d'alias (`zsh/.aliases` / `fish/conf.d/aliases.fish`) qu'il faut garder synchronisés fonctionnellement lors de tout ajout d'alias.

---

## Profils travail / gaming

`setup.sh` demande le profil de la machine **avant** d'afficher le menu d'installation :
```
[1] Workstation (travail)
[2] Gaming
[q] Quitter
```
Ce choix fixe `PROFILE_SCRIPT` (`profiles/setup_workstation.sh` ou `profiles/setup_gaming.sh`) et `PROFILE_LABEL`, utilisés ensuite par le menu (option `[8]` générique) et par « Tout installer ». Pas de flag CLI ni de fichier marqueur persistant : le profil dépend de la machine, pas d'un historique — relancer `setup.sh` repose simplement la question.

Chaque script de profil est **fonctionnel sur les 4 familles de distros** (pas de garde-fou "exit 0 si distro X"), avec une branche par famille à chaque étape. Seuls les mécanismes réellement propres à un outil (le plugin `libdnf5-plugin-actions` de dnf5, RPM Fusion) restent spécifiques à Fedora, mais avec un **équivalent fonctionnel différent** branché pour les autres familles (snap-pac sur Arch, hooks apt sur Debian, plugin zypp natif sur openSUSE — voir `profiles/setup_workstation.sh` plus bas) plutôt qu'un simple `log_warn`.

---

## Architecture et dépendances entre scripts

```
setup.sh
 ├── source scripts/core/utils.sh
 ├── source scripts/core/detect_distro.sh
 ├── select_profile() → fixe PROFILE_SCRIPT / PROFILE_LABEL
 └── bash scripts/<thème>/<module>.sh
```

Chaque sous-script recharge `core/detect_distro.sh` si `DISTRO_FAMILY` n'est pas défini :
```bash
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$(dirname "$0")/../core/detect_distro.sh"
```
`profiles/setup_gaming.sh` recharge en plus `core/detect_gpu.sh` si `GPU_VENDOR` n'est pas défini.

---

## Règles communes à tous les scripts

- Shebang : `#!/usr/bin/env bash`
- `set -euo pipefail` dans chaque script
- Toujours vérifier si un outil est déjà installé avant de l'installer (`cmd_exists`)
- Jamais d'`echo` brut : tous les messages passent par les fonctions de `utils.sh`
- Toute commande réseau à risque (`curl | sh`, `git clone`, ajout de dépôt tiers) est entourée d'un `if`/`else` avec `log_warn` en cas d'échec — jamais une instruction nue qui ferait mourir tout le script sous `set -e` en cas d'aléa réseau
- Invocation de `$PKG_INSTALL` toujours via le pattern `IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"; "${_install_cmd[@]}" <paquet>` (jamais `eval`)
- Permissions finales : `setup.sh`, `scripts/**/*.sh` et `snapper/{dnf5,apt}/{snapper-*,*.actions}` (hors `80snapper`, un fichier de config) → `755` ; dotfiles → `644`
- Idempotence : relancer n'importe quel script ne doit rien casser (vérifications `cmd_exists`, marqueurs de config, `grep` avant ajout dans un fichier partagé, etc.)

---

## scripts/core/utils.sh

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

`link_config <src_relatif_repo> <dest>` est redéfinie localement dans chaque script qui en a besoin (`shell/setup_dotfiles.sh`, `shell/setup_fish.sh`) plutôt que factorisée dans `utils.sh` — garder cette convention si un nouveau script a besoin de symlinker des fichiers. Comportement :
1. Créer le répertoire parent de `<dest>` si nécessaire
2. Si `<dest>` existe et n'est pas un symlink → backup dans `~/.dotfiles_backup/<timestamp>/`, **puis `rm -rf "<dest>"`** — un vrai dossier n'est pas remplacé par `ln -sf` (le lien serait créé à l'intérieur), il doit être supprimé explicitement après le backup
3. `ln -sf "<src_absolu>" "<dest>"`

---

## scripts/core/detect_distro.sh

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

## scripts/core/detect_gpu.sh

Détection du vendeur GPU via `lspci -nn` (VGA compatible controller / 3D controller), par ID PCI plutôt que par texte (robuste face aux traductions locales de `lspci`) :

| ID PCI | `GPU_VENDOR` |
|---|---|
| `[10de]` | `nvidia` |
| `[1002]` | `amd` |
| `[8086]` | `intel` |
| autre / `lspci` absent | `unknown` (non fatal, `log_warn` si `lspci` manque) |

Variable exportée : `GPU_VENDOR`. Sourcé uniquement par `profiles/setup_gaming.sh` (les pilotes GPU ne concernent pas le profil Workstation).

---

## scripts/packages/install_packages.sh

### Étape 1 — Mise à jour système
Sur Debian/Ubuntu, utilise `apt-get update`/`upgrade` directement (avec filtrage des lignes `W:`/`N:`) plutôt que `eval "$PKG_UPDATE"`, pour rester résilient aux warnings apt non bloquants. Les autres familles utilisent `eval "$PKG_UPDATE"` (seule invocation `eval` restante du fichier — sans argument variable interpolé, donc hors du fix `eval`→array ci-dessous).

### Étape 2 — Paquets communs
```
zsh curl wget git htop btop tree unzip zip
ripgrep fzf eza bat tmux neofetch
xclip wl-clipboard jq neovim ranger rsync
net-tools nmap pipx imagemagick
```
`openssh` est résolu par famille (pas un nom de paquet unique) : `openssh-client` (debian), `openssh` (arch), `openssh-clients` (rhel/suse).

Cas particulier Debian/Ubuntu : `bat` s'appelle `batcat` → créer un lien `/usr/local/bin/bat → batcat` si `bat` n'existe pas déjà.

### Fastfetch, Ghostty et gh (installés ici, pas dans un script dédié)
- **fastfetch** : paquet natif sur Arch (`IFS=' ' read -ra` + array, pas `eval`) ; sur les autres familles, binaire récupéré depuis la dernière release GitHub (`fastfetch-linux-<arch>.tar.gz`) et installé dans `/usr/local/bin`. Le téléchargement et les deux tentatives d'extraction (`tar` direct, puis `tar --wildcards -O` en repli) sont dans un seul `if`/`else` : si les deux échouent, `log_warn "fastfetch : échec du téléchargement/extraction du binaire"` au lieu de tuer le script sous `set -e`.
- **ghostty** : paquet natif sur Arch/RHEL/SUSE ; sur Debian/Ubuntu, tente `apt-get install`, puis `snap install --classic` en repli, sinon `log_warn` avec lien vers la doc d'install binaire.
- **gh** (GitHub CLI) : paquet `github-cli` sur Arch, `gh` natif sur SUSE ; sur Debian et RHEL, tente d'abord le paquet natif (`apt`/`dnf`), et si absent ajoute le dépôt officiel GitHub (`cli.github.com/packages/...`) avant réinstallation — toute la séquence d'ajout de dépôt (clé, sources list, update, install) est dans un seul `if`/`else` avec `log_warn` de repli.

### Étape 3 — Brave Browser (⚠️ PAS via Flatpak)
```bash
if ! cmd_exists brave-browser; then
  if curl -fsS https://dl.brave.com/install.sh | sh; then
    log_success "Brave Browser installé"
  else
    log_warn "Brave : échec de l'installation (réseau ?)"
  fi
fi
```

### Étape 4 — Native (AUR) vs Flatpak : Spotify, Discord, suite Proton
Fonction `install_native_or_flatpak <paquet_aur> <id_flatpak> <label>` :
- Arch + `AUR_HELPER` disponible → installe le paquet AUR natif (`pacman -Qi` pour vérifier la présence avant, idempotent)
- Sinon → ajoute `<label>` à `FLATPAK_APPS[<id_flatpak>]` pour l'étape 5 (Arch sans AUR helper : `log_warn` avant le repli)
- Si `<id_flatpak>` est une chaîne vide → pas de Flatpak connu pour cette appli : `log_warn` invitant à une installation manuelle plutôt qu'un `flatpak install` voué à l'échec

Appliqué à :
```bash
install_native_or_flatpak spotify              com.spotify.Client      "Spotify"
install_native_or_flatpak discord              com.discordapp.Discord  "Discord"
install_native_or_flatpak proton-vpn-gtk-app   com.protonvpn.www       "ProtonVPN"
install_native_or_flatpak proton-mail          me.proton.Mail          "Proton Mail"
install_native_or_flatpak proton-authenticator ""                      "Proton Authenticator"
```
Proton Authenticator n'a pas d'équivalent sur Flathub (vérifié via `flatpak remote-info` — pas de `me.proton.authenticator`) : AUR uniquement pour l'instant.

### Étape 5 — Flatpak
1. Installer Flatpak si absent (via le package manager natif)
2. Ajouter Flathub : `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
3. `FLATPAK_APPS` est pré-rempli avec les apps toujours-Flatpak, puis complété par `install_native_or_flatpak` (étape 4) pour les apps qui n'ont pas pu être installées nativement
4. Installer chaque app seulement si absente (`flatpak list --app | grep -q <id>`)

**Apps toujours-Flatpak (statiques dans `FLATPAK_APPS`) :**
```
im.riot.Riot                    # Element (client Matrix)
io.appflowy.AppFlowy            # AppFlowy (notes / gestion de projets)
org.localsend.localsend_app     # LocalSend (partage fichiers local)
org.onlyoffice.desktopeditors   # OnlyOffice
```
Discord, ProtonVPN, Proton Mail, Proton Authenticator et Spotify n'apparaissent dans `FLATPAK_APPS` que si `install_native_or_flatpak` (étape 4) les y a ajoutés (pas d'AUR helper, ou famille non-Arch).

> ⚠️ VSCodium n'est PAS à installer — Zed est l'éditeur principal.

---

## scripts/shell/setup_dotfiles.sh

**Fonction `link_config <src> <dest>`** : voir `scripts/core/utils.sh` ci-dessus pour le détail des 3 étapes (dont le `rm -rf` sur un vrai dossier préexistant).

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

**oh-my-posh** — installé si absent (`curl -s https://ohmyposh.dev/install.sh | bash -s`, dans un `if`/`else` avec `log_warn` en cas d'échec réseau). ⚠️ Ne PAS installer Starship.

**zinit** — pré-installé si absent dans `~/.local/share/zinit/zinit.git` (`git clone` dans un `if`/`else` avec `log_warn` en cas d'échec ; s'auto-installe aussi via `.zshrc` au premier lancement).

**PATH** : `export PATH="$HOME/.local/bin:$PATH"` ajouté de façon permanente dans `~/.zshenv` (idempotent, `grep -qxF` avant ajout).

**Nerd Font** : JetBrainsMono Nerd Font installée via `oh-my-posh font install JetBrainsMono` si absente (`fc-list | grep -qi`).

**Shell par défaut (zsh)** : si `$SHELL` n'est pas zsh, propose via `confirm` de lancer `chsh -s zsh`, avec repli `sudo chsh -s zsh "$USER"` si `chsh` échoue (contraintes PAM sur certaines distros).

---

## scripts/shell/setup_fish.sh

Shell alternatif proposé comme défaut, en plus de zsh (voir « Deux shells cohabitent » plus haut).

1. **fish** : installé via `$PKG_INSTALL` si absent.
2. **Fisher** (gestionnaire de plugins fish) : installé via le script officiel si `functions -q fisher` échoue dans `fish -c` (dans un `if`/`else` avec `log_warn` en cas d'échec).
3. **`jorgebucaran/nvm.fish`** : remplace nvm classique (incompatible avec fish). Installé via `fisher install` (même garde `if`/`else`).
4. **Tide (`ilancosman/tide@v6`)** : installé via `fisher install`, puis configuré de façon **non interactive** via `tide configure --auto --style=Classic --prompt_colors='True color' --classic_prompt_color=Darkest --show_time='24-hour format' --classic_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Sharp --powerline_prompt_style='Two lines, frame' --prompt_connection=Solid --powerline_right_prompt_frame=Yes --prompt_connection_andor_frame_color=Darkest --prompt_spacing=Sparse --icons='Many icons' --transient=No --finish='Overwrite your current tide config'` (prompt encadré sur deux lignes, aligné sur le PC de référence). Un marqueur universel `__linux_setup_tide_configured` évite de relancer la configuration à chaque exécution. En cas d'échec, `log_warn` invite à lancer `tide configure` manuellement plutôt que de bloquer le script.
5. **Symlinks** (via un `link_config` local, identique à celui de `setup_dotfiles.sh`) :
   - `fish/config.fish` → `~/.config/fish/config.fish`
   - `fish/conf.d/aliases.fish` → `~/.config/fish/conf.d/aliases.fish`

   `~/.config/fish/conf.d/` reste un vrai répertoire (pas symlinké dans son ensemble) : Fisher y écrit ses propres fichiers de plugins (tide.fish, nvm.fish…) et ne doit pas polluer le dépôt git — ces fichiers, ainsi que `functions/`, `completions/`, `fish_variables*`, `fish_plugins` et les `fish_frozen_*.fish` générés par fish lors d'une montée de version, sont exclus via `.gitignore`.
6. **Shell par défaut** : `confirm` puis `chsh -s fish` → repli `sudo chsh -s fish "$USER"` → repli `sudo usermod -s fish "$USER"`. Ajoute d'abord le chemin de fish à `/etc/shells` si absent (sinon `chsh` le refuse).

### fish/config.fish
Chargé à chaque démarrage (interactif ou non) : `fish_add_path` pour `~/.local/bin` et `~/.lmstudio/bin`, `$EDITOR`, `$DOCKER_BUILDKIT`, `fish_history_max`, et le thème de coloration syntaxique (`fish_color_*` / `fish_pager_color_*`, porté en dur ici pour rester reproductible sur une nouvelle machine — voir note ci-dessous). En session interactive uniquement : `fish_greeting` vidé, `fastfetch` lancé (`command -q fastfetch` avant), et démarrage/chargement automatique de l'agent SSH (voir section Git & SSH ci-dessous) avec garde-fou non exporté `set -g __linux_setup_ssh_agent_loaded` pour ne s'exécuter qu'une fois par session (et ne pas polluer l'environnement des sous-processus).

> Le thème (`fish_color_*`) et les key-bindings ne doivent JAMAIS être repris depuis les fichiers `fish_frozen_*.fish` générés par fish — ils sont ignorés par git. Toute personnalisation de thème doit être ajoutée directement en dur dans `fish/config.fish` (`set -g fish_color_...`) pour rester reproductible sur une nouvelle machine.

### fish/conf.d/aliases.fish
Port fonctionnel de `zsh/.aliases` en syntaxe fish (`alias`, `command -q`, `and`/`&&`) : navigation, ls→eza, cat→bat, git, docker, système, `mkcd`. Toute modification d'alias doit être répercutée dans les deux fichiers (zsh et fish) si elle doit s'appliquer aux deux shells — voir la liste exhaustive dans la section `zsh/.aliases et fish/conf.d/aliases.fish` plus bas.

---

## scripts/git/setup_git_ssh.sh — double identité perso / ETNA

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

La passphrase est transmise à `ssh-keygen` via `SSH_ASKPASS`/`SSH_ASKPASS_REQUIRE=force` (script temporaire `chmod 700` qui l'imprime depuis une variable d'env) plutôt qu'en argument `-N` : un argument de ligne de commande est visible par d'autres utilisateurs locaux via `ps`/`/proc/<pid>/cmdline`, une variable d'environnement ne l'est pas. **Nécessite OpenSSH ≥ 8.4.**

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

**ssh-agent** : réutilise un agent déjà actif s'il est joignable (`_agent_reachable` : `SSH_AUTH_SOCK` défini + `ssh-add -l` retourne 0 ou 1) plutôt que d'en spawn un nouveau à chaque exécution — évite l'accumulation de process `ssh-agent` orphelins quand le script est relancé (idempotence). Les deux clés sont ajoutées à l'agent (existant ou nouveau) en fin de script, et rechargées automatiquement à chaque nouvelle session fish (voir `fish/config.fish`) — pas de copie presse-papiers automatique ici (ambigu avec deux clés) : les deux clés publiques sont juste affichées avec les liens/instructions pour GitHub et le GitLab ETNA.

---

## scripts/security/setup_security.sh

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
- Sinon → écriture directe dans `/etc/resolv.conf`, avec backup **seulement si le contenu diffère réellement** (`diff -q` contre le contenu cible) — sinon pas de backup à chaque relance. Les backups sont purgés pour ne garder que les 3 derniers (`ls -1t /etc/resolv.conf.backup.* | tail -n +4 | xargs -r sudo rm -f`).

**Services crash-report** (avec `|| true`) :
```bash
sudo systemctl disable --now apport.service  2>/dev/null || true
sudo systemctl disable --now whoopsie.service 2>/dev/null || true
```

---

## scripts/dev/setup_dev_tools.sh

Chaque installation (Docker, Ollama, Zed) est précédée d'un `check_disk_space <go_requis> <label>` : si l'espace disponible sur `/` est insuffisant, `log_warn` et l'étape est ignorée plutôt que d'échouer bruyamment.

### nvm + Node LTS
```bash
nvm_version="$(curl -fsS https://api.github.com/repos/nvm-sh/nvm/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4 || true)"
[[ -z "$nvm_version" ]] && nvm_version="v0.40.1"   # repli si l'API GitHub échoue/rate-limite
curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
nvm install --lts && nvm use --lts
```
L'installation de nvm (`curl | bash`) est entourée d'un `if`/`else` : en cas d'échec, `log_warn` et tout le bloc Node/pnpm qui suit est ignoré (`cmd_exists nvm` re-vérifié avant chaque étape) plutôt que de tenter d'utiliser une fonction `nvm` qui n'existe pas.

`set +u`/`set -u` autour du sourcing de `nvm.sh`, qui est incompatible avec `nounset`. Ce nvm classique reste utilisé pour les scripts bash/zsh ; `shell/setup_fish.sh` installe séparément `nvm.fish` pour l'usage interactif sous fish (voir plus haut).

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
| debian | `curl -fsSL https://get.docker.com \| sudo sh` (dans un `if`/`else`) + `apt install docker-compose-plugin` |
| rhel | `dnf install -y moby-engine docker-compose` |
| suse | `zypper install docker docker-compose` |

Puis, seulement si `cmd_exists docker` : `sudo systemctl enable --now docker` + `sudo usermod -aG docker "$USER"`.

> Sur RHEL/Fedora, `moby-engine` (paquet officiel Fedora) est utilisé plutôt que le dépôt `docker-ce` — non officiellement supporté sur Fedora, et en conflit avec l'installation faite par `scripts/profiles/setup_workstation.sh`.

### Ollama / Zed
Installés via leurs scripts officiels (`ollama.com/install.sh`, `zed.dev/install.sh`) si absents, chacun derrière son propre `check_disk_space` et un `if`/`else` avec `log_warn` en cas d'échec réseau.

---

## scripts/profiles/setup_workstation.sh — extras "travail", 4 familles

Renommé depuis l'ancien `setup_fedora.sh`. Plus de garde-fou "exit si pas Fedora" : chaque étape a une branche par `$DISTRO_FAMILY`.

| Étape | Fedora (rhel) | Arch | Debian/Ubuntu | openSUSE |
|---|---|---|---|---|
| Dépôts non-libres | RPM Fusion free+nonfree (`rpm -q` idempotent) | rien à faire (AUR couvre déjà) | détecte `contrib`/`non-free`/`non-free-firmware` dans les sources APT, `log_warn` + lien doc si absents (pas d'édition automatique des sources — trop risqué à faire sans confirmation exacte du format) | ajoute le dépôt Packman (`zypper ar`, URL Tumbleweed ou Leap selon `/etc/os-release`) |
| Docker | `moby-engine` + `docker-compose` | `pacman` | `get.docker.com` (guardé) + `docker-compose-plugin` | `zypper` |
| kubectl | `kubernetes-client` (dnf) | paquet officiel, sinon AUR `kubectl-bin` | dépôt officiel `pkgs.k8s.io` (clé + sources.list.d, à bumper périodiquement sur la version mineure) | `kubernetes-client` (zypper) |
| yazi (remplace `ranger`) | COPR `lihaohong/yazi` | paquet officiel | binaire de la dernière release GitHub (musl, même stratégie que `install_fastfetch`) | idem Debian |
| lynis + rkhunter | `$PKG_INSTALL` (paquets natifs sur les 4 familles) puis `rkhunter --propupd` à chaque exécution | — | — | — |
| OnlyOffice par défaut | `xdg-mime` (agnostique de la distro), seulement si le Flatpak est déjà installé | — | — | — |
| Suppression LibreOffice | détection via `cmd_exists libreoffice \|\| cmd_exists soffice` (agnostique), suppression par le gestionnaire natif | | | |
| Clavier AZERTY | `gsettings` (agnostique, nécessite GNOME, sinon `log_warn`) | | | |
| Snapshots Btrfs | mécanisme `libdnf5-plugin-actions` (voir `snapper/dnf5/`) | `snapper snap-pac` — hooks pacman natifs, aucun fichier de ressource nécessaire | `snapper` + hooks `DPkg::Pre-Invoke`/`Post-Invoke` (voir `snapper/apt/`) | `snapper` (+ `snapper-zypp-plugin` si disponible séparément) — plugin zypp natif sur une install Btrfs standard |
| Correctif Spotify Wayland | `flatpak override` (agnostique, seulement si le Flatpak Spotify est installé) | | | |

Toujours conditionné à `findmnt -no FSTYPE / = btrfs` pour l'étape snapshots. Réglages communs aux 4 familles une fois le mécanisme en place : `NUMBER_LIMIT=2`, `NUMBER_LIMIT_IMPORTANT=2`, `NUMBER_MIN_AGE=1800` (via `sed -i` sur `/etc/snapper/configs/root`), et `snapper-cleanup.timer` activé.

### snapper/ — mécanismes de snapshot par famille

- `snapper/dnf5/snapper.actions` → copié dans `/etc/dnf/libdnf5-plugins/actions.d/snapper.actions`. Déclare les hooks `pre_transaction`/`post_transaction` du plugin `libdnf5-plugin-actions`, au format `callback:package_filter:direction:options:command`.
- `snapper/dnf5/snapper-dnf5-pre` → copié dans `/usr/local/bin/`. Crée un snapshot `pre` et renvoie son numéro à l'engine libdnf5 via `echo "tmp.snapper_pre_number=<n>"` (mécanisme de substitution de variables propre au plugin actions).
- `snapper/dnf5/snapper-dnf5-post` → copié dans `/usr/local/bin/`. Reçoit ce numéro en `$1` (substitué par l'engine via `'${tmp.snapper_pre_number}'`) et crée le snapshot `post` correspondant.
- `snapper/apt/80snapper` → copié dans `/etc/apt/apt.conf.d/80snapper`. Déclare `DPkg::Pre-Invoke`/`DPkg::Post-Invoke` pointant vers les deux scripts ci-dessous.
- `snapper/apt/snapper-apt-pre` → copié dans `/usr/local/bin/`. Crée un snapshot `pre` et écrit son numéro dans `/run/snapper-apt-pre-number` — pas de mécanisme de substitution de variables côté apt/dpkg, contrairement à libdnf5-plugin-actions, d'où ce fichier d'état temporaire.
- `snapper/apt/snapper-apt-post` → copié dans `/usr/local/bin/`. Lit ce fichier, crée le snapshot `post` correspondant, puis le supprime.
- Arch (`snap-pac`) et openSUSE (plugin zypp natif) : aucun fichier de ressource nécessaire, le paquet système fournit directement le mécanisme.

Si l'un des fichiers dans `snapper/` doit changer de comportement, l'équivalent installé dans `/etc/` et `/usr/local/bin/` ne sera mis à jour qu'au prochain lancement de `setup_workstation.sh` (le script fait un `install -m` à chaque exécution, donc idempotent et toujours à jour après relance).

---

## scripts/profiles/setup_gaming.sh — extras "gaming", 4 familles

Nouveau script, jamais appelé automatiquement — uniquement via le choix de profil Gaming dans `setup.sh` (menu `[8]`, ou "Tout installer" si ce profil est sélectionné).

| Étape | Fedora (rhel) | Arch | Debian/Ubuntu | openSUSE |
|---|---|---|---|---|
| Support 32-bit | non nécessaire (paquets 32-bit déjà disponibles) | active `[multilib]` dans `/etc/pacman.conf` si absent | `dpkg --add-architecture i386` si absent | non nécessaire |
| Pilotes GPU (`$GPU_VENDOR` via `core/detect_gpu.sh`) | `mesa-vulkan-drivers` (amd/intel) ; `akmod-nvidia` si RPM Fusion nonfree déjà actif, sinon `log_warn` vers le profil Workstation | `vulkan-radeon`/`vulkan-intel`/`nvidia-open` + variantes `lib32-*` | `mesa-vulkan-drivers` (amd/intel) ; `nvidia-driver firmware-misc-nonfree` (nvidia, nécessite contrib/non-free) | `Mesa-vulkan-drivers` (amd/intel) ; NVIDIA non automatisé, `log_warn` + lien doc |
| Steam / Lutris / Heroic | Flatpak (`com.valvesoftware.Steam`, `net.lutris.Lutris`, `com.heroicgameslauncher.hgl`) | natif (`pacman` + AUR pour Heroic) | Flatpak | Flatpak |
| Stack Wine | paquets Fedora natifs (`wine winetricks`) | `wine-staging wine-gecko wine-mono winetricks` (dépôts officiels) + `protontricks` AUR | dépôt officiel WineHQ (clé + sources.list.d) + `winehq-staging` | `wine winetricks` via zypper (Packman) |
| `protontricks` (hors Arch) | `pipx install protontricks` (repli) | AUR | `pipx install protontricks` (repli) | `pipx install protontricks` (repli) |
| GameMode + MangoHud | paquets natifs (`log_warn` si absents sur une version trop ancienne) | `gamemode lib32-gamemode mangohud lib32-mangohud` | paquets natifs | paquets natifs |
| Gestionnaire Proton | Flatpak ProtonUp-Qt (`net.davidotek.pupgui2`) | AUR `protonplus` | Flatpak ProtonUp-Qt | Flatpak ProtonUp-Qt |

Écrit dès le départ avec le même niveau de robustesse que les fixes de l'audit : jamais de `curl | sh` nu, toujours `$PKG_INSTALL` en array (jamais `eval`).

---

## zsh/.aliases et fish/conf.d/aliases.fish

Les deux fichiers doivent rester équivalents fonctionnellement :
- Navigation : `..`, `...`
- ls → eza avec fallback ls classique (`ls, ll, la, lt`, + `lth` côté fish)
- cat → bat avec fallback
- Git : `gs, ga, gc, gcm, gcam, gp, gpl, gfp, gl (log), gr, gco, gcob, gcod, gcom, gb, gbr, gba, gbd, gbD, gbm, gst, gstp, gstl, gd, gds, grs, grb, gm, gsw, gswc`
- Docker : `d, dc, dcu, dcd, dps, dlogs`
- Système : `myip, ports, df, du, free`
- Misc : `reload`, `please`, `ssh` (force `TERM=xterm-256color`), `mkcd`

> `gl` = `git log --oneline --graph --decorate` (pas `git pull`, qui est `gpl`). Pas d'alias `glog` séparé ni d'alias bare `g` — supprimés lors de l'alignement zsh/fish.

---

## ghostty/config

Fichier attendu par ghostty sous le nom exact `config` (pas `config.ghostty` — piège historique : le fichier n'était jamais chargé car symlinké sous le mauvais nom). Points notables :
- `cursor-style = block` (obligatoire pour que `custom-shader` s'applique)
- `custom-shader = shaders/cursor_smear_fade.glsl` (chemin relatif au dossier de config ghostty, donc au dossier `ghostty/` du repo une fois symlinké)
- `command = fish` : lance fish directement au démarrage du terminal, sans dépendre du changement de shell par défaut (`chsh`) qui ne prend effet qu'à la reconnexion
- `window-width = 169`, `window-height = 42` (~70 % d'un écran 1920×1080 en JetBrainsMono Nerd Font Mono 13)
- `background-opacity = 0.93`
- `shell-integration-features = no-cursor,sudo,title` : `no-cursor` désactive le forçage du curseur en barre au prompt (comportement par défaut de ghostty avec `cursor`) pour garder le curseur en `block` en permanence, y compris pendant la saisie — préférence explicite, l'animation du shader s'applique alors au curseur block plutôt qu'à une barre.

---

## setup.sh (menu principal)

1. Sourcer `scripts/core/utils.sh` puis `scripts/core/detect_distro.sh`
2. Afficher une bannière ASCII avec le nom du projet et la date
3. `select_profile()` — demande le profil (voir « Profils travail / gaming » plus haut), fixe `PROFILE_SCRIPT`/`PROFILE_LABEL`
4. Menu interactif :
   ```
   [1] Tout installer
   [2] Paquets système + Flatpak
   [3] Dotfiles
   [4] Git & SSH (identités perso/ETNA)
   [5] Sécurité
   [6] Outils dev
   [7] Shell fish + Tide
   [8] <PROFILE_LABEL>          ← "Extras Workstation" ou "Profil Gaming"
   [q] Quitter
   ```
5. Option 1 : enchaîne `packages/install_packages.sh → shell/setup_dotfiles.sh → shell/setup_fish.sh → git/setup_git_ssh.sh → security/setup_security.sh → dev/setup_dev_tools.sh → $PROFILE_SCRIPT` (systématique, plus de condition sur `DISTRO_ID` — chaque script de profil gère lui-même toutes les familles).
6. Options 2-8 : lancent le script correspondant directement (`run_script "$PROFILE_SCRIPT"` pour l'option 8).
7. Message de fin avec rappel des actions manuelles : re-login Docker, ajout des deux clés SSH (GitHub + GitLab ETNA), redémarrage du terminal pour fish, vérification de l'identité git utilisée selon le dossier du dépôt.

---

## .gitignore

```
.env
*.pem
*.key
*.log
.dotfiles_backup/

# fish : fichiers gérés par Fisher / l'état runtime de fish, jamais à committer
fish/functions/
fish/completions/
fish/fish_variables*
fish/fish_plugins
fish/conf.d/_tide_init.fish
fish/conf.d/nvm.fish
fish/conf.d/fish_frozen_*.fish
```

---

## README.md

Sections : description courte, distributions supportées, arborescence, démarrage rapide, choix du profil (Workstation/Gaming), ce qui est installé (paquets système, Brave, Spotify/Discord/Proton natif vs Flatpak, apps Flatpak, shells zsh/fish, Git & SSH double identité, sécurité, extras Workstation, extras Gaming), actions manuelles restantes (passphrases SSH, shell par défaut, liens SSH GitHub/GitLab ETNA), personnalisation.

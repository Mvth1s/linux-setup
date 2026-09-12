#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log_info()    { printf "${BLUE}[INFO]${RESET}  %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
log_warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
log_error()   { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }
log_step()    { printf "\n${BOLD}${CYAN}══════════════════════════════════════════\n  %s\n══════════════════════════════════════════${RESET}\n\n" "$*"; }
cmd_exists()  { command -v "$1" &>/dev/null; }

confirm() {
    local prompt="${1:-Continuer ?}"
    printf "%s [y/N] " "$prompt"
    read -r _reply
    [[ "$_reply" =~ ^[Yy]$ ]]
}

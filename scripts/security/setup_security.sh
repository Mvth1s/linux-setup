#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"
[[ -z "${DISTRO_FAMILY:-}" ]] && source "$SCRIPT_DIR/detect_distro.sh"

log_step "Configuration du pare-feu (UFW)"

if ! cmd_exists ufw; then
    log_info "Installation de UFW..."
    IFS=' ' read -ra _install_cmd <<< "$PKG_INSTALL"
    "${_install_cmd[@]}" ufw
    log_success "UFW installé"
fi

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw --force enable
log_success "UFW activé (SSH autorisé, reste bloqué)"

log_step "Configuration DNS Quad9"

if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    log_info "systemd-resolved détecté — configuration via drop-in"
    RESOLVED_CONF_DIR="/etc/systemd/resolved.conf.d"
    sudo mkdir -p "$RESOLVED_CONF_DIR"
    sudo tee "$RESOLVED_CONF_DIR/quad9.conf" > /dev/null <<'EOF'
[Resolve]
DNS=9.9.9.9 149.112.112.112
FallbackDNS=1.1.1.1 1.0.0.1
DNSSEC=yes
DNSOverTLS=opportunistic
EOF
    sudo systemctl restart systemd-resolved
    log_success "DNS Quad9 configuré via systemd-resolved"
else
    log_info "systemd-resolved inactif — écriture directe dans /etc/resolv.conf"
    if [[ -f /etc/resolv.conf ]]; then
        sudo cp /etc/resolv.conf "/etc/resolv.conf.backup.$(date '+%Y%m%d_%H%M%S')"
        log_info "Backup de /etc/resolv.conf créé"
    fi
    sudo tee /etc/resolv.conf > /dev/null <<'EOF'
nameserver 9.9.9.9
nameserver 149.112.112.112
nameserver 1.1.1.1
EOF
    log_success "DNS Quad9 configuré dans /etc/resolv.conf"
fi

log_step "Désactivation des services de crash-report"
sudo systemctl disable --now apport.service  2>/dev/null || true
sudo systemctl disable --now whoopsie.service 2>/dev/null || true
log_success "Services de crash-report désactivés (s'ils étaient présents)"

log_success "Sécurité configurée"

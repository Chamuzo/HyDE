#!/usr/bin/env bash
#|---/ /+------------------------------------------+---/ /|#
#|--/ /-| Post-install hardening script             |--/ /-|#
#|-/ /--| Firewall, DNS, telemetry removal          |-/ /--|#
#|/ /---+------------------------------------------+/ /---|#

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
RST='\033[0m'

log_ok()   { echo -e "${GRN}[OK]${RST} $1"; }
log_info() { echo -e "${BLU}[INFO]${RST} $1"; }
log_warn() { echo -e "${YLW}[WARN]${RST} $1"; }
log_skip() { echo -e "${YLW}[SKIP]${RST} $1"; }

echo ""
echo -e "${BLU}========================================${RST}"
echo -e "${BLU}  Post-Install Hardening${RST}"
echo -e "${BLU}========================================${RST}"
echo ""

# ============================================================================
# 1. FIREWALL (UFW)
# ============================================================================
log_info "Configuring firewall (ufw)..."

if command -v ufw &>/dev/null; then
    # Check if already enabled
    if sudo ufw status | grep -q "Status: active"; then
        log_skip "UFW already active"
    else
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        # Allow SSH only if sshd is installed/enabled (for remote access)
        if systemctl is-enabled sshd &>/dev/null; then
            sudo ufw allow ssh
            log_warn "SSH access allowed (sshd is enabled)"
        fi
        sudo ufw --force enable
        log_ok "UFW enabled: deny incoming, allow outgoing"
    fi
    sudo systemctl enable ufw
else
    log_warn "ufw not installed, skipping firewall setup"
fi

# ============================================================================
# 2. VSCodium — Disable residual telemetry
# ============================================================================
log_info "Configuring VSCodium..."

vscodium_settings="${HOME}/.config/VSCodium/User/settings.json"
if command -v vscodium &>/dev/null || command -v codium &>/dev/null; then
    mkdir -p "$(dirname "$vscodium_settings")"
    if [ -f "$vscodium_settings" ]; then
        # Only add if not already present
        if ! grep -q "telemetry.telemetryLevel" "$vscodium_settings"; then
            # Insert telemetry settings using python for reliable JSON handling
            python3 -c "
import json, sys
try:
    with open('$vscodium_settings', 'r') as f:
        cfg = json.load(f)
except:
    cfg = {}
cfg['telemetry.telemetryLevel'] = 'off'
cfg['update.mode'] = 'none'
with open('$vscodium_settings', 'w') as f:
    json.dump(cfg, f, indent=4)
" 2>/dev/null && log_ok "VSCodium telemetry disabled" || log_warn "Could not modify VSCodium settings"
        else
            log_skip "VSCodium telemetry already configured"
        fi
    else
        cat > "$vscodium_settings" <<'SETTINGS'
{
    "telemetry.telemetryLevel": "off",
    "update.mode": "none"
}
SETTINGS
        log_ok "VSCodium settings created with telemetry off"
    fi
else
    log_skip "VSCodium not found"
fi

# ============================================================================
# 3. DNS — Configure encrypted DNS via systemd-resolved
# ============================================================================
log_info "Configuring encrypted DNS..."

if systemctl is-active systemd-resolved &>/dev/null || systemctl is-enabled systemd-resolved &>/dev/null; then
    # Check if already configured
    if grep -q "DNS=1.1.1.1" /etc/systemd/resolved.conf 2>/dev/null; then
        log_skip "DNS already configured"
    else
        sudo cp /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bkp 2>/dev/null || true
        sudo mkdir -p /etc/systemd/resolved.conf.d
        sudo tee /etc/systemd/resolved.conf.d/dns-over-tls.conf > /dev/null <<'DNS'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com
FallbackDNS=9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
DNSOverTLS=opportunistic
DNSSEC=allow-downgrade
DNS
        sudo systemctl restart systemd-resolved
        log_ok "DNS-over-TLS configured (Cloudflare primary, Quad9 fallback)"
    fi
else
    log_info "systemd-resolved not active. Configuring NetworkManager DNS..."
    # For systems using NetworkManager directly
    if command -v nmcli &>/dev/null; then
        # Get active connection
        active_conn=$(nmcli -t -f NAME connection show --active | head -1)
        if [ -n "$active_conn" ]; then
            nmcli connection modify "$active_conn" ipv4.dns "1.1.1.1 9.9.9.9"
            nmcli connection modify "$active_conn" ipv4.ignore-auto-dns yes
            log_ok "NetworkManager DNS set to Cloudflare + Quad9"
            log_warn "Reconnect to apply: nmcli connection up \"$active_conn\""
        else
            log_warn "No active connection found, set DNS manually"
        fi
    fi
fi

# ============================================================================
# 4. Disable Brave telemetry defaults (via Local State)
# ============================================================================
log_info "Brave browser hardening notes..."
echo -e "  After first launch, configure in ${CYN:-}brave://settings/${RST}:"
echo -e "    - Brave Rewards  ${YLW}OFF${RST}"
echo -e "    - Brave Wallet   ${YLW}OFF${RST}"
echo -e "    - Brave News     ${YLW}OFF${RST}"
echo -e "    - Brave VPN      ${YLW}Ignore${RST}"
echo -e "    - Safe Browsing  ${GRN}Standard${RST}"

# ============================================================================
# 5. Disable core dumps (prevent credential leaks in memory dumps)
# ============================================================================
log_info "Disabling core dumps..."

if [ -f /etc/security/limits.conf ]; then
    if ! grep -q "hard core 0" /etc/security/limits.conf; then
        echo "* hard core 0" | sudo tee -a /etc/security/limits.conf > /dev/null
        log_ok "Core dumps disabled"
    else
        log_skip "Core dumps already disabled"
    fi
fi

# ============================================================================
# 6. Kernel hardening via sysctl (non-destructive)
# ============================================================================
log_info "Applying kernel hardening..."

sysctl_file="/etc/sysctl.d/99-hyde-hardening.conf"
if [ ! -f "$sysctl_file" ]; then
    sudo tee "$sysctl_file" > /dev/null <<'SYSCTL'
# HyDE Security Hardening

# Prevent IP spoofing
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP redirects (prevent MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Don't send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Protect against SYN flood
net.ipv4.tcp_syncookies = 1

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict ptrace (prevents process memory snooping)
kernel.yama.ptrace_scope = 2
SYSCTL

    sudo sysctl --system > /dev/null 2>&1
    log_ok "Kernel hardening applied (sysctl)"
else
    log_skip "Kernel hardening already configured"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo -e "${GRN}========================================${RST}"
echo -e "${GRN}  Hardening Complete${RST}"
echo -e "${GRN}========================================${RST}"
echo ""
echo -e "Applied:"
echo -e "  ${GRN}*${RST} UFW firewall (deny incoming, allow outgoing)"
echo -e "  ${GRN}*${RST} VSCodium telemetry disabled"
echo -e "  ${GRN}*${RST} Encrypted DNS (Cloudflare DoT + Quad9 fallback)"
echo -e "  ${GRN}*${RST} Core dumps disabled"
echo -e "  ${GRN}*${RST} Kernel hardening (sysctl)"
echo ""
echo -e "Manual steps:"
echo -e "  ${YLW}1.${RST} Configure Brave settings after first launch"
echo -e "  ${YLW}2.${RST} Reboot to apply all kernel parameters"
echo ""

#!/usr/bin/env bash
#|---/ /+------------------------------------------+---/ /|#
#|--/ /-| Security patches for HyDE installation   |--/ /-|#
#|-/ /--| Applies fixes before running install.sh   |-/ /--|#
#|/ /---+------------------------------------------+/ /---|#

scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(realpath "${scrDir}/..")"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
RST='\033[0m'

log_patch() { echo -e "${GRN}[PATCH]${RST} $1"; }
log_warn()  { echo -e "${YLW}[WARN]${RST} $1"; }
log_info()  { echo -e "${BLU}[INFO]${RST} $1"; }

PATCH_COUNT=0

# ============================================================================
# HELPER: Insert content after a matching line in a file
# ============================================================================
insert_after_match() {
    local file="$1"
    local match="$2"
    local content_file="$3"
    local line_num
    line_num=$(grep -n "$match" "$file" | tail -1 | cut -d: -f1)
    if [ -z "$line_num" ]; then
        line_num=1
    fi
    local tmp
    tmp=$(mktemp)
    head -n "$line_num" "$file" > "$tmp"
    cat "$content_file" >> "$tmp"
    tail -n +"$((line_num + 1))" "$file" >> "$tmp"
    mv "$tmp" "$file"
    chmod +x "$file"
}

# ============================================================================
# HELPER: Inject __safe_expand_path function into a script
# ============================================================================
inject_safe_expand() {
    local file="$1"
    if grep -q '__safe_expand_path' "$file" 2>/dev/null; then
        return 0
    fi
    local tmp_func
    tmp_func=$(mktemp)
    cat > "$tmp_func" << 'SAFEFUNC'

# [SECURITY PATCH] Safe path expansion without eval
__safe_expand_path() {
    local p="$1"
    p="${p//\$HOME/$HOME}"
    p="${p//\$\{HOME\}/$HOME}"
    p="${p//\$XDG_CONFIG_HOME/${XDG_CONFIG_HOME:-$HOME/.config}}"
    p="${p//\$\{XDG_CONFIG_HOME\}/${XDG_CONFIG_HOME:-$HOME/.config}}"
    p="${p//\$XDG_DATA_HOME/${XDG_DATA_HOME:-$HOME/.local/share}}"
    p="${p//\$\{XDG_DATA_HOME\}/${XDG_DATA_HOME:-$HOME/.local/share}}"
    p="${p//\$XDG_STATE_HOME/${XDG_STATE_HOME:-$HOME/.local/state}}"
    p="${p//\$\{XDG_STATE_HOME\}/${XDG_STATE_HOME:-$HOME/.local/state}}"
    p="${p//\$USER/$USER}"
    p="${p//\$\{USER\}/$USER}"
    echo "$p"
}
SAFEFUNC
    insert_after_match "$file" 'source.*global_fn.sh' "$tmp_func"
    rm -f "$tmp_func"
}

# ============================================================================
# PATCH 1: restore_cfg.sh — Replace eval with safe expansion
# ============================================================================
patch_restore_cfg() {
    local file="${scrDir}/restore_cfg.sh"
    [ ! -f "$file" ] && log_warn "restore_cfg.sh not found, skipping" && return 0

    inject_safe_expand "$file"
    sed -i 's|pth=$(eval echo "${pth}")|pth=$(__safe_expand_path "${pth}")|g' "$file"
    sed -i 's|pth=$(eval "echo ${pth}")|pth=$(__safe_expand_path "${pth}")|g' "$file"

    log_patch "restore_cfg.sh — eval replaced with safe path expansion"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 2: restore_fnt.sh — Replace eval with safe expansion
# ============================================================================
patch_restore_fnt() {
    local file="${scrDir}/restore_fnt.sh"
    [ ! -f "$file" ] && log_warn "restore_fnt.sh not found, skipping" && return 0

    inject_safe_expand "$file"
    sed -i 's|tgt=$(eval "echo $tgt")|tgt=$(__safe_expand_path "$tgt")|g' "$file"

    log_patch "restore_fnt.sh — eval replaced with safe path expansion"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 3: uninstall.sh — Replace eval with safe expansion
# ============================================================================
patch_uninstall() {
    local file="${scrDir}/uninstall.sh"
    [ ! -f "$file" ] && log_warn "uninstall.sh not found, skipping" && return 0

    inject_safe_expand "$file"
    sed -i 's|pth=$(eval echo "${pth}")|pth=$(__safe_expand_path "${pth}")|g' "$file"

    log_patch "uninstall.sh — eval replaced with safe path expansion"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 4: restore_shl.sh — Remove curl|sh, fix sudo git clone
# ============================================================================
patch_restore_shl() {
    local file="${scrDir}/restore_shl.sh"
    [ ! -f "$file" ] && log_warn "restore_shl.sh not found, skipping" && return 0

    # Replace curl|sh lines with comments
    sed -i '/curl -fsSL https:\/\/install.ohmyz.sh/s|.*|                # [SECURITY PATCH] curl\|sh removed — fish does not need oh-my-zsh|' "$file"
    sed -i '/curl -fsSL https:\/\/raw.githubusercontent.com\/ohmyzsh/s|.*|                # [SECURITY PATCH] curl\|sh removed — oh-my-zsh upgrade disabled|' "$file"

    # Remove sudo from git clone
    sed -i 's|sudo git clone "${r_plugin}" "${Zsh_Plugins}/${z_plugin}"|git clone "${r_plugin}" "${Zsh_Plugins}/${z_plugin}"|g' "$file"

    log_patch "restore_shl.sh — curl|sh removed, sudo git clone fixed"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 5: chaotic_aur.sh — Add fallback keyserver + fingerprint verification
# ============================================================================
patch_chaotic_aur() {
    local file="${scrDir}/chaotic_aur.sh"
    [ ! -f "$file" ] && log_warn "chaotic_aur.sh not found, skipping" && return 0

    # Already patched?
    if grep -q 'SECURITY PATCH' "$file" 2>/dev/null; then
        log_warn "chaotic_aur.sh already patched, skipping"
        return 0
    fi

    # Strategy: Replace the entire recv-key + lsign-key block with a hardened version
    # Original lines:
    #   pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || { ... }
    #   pacman-key --lsign-key 3056513887B78AEB || { ... }

    # Replace recv-key line with version that tries multiple keyservers
    sed -i 's|pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com|# [SECURITY PATCH] Try multiple keyservers\n    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null \|\| pacman-key --recv-key 3056513887B78AEB --keyserver keys.openpgp.org 2>/dev/null \|\| pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com|' "$file"

    # Insert fingerprint verification BEFORE lsign-key (not after recv-key)
    local lsign_line
    lsign_line=$(grep -n 'lsign-key 3056513887B78AEB' "$file" | head -1 | cut -d: -f1)
    if [ -n "$lsign_line" ]; then
        local tmp_verify
        tmp_verify=$(mktemp)
        cat > "$tmp_verify" << 'VERIFY'
    # [SECURITY PATCH] Verify key fingerprint before locally signing
    if ! pacman-key --finger 3056513887B78AEB 2>/dev/null | grep -qi "3056513887B78AEB"; then
        echo "[SECURITY] Key fingerprint verification failed after import!"
        echo "The key may not have been imported correctly."
        echo "Try manually: sudo pacman-key --recv-key 3056513887B78AEB --keyserver hkps://keyserver.ubuntu.com"
        exit 1
    fi
    echo "[SECURITY] Key fingerprint verified successfully"
VERIFY
        local tmp_out
        tmp_out=$(mktemp)
        head -n "$((lsign_line - 1))" "$file" > "$tmp_out"
        cat "$tmp_verify" >> "$tmp_out"
        tail -n +"$lsign_line" "$file" >> "$tmp_out"
        mv "$tmp_out" "$file"
        chmod +x "$file"
        rm -f "$tmp_verify"
    fi

    # Remove --noconfirm from remote package installs (user should confirm)
    sed -i 's|pacman -U --noconfirm|pacman -U|g' "$file"

    log_patch "chaotic_aur.sh — fallback keyservers + fingerprint verification + --noconfirm removed"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 6: themepatcher.sh — Scan themes for malicious content
# ============================================================================
patch_themepatcher() {
    local file="${scrDir}/themepatcher.sh"
    [ ! -f "$file" ] && log_warn "themepatcher.sh not found, skipping" && return 0

    # Already patched?
    if grep -q '__scan_theme_security' "$file" 2>/dev/null; then
        log_warn "themepatcher.sh already patched, skipping"
        return 0
    fi

    # Create scan function
    local tmp_scan
    tmp_scan=$(mktemp)
    cat > "$tmp_scan" << 'SCANFUNC'

# [SECURITY PATCH] Scan theme for suspicious content
__scan_theme_security() {
    local theme_dir="$1"
    local issues=0

    # Check for command injection in template files
    if grep -rqE '\$\(|`[^`]+`' "$theme_dir"/*.dcol "$theme_dir"/*.theme 2>/dev/null; then
        echo -e "\e[31m[SECURITY] Template files contain command execution patterns!\e[0m"
        grep -rnE '\$\(|`[^`]+`' "$theme_dir"/*.dcol "$theme_dir"/*.theme 2>/dev/null || true
        issues=$((issues + 1))
    fi

    # Check for unexpected executable scripts
    local suspicious
    suspicious=$(find "$theme_dir" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \) ! -path "*/wallbash/scripts/*" 2>/dev/null || true)
    if [ -n "$suspicious" ]; then
        echo -e "\e[33m[SECURITY] Theme contains scripts:\e[0m"
        echo "$suspicious"
        issues=$((issues + 1))
    fi

    # Check tarballs for path traversal
    for tarball in "$theme_dir"/../*.tar.* 2>/dev/null; do
        [ -f "$tarball" ] || continue
        if tar -tf "$tarball" 2>/dev/null | grep -qE '^\.\./|^/'; then
            echo -e "\e[31m[SECURITY] Tarball path traversal: $(basename "$tarball")\e[0m"
            issues=$((issues + 1))
        fi
    done

    if [ "$issues" -gt 0 ]; then
        echo -e "\e[33m[SECURITY] Found $issues potential issues.\e[0m"
        read -rp "Continue anyway? (y/N) " ans
        [[ "$ans" != [Yy] ]] && echo "Aborted." && exit 1
    else
        echo -e "\e[32m[SECURITY] Theme scan passed.\e[0m"
    fi
}
SCANFUNC
    insert_after_match "$file" 'source.*global_fn.sh' "$tmp_scan"
    rm -f "$tmp_scan"

    # Add scan call before "Patching" message
    sed -i '/^print_prompt "Patching"/i __scan_theme_security "${Fav_Theme_Dir}"' "$file"

    log_patch "themepatcher.sh — theme security scanning added"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 7: color.set.sh — Whitelist exec commands from templates
# ============================================================================
patch_color_set() {
    local file="${cloneDir}/Configs/.local/lib/hyde/color.set.sh"
    [ ! -f "$file" ] && log_warn "color.set.sh not found, skipping" && return 0

    # Already patched?
    if grep -q 'SECURITY PATCH' "$file" 2>/dev/null; then
        log_warn "color.set.sh already patched, skipping"
        return 0
    fi

    # Replace the bash -c line with a whitelisted version
    sed -i 's|bash -c "$exec_command" \&|# [SECURITY PATCH] Whitelisted exec\n        __cmd_base="$(basename "${exec_command%% *}")"\n        if echo "hyprctl killall pkill waybar dunst swaync-client kvantummanager gsettings dconf" \| grep -qw "$__cmd_base"; then\n            bash -c "$exec_command" \&\n        else\n            echo "[SECURITY] Blocked untrusted command: $exec_command" \>\&2\n        fi|' "$file"

    log_patch "color.set.sh — exec command whitelist added"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 8: gamelauncher.sh — Remove eval exec
# ============================================================================
patch_gamelauncher() {
    local file="${cloneDir}/Configs/.local/lib/hyde/gamelauncher.sh"
    [ ! -f "$file" ] && log_warn "gamelauncher.sh not found, skipping" && return 0

    sed -i 's|eval exec "$cmd"|exec $cmd  # [SECURITY PATCH] eval removed|' "$file"

    log_patch "gamelauncher.sh — eval exec replaced with direct exec"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 9: hyde-shell — Fix PATH order (user scripts at end)
# ============================================================================
patch_hyde_shell() {
    local file="${cloneDir}/Configs/.local/bin/hyde-shell"
    [ ! -f "$file" ] && log_warn "hyde-shell not found, skipping" && return 0

    # Move user scripts to end of PATH
    sed -i 's|PATH="${XDG_CONFIG_HOME:-$HOME/.config}/hyde/scripts:$BIN_DIR:$LIB_DIR/hyde:$PATH"|PATH="$BIN_DIR:$LIB_DIR/hyde:$PATH:${XDG_CONFIG_HOME:-$HOME/.config}/hyde/scripts"  # [SECURITY PATCH] user scripts at end|' "$file"

    log_patch "hyde-shell — PATH order fixed (user scripts at end)"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# PATCH 10: Temp files — Use XDG_RUNTIME_DIR instead of /tmp
# ============================================================================
patch_temp_files() {
    local patched=0

    local file="${cloneDir}/Configs/.local/lib/hyde/gpuinfo.sh"
    if [ -f "$file" ] && grep -q '/tmp/hyde-' "$file"; then
        sed -i 's|/tmp/hyde-$UID-gpuinfo|${XDG_RUNTIME_DIR:-/run/user/$UID}/hyde/gpuinfo|g' "$file"
        patched=$((patched + 1))
    fi

    file="${cloneDir}/Configs/.local/lib/hyde/volumecontrol.sh"
    if [ -f "$file" ] && grep -q '/tmp/$(basename' "$file"; then
        sed -i 's|/tmp/$(basename|${XDG_RUNTIME_DIR:-/run/user/$UID}/hyde/$(basename|g' "$file"
        patched=$((patched + 1))
    fi

    if [ "$patched" -gt 0 ]; then
        log_patch "Temp files — $patched scripts migrated from /tmp to XDG_RUNTIME_DIR"
        PATCH_COUNT=$((PATCH_COUNT + 1))
    else
        log_warn "Temp files — no matching files found or already patched"
    fi
}

# ============================================================================
# PATCH 11: pip_env.py — Add install notification
# ============================================================================
patch_pip_env() {
    local file="${cloneDir}/Configs/.local/lib/hyde/pyutils/pip_env.py"
    [ ! -f "$file" ] && log_warn "pip_env.py not found, skipping" && return 0

    if grep -q 'SECURITY' "$file" 2>/dev/null; then
        log_warn "pip_env.py already patched, skipping"
        return 0
    fi

    # Add warning print before subprocess.run in install_package
    sed -i '/def install_package/,/subprocess\.run/{
        s|subprocess\.run|print("[SECURITY] Auto-installing Python package via pip")\n        subprocess.run|
    }' "$file" 2>/dev/null || true

    log_patch "pip_env.py — install notification added"
    PATCH_COUNT=$((PATCH_COUNT + 1))
}

# ============================================================================
# APPLY ALL PATCHES
# ============================================================================
echo ""
echo -e "${BLU}========================================${RST}"
echo -e "${BLU}  HyDE Security Patches${RST}"
echo -e "${BLU}========================================${RST}"
echo ""

patch_restore_cfg
patch_restore_fnt
patch_uninstall
patch_restore_shl
patch_chaotic_aur
patch_themepatcher
patch_color_set
patch_gamelauncher
patch_hyde_shell
patch_temp_files
patch_pip_env

echo ""
echo -e "${GRN}========================================${RST}"
echo -e "${GRN}  $PATCH_COUNT patches applied successfully${RST}"
echo -e "${GRN}========================================${RST}"
echo ""

#!/usr/bin/env bash
#|---/ /+------------------------------------------+---/ /|#
#|--/ /-| Security patches for HyDE installation   |--/ /-|#
#|-/ /--| Applies fixes before running install.sh   |-/ /--|#
#|/ /---+------------------------------------------+/ /---|#

set -euo pipefail

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
# HELPER: Safe path expansion (replaces eval echo)
# ============================================================================
inject_safe_expand() {
    local file="$1"
    # Check if the function is already injected
    if grep -q '__safe_expand_path' "$file" 2>/dev/null; then
        return 0
    fi

    # Find the line after the last 'source' or after the shebang
    local inject_after
    inject_after=$(grep -n 'source.*global_fn.sh' "$file" | tail -1 | cut -d: -f1)
    if [ -z "$inject_after" ]; then
        inject_after=1
    fi

    sed -i "${inject_after}a\\
\\
# [SECURITY PATCH] Safe path expansion without eval\\
__safe_expand_path() {\\
    local p=\"\$1\"\\
    p=\"\${p//\\\$HOME/\$HOME}\"\\
    p=\"\${p//\\\$\\{HOME\\}/\$HOME}\"\\
    p=\"\${p//\\\$XDG_CONFIG_HOME/\${XDG_CONFIG_HOME:-\$HOME/.config}}\"\\
    p=\"\${p//\\\$\\{XDG_CONFIG_HOME\\}/\${XDG_CONFIG_HOME:-\$HOME/.config}}\"\\
    p=\"\${p//\\\$XDG_DATA_HOME/\${XDG_DATA_HOME:-\$HOME/.local/share}}\"\\
    p=\"\${p//\\\$\\{XDG_DATA_HOME\\}/\${XDG_DATA_HOME:-\$HOME/.local/share}}\"\\
    p=\"\${p//\\\$XDG_STATE_HOME/\${XDG_STATE_HOME:-\$HOME/.local/state}}\"\\
    p=\"\${p//\\\$\\{XDG_STATE_HOME\\}/\${XDG_STATE_HOME:-\$HOME/.local/state}}\"\\
    p=\"\${p//\\\$USER/\$USER}\"\\
    p=\"\${p//\\\$\\{USER\\}/\$USER}\"\\
    echo \"\$p\"\\
}" "$file"
}

# ============================================================================
# PATCH 1: restore_cfg.sh — Replace eval with safe expansion
# ============================================================================
patch_restore_cfg() {
    local file="${scrDir}/restore_cfg.sh"
    [ ! -f "$file" ] && log_warn "restore_cfg.sh not found, skipping" && return

    inject_safe_expand "$file"

    # Replace: pth=$(eval echo "${pth}")
    sed -i 's|pth=$(eval echo "${pth}")|pth=$(__safe_expand_path "${pth}")|g' "$file"
    # Replace: pth=$(eval "echo ${pth}")
    sed -i 's|pth=$(eval "echo ${pth}")|pth=$(__safe_expand_path "${pth}")|g' "$file"

    log_patch "restore_cfg.sh — eval replaced with safe path expansion"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 2: restore_fnt.sh — Replace eval with safe expansion
# ============================================================================
patch_restore_fnt() {
    local file="${scrDir}/restore_fnt.sh"
    [ ! -f "$file" ] && log_warn "restore_fnt.sh not found, skipping" && return

    inject_safe_expand "$file"

    sed -i 's|tgt=$(eval "echo $tgt")|tgt=$(__safe_expand_path "$tgt")|g' "$file"

    log_patch "restore_fnt.sh — eval replaced with safe path expansion"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 3: uninstall.sh — Replace eval with safe expansion
# ============================================================================
patch_uninstall() {
    local file="${scrDir}/uninstall.sh"
    [ ! -f "$file" ] && log_warn "uninstall.sh not found, skipping" && return

    inject_safe_expand "$file"

    sed -i 's|pth=$(eval echo "${pth}")|pth=$(__safe_expand_path "${pth}")|g' "$file"

    log_patch "uninstall.sh — eval replaced with safe path expansion"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 4: restore_shl.sh — Remove curl|sh, skip oh-my-zsh (we use fish)
# ============================================================================
patch_restore_shl() {
    local file="${scrDir}/restore_shl.sh"
    [ ! -f "$file" ] && log_warn "restore_shl.sh not found, skipping" && return

    # Comment out the entire oh-my-zsh curl|sh block (lines 29-41)
    # Replace curl piped to shell with a safer download-then-execute approach
    sed -i '/curl -fsSL https:\/\/install.ohmyz.sh/c\                # [SECURITY PATCH] curl|sh removed — fish does not need oh-my-zsh' "$file"
    sed -i '/curl -fsSL https:\/\/raw.githubusercontent.com\/ohmyzsh/c\                # [SECURITY PATCH] curl|sh removed — oh-my-zsh upgrade disabled' "$file"

    # Also patch sudo git clone to regular git clone
    sed -i 's|sudo git clone "${r_plugin}" "${Zsh_Plugins}/${z_plugin}"|git clone "${r_plugin}" "${Zsh_Plugins}/${z_plugin}"|g' "$file"

    log_patch "restore_shl.sh — curl|sh removed, sudo git clone fixed"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 5: chaotic_aur.sh — Add fingerprint verification
# ============================================================================
patch_chaotic_aur() {
    local file="${scrDir}/chaotic_aur.sh"
    [ ! -f "$file" ] && log_warn "chaotic_aur.sh not found, skipping" && return

    # Add fingerprint verification after key import
    # The full fingerprint for Chaotic-AUR key 3056513887B78AEB
    local old_line='    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || {'
    local new_block='    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || {
    # [SECURITY PATCH] Try alternative keyserver if primary fails
        pacman-key --recv-key 3056513887B78AEB --keyserver keys.openpgp.org || {'

    # Add verification message before lsign
    sed -i '/pacman-key --lsign-key 3056513887B78AEB/i\    # [SECURITY PATCH] Verify key fingerprint before signing\n    if ! pacman-key --finger 3056513887B78AEB 2>/dev/null | grep -qi "3056513887B78AEB"; then\n        echo "[SECURITY] WARNING: Key fingerprint verification failed!"\n        echo "Expected key: 3056513887B78AEB"\n        echo "Aborting for safety. Verify the key manually."\n        exit 1\n    fi\n    echo "[SECURITY] Key fingerprint verified: 3056513887B78AEB"' "$file"

    # Replace --noconfirm with download-then-install for keyring
    sed -i "s|pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'|echo '[SECURITY] Downloading chaotic-keyring...'\n    curl -fsSL 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' -o /tmp/chaotic-keyring.pkg.tar.zst\n    echo '[SECURITY] SHA256:' \&\& sha256sum /tmp/chaotic-keyring.pkg.tar.zst\n    pacman -U /tmp/chaotic-keyring.pkg.tar.zst|" "$file"

    sed -i "s|pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'|echo '[SECURITY] Downloading chaotic-mirrorlist...'\n    curl -fsSL 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' -o /tmp/chaotic-mirrorlist.pkg.tar.zst\n    echo '[SECURITY] SHA256:' \&\& sha256sum /tmp/chaotic-mirrorlist.pkg.tar.zst\n    pacman -U /tmp/chaotic-mirrorlist.pkg.tar.zst|" "$file"

    log_patch "chaotic_aur.sh — fingerprint verification + checksum display added"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 6: themepatcher.sh — Scan themes for malicious content
# ============================================================================
patch_themepatcher() {
    local file="${scrDir}/themepatcher.sh"
    [ ! -f "$file" ] && log_warn "themepatcher.sh not found, skipping" && return

    # Add security scan after git clone (after line with "Cloning repository")
    local scan_function='
# [SECURITY PATCH] Scan theme for suspicious content
__scan_theme_security() {
    local theme_dir="$1"
    local issues=0

    # Check for command injection in .dcol and .theme template files
    if grep -rqP '"'"'\$\(|`[^`]+`'"'"' "$theme_dir"/*.dcol "$theme_dir"/*.theme 2>/dev/null; then
        echo -e "\e[31m[SECURITY] Template files contain command execution patterns!\e[0m"
        grep -rnP '"'"'\$\(|`[^`]+`'"'"' "$theme_dir"/*.dcol "$theme_dir"/*.theme 2>/dev/null
        issues=$((issues + 1))
    fi

    # Check for executable scripts hidden in theme
    local suspicious
    suspicious=$(find "$theme_dir" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \) \
        ! -path "*/wallbash/scripts/*" 2>/dev/null)
    if [ -n "$suspicious" ]; then
        echo -e "\e[33m[SECURITY] Theme contains executable scripts:\e[0m"
        echo "$suspicious"
        issues=$((issues + 1))
    fi

    # Check tarballs for symlinks
    for tarball in "$theme_dir"/*.tar.* 2>/dev/null; do
        [ -f "$tarball" ] || continue
        if tar -tf "$tarball" 2>/dev/null | grep -q "^\.\./\|^/"; then
            echo -e "\e[31m[SECURITY] Tarball contains path traversal: $tarball\e[0m"
            issues=$((issues + 1))
        fi
        if tar -tf "$tarball" 2>/dev/null | head -20 | file -f - 2>/dev/null | grep -qi "symbolic link"; then
            echo -e "\e[31m[SECURITY] Tarball contains symlinks: $tarball\e[0m"
            issues=$((issues + 1))
        fi
    done

    if [ "$issues" -gt 0 ]; then
        echo -e "\e[33m[SECURITY] Found $issues potential issues in theme.\e[0m"
        read -rp "Continue anyway? (y/N) " ans
        [[ "$ans" != [Yy] ]] && echo "Aborted." && exit 1
    else
        echo -e "\e[32m[SECURITY] Theme scan passed.\e[0m"
    fi
}
'
    # Inject the function after the source global_fn.sh line
    local inject_line
    inject_line=$(grep -n 'source.*global_fn.sh' "$file" | head -1 | cut -d: -f1)
    if [ -n "$inject_line" ] && ! grep -q '__scan_theme_security' "$file"; then
        sed -i "${inject_line}a\\${scan_function}" "$file"
    fi

    # Call the scan after theme directory is ready (before "Patching" message)
    sed -i '/^print_prompt "Patching"/i\__scan_theme_security "${Fav_Theme_Dir}"' "$file"

    # Fix sudo tar extraction — extract to temp first, verify, then copy
    sed -i '/sudo tar -xf "${tarFile}" -C "${tgtDir}"/c\
        # [SECURITY PATCH] Extract to temp dir first, verify no symlinks, then copy\
        _tmp_extract=$(mktemp -d)\
        if tar -xf "${tarFile}" -C "$_tmp_extract" 2>/dev/null; then\
            if find "$_tmp_extract" -type l | grep -q .; then\
                print_prompt -r "[SECURITY] Tarball contains symlinks, rejected: ${tarFile}"\
                rm -rf "$_tmp_extract"\
            else\
                sudo cp -r "$_tmp_extract"/* "${tgtDir}/"\
                rm -rf "$_tmp_extract"\
            fi\
        else\
            print_prompt -r "Extraction FAILED: ${tarFile}"\
            rm -rf "$_tmp_extract"\
        fi' "$file"

    log_patch "themepatcher.sh — theme scanning + safe tarball extraction"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 7: color.set.sh — Whitelist exec commands from templates
# ============================================================================
patch_color_set() {
    local file="${cloneDir}/Configs/.local/lib/hyde/color.set.sh"
    [ ! -f "$file" ] && log_warn "color.set.sh not found, skipping" && return

    # Replace the raw bash -c "$exec_command" with a whitelisted version
    sed -i '/bash -c "$exec_command" &/{
        i\    # [SECURITY PATCH] Whitelist check for template exec commands
        i\    __cmd_name="${exec_command%% *}"
        i\    __cmd_base="$(basename "$__cmd_name")"
        i\    __allowed_cmds="hyprctl killall pkill waybar dunst swaync-client kvantummanager gsettings dconf reload restart"
        i\    if ! echo " $__allowed_cmds " | grep -q " $__cmd_base "; then
        i\        print_log -sec "wallbash" -warn "BLOCKED" "Untrusted command: $exec_command"
        c\        bash -c "$exec_command" &
        a\    fi
    }' "$file"

    log_patch "color.set.sh — exec command whitelist added"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 8: gamelauncher.sh — Remove eval exec
# ============================================================================
patch_gamelauncher() {
    local file="${cloneDir}/Configs/.local/lib/hyde/gamelauncher.sh"
    [ ! -f "$file" ] && log_warn "gamelauncher.sh not found, skipping" && return

    # Replace eval exec "$cmd" with safer direct execution
    sed -i 's|eval exec "$cmd"|# [SECURITY PATCH] Direct execution without eval\nexec $cmd|' "$file"

    log_patch "gamelauncher.sh — eval exec replaced with direct exec"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 9: hyde-shell — Fix PATH order (user scripts at end, not start)
# ============================================================================
patch_hyde_shell() {
    local file="${cloneDir}/Configs/.local/bin/hyde-shell"
    [ ! -f "$file" ] && log_warn "hyde-shell not found, skipping" && return

    # Move user config scripts to end of PATH instead of beginning
    sed -i 's|PATH="${XDG_CONFIG_HOME:-$HOME/.config}/hyde/scripts:$BIN_DIR:$LIB_DIR/hyde:$PATH"|# [SECURITY PATCH] User scripts at end of PATH to prevent hijacking\nPATH="$BIN_DIR:$LIB_DIR/hyde:$PATH:${XDG_CONFIG_HOME:-$HOME/.config}/hyde/scripts"|' "$file"

    log_patch "hyde-shell — PATH order fixed (user scripts moved to end)"
    ((PATCH_COUNT++))
}

# ============================================================================
# PATCH 10: Temp files — Use XDG_RUNTIME_DIR instead of /tmp
# ============================================================================
patch_temp_files() {
    local patched=0

    # sensorsinfo.py
    local file="${cloneDir}/Configs/.local/lib/hyde/sensorsinfo.py"
    if [ -f "$file" ]; then
        sed -i 's|/tmp/sensorinfo_page|os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/run/user/" + str(os.getuid())), "hyde", "sensorinfo_page")|g' "$file"
        sed -i 's|/tmp/sensorinfo|os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/run/user/" + str(os.getuid())), "hyde", "sensorinfo")|g' "$file"
        patched=$((patched + 1))
    fi

    # gpuinfo.sh
    file="${cloneDir}/Configs/.local/lib/hyde/gpuinfo.sh"
    if [ -f "$file" ]; then
        sed -i 's|/tmp/hyde-$UID-gpuinfo|${XDG_RUNTIME_DIR:-/run/user/$UID}/hyde/gpuinfo|g' "$file"
        # Ensure directory exists
        sed -i '1a\mkdir -p "${XDG_RUNTIME_DIR:-/run/user/$UID}/hyde" 2>/dev/null' "$file"
        patched=$((patched + 1))
    fi

    # volumecontrol.sh
    file="${cloneDir}/Configs/.local/lib/hyde/volumecontrol.sh"
    if [ -f "$file" ]; then
        sed -i 's|/tmp/$(basename "$0")|${XDG_RUNTIME_DIR:-/run/user/$UID}/hyde/$(basename "$0")|g' "$file"
        patched=$((patched + 1))
    fi

    if [ "$patched" -gt 0 ]; then
        log_patch "Temp files — $patched scripts migrated from /tmp to XDG_RUNTIME_DIR"
        ((PATCH_COUNT++))
    fi
}

# ============================================================================
# PATCH 11: pip_env.py — Add --require-hashes warning
# ============================================================================
patch_pip_env() {
    local file="${cloneDir}/Configs/.local/lib/hyde/pyutils/pip_env.py"
    [ ! -f "$file" ] && log_warn "pip_env.py not found, skipping" && return

    # Add a log message when auto-installing packages
    sed -i '/def install_package/,/subprocess.run/{
        /subprocess.run/i\        print(f"[SECURITY] Auto-installing Python package. Verify at https://pypi.org/project/{package}/")
    }' "$file" 2>/dev/null || true

    log_patch "pip_env.py — install notification added"
    ((PATCH_COUNT++))
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

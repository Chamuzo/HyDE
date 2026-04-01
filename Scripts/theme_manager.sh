#!/usr/bin/env bash
#|---/ /+------------------------------------------+---/ /|#
#|--/ /-| Theme Manager for HyDE                   |--/ /-|#
#|-/ /--| Install/Remove/Switch individual themes   |-/ /--|#
#|/ /---+------------------------------------------+/ /---|#

set -euo pipefail

scrDir="$(dirname "$(realpath "$0")")"
confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/hyde"
themeDir="${confDir}/hyde/themes"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
RST='\033[0m'

# ============================================================================
# Theme Registry — Official HyDE themes
# ============================================================================
declare -A THEME_REPOS=(
    ["Catppuccin Mocha"]="https://github.com/HyDE-Project/hyde-themes/tree/Catppuccin-Mocha"
    ["Catppuccin Latte"]="https://github.com/HyDE-Project/hyde-themes/tree/Catppuccin-Latte"
    ["Rose Pine"]="https://github.com/HyDE-Project/hyde-themes/tree/Rose-Pine"
    ["Tokyo Night"]="https://github.com/HyDE-Project/hyde-themes/tree/Tokyo-Night"
    ["Material Sakura"]="https://github.com/HyDE-Project/hyde-themes/tree/Material-Sakura"
    ["Graphite Mono"]="https://github.com/HyDE-Project/hyde-themes/tree/Graphite-Mono"
    ["Decay Green"]="https://github.com/HyDE-Project/hyde-themes/tree/Decay-Green"
    ["Edge Runner"]="https://github.com/HyDE-Project/hyde-themes/tree/Edge-Runner"
    ["Frosted Glass"]="https://github.com/HyDE-Project/hyde-themes/tree/Frosted-Glass"
    ["Gruvbox Retro"]="https://github.com/HyDE-Project/hyde-themes/tree/Gruvbox-Retro"
    ["Synth Wave"]="https://github.com/HyDE-Project/hyde-themes/tree/Synth-Wave"
    ["Nordic Blue"]="https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue"
)

# Sorted theme names for display
THEME_NAMES=(
    "Catppuccin Mocha"
    "Catppuccin Latte"
    "Decay Green"
    "Edge Runner"
    "Frosted Glass"
    "Graphite Mono"
    "Gruvbox Retro"
    "Material Sakura"
    "Nordic Blue"
    "Rose Pine"
    "Synth Wave"
    "Tokyo Night"
)

# ============================================================================
# Functions
# ============================================================================

list_installed() {
    echo -e "${BLU}Installed themes:${RST}"
    if [ -d "$themeDir" ]; then
        local count=0
        for dir in "$themeDir"/*/; do
            [ -d "$dir" ] || continue
            local name
            name=$(basename "$dir")
            echo -e "  ${GRN}*${RST} $name"
            count=$((count + 1))
        done
        if [ "$count" -eq 0 ]; then
            echo -e "  ${YLW}(none)${RST}"
        fi
    else
        echo -e "  ${YLW}(theme directory not found)${RST}"
    fi
}

list_available() {
    echo -e "${BLU}Available themes:${RST}"
    for i in "${!THEME_NAMES[@]}"; do
        local name="${THEME_NAMES[$i]}"
        local status=""
        if [ -d "${themeDir}/${name}" ]; then
            status="${GRN}[installed]${RST}"
        fi
        printf "  ${CYN}%2d${RST}) %-20s %s\n" "$((i + 1))" "$name" "$status"
    done
}

scan_theme() {
    local theme_dir="$1"
    local issues=0

    # Check for command injection in template files
    if grep -rqP '\$\(|`[^`]+`' "$theme_dir"/*.dcol "$theme_dir"/*.theme 2>/dev/null; then
        echo -e "${RED}[SECURITY] Template files contain command execution patterns!${RST}"
        grep -rnP '\$\(|`[^`]+`' "$theme_dir"/*.dcol "$theme_dir"/*.theme 2>/dev/null
        issues=$((issues + 1))
    fi

    # Check for unexpected executable scripts
    local suspicious
    suspicious=$(find "$theme_dir" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \) \
        ! -path "*/wallbash/scripts/*" 2>/dev/null || true)
    if [ -n "$suspicious" ]; then
        echo -e "${YLW}[SECURITY] Theme contains executable scripts:${RST}"
        echo "$suspicious"
        issues=$((issues + 1))
    fi

    # Check tarballs for path traversal and symlinks
    for tarball in "$theme_dir"/../*.tar.*; do
        [ -f "$tarball" ] || continue
        if tar -tf "$tarball" 2>/dev/null | grep -q '^\.\./\|^/'; then
            echo -e "${RED}[SECURITY] Tarball contains path traversal: $(basename "$tarball")${RST}"
            issues=$((issues + 1))
        fi
    done

    if [ "$issues" -gt 0 ]; then
        echo -e "${YLW}Found $issues potential issues.${RST}"
        read -rp "Continue installing? (y/N) " ans
        [[ "$ans" != [Yy] ]] && return 1
    else
        echo -e "${GRN}[OK]${RST} Security scan passed"
    fi
    return 0
}

install_theme() {
    local name="$1"
    local repo="${THEME_REPOS[$name]:-}"

    if [ -z "$repo" ]; then
        echo -e "${RED}[ERROR]${RST} Unknown theme: $name"
        return 1
    fi

    if [ -d "${themeDir}/${name}" ]; then
        echo -e "${YLW}[SKIP]${RST} Theme '$name' is already installed"
        read -rp "Reinstall? (y/N) " ans
        [[ "$ans" != [Yy] ]] && return 0
    fi

    echo -e "${BLU}[INSTALL]${RST} Installing theme: $name"
    echo ""

    # Use HyDE's themepatcher
    if [ -f "${scrDir}/themepatcher.sh" ]; then
        bash "${scrDir}/themepatcher.sh" "$name" "$repo"
    else
        echo -e "${RED}[ERROR]${RST} themepatcher.sh not found"
        return 1
    fi

    echo -e "${GRN}[OK]${RST} Theme '$name' installed"
}

remove_theme() {
    local name="$1"
    local theme_path="${themeDir}/${name}"

    if [ ! -d "$theme_path" ]; then
        echo -e "${RED}[ERROR]${RST} Theme '$name' is not installed"
        return 1
    fi

    # Check if it's the active theme
    local active_theme=""
    if [ -f "${confDir}/hyde/themes/.current" ]; then
        active_theme=$(cat "${confDir}/hyde/themes/.current" 2>/dev/null || true)
    fi
    # Also check hyprland variable
    if [ -z "$active_theme" ]; then
        active_theme=$(grep '^\$HYDE_THEME=' "${confDir}/hypr/themes/wallbash.conf" 2>/dev/null | cut -d= -f2 || true)
    fi

    if [ "$active_theme" = "$name" ]; then
        echo -e "${YLW}[WARN]${RST} '$name' is the currently active theme!"
        echo -e "Switch to another theme first, or proceed to force remove."
        read -rp "Force remove? (y/N) " ans
        [[ "$ans" != [Yy] ]] && return 0
    fi

    echo -e "${BLU}[REMOVE]${RST} Removing theme: $name"

    # Backup before removing
    local backup_dir="${HOME}/.config/cfg_backups/themes_$(date +'%y%m%d_%Hh%Mm%Ss')"
    mkdir -p "$backup_dir"
    cp -r "$theme_path" "$backup_dir/"
    echo -e "  Backed up to: $backup_dir"

    rm -rf "$theme_path"

    # Clean wallpaper cache for this theme
    local wall_cache="${cacheDir}/wallpapers/${name}"
    [ -d "$wall_cache" ] && rm -rf "$wall_cache"

    echo -e "${GRN}[OK]${RST} Theme '$name' removed (backup saved)"
}

switch_theme() {
    local name="$1"

    if [ ! -d "${themeDir}/${name}" ]; then
        echo -e "${RED}[ERROR]${RST} Theme '$name' is not installed. Install it first."
        return 1
    fi

    echo -e "${BLU}[SWITCH]${RST} Switching to: $name"

    if command -v hyde-shell &>/dev/null; then
        hyde-shell theme set "$name" 2>/dev/null || true
    fi

    # Fallback: use HyDE's theme switch script
    if [ -f "$HOME/.local/lib/hyde/theme.switch.sh" ]; then
        bash "$HOME/.local/lib/hyde/theme.switch.sh" "$name" 2>/dev/null || true
    fi

    echo -e "${GRN}[OK]${RST} Switched to theme: $name"
}

install_all() {
    echo -e "${BLU}Installing all ${#THEME_NAMES[@]} themes...${RST}"
    echo ""
    for name in "${THEME_NAMES[@]}"; do
        if [ -d "${themeDir}/${name}" ]; then
            echo -e "${YLW}[SKIP]${RST} $name (already installed)"
        else
            install_theme "$name"
        fi
        echo ""
    done
}

interactive_install() {
    list_available
    echo ""
    echo -e "Enter theme numbers to install (space-separated), ${CYN}a${RST} for all, ${CYN}q${RST} to quit:"
    read -rp "> " selection

    [[ "$selection" == "q" ]] && return 0

    if [[ "$selection" == "a" ]]; then
        install_all
        return 0
    fi

    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#THEME_NAMES[@]}" ]; then
            install_theme "${THEME_NAMES[$((num - 1))]}"
            echo ""
        else
            echo -e "${RED}[ERROR]${RST} Invalid selection: $num"
        fi
    done
}

interactive_remove() {
    echo -e "${BLU}Installed themes:${RST}"
    local installed=()
    for dir in "$themeDir"/*/; do
        [ -d "$dir" ] || continue
        installed+=("$(basename "$dir")")
    done

    if [ ${#installed[@]} -eq 0 ]; then
        echo -e "  ${YLW}No themes installed${RST}"
        return 0
    fi

    for i in "${!installed[@]}"; do
        printf "  ${CYN}%2d${RST}) %s\n" "$((i + 1))" "${installed[$i]}"
    done

    echo ""
    echo -e "Enter theme numbers to remove (space-separated), ${CYN}q${RST} to quit:"
    read -rp "> " selection

    [[ "$selection" == "q" ]] && return 0

    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#installed[@]}" ]; then
            remove_theme "${installed[$((num - 1))]}"
            echo ""
        else
            echo -e "${RED}[ERROR]${RST} Invalid selection: $num"
        fi
    done
}

# ============================================================================
# CLI Interface
# ============================================================================
usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [theme-name]

Commands:
    list                List all available and installed themes
    install [name]      Install a theme (interactive if no name given)
    install-all         Install all 12 official themes
    remove [name]       Remove a theme (interactive if no name given)
    switch <name>       Switch to an installed theme
    help                Show this help

Examples:
    $(basename "$0") install "Tokyo Night"
    $(basename "$0") remove "Catppuccin Latte"
    $(basename "$0") switch "Gruvbox Retro"
    $(basename "$0") install            # interactive mode
    $(basename "$0") install-all        # install all themes
EOF
}

case "${1:-help}" in
    list)
        list_available
        echo ""
        list_installed
        ;;
    install)
        if [ -n "${2:-}" ]; then
            install_theme "$2"
        else
            interactive_install
        fi
        ;;
    install-all)
        install_all
        ;;
    remove)
        if [ -n "${2:-}" ]; then
            remove_theme "$2"
        else
            interactive_remove
        fi
        ;;
    switch)
        if [ -n "${2:-}" ]; then
            switch_theme "$2"
        else
            echo -e "${RED}[ERROR]${RST} Specify a theme name: $(basename "$0") switch \"Theme Name\""
        fi
        ;;
    help | --help | -h)
        usage
        ;;
    *)
        echo -e "${RED}[ERROR]${RST} Unknown command: $1"
        usage
        exit 1
        ;;
esac

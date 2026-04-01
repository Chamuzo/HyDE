#!/usr/bin/env bash
#|---/ /+------------------------------------------+---/ /|#
#|--/ /-| Custom HyDE Installer (Security Patched) |--/ /-|#
#|-/ /--| Wraps install.sh with hardening          |-/ /--|#
#|/ /---+------------------------------------------+/ /---|#

cat <<"EOF"

-------------------------------------------------
        .
       / \         _       _  _      ___  ___
      /^  \      _| |_    | || |_  _|   \| __|
     /  _  \    |_   _|   | __ | || | |) | _|
    /  | | ~\     |_|     |_||_|\_, |___/|___|
   /.-'   '-.\                  |__/

  [ CUSTOM INSTALLER — Security Patched ]
-------------------------------------------------

EOF

scrDir="$(dirname "$(realpath "$0")")"
cloneDir="$(realpath "${scrDir}/..")"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
BLU='\033[0;34m'
RST='\033[0m'

# ============================================================================
# STEP 0: Pre-flight checks
# ============================================================================
echo -e "${BLU}[1/6]${RST} Pre-flight checks..."

if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}[ERROR]${RST} Do not run this as root. The script will ask for sudo when needed."
    exit 1
fi

if ! command -v pacman &>/dev/null; then
    echo -e "${RED}[ERROR]${RST} This installer is for Arch Linux only."
    exit 1
fi

if ! ping -q -c 1 -W 3 archlinux.org &>/dev/null; then
    echo -e "${RED}[ERROR]${RST} No internet connection."
    exit 1
fi

echo -e "${GRN}[OK]${RST} System checks passed"

# ============================================================================
# STEP 1.5: Fix permissions on all scripts
# ============================================================================
echo ""
echo -e "${BLU}[1.5/6]${RST} Fixing script permissions..."

find "${cloneDir}" -name "*.sh" -exec chmod +x {} \;
# Also fix non-.sh executables
chmod +x "${cloneDir}/Configs/.local/bin/"* 2>/dev/null || true
chmod +x "${cloneDir}/Configs/.local/lib/hyde/"*.sh 2>/dev/null || true
chmod +x "${cloneDir}/Configs/.local/lib/hyde/"*.py 2>/dev/null || true

echo -e "${GRN}[OK]${RST} All scripts marked as executable"

# ============================================================================
# STEP 2: Apply security patches
# ============================================================================
echo ""
echo -e "${BLU}[2/6]${RST} Applying security patches..."

if [ -f "${scrDir}/security_patches.sh" ]; then
    bash "${scrDir}/security_patches.sh"
else
    echo -e "${RED}[ERROR]${RST} security_patches.sh not found!"
    exit 1
fi

# ============================================================================
# STEP 2: Replace package list with custom selection
# ============================================================================
echo ""
echo -e "${BLU}[3/6]${RST} Setting up custom package list..."

if [ -f "${scrDir}/pkg_custom.lst" ]; then
    # Backup original
    cp "${scrDir}/pkg_core.lst" "${scrDir}/pkg_core.lst.original"
    # Replace with custom
    cp "${scrDir}/pkg_custom.lst" "${scrDir}/pkg_core.lst"
    echo -e "${GRN}[OK]${RST} Custom package list applied (original backed up as pkg_core.lst.original)"
else
    echo -e "${RED}[ERROR]${RST} pkg_custom.lst not found!"
    exit 1
fi

# Create empty extra list to prevent extras from being loaded
cp "${scrDir}/pkg_extra.lst" "${scrDir}/pkg_extra.lst.original"
echo "# Extras disabled by custom installer" > "${scrDir}/pkg_extra.lst"
echo -e "${GRN}[OK]${RST} Extra packages disabled"

# Ensure originals are restored even if installer fails
restore_originals() {
    [ -f "${scrDir}/pkg_core.lst.original" ] && mv "${scrDir}/pkg_core.lst.original" "${scrDir}/pkg_core.lst"
    [ -f "${scrDir}/pkg_extra.lst.original" ] && mv "${scrDir}/pkg_extra.lst.original" "${scrDir}/pkg_extra.lst"
}
trap restore_originals EXIT

# ============================================================================
# STEP 3: Pre-set choices (fish shell, skip oh-my-zsh)
# ============================================================================
echo ""
echo -e "${BLU}[4/6]${RST} Pre-configuring choices..."

# Export shell choice so install.sh doesn't ask
export myShell="fish"
echo -e "${GRN}[OK]${RST} Shell set to: fish"

# ============================================================================
# STEP 4: Run the main HyDE installer
# ============================================================================
echo ""
echo -e "${BLU}[5/6]${RST} Running HyDE installer..."
echo ""

# Run with all flags: install + restore + services
bash "${scrDir}/install.sh"

# ============================================================================
# STEP 5: Post-install hardening
# ============================================================================
echo ""
echo -e "${BLU}[6/6]${RST} Post-install hardening..."

if [ -f "${scrDir}/harden.sh" ]; then
    bash "${scrDir}/harden.sh"
else
    echo -e "${YLW}[WARN]${RST} harden.sh not found, skipping post-install hardening"
fi

# ============================================================================
# DONE (originals restored automatically via trap)
# ============================================================================
echo ""
echo -e "${GRN}========================================${RST}"
echo -e "${GRN}  Installation Complete!${RST}"
echo -e "${GRN}========================================${RST}"
echo ""
echo -e "Installed with:"
echo -e "  Browser:  ${BLU}Brave${RST}"
echo -e "  Shell:    ${BLU}Fish${RST}"
echo -e "  Terminal: ${BLU}Kitty${RST}"
echo -e "  Files:    ${BLU}Yazi${RST}"
echo -e "  IDE:      ${BLU}VSCodium${RST}"
echo -e "  Firewall: ${BLU}UFW (enabled)${RST}"
echo ""
echo -e "Use ${YLW}theme_manager.sh${RST} to install/remove themes."
echo -e "All 11 security patches have been applied."
echo ""
echo -e "${YLW}Please reboot to apply all changes.${RST}"

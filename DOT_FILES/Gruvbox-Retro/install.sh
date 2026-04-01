#!/usr/bin/env bash
set -euo pipefail

THEME_SLUG="Gruvbox-Retro"
THEME_NAME="Gruvbox Retro"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$SCRIPT_DIR/dots"
SOURCE_DIR="$SCRIPT_DIR/source"
PACKAGES_DIR="$SCRIPT_DIR/packages"
THEME_DIR="$DOTS_DIR/.config/hyde/themes/$THEME_NAME"
MANUAL_SHARE_DIR="$HOME/.local/share/manual-themes/$THEME_SLUG"
BACKUP_ROOT="$HOME/.local/share/manual-theme-backups/$THEME_SLUG/$(date +%Y%m%d-%H%M%S)"

MODE="manual-pure"
INSTALL_PACKAGES=1
EXTRACT_ASSETS=1
DO_BACKUP=1
DRY_RUN=0

log() {
    printf '[%s] %s\n' "$THEME_SLUG" "$*"
}

warn() {
    printf '[%s][warn] %s\n' "$THEME_SLUG" "$*" >&2
}

die() {
    printf '[%s][error] %s\n' "$THEME_SLUG" "$*" >&2
    exit 1
}

run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '+'
        for arg in "$@"; do
            printf ' %q' "$arg"
        done
        printf '\n'
        return 0
    fi
    "$@"
}

usage() {
    cat <<EOF
Usage:
  bash ./install.sh [options]

Options:
  --manual-pure      Install a standalone minimal profile without HyDE runtime helpers.
  --bundle           Install the full bundled profile shipped inside this theme folder.
  --skip-packages    Do not install packages.
  --skip-assets      Do not extract theme archives from ./source.
  --no-backup        Do not back up existing files before overwriting.
  --dry-run          Print actions without modifying the system.
  -h, --help         Show this help.

Notes:
  - Default mode is --manual-pure.
  - Backups are stored in: $HOME/.local/share/manual-theme-backups/$THEME_SLUG/
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manual-pure)
            MODE="manual-pure"
            ;;
        --bundle)
            MODE="bundle"
            ;;
        --skip-packages)
            INSTALL_PACKAGES=0
            ;;
        --skip-assets)
            EXTRACT_ASSETS=0
            ;;
        --no-backup)
            DO_BACKUP=0
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
    shift
done

[[ -d "$DOTS_DIR" ]] || die "Missing dots directory: $DOTS_DIR"
[[ -d "$THEME_DIR" ]] || die "Missing theme directory: $THEME_DIR"

backup_path() {
    local target="$1"
    local relative_target backup_target

    [[ "$DO_BACKUP" -eq 1 ]] || return 0
    [[ -e "$target" || -L "$target" ]] || return 0

    relative_target="${target#$HOME/}"
    backup_target="$BACKUP_ROOT/$relative_target"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would back up $target to $backup_target"
        return 0
    fi

    mkdir -p "$(dirname "$backup_target")"
    cp -a "$target" "$backup_target"
}

copy_dir_contents() {
    local src="$1"
    local dest="$2"

    [[ -d "$src" ]] || return 0
    backup_path "$dest"
    run mkdir -p "$dest"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would copy directory contents from $src to $dest"
        return 0
    fi
    cp -a "$src"/. "$dest"/
}

copy_file() {
    local src="$1"
    local dest="$2"

    [[ -f "$src" ]] || return 0
    backup_path "$dest"
    run mkdir -p "$(dirname "$dest")"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would copy file $src to $dest"
        return 0
    fi
    cp -a "$src" "$dest"
}

write_template_body() {
    local src="$1"
    local dest="$2"
    local sanitize_exec="${3:-0}"

    [[ -f "$src" ]] || return 0
    backup_path "$dest"
    run mkdir -p "$(dirname "$dest")"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would render template $src into $dest"
        return 0
    fi

    if [[ "$sanitize_exec" -eq 1 ]]; then
        tail -n +2 "$src" | grep -Ev '^[[:space:]]*exec[[:space:]]*=' > "$dest" || true
    else
        tail -n +2 "$src" > "$dest"
    fi
}

write_text_file() {
    local dest="$1"
    local content="$2"

    backup_path "$dest"
    run mkdir -p "$(dirname "$dest")"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log "Would write $dest"
        return 0
    fi

    printf '%s\n' "$content" > "$dest"
}

theme_var() {
    local var_name="$1"
    local theme_file="$THEME_DIR/hypr.theme"

    [[ -f "$theme_file" ]] || return 0

    grep -E "^[[:space:]]*\\$$var_name[[:space:]]*=" "$theme_file" | head -n 1 | cut -d '=' -f 2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//'
}

pick_wallpaper() {
    local wallpaper_path
    wallpaper_path="$(find "$THEME_DIR/wallpapers" -maxdepth 1 -type f 2>/dev/null | sort | head -n 1 || true)"
    printf '%s' "$wallpaper_path"
}

extract_assets() {
    local archive_name archive_path target_dir

    [[ "$EXTRACT_ASSETS" -eq 1 ]] || return 0
    [[ -d "$SOURCE_DIR" ]] || return 0

    while IFS= read -r archive_path; do
        archive_name="$(basename "$archive_path")"
        case "$archive_name" in
            Gtk_*)
                target_dir="$HOME/.local/share/themes"
                ;;
            Icon_*|Cursor_*)
                target_dir="$HOME/.local/share/icons"
                ;;
            Font_*|Document-Font_*|Monospace-Font_*|Bar-Font_*|Menu-Font_*|Notification-Font_*)
                target_dir="$HOME/.local/share/fonts"
                ;;
            *)
                warn "Skipping archive not used by the standalone installer: $archive_name"
                continue
                ;;
        esac

        run mkdir -p "$target_dir"
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Would extract $archive_name into $target_dir"
        else
            tar -xf "$archive_path" -C "$target_dir"
        fi
    done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.tar.gz' | sort)
}

install_packages() {
    local package_file manager

    [[ "$INSTALL_PACKAGES" -eq 1 ]] || return 0

    if command -v pacman >/dev/null 2>&1; then
        manager="pacman"
    elif command -v apt-get >/dev/null 2>&1; then
        manager="apt"
    elif command -v dnf >/dev/null 2>&1; then
        manager="dnf"
    else
        warn "No supported package manager detected. Review the files in $PACKAGES_DIR and install packages manually."
        return 0
    fi

    package_file="$PACKAGES_DIR/$manager.txt"
    [[ -f "$package_file" ]] || {
        warn "Missing package list for $manager: $package_file"
        return 0
    }

    mapfile -t packages < <(grep -Ev '^[[:space:]]*($|#)' "$package_file")
    [[ "${#packages[@]}" -gt 0 ]] || return 0

    log "Installing packages for $manager"
    case "$manager" in
        pacman)
            if [[ "$DRY_RUN" -eq 1 ]]; then
                run sudo pacman -S --needed --noconfirm "${packages[@]}"
            else
                sudo pacman -S --needed --noconfirm "${packages[@]}" || warn "pacman reported errors. Continuing."
            fi
            ;;
        apt)
            if [[ "$DRY_RUN" -eq 1 ]]; then
                run sudo apt-get update
                run sudo apt-get install -y "${packages[@]}"
            else
                sudo apt-get update || warn "apt-get update reported errors."
                sudo apt-get install -y "${packages[@]}" || warn "apt-get install reported errors. Continuing."
            fi
            ;;
        dnf)
            if [[ "$DRY_RUN" -eq 1 ]]; then
                run sudo dnf install -y "${packages[@]}"
            else
                sudo dnf install -y "${packages[@]}" || warn "dnf install reported errors. Continuing."
            fi
            ;;
    esac
}

configure_theme_settings() {
    local gtk_theme icon_theme color_scheme cursor_theme cursor_size ui_font ui_font_size monospace_font monospace_font_size

    gtk_theme="$(theme_var GTK_THEME)"
    icon_theme="$(theme_var ICON_THEME)"
    color_scheme="$(theme_var COLOR_SCHEME)"
    cursor_theme="$(theme_var CURSOR_THEME)"
    cursor_size="$(theme_var CURSOR_SIZE)"
    ui_font="$(theme_var FONT)"
    ui_font_size="$(theme_var FONT_SIZE)"
    monospace_font="$(theme_var MONOSPACE_FONT)"
    monospace_font_size="$(theme_var MONOSPACE_FONT_SIZE)"

    gtk_theme="${gtk_theme:-Adwaita-dark}"
    icon_theme="${icon_theme:-Adwaita}"
    color_scheme="${color_scheme:-prefer-dark}"
    cursor_theme="${cursor_theme:-Bibata-Modern-Ice}"
    cursor_size="${cursor_size:-24}"
    ui_font="${ui_font:-Cantarell}"
    ui_font_size="${ui_font_size:-10}"
    monospace_font="${monospace_font:-CaskaydiaCove Nerd Font Mono}"
    monospace_font_size="${monospace_font_size:-10}"

    write_text_file "$HOME/.config/gtk-3.0/settings.ini" "[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=$icon_theme
gtk-cursor-theme-name=$cursor_theme
gtk-cursor-theme-size=$cursor_size
gtk-font-name=$ui_font $ui_font_size
gtk-application-prefer-dark-theme=1"

    write_text_file "$HOME/.gtkrc-2.0" "gtk-theme-name=\"$gtk_theme\"
gtk-icon-theme-name=\"$icon_theme\"
gtk-cursor-theme-name=\"$cursor_theme\"
gtk-cursor-theme-size=$cursor_size
gtk-font-name=\"$ui_font $ui_font_size\""

    write_text_file "$HOME/.config/xsettingsd/xsettingsd.conf" "Net/ThemeName \"$gtk_theme\"
Net/IconThemeName \"$icon_theme\"
Gtk/CursorThemeName \"$cursor_theme\"
Gtk/CursorThemeSize $cursor_size"

    write_text_file "$HOME/.config/qt5ct/qt5ct.conf" "[Appearance]
icon_theme=$icon_theme
style=kvantum

[Fonts]
fixed=\"$monospace_font,$monospace_font_size,-1,5,50,0,0,0,0,0\"
general=\"$ui_font,$ui_font_size,-1,5,50,0,0,0,0,0\""

    write_text_file "$HOME/.config/qt6ct/qt6ct.conf" "[Appearance]
icon_theme=$icon_theme
style=kvantum

[Fonts]
fixed=\"$monospace_font,$monospace_font_size,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\"
general=\"$ui_font,$ui_font_size,-1,5,400,0,0,0,0,0,0,0,0,0,0,1\""

    write_text_file "$HOME/.config/Kvantum/kvantum.kvconfig" "[General]
theme=wallbash"

    if [[ -d "$HOME/.local/share/themes/$gtk_theme/gtk-4.0" ]]; then
        backup_path "$HOME/.config/gtk-4.0"
        if [[ "$DRY_RUN" -eq 1 ]]; then
            log "Would link GTK4 theme from $HOME/.local/share/themes/$gtk_theme/gtk-4.0"
        else
            rm -rf "$HOME/.config/gtk-4.0"
            ln -snf "$HOME/.local/share/themes/$gtk_theme/gtk-4.0" "$HOME/.config/gtk-4.0"
        fi
    fi

    if command -v gsettings >/dev/null 2>&1; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            run gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
            run gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
            run gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"
            run gsettings set org.gnome.desktop.interface cursor-size "$cursor_size"
            run gsettings set org.gnome.desktop.interface color-scheme "$color_scheme"
        else
            gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" || true
            gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" || true
            gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" || true
            gsettings set org.gnome.desktop.interface cursor-size "$cursor_size" || true
            gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" || true
        fi
    fi
}

apply_theme_files() {
    write_template_body "$THEME_DIR/hypr.theme" "$HOME/.config/hypr/themes/theme.conf" 1
    copy_file "$DOTS_DIR/.config/hypr/themes/colors.conf" "$HOME/.config/hypr/themes/colors.conf"
    write_template_body "$THEME_DIR/kitty.theme" "$HOME/.config/kitty/theme.conf" 0
    write_template_body "$THEME_DIR/rofi.theme" "$HOME/.config/rofi/theme.rasi" 0
    write_template_body "$THEME_DIR/waybar.theme" "$HOME/.config/waybar/theme.css" 0
    write_template_body "$THEME_DIR/kvantum/kvconfig.theme" "$HOME/.config/Kvantum/wallbash/wallbash.kvconfig" 0
    write_template_body "$THEME_DIR/kvantum/kvantum.theme" "$HOME/.config/Kvantum/wallbash/wallbash.svg" 0
}

copy_theme_assets() {
    local chosen_wallpaper

    run mkdir -p "$MANUAL_SHARE_DIR"
    copy_dir_contents "$THEME_DIR/wallpapers" "$MANUAL_SHARE_DIR/wallpapers"
    copy_dir_contents "$THEME_DIR/logo" "$MANUAL_SHARE_DIR/logo"

    chosen_wallpaper="$(pick_wallpaper)"
    if [[ -n "$chosen_wallpaper" ]]; then
        copy_file "$chosen_wallpaper" "$MANUAL_SHARE_DIR/default-wallpaper$(printf '%s' "$chosen_wallpaper" | sed 's|.*\(\.[^.]*\)$|\1|')"
    fi
}

install_bundle_mode() {
    log "Installing bundled profile"
    copy_dir_contents "$DOTS_DIR/.config" "$HOME/.config"
    copy_dir_contents "$DOTS_DIR/.local" "$HOME/.local"
    copy_file "$DOTS_DIR/.gtkrc-2.0" "$HOME/.gtkrc-2.0"
    copy_file "$DOTS_DIR/.zshenv" "$HOME/.zshenv"
    apply_theme_files
    copy_theme_assets
    configure_theme_settings
}

install_manual_pure_mode() {
    local gtk_theme icon_theme cursor_theme cursor_size ui_font ui_font_size monospace_font monospace_font_size wallpaper_source wallpaper_path wallpaper_name

    log "Installing manual-pure profile"

    gtk_theme="$(theme_var GTK_THEME)"
    icon_theme="$(theme_var ICON_THEME)"
    cursor_theme="$(theme_var CURSOR_THEME)"
    cursor_size="$(theme_var CURSOR_SIZE)"
    ui_font="$(theme_var FONT)"
    ui_font_size="$(theme_var FONT_SIZE)"
    monospace_font="$(theme_var MONOSPACE_FONT)"
    monospace_font_size="$(theme_var MONOSPACE_FONT_SIZE)"

    gtk_theme="${gtk_theme:-Adwaita-dark}"
    icon_theme="${icon_theme:-Adwaita}"
    cursor_theme="${cursor_theme:-Bibata-Modern-Ice}"
    cursor_size="${cursor_size:-24}"
    ui_font="${ui_font:-Cantarell}"
    ui_font_size="${ui_font_size:-10}"
    monospace_font="${monospace_font:-CaskaydiaCove Nerd Font Mono}"
    monospace_font_size="${monospace_font_size:-10}"

    copy_dir_contents "$THEME_DIR/wallpapers" "$MANUAL_SHARE_DIR/wallpapers"
    copy_dir_contents "$THEME_DIR/logo" "$MANUAL_SHARE_DIR/logo"
    copy_dir_contents "$DOTS_DIR/.config/hypr/shaders" "$HOME/.config/hypr/shaders"
    copy_file "$DOTS_DIR/.config/hypr/animations.conf" "$HOME/.config/hypr/animations.conf"
    copy_file "$DOTS_DIR/.config/hypr/userprefs.conf" "$HOME/.config/hypr/userprefs.conf"
    copy_file "$DOTS_DIR/.config/hypr/windowrules.conf" "$HOME/.config/hypr/windowrules.conf"
    copy_file "$DOTS_DIR/.config/hypr/monitors.conf" "$HOME/.config/hypr/monitors.conf"
    copy_file "$DOTS_DIR/.config/hypr/shaders.conf" "$HOME/.config/hypr/shaders.conf"
    copy_file "$DOTS_DIR/.config/hypr/hyprsunset.conf" "$HOME/.config/hypr/hyprsunset.conf"
    copy_file "$DOTS_DIR/.config/dunst/dunst.conf" "$HOME/.config/dunst/dunst.conf"
    copy_file "$DOTS_DIR/.config/swaync/config.json" "$HOME/.config/swaync/config.json"
    copy_file "$DOTS_DIR/.config/swaync/style.css" "$HOME/.config/swaync/style.css"
    copy_file "$DOTS_DIR/.config/swaync/user-style.css" "$HOME/.config/swaync/user-style.css"

    apply_theme_files
    configure_theme_settings

    wallpaper_source="$(pick_wallpaper)"
    wallpaper_name="$(basename "$wallpaper_source")"
    if [[ -z "$wallpaper_name" ]]; then
        wallpaper_name="wallpaper.png"
    fi
    wallpaper_path="$MANUAL_SHARE_DIR/wallpapers/$wallpaper_name"

    write_text_file "$HOME/.config/hypr/themes/standalone.conf" "\$TERMINAL=kitty
\$FILE_MANAGER=dolphin
\$BROWSER=xdg-open
\$MENU=rofi -show drun -theme $HOME/.config/rofi/launcher.rasi
\$CURSOR_THEME=$cursor_theme
\$CURSOR_SIZE=$cursor_size
\$FONT=$ui_font
\$FONT_SIZE=$ui_font_size
\$MONOSPACE_FONT=$monospace_font
\$MONOSPACE_FONT_SIZE=$monospace_font_size
\$GTK_THEME=$gtk_theme
\$ICON_THEME=$icon_theme"

    write_text_file "$HOME/.config/hypr/hyprpaper.conf" "preload = $wallpaper_path
wallpaper = ,$wallpaper_path
splash = false"

    write_text_file "$HOME/.config/hypr/hyprland.conf" "source = $HOME/.config/hypr/themes/standalone.conf
source = $HOME/.config/hypr/themes/colors.conf
source = $HOME/.config/hypr/themes/theme.conf
source = $HOME/.config/hypr/monitors.conf
source = $HOME/.config/hypr/userprefs.conf
source = $HOME/.config/hypr/windowrules.conf
source = $HOME/.config/hypr/animations.conf
source = $HOME/.config/hypr/shaders.conf
source = $HOME/.config/hypr/keybindings.conf

env = XCURSOR_THEME,\$CURSOR_THEME
env = XCURSOR_SIZE,\$CURSOR_SIZE
env = HYPRCURSOR_THEME,\$CURSOR_THEME
env = HYPRCURSOR_SIZE,\$CURSOR_SIZE
env = QT_QPA_PLATFORMTHEME,qt6ct
env = GTK_THEME,\$GTK_THEME

exec-once = sh -lc 'command -v dbus-update-activation-environment >/dev/null && dbus-update-activation-environment --systemd --all'
exec-once = sh -lc 'command -v hyprpaper >/dev/null && hyprpaper'
exec-once = sh -lc 'command -v waybar >/dev/null && waybar'
exec-once = sh -lc 'command -v dunst >/dev/null && dunst'
exec-once = sh -lc 'command -v nm-applet >/dev/null && nm-applet'
exec-once = sh -lc 'command -v udiskie >/dev/null && udiskie -t'
exec-once = sh -lc 'command -v hyprctl >/dev/null && hyprctl setcursor \"$cursor_theme\" \"$cursor_size\"'"

    write_text_file "$HOME/.config/hypr/keybindings.conf" "\$mainMod = SUPER

bind = \$mainMod, Return, exec, \$TERMINAL
bind = \$mainMod, D, exec, \$MENU
bind = \$mainMod, E, exec, sh -lc 'command -v dolphin >/dev/null && dolphin || xdg-open \"$HOME\"'
bind = \$mainMod, Q, killactive
bind = \$mainMod Shift, Q, exit
bind = \$mainMod, F, fullscreen, 0
bind = \$mainMod, V, togglefloating
bind = \$mainMod, J, togglesplit
bind = \$mainMod, Space, exec, \$MENU
bind = \$mainMod, L, exec, loginctl lock-session
bind = \$mainMod Shift, R, exec, hyprctl reload
bind = , Print, exec, sh -lc 'command -v grim >/dev/null && command -v slurp >/dev/null && grim -g \"\$(slurp)\" - | wl-copy'
bindl = , XF86AudioRaiseVolume, exec, sh -lc 'command -v pamixer >/dev/null && pamixer -i 5'
bindl = , XF86AudioLowerVolume, exec, sh -lc 'command -v pamixer >/dev/null && pamixer -d 5'
bindl = , XF86AudioMute, exec, sh -lc 'command -v pamixer >/dev/null && pamixer -t'
bindl = , XF86MonBrightnessUp, exec, sh -lc 'command -v brightnessctl >/dev/null && brightnessctl s +5%'
bindl = , XF86MonBrightnessDown, exec, sh -lc 'command -v brightnessctl >/dev/null && brightnessctl s 5%-'

bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10

bind = \$mainMod Shift, 1, movetoworkspace, 1
bind = \$mainMod Shift, 2, movetoworkspace, 2
bind = \$mainMod Shift, 3, movetoworkspace, 3
bind = \$mainMod Shift, 4, movetoworkspace, 4
bind = \$mainMod Shift, 5, movetoworkspace, 5
bind = \$mainMod Shift, 6, movetoworkspace, 6
bind = \$mainMod Shift, 7, movetoworkspace, 7
bind = \$mainMod Shift, 8, movetoworkspace, 8
bind = \$mainMod Shift, 9, movetoworkspace, 9
bind = \$mainMod Shift, 0, movetoworkspace, 10"

    write_text_file "$HOME/.config/hypr/hypridle.conf" "general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

listener {
    timeout = 360
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}"

    write_text_file "$HOME/.config/hypr/hyprlock.conf" "source = $HOME/.config/hypr/themes/colors.conf

background {
    path = $wallpaper_path
    blur_passes = 2
    blur_size = 6
}

label {
    text = cmd[update:1000] date +\"%H:%M\"
    color = rgba(\$wallbash_txt1_rgba)
    font_size = 64
    position = 0, 130
    halign = center
    valign = center
}

label {
    text = cmd[update:1000] date +\"%A, %d %B\"
    color = rgba(\$wallbash_txt1_rgba)
    font_size = 18
    position = 0, 80
    halign = center
    valign = center
}

input-field {
    size = 280, 56
    position = 0, -80
    outline_thickness = 2
    dots_size = 0.2
    fade_on_empty = false
    font_color = rgba(\$wallbash_txt1_rgba)
    inner_color = rgba(\$wallbash_pry1_rgba)
    outer_color = rgba(\$wallbash_pry3_rgba)
    check_color = rgba(\$wallbash_pry4_rgba)
    fail_color = rgba(\$wallbash_4xa8_rgba)
    rounding = 16
    placeholder_text = <i>Password</i>
}"

    write_text_file "$HOME/.config/kitty/kitty.conf" "font_family $monospace_font
font_size $monospace_font_size
enable_audio_bell no
window_padding_width 18
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
include theme.conf"

    write_text_file "$HOME/.config/rofi/config.rasi" "@theme \"$HOME/.config/rofi/launcher.rasi\""

    write_text_file "$HOME/.config/rofi/launcher.rasi" "@import \"theme.rasi\"

configuration {
    modi: \"drun,run,window\";
    show-icons: true;
    drun-display-format: \"{name}\";
}

* {
    font: \"$ui_font 11\";
}

window {
    width: 42%;
    border: 2px;
    border-color: @main-br;
    border-radius: 18px;
    background-color: @main-bg;
}

mainbox {
    children: [inputbar, listview];
    spacing: 14px;
    padding: 18px;
}

inputbar {
    children: [prompt, entry];
    spacing: 10px;
    padding: 12px 14px;
    border: 0px;
    border-radius: 14px;
    background-color: @main-bg;
}

prompt {
    text-color: @main-ex;
}

entry {
    text-color: @main-fg;
    placeholder: \"Search\";
    placeholder-color: @main-fg;
}

listview {
    lines: 10;
    columns: 1;
    fixed-height: false;
    border: 0px;
    scrollbar: false;
    background-color: transparent;
}

element {
    padding: 12px;
    border-radius: 12px;
    text-color: @main-fg;
    background-color: transparent;
}

element selected {
    background-color: @select-bg;
    text-color: @select-fg;
}"

    write_text_file "$HOME/.config/waybar/config.jsonc" "{
  \"layer\": \"top\",
  \"position\": \"top\",
  \"reload_style_on_change\": true,
  \"modules-left\": [\"hyprland/workspaces\"],
  \"modules-center\": [\"clock\"],
  \"modules-right\": [\"pulseaudio\", \"network\", \"cpu\", \"memory\", \"tray\", \"battery\"],
  \"clock\": {
    \"format\": \"{:%H:%M}\",
    \"tooltip-format\": \"{:%A %d %B %Y}\"
  },
  \"pulseaudio\": {
    \"format\": \"VOL {volume}%\",
    \"format-muted\": \"MUTE\",
    \"scroll-step\": 5
  },
  \"network\": {
    \"format-wifi\": \"WIFI {signalStrength}%\",
    \"format-ethernet\": \"LAN\",
    \"format-disconnected\": \"OFF\"
  },
  \"cpu\": {
    \"format\": \"CPU {usage}%\"
  },
  \"memory\": {
    \"format\": \"RAM {}%\"
  },
  \"battery\": {
    \"format\": \"BAT {capacity}%\",
    \"format-charging\": \"CHR {capacity}%\",
    \"format-plugged\": \"AC\"
  },
  \"tray\": {
    \"spacing\": 10
  }
}"

    write_text_file "$HOME/.config/waybar/style.css" "@import \"theme.css\";
@import \"user-style.css\";

* {
    font-family: \"$ui_font\", \"$monospace_font\";
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: transparent;
    color: @main-fg;
}

.modules-left,
.modules-center,
.modules-right {
    background: @main-bg;
    border: 1px solid transparent;
    border-radius: 16px;
    padding: 0 10px;
    margin: 8px 10px 0 10px;
}

#workspaces button {
    color: @main-fg;
    background: transparent;
    border: 0;
    border-radius: 10px;
    padding: 0 8px;
    margin: 4px 2px;
}

#workspaces button.active {
    background: @wb-act-bg;
    color: @wb-act-fg;
}

#workspaces button:hover {
    background: @wb-hvr-bg;
    color: @wb-hvr-fg;
}

#clock,
#pulseaudio,
#network,
#cpu,
#memory,
#battery,
#tray {
    padding: 0 10px;
    margin: 4px 0;
}

tooltip {
    background: @main-bg;
    color: @main-fg;
    border: 1px solid @main-br;
}"

    write_text_file "$HOME/.config/waybar/user-style.css" "/* Add local overrides here. */"
}

main() {
    install_packages
    extract_assets

    case "$MODE" in
        bundle)
            install_bundle_mode
            ;;
        manual-pure)
            install_manual_pure_mode
            ;;
        *)
            die "Unknown mode: $MODE"
            ;;
    esac

    log "Done. Mode: $MODE"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        log "Backup directory: $BACKUP_ROOT"
    fi
}

main "$@"


param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Reset-Directory {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path | Out-Null
}

function Copy-IfExists {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Source) {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

function Write-Utf8NoBomLf {
    param(
        [string]$Path,
        [string]$Content
    )

    $normalized = ($Content -replace "`r`n", "`n" -replace "`r", "`n").TrimStart([char]0xFEFF)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $bytes = $utf8NoBom.GetBytes($normalized)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

$dotFilesRoot = Join-Path $RepoRoot "DOT_FILES"
$configsRoot = Join-Path $RepoRoot "Configs"
$sourceAssets = Join-Path $RepoRoot "Source\assets"
$restoreList = Join-Path $RepoRoot "Scripts\restore_cfg.lst"
$restoreLegacy = Join-Path $RepoRoot "Scripts\restore_cfg.psv"
$themeList = Join-Path $RepoRoot "Scripts\themepatcher.lst"
$tempThemeRoot = Join-Path $RepoRoot ".theme_tmp"
$installTemplate = Join-Path $RepoRoot "Scripts\theme_bundle_install.sh.template"

Reset-Directory -Path $dotFilesRoot

$themes = @(
    @{
        Name = "Catppuccin-Mocha"
        Display = "Catppuccin Mocha"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Catppuccin-Mocha"
        Preview = @("theme_mocha_1.png", "theme_mocha_2.png")
    },
    @{
        Name = "Catppuccin-Latte"
        Display = "Catppuccin Latte"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Catppuccin-Latte"
        Preview = @("theme_latte_1.png", "theme_latte_2.png")
    },
    @{
        Name = "Rose-Pine"
        Display = "Rose Pine"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Rose-Pine"
        Preview = @("theme_rosine_1.png", "theme_rosine_2.png")
    },
    @{
        Name = "Tokyo-Night"
        Display = "Tokyo Night"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Tokyo-Night"
        Preview = @("theme_tokyo_1.png", "theme_tokyo_2.png")
    },
    @{
        Name = "Material-Sakura"
        Display = "Material Sakura"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Material-Sakura"
        Preview = @("theme_maura_1.png", "theme_maura_2.png")
    },
    @{
        Name = "Graphite-Mono"
        Display = "Graphite Mono"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Graphite-Mono"
        Preview = @("theme_graph_1.png", "theme_graph_2.png")
    },
    @{
        Name = "Decay-Green"
        Display = "Decay Green"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Decay-Green"
        Preview = @("theme_decay_1.png", "theme_decay_2.png")
    },
    @{
        Name = "Edge-Runner"
        Display = "Edge Runner"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Edge-Runner"
        Preview = @("theme_cedge_1.png", "theme_cedge_2.png")
    },
    @{
        Name = "Frosted-Glass"
        Display = "Frosted Glass"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Frosted-Glass"
        Preview = @("theme_frosted_1.png", "theme_frosted_2.png")
    },
    @{
        Name = "Gruvbox-Retro"
        Display = "Gruvbox Retro"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Gruvbox-Retro"
        Preview = @("theme_gruvbox_1.png", "theme_gruvbox_2.png")
    },
    @{
        Name = "Synth-Wave"
        Display = "Synth Wave"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Synth-Wave"
        Preview = @()
    },
    @{
        Name = "Nordic-Blue"
        Display = "Nordic Blue"
        Repo = "https://github.com/HyDE-Project/hyde-themes/tree/Nordic-Blue"
        Preview = @()
    }
)

$basePackages = @(
    "hyprland",
    "hyprlock",
    "hypridle",
    "waybar",
    "rofi",
    "dunst",
    "kitty",
    "swaylock-effects",
    "swww or hyprpaper",
    "qt5ct",
    "qt6ct",
    "kvantum",
    "nwg-look",
    "fastfetch",
    "fish or zsh",
    "starship",
    "dolphin",
    "libinput-gestures"
)

$pacmanPackages = @(
    "hyprland",
    "hyprpaper",
    "hyprlock",
    "hypridle",
    "waybar",
    "rofi",
    "kitty",
    "dunst",
    "wl-clipboard",
    "grim",
    "slurp",
    "pamixer",
    "brightnessctl",
    "playerctl",
    "network-manager-applet",
    "udiskie",
    "polkit-kde-agent",
    "qt5ct",
    "qt6ct",
    "kvantum",
    "nwg-look",
    "xdg-desktop-portal-hyprland"
)

$aptPackages = @(
    "hyprland",
    "hyprpaper",
    "hyprlock",
    "hypridle",
    "waybar",
    "rofi",
    "kitty",
    "dunst",
    "wl-clipboard",
    "grim",
    "slurp",
    "pamixer",
    "brightnessctl",
    "playerctl",
    "network-manager-gnome",
    "udiskie",
    "policykit-1-gnome",
    "qt5ct",
    "qt6ct",
    "kvantum",
    "nwg-look",
    "xdg-desktop-portal-hyprland"
)

$dnfPackages = @(
    "hyprland",
    "hyprpaper",
    "hyprlock",
    "hypridle",
    "waybar",
    "rofi",
    "kitty",
    "dunst",
    "wl-clipboard",
    "grim",
    "slurp",
    "pamixer",
    "brightnessctl",
    "playerctl",
    "network-manager-applet",
    "udiskie",
    "polkit-kde",
    "qt5ct",
    "qt6ct",
    "kvantum",
    "nwg-look",
    "xdg-desktop-portal-hyprland"
)

$commonSourceArchives = @(
    "Source\arcs\Cursor_BibataIce.tar.gz",
    "Source\arcs\Font_CascadiaCove.tar.gz"
)

$downloadedThemes = @(
    $themes |
        Where-Object {
            $candidateRoot = Join-Path (Join-Path $tempThemeRoot $_.Name) "Configs\.config\hyde\themes"
            (Test-Path -LiteralPath $candidateRoot) -and ((Get-ChildItem -LiteralPath $candidateRoot -Directory | Measure-Object).Count -gt 0)
        } |
        ForEach-Object { $_.Display }
)

$downloadedSummary = if ($downloadedThemes.Count -gt 0) {
    ($downloadedThemes | ForEach-Object { "- $_" }) -join "`r`n"
}
else {
    "- Ningun tema oficial descargado todavia."
}

$globalStatusText = if ($downloadedThemes.Count -eq $themes.Count) {
    "Los 12 temas oficiales ya estan descargados e integrados en sus carpetas correspondientes."
}
elseif ($downloadedThemes.Count -gt 0) {
    "Hay temas oficiales descargados e integrados parcialmente. El resto sigue con la base comun preparada."
}
else {
    "Este repo no trae dentro de Configs los 12 temas oficiales ya descargados. HyDE los instala desde repos externos."
}

$globalReadme = @"
# DOT_FILES

Export manual de dotfiles por tema, pensado para usar sin depender de HyDE en tiempo de ejecucion.

## Estructura

- Cada carpeta de tema incluye la carpeta dots con la base de configuracion actual de este repo.
- Cada tema incluye assets con previews locales si existen.
- Cada tema incluye manifests con restore_cfg.lst, restore_cfg.psv y themepatcher.lst como referencia.
- Cada tema incluye un README.md con dependencias y pasos de instalacion manual.
- Cada tema incluye install.sh y packages/ para instalarlo de forma independiente.

## Estado

$globalStatusText

## Temas descargados

$downloadedSummary

## Nota importante

- La base comun de dotfiles si esta incluida y se ha duplicado dentro de cada tema.
- Cada tema usa su propia carpeta y mantiene sus wallpapers, logos y fuentes de origen por separado.
- En cada README se indica la URL fuente del tema y los archivos upstream que quedaron incluidos.

## Regenerar

Si cambias Configs y quieres rehacer esta exportacion:

powershell -ExecutionPolicy Bypass -File .\Scripts\export_dot_files.ps1
"@

Write-Utf8NoBomLf -Path (Join-Path $dotFilesRoot "README.md") -Content $globalReadme

foreach ($theme in $themes) {
    $themeRoot = Join-Path $dotFilesRoot $theme.Name
    $dotsRoot = Join-Path $themeRoot "dots"
    $assetsRoot = Join-Path $themeRoot "assets"
    $manifestRoot = Join-Path $themeRoot "manifests"
    $sourceRoot = Join-Path $themeRoot "source"
    $packagesRoot = Join-Path $themeRoot "packages"
    $manualPureRoot = Join-Path $themeRoot "manual-pure"
    $themeConfigRoot = Join-Path $dotsRoot ".config\hyde\themes\$($theme.Display)"
    $themeWallpapers = Join-Path $themeConfigRoot "wallpapers"
    $themeLogos = Join-Path $themeConfigRoot "logo"
    $upstreamRoot = Join-Path $tempThemeRoot $theme.Name
    $upstreamThemesRoot = Join-Path $upstreamRoot "Configs\.config\hyde\themes"
    $upstreamSourceRoot = Join-Path $upstreamRoot "Source"
    $upstreamReadme = Join-Path $upstreamRoot "README.md"
    $upstreamThemeDir = $null
    if (Test-Path -LiteralPath $upstreamThemesRoot) {
        $upstreamThemeDir = Get-ChildItem -LiteralPath $upstreamThemesRoot -Directory | Select-Object -First 1
    }
    $upstreamThemeConfig = if ($null -ne $upstreamThemeDir) { $upstreamThemeDir.FullName } else { $null }
    $upstreamThemeName = if ($null -ne $upstreamThemeDir) { $upstreamThemeDir.Name } else { $theme.Display }
    $upstreamDownloaded = $null -ne $upstreamThemeConfig

    Ensure-Directory -Path $themeRoot
    Ensure-Directory -Path $assetsRoot
    Ensure-Directory -Path $manifestRoot
    Ensure-Directory -Path $sourceRoot
    Ensure-Directory -Path $packagesRoot
    Ensure-Directory -Path $manualPureRoot

    Copy-Item -LiteralPath $configsRoot -Destination $dotsRoot -Recurse -Force

    if (Test-Path -LiteralPath $themeConfigRoot) {
        Remove-Item -LiteralPath $themeConfigRoot -Recurse -Force
    }
    Ensure-Directory -Path $themeConfigRoot

    if ($upstreamDownloaded) {
        Get-ChildItem -LiteralPath $upstreamThemeConfig -Force | Copy-Item -Destination $themeConfigRoot -Recurse -Force
    }
    else {
        Ensure-Directory -Path $themeWallpapers
        Ensure-Directory -Path $themeLogos

        $placeholder = @"
# $($theme.Display)

Esta carpeta queda reservada para los archivos propios del tema.

Esperado aqui:

- hypr.theme
- theme.dcol si el tema sobreescribe colores dominantes
- wallpapers/
- logo/ opcional
- cualquier override adicional que quieras mantener local

Fuente oficial:
$($theme.Repo)
"@

        Write-Utf8NoBomLf -Path (Join-Path $themeConfigRoot "README.md") -Content $placeholder
    }

    Copy-IfExists -Source $restoreList -Destination $manifestRoot
    Copy-IfExists -Source $restoreLegacy -Destination $manifestRoot
    Copy-IfExists -Source $themeList -Destination $manifestRoot

    foreach ($previewName in $theme.Preview) {
        Copy-IfExists -Source (Join-Path $sourceAssets $previewName) -Destination $assetsRoot
    }

    if (Test-Path -LiteralPath $upstreamSourceRoot) {
        Get-ChildItem -LiteralPath $upstreamSourceRoot -Force | Copy-Item -Destination $sourceRoot -Recurse -Force
    }

    foreach ($archiveRel in $commonSourceArchives) {
        Copy-IfExists -Source (Join-Path $RepoRoot $archiveRel) -Destination $sourceRoot
    }

    if (Test-Path -LiteralPath $upstreamReadme) {
        Copy-Item -LiteralPath $upstreamReadme -Destination (Join-Path $sourceRoot "UPSTREAM_README.md") -Force
    }

    $installScript = (Get-Content -LiteralPath $installTemplate -Raw).
        Replace("__THEME_SLUG__", $theme.Name).
        Replace("__THEME_NAME__", $theme.Display).
        Replace("__PACMAN_PACKAGES__", (($pacmanPackages | ForEach-Object { '    "' + $_ + '"' }) -join "`r`n")).
        Replace("__APT_PACKAGES__", (($aptPackages | ForEach-Object { '    "' + $_ + '"' }) -join "`r`n")).
        Replace("__DNF_PACKAGES__", (($dnfPackages | ForEach-Object { '    "' + $_ + '"' }) -join "`r`n"))
    Write-Utf8NoBomLf -Path (Join-Path $themeRoot "install.sh") -Content $installScript

    Write-Utf8NoBomLf -Path (Join-Path $packagesRoot "pacman.txt") -Content (($pacmanPackages -join "`n") + "`n")
    Write-Utf8NoBomLf -Path (Join-Path $packagesRoot "apt.txt") -Content (($aptPackages -join "`n") + "`n")
    Write-Utf8NoBomLf -Path (Join-Path $packagesRoot "dnf.txt") -Content (($dnfPackages -join "`n") + "`n")

    $manualPureNote = if ($theme.Name -eq "Catppuccin-Mocha") {
        "Este es el tema piloto recomendado para validar el modo manual-pure antes de replicar ajustes finos al resto."
    }
    else {
        "Este tema tambien puede instalarse con el modo manual-pure usando el instalador de esta carpeta."
    }

    $manualPureReadme = @"
# Manual Pure

$manualPureNote

## Objetivo

- Usar el tema sin depender de HyDE en tiempo de ejecucion.
- Mantener Hyprland, Waybar, Rofi y Kitty en una forma mas controlable y auditable.
- Aplicar los archivos reales del tema, wallpapers y assets desde esta carpeta.

## Uso

bash ./install.sh --manual-pure

## Que hace

- Instala paquetes desde packages/ si no usas --skip-packages.
- Extrae GTK, iconos, cursores y fuentes desde source/ si existen.
- Genera una configuracion minima y standalone para Hyprland, Hyprpaper, Waybar, Kitty y Rofi.
- Aplica hypr.theme, kitty.theme, rofi.theme, waybar.theme y Kvantum sin usar themepatcher.
"@
    Write-Utf8NoBomLf -Path (Join-Path $manualPureRoot "README.md") -Content $manualPureReadme

    $sourceFiles = @()
    if (Test-Path -LiteralPath $sourceRoot) {
        $sourceFiles = Get-ChildItem -LiteralPath $sourceRoot -File | Select-Object -ExpandProperty Name
    }
    $sourceListText = if ($sourceFiles.Count -gt 0) {
        ($sourceFiles | ForEach-Object { "- $_" }) -join "`r`n"
    }
    else {
        "- No hay paquetes extra descargados para este tema."
    }

    $stateText = if ($upstreamDownloaded) {
        "El tema oficial ya fue descargado e integrado dentro de esta carpeta."
    }
    else {
        "La base del sistema esta incluida aqui, pero los archivos oficiales especificos del tema no venian dentro de este repo local."
    }

    $upstreamThemeNameText = if ($upstreamThemeName -ne $theme.Display) {
        "Nombre original del tema en upstream: $upstreamThemeName"
    }
    else {
        ""
    }

    $pkgText = ($basePackages | ForEach-Object { "- $_" }) -join "`r`n"
    $themeReadme = @"
# $($theme.Display)

Dotfiles exportados para mantener una instalacion manual y controlable.

## Contenido

- dots/: copia completa de Configs/ del repo base.
- dots/.config/hyde/themes/$($theme.Display)/: espacio preparado para los archivos propios del tema.
- assets/: previews locales del tema si estaban disponibles en este repo.
- manifests/: listas de restauracion de HyDE usadas como referencia.
- source/: archivos descargados del repo upstream del tema, incluyendo tarballs y README si existen.
- packages/: listas de paquetes para pacman, apt y dnf.
- install.sh: instalador standalone con modo manual-pure y modo bundle, con listas de paquetes embebidas.
- manual-pure/: notas del modo standalone usado como referencia.

## Estado actual

$stateText

$upstreamThemeNameText

URL fuente del tema:
$($theme.Repo)

## Archivos upstream incluidos

$sourceListText

## Paquetes base recomendados

$pkgText

## Instalacion manual sugerida

1. Recomendado: usa bash ./install.sh --manual-pure para una instalacion mas controlable.
2. Si prefieres el bundle completo exportado, usa bash ./install.sh --bundle.
3. Revisa packages/ si quieres instalar dependencias a mano antes de ejecutar el script.
4. Revisa manual-pure/README.md para el modo standalone.
5. Si quieres hacer la copia manual tradicional, dots/ sigue disponible como base completa.
6. Revisa manifests/restore_cfg.lst para ver que paquetes esperaba cada bloque de configuracion.

## Para una distro de seguridad

- Instala solo los componentes que uses.
- Usa preferentemente install.sh --manual-pure en vez de themepatcher o restore scripts de HyDE.
- Prefiere copiar archivo por archivo y revisar exec, source y scripts en .local/bin y .local/lib.
- Si no quieres nada dinamico, puedes dejar sin uso wallbash y fijar colores manuales en Hyprland, Waybar y Kitty.
"@

    Write-Utf8NoBomLf -Path (Join-Path $themeRoot "README.md") -Content $themeReadme
}

Write-Host "DOT_FILES generated in $dotFilesRoot"

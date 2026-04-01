# Rose Pine

Dotfiles exportados para mantener una instalacion manual y controlable.

## Contenido

- dots/: copia completa de Configs/ del repo base.
- dots/.config/hyde/themes/Rose Pine/: espacio preparado para los archivos propios del tema.
- assets/: previews locales del tema si estaban disponibles en este repo.
- manifests/: listas de restauracion de HyDE usadas como referencia.
- source/: archivos descargados del repo upstream del tema, incluyendo tarballs y README si existen.
- packages/: listas de paquetes para pacman, apt y dnf.
- install.sh: instalador standalone con modo manual-pure y modo bundle.
- manual-pure/: notas del modo standalone usado como referencia.

## Estado actual

El tema oficial ya fue descargado e integrado dentro de esta carpeta.

Nombre original del tema en upstream: Rosé Pine

URL fuente del tema:
https://github.com/HyDE-Project/hyde-themes/tree/Rose-Pine

## Archivos upstream incluidos

- Cursor_BibataIce.tar.gz
- Font_CascadiaCove.tar.gz
- Gtk_RosePine.tar.gz
- Icon_TelaPink.tar.gz
- UPSTREAM_README.md

## Paquetes base recomendados

- hyprland
- hyprlock
- hypridle
- waybar
- rofi
- dunst
- kitty
- swaylock-effects
- swww or hyprpaper
- qt5ct
- qt6ct
- kvantum
- nwg-look
- fastfetch
- fish or zsh
- starship
- dolphin
- libinput-gestures

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

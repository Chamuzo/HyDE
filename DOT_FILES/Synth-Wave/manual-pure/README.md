# Manual Pure

Este tema tambien puede instalarse con el modo manual-pure usando el instalador de esta carpeta.

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

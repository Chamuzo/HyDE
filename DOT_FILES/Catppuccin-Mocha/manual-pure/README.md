# Manual Pure

Este es el tema piloto recomendado para validar el modo manual-pure antes de replicar ajustes finos al resto.

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

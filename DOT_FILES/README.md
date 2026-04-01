# DOT_FILES

Export manual de dotfiles por tema, pensado para usar sin depender de HyDE en tiempo de ejecucion.

## Estructura

- Cada carpeta de tema incluye la carpeta dots con la base de configuracion actual de este repo.
- Cada tema incluye assets con previews locales si existen.
- Cada tema incluye manifests con restore_cfg.lst, restore_cfg.psv y themepatcher.lst como referencia.
- Cada tema incluye un README.md con dependencias y pasos de instalacion manual.
- Cada tema incluye install.sh y packages/ para instalarlo de forma independiente.

## Estado

Los 12 temas oficiales ya estan descargados e integrados en sus carpetas correspondientes.

## Temas descargados

- Catppuccin Mocha
- Catppuccin Latte
- Rose Pine
- Tokyo Night
- Material Sakura
- Graphite Mono
- Decay Green
- Edge Runner
- Frosted Glass
- Gruvbox Retro
- Synth Wave
- Nordic Blue

## Nota importante

- La base comun de dotfiles si esta incluida y se ha duplicado dentro de cada tema.
- Cada tema usa su propia carpeta y mantiene sus wallpapers, logos y fuentes de origen por separado.
- En cada README se indica la URL fuente del tema y los archivos upstream que quedaron incluidos.

## Regenerar

Si cambias Configs y quieres rehacer esta exportacion:

powershell -ExecutionPolicy Bypass -File .\Scripts\export_dot_files.ps1

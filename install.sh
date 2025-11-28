#!/usr/bin/env bash

# Oh My Bash Enhanced Installer
# Instalación simple y directa

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Oh My Bash Enhanced Installer${NC}"
echo -e "${BLUE}=================================${NC}"

# Detectar si estamos en el repo o instalando remotamente
if [[ -f "oh-my-bash.sh" && -d "lib" ]]; then
    echo -e "${GREEN}📂 Instalando desde directorio local${NC}"
    SOURCE_DIR="$(pwd)"
else
    echo -e "${GREEN}📥 Descargando Oh My Bash Enhanced...${NC}"
    TEMP_DIR=$(mktemp -d)
    git clone --depth=1 https://github.com/ramgeart/oh-my-bash.git "$TEMP_DIR" 2>/dev/null
    SOURCE_DIR="$TEMP_DIR"
fi

# Directorios destino
OSH_DIR="$HOME/.oh-my-bash"
BACKUP_DIR="$HOME/.oh-my-bash.backup"
BASHRC="$HOME/.bashrc"

# Backup si existe
if [[ -d "$OSH_DIR" ]]; then
    echo -e "${YELLOW}📦 Haciendo backup del instalación anterior${NC}"
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
    mv "$OSH_DIR" "$BACKUP_DIR"
fi

# Copiar archivos
echo -e "${GREEN}📂 Instalando archivos...${NC}"
cp -r "$SOURCE_DIR" "$OSH_DIR"

# Limpiar si vinimos de git remoto
if [[ -n "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
fi

# Configurar .bashrc
INSTALL_CONFIG="
# Oh My Bash Enhanced
export OSH=\"\$HOME/.oh-my-bash\"
OSH_THEME=\"font\"
plugins=(git)
source \$OSH/oh-my-bash.sh
"

if [[ -f "$BASHRC" ]]; then
    if ! grep -q "oh-my-bash.sh" "$BASHRC"; then
        echo -e "${GREEN}📝 Agregando a $BASHRC${NC}"
        echo "$INSTALL_CONFIG" >> "$BASHRC"
    else
        echo -e "${YELLOW}⚠️  Oh My Bash ya está configurado en $BASHRC${NC}"
    fi
else
    echo -e "${GREEN}📝 Creando $BASHRC${NC}"
    echo "$INSTALL_CONFIG" > "$BASHRC"
fi

echo -e "${GREEN}✅ Instalación completada!${NC}"
echo ""
echo -e "${BLUE}🎯 Próximos pasos:${NC}"
echo -e "1. Ejecuta: ${YELLOW}source ~/.bashrc${NC}"
echo -e "2. Prueba: ${YELLOW}omb help${NC}"
echo -e "3. Activa plugins: ${YELLOW}omb plugin enable git docker${NC}"
echo -e "4. Cambia tema: ${YELLOW}omb theme use powerline-main${NC}"
echo ""
echo -e "${BLUE}📚 Comandos útiles:${NC}"
echo -e "  • omb help     - Ver ayuda completa"
echo -e "  • omb version  - Ver versiones"
echo -e "  • omb update   - Actualizar"
echo -e "  • omb reload   - Recargar configuración"
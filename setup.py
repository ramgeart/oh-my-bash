#!/usr/bin/env python3
"""
Oh My Bash Enhanced - Instalador Python
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def install_oh_my_bash():
    """Instala Oh My Bash Enhanced"""
    
    home = Path.home()
    osh_dir = home / ".oh-my-bash"
    bashrc = home / ".bashrc"
    
    print("🚀 Instalando Oh My Bash Enhanced...")
    
    # Detectar si estamos en el repo o instalando desde pip
    if os.path.exists(".git"):
        # Estamos en el repo, copiar desde aquí
        source_dir = Path.cwd()
    else:
        # Instalando desde pip, usar el directorio del paquete
        source_dir = Path(__file__).parent
    
    # Copiar archivos
    if osh_dir.exists():
        print(f"📦 Respaldo anterior en {osh_dir}.backup")
        shutil.move(osh_dir, osh_dir.with_suffix(".backup"))
    
    print(f"📂 Copiando a {osh_dir}")
    shutil.copytree(source_dir, osh_dir, ignore=shutil.ignore_patterns(
        '.git', '__pycache__', '*.pyc', 'setup.py', '*.egg-info'
    ))
    
    # Agregar a .bashrc
    osh_config = f'''
# Oh My Bash Enhanced
export OSH="{osh_dir}"
OSH_THEME="font"
plugins=(git)
source $OSH/oh-my-bash.sh
'''
    
    if bashrc.exists():
        content = bashrc.read_text()
        if "oh-my-bash.sh" not in content:
            print(f"📝 Agregando configuración a {bashrc}")
            bashrc.write_text(content + "\n" + osh_config)
        else:
            print(f"⚠️  Oh My Bash ya está configurado en {bashrc}")
    else:
        print(f"📝 Creando {bashrc} con configuración")
        bashrc.write_text(osh_config)
    
    print("✅ Instalación completada!")
    print("\n🎯 Próximos pasos:")
    print("1. Ejecuta: source ~/.bashrc")
    print("2. Prueba: omb help")
    print("3. Disfruta de todas las funciones implementadas!")

def uninstall_oh_my_bash():
    """Desinstala Oh My Bash Enhanced"""
    
    home = Path.home()
    osh_dir = home / ".oh-my-bash"
    bashrc = home / ".bashrc"
    
    print("🗑️  Desinstalando Oh My Bash Enhanced...")
    
    # Remover directorio
    if osh_dir.exists():
        shutil.rmtree(osh_dir)
        print(f"✅ Removido {osh_dir}")
    
    # Remover de .bashrc
    if bashrc.exists():
        content = bashrc.read_text()
        lines = content.split('\n')
        new_lines = []
        skip = False
        
        for line in lines:
            if "# Oh My Bash Enhanced" in line:
                skip = True
            elif skip and line.strip() == "":
                skip = False
            elif not skip:
                new_lines.append(line)
        
        bashrc.write_text('\n'.join(new_lines))
        print(f"✅ Removido de {bashrc}")
    
    print("✅ Desinstalación completada!")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "uninstall":
        uninstall_oh_my_bash()
    else:
        install_oh_my_bash()
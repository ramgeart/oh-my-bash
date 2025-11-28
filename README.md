# Oh My Bash Enhanced 🚀

Oh My Bash con **todas las funciones CLI implementadas**.

## Instalación

### Con uv (recomendado)
```bash
uv pip install git+https://github.com/ramgeart/oh-my-bash-enhanced
omb-install
```

### Con pip
```bash
pip install git+https://github.com/ramgeart/oh-my-bash-enhanced
omb-install
```

### Directo con git
```bash
git clone https://github.com/ramgeart/oh-my-bash-enhanced ~/.oh-my-bash
# Agrega al ~/.bashrc: source ~/.oh-my-bash/oh-my-bash.sh
```

## Funciones Nuevas ✨

Todas las funciones `omb` ahora funcionan:

```bash
omb help                    # Ayuda completa
omb version                 # Versiones
omb plugin list            # Ver plugins
omb plugin enable git      # Activar plugin
omb theme list             # Ver temas
omb theme use agnoster     # Usar tema
omb update                 # Actualizar
omb reload                 # Recargar
```

## Características

- ✅ **Todas las funciones CLI implementadas**
- ✅ 85+ temas incluidos
- ✅ 150+ plugins incluidos
- ✅ Actualización desde git
- ✅ Compatible con Oh My Bash original

## Uso Rápido

```bash
# Ver todos los comandos
omb help

# Activar plugins útiles
omb plugin enable git docker battery

# Usar un tema bonito
omb theme use powerline-main

# Actualizar
omb update && omb reload
```

## Desinstalar

```bash
omb-uninstall
```

---

**Repo**: https://github.com/ramgeart/oh-my-bash-enhanced  
**Original**: https://github.com/ohmybash/oh-my-bash
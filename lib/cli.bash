#!/usr/bin/env bash

_omb_module_require lib:utils

function _omb_cmd_help {
  cat << 'EOF'
Usage: omb <command> [options]

Commands:
  help                    Show this help message
  version                 Show the current version of Oh My Bash
  changelog [ref]         Show the changelog for a specific version or branch
  plugin <subcommand>     Manage plugins
    enable <plugin>       Enable a plugin
    disable <plugin>      Disable a plugin
    load <plugin>         Load a plugin
    list                  List all available plugins
    info <plugin>         Show information about a plugin
  theme <subcommand>      Manage themes
    list                  List all available themes
    use <theme>           Use a theme temporarily
    set <theme>           Set a theme permanently
  update                  Update Oh My Bash to the latest version
  pull                    Pull the latest changes from the repository
  reload                  Reload the current bash session

Examples:
  omb plugin enable git
  omb theme use agnoster
  omb update
  omb version

For more information, visit: https://github.com/ohmybash/oh-my-bash
EOF
}
function _omb_cmd_changelog {
  local ref="${1:-master}"
  
  echo "Changelog for $ref:"
  echo "=================="
  echo
  
  # Obtener los commits del ref especificado
  if command git -C "$OSH" rev-parse --verify "$ref" &>/dev/null; then
    local commits
    mapfile -t commits < <(command git -C "$OSH" log --oneline --no-merges -20 "$ref")
    
    if ((${#commits[@]} > 0)); then
      local commit
      for commit in "${commits[@]}"; do
        echo "  $commit"
      done
    else
      echo "  No commits found for $ref"
    fi
  else
    echo "  Error: Reference '$ref' not found in the repository"
    echo "  Available references:"
    command git -C "$OSH" for-each-ref --format="%(refname:short)" refs/heads refs/tags | sed 's/^/    /'
  fi
}
function _omb_cmd_plugin {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
  enable)
    if (($# == 0)); then
      echo "Error: Please specify plugin name(s) to enable"
      echo "Usage: omb plugin enable <plugin> [plugin...]"
      return 1
    fi

    local plugin
    for plugin in "$@"; do
      if _omb_plugin_exists "$plugin"; then
        if _omb_util_array_contains plugins "$plugin"; then
          echo "Plugin '$plugin' is already enabled"
        else
          plugins+=("$plugin")
          _omb_plugin_save_config
          echo "Plugin '$plugin' enabled. Please run 'omb reload' to apply changes."
        fi
      else
        echo "Error: Plugin '$plugin' not found"
        return 1
      fi
    done
    ;;

  disable)
    if (($# == 0)); then
      echo "Error: Please specify plugin name(s) to disable"
      echo "Usage: omb plugin disable <plugin> [plugin...]"
      return 1
    fi

    local plugin
    for plugin in "$@"; do
      if _omb_util_array_contains plugins "$plugin"; then
        _omb_util_array_remove plugins "$plugin"
        _omb_plugin_save_config
        echo "Plugin '$plugin' disabled. Please run 'omb reload' to apply changes."
      else
        echo "Plugin '$plugin' is not enabled"
      fi
    done
    ;;

  list)
    echo "Available plugins:"
    echo "=================="
    
    local -a available_plugins
    _comp_cmd_omb__get_available_plugins
    
    local plugin
    for plugin in "${available_plugins[@]}"; do
      if _omb_util_array_contains plugins "$plugin"; then
        echo "  ✓ $plugin (enabled)"
      else
        echo "    $plugin"
      fi
    done
    ;;

  info)
    local plugin="${1:-}"
    if [[ -z "$plugin" ]]; then
      echo "Error: Please specify a plugin name"
      echo "Usage: omb plugin info <plugin>"
      return 1
    fi

    local plugin_file
    if _omb_plugin_exists "$plugin"; then
      plugin_file=$(_omb_plugin_find_file "$plugin")
      echo "Plugin: $plugin"
      echo "File: $plugin_file"
      echo
      if [[ -f "$plugin_file" ]]; then
        echo "Description:"
        grep -E "^#.*@about|^#.*Description" "$plugin_file" | head -5 | sed 's/^# *//' | sed 's/@about/Description:/'
      fi
    else
      echo "Error: Plugin '$plugin' not found"
      return 1
    fi
    ;;

  load)
    if (($# == 0)); then
      echo "Error: Please specify plugin name(s) to load"
      echo "Usage: omb plugin load <plugin> [plugin...]"
      return 1
    fi

    local plugin
    for plugin in "$@"; do
      if _omb_plugin_exists "$plugin"; then
        _omb_module_require_plugin "$plugin"
        echo "Plugin '$plugin' loaded."
      else
        echo "Error: Plugin '$plugin' not found"
        return 1
      fi
    done
    ;;

  *)
    echo "Error: Unknown plugin subcommand '$subcommand'"
    echo "Usage: omb plugin <enable|disable|list|info|load> [args...]"
    return 1
    ;;
  esac
}

function _omb_plugin_exists {
  local plugin="$1"
  local -a plugin_files
  _omb_util_glob_expand plugin_files "{$OSH,$OSH_CUSTOM}/plugins/$plugin/{$plugin,*.plugin}.{bash,sh}"
  ((${#plugin_files[@]} > 0))
}

function _omb_plugin_find_file {
  local plugin="$1"
  local -a plugin_files
  _omb_util_glob_expand plugin_files "{$OSH,$OSH_CUSTOM}/plugins/$plugin/{$plugin,*.plugin}.{bash,sh}"
  if ((${#plugin_files[@]} > 0)); then
    _omb_util_print "${plugin_files[0]}"
  fi
}

function _omb_plugin_save_config {
  # Esta es una implementación básica que muestra las configuraciones actuales
  echo "# Current plugin configuration:"
  echo "plugins=(${plugins[@]@Q})"
}
function _omb_cmd_pull {
  echo "Pulling latest changes for Oh My Bash..."
  
  # Verificar si estamos en un repositorio git
  if [[ ! -d "$OSH/.git" ]]; then
    echo "Error: Oh My Bash directory is not a git repository"
    return 1
  fi

  # Guardar la rama actual
  local current_branch
  current_branch=$(command git -C "$OSH" rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  if [[ -z "$current_branch" ]]; then
    echo "Error: Unable to determine current branch"
    return 1
  fi

  echo "Current branch: $current_branch"
  
  # Hacer pull de los cambios
  if command git -C "$OSH" pull; then
    echo "Changes pulled successfully!"
    echo "Please run 'omb reload' to apply the changes."
  else
    echo "Error: Failed to pull changes"
    return 1
  fi
}
function _omb_cmd_reload {
  echo "Reloading Oh My Bash..."
  
  # Recargar la configuración de oh-my-bash
  if [[ -f "$OSH/oh-my-bash.sh" ]]; then
    # Guardar algunas variables importantes
    local old_OSH="$OSH"
    local old_OSH_CUSTOM="$OSH_CUSTOM"
    local old_OSH_THEME="$OSH_THEME"
    
    # Recargar oh-my-bash
    source "$OSH/oh-my-bash.sh"
    
    echo "Oh My Bash reloaded successfully!"
    echo "Theme: $OSH_THEME"
    echo "Plugins: ${plugins[*]}"
  else
    echo "Error: Oh My Bash main file not found at $OSH/oh-my-bash.sh"
    return 1
  fi
}
function _omb_cmd_theme {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
  list)
    echo "Available themes:"
    echo "=================="
    
    local -a available_themes
    _comp_cmd_omb__get_available_themes
    
    local theme
    for theme in "${available_themes[@]}"; do
      if [[ "$theme" == "$OSH_THEME" ]]; then
        echo "  ✓ $theme (current)"
      else
        echo "    $theme"
      fi
    done
    ;;

  use)
    local theme="${1:-}"
    if [[ -z "$theme" ]]; then
      echo "Error: Please specify a theme name"
      echo "Usage: omb theme use <theme>"
      return 1
    fi

    if _omb_theme_exists "$theme"; then
      _omb_module_require_theme "$theme"
      echo "Theme '$theme' loaded temporarily. This will not persist after reload."
    else
      echo "Error: Theme '$theme' not found"
      return 1
    fi
    ;;

  set)
    local theme="${1:-}"
    if [[ -z "$theme" ]]; then
      echo "Error: Please specify a theme name"
      echo "Usage: omb theme set <theme>"
      return 1
    fi

    if _omb_theme_exists "$theme"; then
      _omb_theme_set_config "$theme"
      echo "Theme '$theme' set as default. Please run 'omb reload' to apply changes."
    else
      echo "Error: Theme '$theme' not found"
      return 1
    fi
    ;;

  *)
    echo "Error: Unknown theme subcommand '$subcommand'"
    echo "Usage: omb theme <list|use|set> [args...]"
    return 1
    ;;
  esac
}

function _omb_theme_exists {
  local theme="$1"
  local -a theme_files
  _omb_util_glob_expand theme_files "{$OSH,$OSH_CUSTOM}/themes/$theme/{$theme,*.theme}.{bash,sh}"
  ((${#theme_files[@]} > 0))
}

function _omb_theme_set_config {
  local theme="$1"
  echo "# To make this theme permanent, add this line to your ~/.bashrc:"
  echo "export OSH_THEME=\"$theme\""
}
function _omb_cmd_update {
  echo "Updating Oh My Bash..."
  
  # Verificar si estamos en un repositorio git
  if [[ ! -d "$OSH/.git" ]]; then
    echo "Error: Oh My Bash directory is not a git repository"
    return 1
  fi

  # Guardar la rama actual
  local current_branch
  current_branch=$(command git -C "$OSH" rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  if [[ -z "$current_branch" ]]; then
    echo "Error: Unable to determine current branch"
    return 1
  fi

  echo "Current branch: $current_branch"
  echo "Fetching latest changes..."
  
  # Hacer fetch de los últimos cambios
  if command git -C "$OSH" fetch origin; then
    echo "Checking for updates..."
    
    # Verificar si hay actualizaciones disponibles
    local local_commit remote_commit
    local_commit=$(command git -C "$OSH" rev-parse HEAD)
    remote_commit=$(command git -C "$OSH" rev-parse "@{u}")
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
      echo "Oh My Bash is already up to date!"
    else
      echo "Updates available. Pulling changes..."
      
      # Hacer pull de los cambios
      if command git -C "$OSH" pull --rebase; then
        echo "Oh My Bash updated successfully!"
        echo "Please run 'omb reload' to apply the changes."
      else
        echo "Error: Failed to pull updates"
        return 1
      fi
    fi
  else
    echo "Error: Failed to fetch updates"
    return 1
  fi
}
function _omb_cmd_version {
  echo "Oh My Bash version: $OMB_VERSION"
  echo "Bash version: $BASH_VERSION"
}

function omb {
  if (($# == 0)); then
    _omb_cmd_help
    return 2
  fi

  # Subcommand functions start with _ so that they don't
  # appear as completion entries when looking for `omb`
  if ! _omb_util_function_exists "_omb_cmd_$1"; then
    _omb_cmd_help
    return 2
  fi

  _omb_cmd_"$@"
}


_omb_module_require lib:utils

_omb_lib_cli__init_shopt=
_omb_util_get_shopt -v _omb_lib_cli__init_shopt extglob
shopt -s extglob

function _comp_cmd_omb__describe {
  eval "set -- $1 \"\${$2[@]}\""
  local type=$1; shift
  local word desc words iword=0
  for word; do
    desc="($type) ${word#*:}" # unused
    word=${word%%:*}
    words[iword++]=$word
  done

  local -a filtered
  _omb_util_split_lines filtered "$(compgen -W '"${words[@]}"' -- "${COMP_WORDS[COMP_CWORD]}")"
  COMPREPLY+=("${filtered[@]}")
}

function _comp_cmd_omb__get_available_plugins {
  available_plugins=()

  local -a plugin_files
  _omb_util_glob_expand plugin_files '{"$OSH","$OSH_CUSTOM"}/plugins/*/{_*,*.plugin.{bash,sh}}'

  local plugin
  for plugin in "${plugin_files[@]##*/}"; do
    case $plugin in
    *.plugin.bash) plugin=${plugin%.plugin.bash} ;;
    *.plugin.sh) plugin=${plugin%.plugin.sh} ;;
    *) plugin=${plugin#_} ;;
    esac

    _omb_util_array_contains available_plugins "$plugin" ||
      available_plugins+=("$plugin")
  done
}

function _comp_cmd_omb__get_available_themes {
  available_themes=()

  local -a theme_files
  _omb_util_glob_expand theme_files '{"$OSH","$OSH_CUSTOM"}/themes/*/{_*,*.theme.{bash,sh}}'

  local theme
  for theme in "${theme_files[@]##*/}"; do
    case $theme in
    *.theme.bash) theme=${theme%.theme.bash} ;;
    *.theme.sh) theme=${theme%.theme.sh} ;;
    *) theme=${theme#_} ;;
    esac

    _omb_util_array_contains available_themes "$theme" ||
      available_themes+=("$theme")
  done
}

## @fn _comp_cmd_omb__get_valid_plugins type
function _comp_cmd_omb__get_valid_plugins {
  if [[ $1 == disable ]]; then
    # if command is "disable", only offer already enabled plugins
    valid_plugins=("${plugins[@]}")
  else
    local -a available_plugins
    _comp_cmd_omb__get_available_plugins
    valid_plugins=("${available_plugins[@]}")

    # if command is "enable", remove already enabled plugins
    if [[ ${COMP_WORDS[2]} == enable ]]; then
      _omb_util_array_remove valid_plugins "${plugins[@]}"
    fi
  fi
}

function _comp_cmd_omb {
  local shopt
  _omb_util_get_shopt extglob
  shopt -s extglob

  if ((COMP_CWORD == 1)); then
    local -a cmds=(
      'changelog:Print the changelog'
      'help:Usage information'
      'plugin:Manage plugins'
      'pr:Manage Oh My Bash Pull Requests'
      'reload:Reload the current bash session'
      'theme:Manage themes'
      'update:Update Oh My Bash'
      'version:Show the version'
    )
    _comp_cmd_omb__describe 'command' cmds
  elif ((COMP_CWORD ==2)); then
    case "${COMP_WORDS[1]}" in
    changelog)
      local -a refs
      _omb_util_split_lines refs "$(command git -C "$OSH" for-each-ref --format="%(refname:short):%(subject)" refs/heads refs/tags)"
      _comp_cmd_omb__describe 'command' refs ;;
    plugin)
      local -a subcmds=(
        'disable:Disable plugin(s)'
        'enable:Enable plugin(s)'
        'info:Get plugin information'
        'list:List plugins'
        'load:Load plugin(s)'
      )
      _comp_cmd_omb__describe 'command' subcmds ;;
    pr)
      local -a subcmds=(
        'clean:Delete all Pull Request branches'
        'test:Test a Pull Request'
      )
      _comp_cmd_omb__describe 'command' subcmds ;;
    theme)
      local -a subcmds=(
        'list:List themes'
        'set:Set a theme in your .zshrc file'
        'use:Load a theme'
      )
      _comp_cmd_omb__describe 'command' subcmds ;;
    esac
  elif ((COMP_CWORD == 3)); then
    case "${COMP_WORDS[1]}::${COMP_WORDS[2]}" in
    plugin::@(disable|enable|load))
      local -a valid_plugins
      _comp_cmd_omb__get_valid_plugins "${COMP_WORDS[2]}"
      _comp_cmd_omb__describe 'plugin' valid_plugins ;;
    plugin::info)
      local -a available_plugins
      _comp_cmd_omb__get_available_plugins
      _comp_cmd_omb__describe 'plugin' available_plugins ;;
    theme::@(set|use))
      local -a available_themes
      _comp_cmd_omb__get_available_themes
      _comp_cmd_omb__describe 'theme' available_themes ;;
    esac
  elif ((COMP_CWORD > 3)); then
    case "${COMP_WORDS[1]}::${COMP_WORDS[2]}" in
    plugin::@(enable|disable|load))
      local -a valid_plugins
      _comp_cmd_omb__get_valid_plugins "${COMP_WORDS[2]}"

      # Remove plugins already passed as arguments
      # NOTE: $((COMP_CWORD - 1)) is the last plugin argument completely passed, i.e. that which
      # has a space after them. This is to avoid removing plugins partially passed, which makes
      # the completion not add a space after the completed plugin.
      _omb_util_array_remove valid_plugins "${COMP_WORDS[@]:3:COMP_CWORD-3}"

      _comp_cmd_omb__describe 'plugin' valid_plugins ;;
    esac
  fi

  [[ :$shopt: == *:extglob:* ]] || shopt -u extglob
  return 0
}

complete -F _comp_cmd_omb omb

[[ :$_omb_lib_cli__init_shopt: == *:extglob:* ]] || shopt -u extglob
unset -v _omb_lib_cli__init_shopt

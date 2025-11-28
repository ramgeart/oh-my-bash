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
  
  if ! _omb_util_command_exists git; then
    _omb_util_print "Error: git is required to view the changelog"
    return 1
  fi
  
  if [[ ! -d "$OSH/.git" ]]; then
    _omb_util_print "Error: Oh My Bash directory is not a git repository"
    return 1
  fi
  
  _omb_util_print "Changelog for $ref:"
  _omb_util_print "=================="
  _omb_util_print ""
  
  if command git -C "$OSH" rev-parse --verify "$ref" &>/dev/null; then
    local commits
    mapfile -t commits < <(command git -C "$OSH" log --oneline --no-merges -20 "$ref")
    
    if ((${#commits[@]} > 0)); then
      local commit
      for commit in "${commits[@]}"; do
        _omb_util_print "  $commit"
      done
    else
      _omb_util_print "  No commits found for $ref"
    fi
  else
    _omb_util_print "  Error: Reference '$ref' not found in the repository"
    _omb_util_print "  Available references:"
    command git -C "$OSH" for-each-ref --format="%(refname:short)" refs/heads refs/tags | sed 's/^/    /'
  fi
}
function _omb_cmd_plugin {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
  enable)
    if (($# == 0)); then
      _omb_util_print "Error: Please specify plugin name(s) to enable"
      _omb_util_print "Usage: omb plugin enable <plugin> [plugin...]"
      return 1
    fi

    # Initialize plugins array if it doesn't exist
    if ! _omb_util_function_exists plugins; then
      plugins=()
    fi

    local plugin
    for plugin in "$@"; do
      if _omb_plugin_exists "$plugin"; then
        if _omb_util_array_contains plugins "$plugin"; then
          _omb_util_print "Plugin '$plugin' is already enabled"
        else
          plugins+=("$plugin")
          _omb_plugin_save_config
          _omb_util_print "Plugin '$plugin' enabled. Please run 'omb reload' to apply changes."
        fi
      else
        _omb_util_print "Error: Plugin '$plugin' not found"
        return 1
      fi
    done
    ;;

  disable)
    if (($# == 0)); then
      _omb_util_print "Error: Please specify plugin name(s) to disable"
      _omb_util_print "Usage: omb plugin disable <plugin> [plugin...]"
      return 1
    fi

    # Check if plugins array exists
    if ! _omb_util_function_exists plugins; then
      _omb_util_print "No plugins are currently enabled"
      return 0
    fi

    local plugin
    for plugin in "$@"; do
      if _omb_util_array_contains plugins "$plugin"; then
        _omb_util_array_remove plugins "$plugin"
        _omb_plugin_save_config
        _omb_util_print "Plugin '$plugin' disabled. Please run 'omb reload' to apply changes."
      else
        _omb_util_print "Plugin '$plugin' is not enabled"
      fi
    done
    ;;

  list)
    _omb_util_print "Available plugins:"
    _omb_util_print "=================="
    
    local -a available_plugins
    _comp_cmd_omb__get_available_plugins
    
    local plugin
    for plugin in "${available_plugins[@]}"; do
      if _omb_util_array_contains plugins "$plugin"; then
        _omb_util_print "  ✓ $plugin (enabled)"
      else
        _omb_util_print "    $plugin"
      fi
    done
    ;;

  info)
    local plugin="${1:-}"
    if [[ -z "$plugin" ]]; then
      _omb_util_print "Error: Please specify a plugin name"
      _omb_util_print "Usage: omb plugin info <plugin>"
      return 1
    fi

    local plugin_file
    if _omb_plugin_exists "$plugin"; then
      plugin_file=$(_omb_plugin_find_file "$plugin")
      _omb_util_print "Plugin: $plugin"
      _omb_util_print "File: $plugin_file"
      _omb_util_print ""
      if [[ -f "$plugin_file" ]]; then
        _omb_util_print "Description:"
        grep -E "^#.*@about|^#.*Description" "$plugin_file" | head -5 | sed 's/^# *//' | sed 's/@about/Description:/'
      fi
    else
      _omb_util_print "Error: Plugin '$plugin' not found"
      return 1
    fi
    ;;

  load)
    if (($# == 0)); then
      _omb_util_print "Error: Please specify plugin name(s) to load"
      _omb_util_print "Usage: omb plugin load <plugin> [plugin...]"
      return 1
    fi

    local plugin
    for plugin in "$@"; do
      if _omb_plugin_exists "$plugin"; then
        _omb_module_require_plugin "$plugin"
        _omb_util_print "Plugin '$plugin' loaded."
      else
        _omb_util_print "Error: Plugin '$plugin' not found"
        return 1
      fi
    done
    ;;

  *)
    _omb_util_print "Error: Unknown plugin subcommand '$subcommand'"
    _omb_util_print "Usage: omb plugin <enable|disable|list|info|load> [args...]"
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
    return 0
  else
    return 1
  fi
}

function _omb_plugin_save_config {
  _omb_util_print "# Current plugin configuration:"
  _omb_util_print "plugins=(${plugins[@]@Q})"
  _omb_util_print ""
  _omb_util_print "# To make these changes permanent, add the above line to your ~/.bashrc"
}
function _omb_cmd_pull {
  _omb_util_print "Pulling latest changes for Oh My Bash..."
  
  if ! _omb_util_command_exists git; then
    _omb_util_print "Error: git is required to pull updates"
    return 1
  fi
  
  if [[ ! -d "$OSH/.git" ]]; then
    _omb_util_print "Error: Oh My Bash directory is not a git repository"
    return 1
  fi

  local current_branch
  current_branch=$(command git -C "$OSH" rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  if [[ -z "$current_branch" ]]; then
    _omb_util_print "Error: Unable to determine current branch"
    return 1
  fi

  _omb_util_print "Current branch: $current_branch"
  
  if command git -C "$OSH" pull --rebase origin "$current_branch"; then
    _omb_util_print "Changes pulled successfully!"
    _omb_util_print "Please run 'omb reload' to apply the changes."
  else
    _omb_util_print "Error: Failed to pull changes"
    _omb_util_print "You may have uncommitted changes or conflicts"
    return 1
  fi
}
function _omb_cmd_reload {
  _omb_util_print "Reloading Oh My Bash..."
  
  if [[ -f "$OSH/oh-my-bash.sh" ]]; then
    # Save current working directory and important variables
    local current_dir=$PWD
    local old_OSH="$OSH"
    local old_OSH_CUSTOM="$OSH_CUSTOM"
    local old_OSH_THEME="$OSH_THEME"
    local old_plugins=("${plugins[@]}")
    
    # Source the main file to reload everything
    source "$OSH/oh-my-bash.sh"
    
    # Return to original directory
    cd "$current_dir" || return 1
    
    _omb_util_print "Oh My Bash reloaded successfully!"
    _omb_util_print "Theme: $OSH_THEME"
    _omb_util_print "Plugins: ${plugins[*]}"
  else
    _omb_util_print "Error: Oh My Bash main file not found at $OSH/oh-my-bash.sh"
    return 1
  fi
}
function _omb_cmd_theme {
  local subcommand="${1:-}"
  shift || true

  case "$subcommand" in
  list)
    _omb_util_print "Available themes:"
    _omb_util_print "=================="
    
    local -a available_themes
    _comp_cmd_omb__get_available_themes
    
    local theme
    for theme in "${available_themes[@]}"; do
      if [[ "$theme" == "${OSH_THEME:-}" ]]; then
        _omb_util_print "  ✓ $theme (current)"
      else
        _omb_util_print "    $theme"
      fi
    done
    ;;

  use)
    local theme="${1:-}"
    if [[ -z "$theme" ]]; then
      _omb_util_print "Error: Please specify a theme name"
      _omb_util_print "Usage: omb theme use <theme>"
      return 1
    fi

    if _omb_theme_exists "$theme"; then
      _omb_module_require_theme "$theme"
      _omb_util_print "Theme '$theme' loaded temporarily. This will not persist after reload."
    else
      _omb_util_print "Error: Theme '$theme' not found"
      return 1
    fi
    ;;

  set)
    local theme="${1:-}"
    if [[ -z "$theme" ]]; then
      _omb_util_print "Error: Please specify a theme name"
      _omb_util_print "Usage: omb theme set <theme>"
      return 1
    fi

    if _omb_theme_exists "$theme"; then
      _omb_theme_set_config "$theme"
      _omb_util_print "Theme '$theme' set as default. Please run 'omb reload' to apply changes."
    else
      _omb_util_print "Error: Theme '$theme' not found"
      return 1
    fi
    ;;

  *)
    _omb_util_print "Error: Unknown theme subcommand '$subcommand'"
    _omb_util_print "Usage: omb theme <list|use|set> [args...]"
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
  _omb_util_print "# To make this theme permanent, add this line to your ~/.bashrc:"
  _omb_util_print "export OSH_THEME=\"$theme\""
  _omb_util_print ""
  _omb_util_print "# Then run 'source ~/.bashrc' or start a new session to apply the change"
}
function _omb_cmd_update {
  if ! _omb_util_command_exists git; then
    _omb_util_print "Error: git is required to update Oh My Bash"
    return 1
  fi
  
  if [[ ! -d "$OSH/.git" ]]; then
    _omb_util_print "Error: Oh My Bash directory is not a git repository"
    return 1
  fi

  local current_branch
  current_branch=$(command git -C "$OSH" rev-parse --abbrev-ref HEAD 2>/dev/null)
  
  if [[ -z "$current_branch" ]]; then
    _omb_util_print "Error: Unable to determine current branch"
    return 1
  fi

  _omb_util_print "Updating Oh My Bash..."
  _omb_util_print "Current branch: $current_branch"
  _omb_util_print "Fetching latest changes..."
  
  if command git -C "$OSH" fetch origin; then
    _omb_util_print "Checking for updates..."
    
    local local_commit remote_commit
    local_commit=$(command git -C "$OSH" rev-parse HEAD)
    remote_commit=$(command git -C "$OSH" rev-parse "@{u}")
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
      _omb_util_print "Oh My Bash is already up to date!"
    else
      _omb_util_print "Updates available. Pulling changes..."
      
      if command git -C "$OSH" pull --rebase; then
        _omb_util_print "Oh My Bash updated successfully!"
        _omb_util_print "Please run 'omb reload' to apply the changes."
      else
        _omb_util_print "Error: Failed to pull updates"
        _omb_util_print "You may have uncommitted changes or conflicts"
        return 1
      fi
    fi
  else
    _omb_util_print "Error: Failed to fetch updates"
    return 1
  fi
}
function _omb_cmd_version {
  _omb_util_print "Oh My Bash version: $OMB_VERSION"
  _omb_util_print "Bash version: $BASH_VERSION"
  
  if [[ -d "$OSH/.git" ]] && _omb_util_command_exists git; then
    local current_branch current_commit
    current_branch=$(command git -C "$OSH" rev-parse --abbrev-ref HEAD 2>/dev/null)
    current_commit=$(command git -C "$OSH" rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$current_branch" && -n "$current_commit" ]]; then
      _omb_util_print "Git branch: $current_branch"
      _omb_util_print "Git commit: $current_commit"
    fi
  fi
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

# Función principal omb - hacerla disponible globalmente
function omb {
  if (($# == 0)); then
    _omb_cmd_help
    return 2
  fi

  # Verificar si el subcomando existe
  if ! _omb_util_function_exists "_omb_cmd_$1"; then
    echo "Error: Unknown command '$1'" >&2
    echo "Run 'omb help' for usage information" >&2
    return 2
  fi

  # Ejecutar el subcomando
  "_omb_cmd_$@"
}

#!/usr/bin/env bash

_omb_module_require lib:utils

function _omb_cmd_help {
  cat << EOF
Usage: omb <command> [options]

Available commands:
  changelog [ref]       Show the Oh My Bash changelog
  help                  Show this help message
  plugin <subcmd>       Manage plugins
    disable <plugins>     Disable one or more plugins
    enable <plugins>      Enable one or more plugins
    info <plugin>         Get information about a plugin
    list                  List all available plugins
    load <plugins>        Load one or more plugins
  pull                  Pull latest changes from repository
  reload                Reload the current bash session
  theme <subcmd>        Manage themes
    list                  List all available themes
    set <theme>           Set theme in .bashrc
    use <theme>           Use theme in current session
  update                Update Oh My Bash to latest version
  version               Show Oh My Bash version

For more information, visit: https://github.com/ohmybash/oh-my-bash
EOF
}
function _omb_cmd_changelog {
  local target=${1:-HEAD}

  if [[ ! -d "$OSH/.git" ]]; then
    _omb_log_error "Oh My Bash directory is not a git repository"
    return 1
  fi
  
  _omb_log_arrow "Oh My Bash Changelog"
  command git --git-dir="$OSH/.git" --work-tree="$OSH" log --oneline --decorate --color "$target" | head -20
}
function _omb_cmd_plugin {
  local subcmd=${1:-}
  
  case "$subcmd" in
  list)
    _omb_log_arrow "Available plugins:"
    local -a available_plugins
    _comp_cmd_omb__get_available_plugins
    printf '%s\n' "${available_plugins[@]}" | sort
    ;;
  info)
    if [[ -z ${2:-} ]]; then
      _omb_log_error "Please specify a plugin name"
      echo "Usage: omb plugin info <plugin>"
      return 1
    fi
    local plugin=$2
    local readme
    
    # Search for README in plugin directory
    for readme in "$OSH_CUSTOM/plugins/$plugin/README.md" "$OSH/plugins/$plugin/README.md" \
                  "$OSH_CUSTOM/plugins/$plugin/README" "$OSH/plugins/$plugin/README"; do
      if [[ -f $readme ]]; then
        _omb_log_arrow "Plugin: $plugin"
        cat "$readme"
        return 0
      fi
    done
    
    _omb_log_warning "No README found for plugin '$plugin'"
    ;;
  load)
    shift
    if [[ $# -eq 0 ]]; then
      _omb_log_error "Please specify one or more plugins"
      echo "Usage: omb plugin load <plugin1> [plugin2 ...]"
      return 1
    fi
    
    local plugin failed=0
    for plugin in "$@"; do
      if _omb_module_require "plugin:$plugin" 2>/dev/null; then
        _omb_log_success "Plugin '$plugin' loaded"
      else
        _omb_log_error "Failed to load plugin '$plugin'"
        failed=1
      fi
    done
    return $failed
    ;;
  enable)
    shift
    if [[ $# -eq 0 ]]; then
      _omb_log_error "Please specify one or more plugins"
      echo "Usage: omb plugin enable <plugin1> [plugin2 ...]"
      return 1
    fi
    
    local bashrc="$HOME/.bashrc"
    if [[ ! -f $bashrc ]]; then
      _omb_log_error "$bashrc not found"
      return 1
    fi
    
    local plugin
    for plugin in "$@"; do
      # Check if plugin exists
      local -a available_plugins
      _comp_cmd_omb__get_available_plugins
      if ! _omb_util_array_contains available_plugins "$plugin"; then
        _omb_log_error "Plugin '$plugin' not found"
        continue
      fi
      
      # Check if already enabled (using word boundaries to match exact plugin name)
      if grep -qE "^plugins=\(.*[[:space:]]$plugin([[:space:]]|\))" "$bashrc" || \
         grep -qE "^plugins=\($plugin([[:space:]]|\))" "$bashrc"; then
        _omb_log_warning "Plugin '$plugin' is already enabled"
        continue
      fi
      
      # Add plugin to plugins array in .bashrc
      if grep -q "^plugins=(" "$bashrc"; then
        sed -i.bak "s/^plugins=(\(.*\))/plugins=(\1 $plugin)/" "$bashrc"
        _omb_log_success "Plugin '$plugin' enabled in $bashrc"
      else
        _omb_log_error "Could not find plugins setting in $bashrc"
        return 1
      fi
    done
    _omb_log_note "Reload your session with 'omb reload' or 'source ~/.bashrc'"
    ;;
  disable)
    shift
    if [[ $# -eq 0 ]]; then
      _omb_log_error "Please specify one or more plugins"
      echo "Usage: omb plugin disable <plugin1> [plugin2 ...]"
      return 1
    fi
    
    local bashrc="$HOME/.bashrc"
    if [[ ! -f $bashrc ]]; then
      _omb_log_error "$bashrc not found"
      return 1
    fi
    
    local plugin
    for plugin in "$@"; do
      # Check if plugin is enabled (using word boundaries to match exact plugin name)
      if grep -qE "^plugins=\(.*[[:space:]]$plugin([[:space:]]|\))" "$bashrc" || \
         grep -qE "^plugins=\($plugin([[:space:]]|\))" "$bashrc"; then
        # Remove plugin from plugins array using awk for better readability
        cp "$bashrc" "$bashrc.bak"
        awk -v plugin="$plugin" '
          /^plugins=\(/ {
            # Extract content between parentheses
            match($0, /^plugins=\((.*)\)/, arr)
            content = arr[1]
            # Split by spaces and rebuild without the target plugin
            n = split(content, plugins, " ")
            new_content = ""
            for (i = 1; i <= n; i++) {
              if (plugins[i] != plugin && plugins[i] != "") {
                if (new_content != "") new_content = new_content " "
                new_content = new_content plugins[i]
              }
            }
            print "plugins=(" new_content ")"
            next
          }
          { print }
        ' "$bashrc.bak" > "$bashrc"
        _omb_log_success "Plugin '$plugin' disabled in $bashrc"
      else
        _omb_log_warning "Plugin '$plugin' is not enabled"
      fi
    done
    _omb_log_note "Reload your session with 'omb reload' or 'source ~/.bashrc'"
    ;;
  *)
    _omb_log_error "Unknown plugin subcommand: $subcmd"
    echo "Usage: omb plugin <list|info|load|enable|disable> [options]"
    return 1
    ;;
  esac
}
function _omb_cmd_pull {
  if [[ ! -d "$OSH/.git" ]]; then
    _omb_log_error "Oh My Bash directory is not a git repository"
    return 1
  fi
  
  _omb_log_arrow "Pulling latest changes from Oh My Bash repository..."
  if command git --git-dir="$OSH/.git" --work-tree="$OSH" pull --rebase --stat origin master; then
    _omb_log_success "Successfully pulled latest changes"
  else
    _omb_log_error "Failed to pull changes"
    return 1
  fi
}
function _omb_cmd_reload {
  _omb_log_arrow "Reloading Oh My Bash..."
  if [[ -f ~/.bashrc ]]; then
    # shellcheck disable=SC1090
    source ~/.bashrc
    _omb_log_success "Bash session reloaded!"
  else
    _omb_log_error "Cannot find ~/.bashrc"
    return 1
  fi
}
function _omb_cmd_theme {
  local subcmd=${1:-}
  
  case "$subcmd" in
  list)
    _omb_log_arrow "Available themes:"
    local -a available_themes
    _comp_cmd_omb__get_available_themes
    printf '%s\n' "${available_themes[@]}" | sort
    ;;
  use)
    if [[ -z ${2:-} ]]; then
      _omb_log_error "Please specify a theme name"
      echo "Usage: omb theme use <theme>"
      return 1
    fi
    local theme=$2
    if _omb_module_require "theme:$theme" 2>/dev/null; then
      _omb_log_success "Theme '$theme' loaded successfully"
    else
      _omb_log_error "Failed to load theme '$theme'"
      return 1
    fi
    ;;
  set)
    if [[ -z ${2:-} ]]; then
      _omb_log_error "Please specify a theme name"
      echo "Usage: omb theme set <theme>"
      return 1
    fi
    local theme=$2
    local bashrc="$HOME/.bashrc"
    
    if [[ ! -f $bashrc ]]; then
      _omb_log_error "$bashrc not found"
      return 1
    fi
    
    # Check if theme exists
    local -a available_themes
    _comp_cmd_omb__get_available_themes
    if ! _omb_util_array_contains available_themes "$theme"; then
      _omb_log_error "Theme '$theme' not found"
      return 1
    fi
    
    # Update OSH_THEME in .bashrc
    if grep -q "^OSH_THEME=" "$bashrc"; then
      sed -i.bak "s/^OSH_THEME=.*/OSH_THEME=\"$theme\"/" "$bashrc"
      _omb_log_success "Theme set to '$theme' in $bashrc"
      _omb_log_note "Reload your session with 'omb reload' or 'source ~/.bashrc'"
    else
      _omb_log_error "Could not find OSH_THEME setting in $bashrc"
      return 1
    fi
    ;;
  *)
    _omb_log_error "Unknown theme subcommand: $subcmd"
    echo "Usage: omb theme <list|use|set> [theme]"
    return 1
    ;;
  esac
}
function _omb_cmd_update {
  if [[ ! -d "$OSH/.git" ]]; then
    _omb_log_error "Oh My Bash directory is not a git repository"
    return 1
  fi
  
  # Use the existing upgrade.sh script
  if [[ -f "$OSH/tools/upgrade.sh" ]]; then
    source "$OSH/tools/upgrade.sh"
  else
    _omb_log_error "Upgrade script not found"
    return 1
  fi
}
function _omb_cmd_version {
  echo "Oh My Bash version: ${OMB_VERSION}"
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

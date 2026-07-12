# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

# =============================================================================
# PATH hygiene
# =============================================================================
# Deduplicate path/fpath entries (prevents repeated exports from piling up).
typeset -U path PATH fpath FPATH

# Start configuration added by Zim Framework install {{{
#
# User configuration sourced by interactive shells
#

# -----------------
# Zsh configuration
# -----------------

#
# History
#

# Remove older command from the history if a duplicate is to be added.
setopt HIST_IGNORE_ALL_DUPS

#
# Input/output
#

# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e

# Prompt for spelling correction of commands.
#setopt CORRECT

# Customize spelling correction prompt.
#SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '

# Remove path separator from WORDCHARS.
WORDCHARS=${WORDCHARS//[\/]}

# --------------------
# Module configuration
# --------------------

#
# git (zim module)
#

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
#zstyle ':zim:git' aliases-prefix 'g'

#
# input (zim module)
#

# Append `../` to your input for each `.` you type after an initial `..`
#zstyle ':zim:input' double-dot-expand yes

#
# termtitle (zim module)
#

# Set a custom terminal title format using prompt expansion escape sequences.
# See http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html#Simple-Prompt-Escapes
# If none is provided, the default '%n@%m: %~' is used.
#zstyle ':zim:termtitle' format '%1~'

#
# zsh-autosuggestions
#

# Disable automatic widget re-binding on each precmd. This can be set when
# zsh-users/zsh-autosuggestions is the last module in your ~/.zimrc.
ZSH_AUTOSUGGEST_MANUAL_REBIND=1

# Customize the style that the suggestions are shown with.
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
#ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'

#
# zsh-syntax-highlighting
#

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# Customize the main highlighter styles.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters/main.md#how-to-tweak-it
#typeset -A ZSH_HIGHLIGHT_STYLES
#ZSH_HIGHLIGHT_STYLES[comment]='fg=242'

# ------------------
# Initialize modules
# ------------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]]; then
  source ${ZIM_HOME}/zimfw.zsh init
fi

# Completions must be in fpath BEFORE Zim's completion module runs compinit.
# - Docker CLI completions
# - Grok CLI completions
fpath=($HOME/.docker/completions $HOME/.grok/completions/zsh $fpath)

# Initialize modules.
source ${ZIM_HOME}/init.zsh
# }}} End configuration added by Zim Framework install

# =============================================================================
# Prompt — Starship
# =============================================================================
# Prompt is handled by Starship (not Zim asciiship). See ~/.zimrc.
eval "$(starship init zsh)"

# =============================================================================
# PATH additions (tools & language runtimes)
# =============================================================================

# --- SkillHub / user-local CLI tools (~/.local/bin) ---
path=($HOME/.local/bin $path)

# --- Personal scripts (~/bin: aria2 wrapper a2, etc.) ---
# Only prepend if the directory exists.
[[ -d $HOME/bin ]] && path=($HOME/bin $path)

# --- zoxide (smarter cd) ---
eval "$(zoxide init zsh)"

# --- Homebrew Ruby + gem executables ---
# Hardcoded gem bindir avoids spawning `ruby -e` on every shell start.
# Update the gem path after a major Ruby upgrade (`brew info ruby` / `gem env`).
path=(
  /opt/homebrew/lib/ruby/gems/4.0.0/bin
  /opt/homebrew/opt/ruby/bin
  $path
)

# --- bun (JS runtime) ---
export BUN_INSTALL="$HOME/.bun"
path=($BUN_INSTALL/bin $path)
# Bun shell completions (uses compdef; safe after Zim's compinit).
[[ -s $HOME/.bun/_bun ]] && source "$HOME/.bun/_bun"

# --- ImageMagick (Homebrew formula: imagemagick, not imagemagick-full) ---
[[ -d /opt/homebrew/opt/imagemagick/bin ]] && path=(/opt/homebrew/opt/imagemagick/bin $path)

# --- MiniMax Code (mavis) ---
path=($HOME/.mavis/bin $path)

# --- LM Studio CLI (lms) ---
path=($path $HOME/.lmstudio/bin)

# --- Grok CLI ---
# Completions fpath is set before Zim init above. Do NOT call compinit here —
# Zim's completion module already runs it once.
path=($HOME/.grok/bin $path)

# =============================================================================
# NVM (Node Version Manager) — lazy load
# =============================================================================
# Eager `source nvm.sh` is a common zsh startup bottleneck.
# - Resolve default alias onto PATH so node/npm/npx work immediately.
# - Alias may be full (24.15.0) or partial (24); pick newest matching install.
# - Prepend so nvm's node wins over other copies (e.g. ~/.local/bin/node).
# - Only load full nvm when `nvm` is first invoked (e.g. nvm use / nvm install).
# - Skip nvm's bash_completion; Zim zsh-completions already ships _nvm.
export NVM_DIR="$HOME/.nvm"
if [[ -s $NVM_DIR/alias/default ]]; then
  _nvm_ver=${$(<"$NVM_DIR/alias/default")#v}
  if [[ -d $NVM_DIR/versions/node/v${_nvm_ver}/bin ]]; then
    path=($NVM_DIR/versions/node/v${_nvm_ver}/bin $path)
  else
    # Partial alias: "24" -> newest v24.* directory (version-sorted).
    _nvm_match=$(print -rl -- $NVM_DIR/versions/node/v${_nvm_ver}*(N/) | sort -V | tail -1)
    [[ -n $_nvm_match && -d $_nvm_match/bin ]] && path=($_nvm_match/bin $path)
    unset _nvm_match
  fi
  unset _nvm_ver
fi
nvm() {
  unset -f nvm
  [[ -s $NVM_DIR/nvm.sh ]] && . "$NVM_DIR/nvm.sh"
  nvm "$@"
}

# =============================================================================
# Clash Verge proxy helpers (port 7890)
# =============================================================================
# Usage: pon / poff / pst  (aliases below)
# - Terminal env vars for curl/wget/etc.
# - Git global http(s).proxy for git push / lazygit

_PROXY_HTTP="http://127.0.0.1:7890"
_PROXY_SOCKS5="socks5://127.0.0.1:7890"
# Keep no_proxy conservative: many tools ignore shell-style wildcards (e.g. 192.168.*).
_NO_PROXY="localhost,127.0.0.1,::1,.local,.internal"

# Enable terminal + Git proxy.
function proxy_all_on() {
  export http_proxy="$_PROXY_HTTP"
  export https_proxy="$_PROXY_HTTP"
  export all_proxy="$_PROXY_SOCKS5"
  export HTTP_PROXY="$_PROXY_HTTP"
  export HTTPS_PROXY="$_PROXY_HTTP"
  export ALL_PROXY="$_PROXY_SOCKS5"
  export no_proxy="$_NO_PROXY"
  export NO_PROXY="$_NO_PROXY"

  git config --global http.proxy "$_PROXY_HTTP"
  git config --global https.proxy "$_PROXY_HTTP"

  echo "✅ 已开启所有代理："
  echo "   - 终端代理（curl/wget 等）: $_PROXY_HTTP"
  echo "   - Git 代理（git push/lazygit）: $_PROXY_HTTP"
}

# Disable terminal + Git proxy (safe if Git proxy was never set).
function proxy_all_off() {
  unset http_proxy https_proxy all_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  unset no_proxy NO_PROXY

  git config --global --unset http.proxy 2>/dev/null || true
  git config --global --unset https.proxy 2>/dev/null || true

  echo "❌ 已关闭所有代理（终端代理 + Git 代理）"
}

# Show terminal env + Git proxy status.
function proxy_all_status() {
  echo "========== 终端代理环境变量 =========="
  echo "http_proxy  = $http_proxy"
  echo "https_proxy = $https_proxy"
  echo "all_proxy   = $all_proxy"
  echo "no_proxy    = $no_proxy"

  echo ""
  echo "========== Git 代理配置（全局） =========="
  local http_proxy_git https_proxy_git
  http_proxy_git=$(git config --global --get http.proxy 2>/dev/null)
  https_proxy_git=$(git config --global --get https.proxy 2>/dev/null)
  if [[ -z $http_proxy_git && -z $https_proxy_git ]]; then
    echo "未设置任何 Git 代理"
  else
    [[ -n $http_proxy_git ]] && echo "http.proxy  = $http_proxy_git"
    [[ -n $https_proxy_git ]] && echo "https.proxy = $https_proxy_git"
  fi
}

# =============================================================================
# User aliases
# =============================================================================
alias bt='btop'
alias oc='opencode'
alias ff='~/.config/fastfetch/pokemon.sh'
alias lg='lazygit'
alias rsx='reasonix'
alias pon='proxy_all_on'
alias poff='proxy_all_off'
alias pst='proxy_all_status'

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"

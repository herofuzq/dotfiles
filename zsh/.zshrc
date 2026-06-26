
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

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
# git
#

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
#zstyle ':zim:git' aliases-prefix 'g'

#
# input
#

# Append `../` to your input for each `.` you type after an initial `..`
#zstyle ':zim:input' double-dot-expand yes

#
# termtitle
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
# Docker CLI completions must be in fpath before Zim initializes completions.
fpath=(/Users/fuzhuoqun/.docker/completions $fpath)
# Initialize modules.
source ${ZIM_HOME}/init.zsh
# }}} End configuration added by Zim Framework install

# test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
eval "$(starship init zsh)"

# Added by SkillHub CLI installer
export PATH="/Users/fuzhuoqun/.local/bin:$PATH"

# 用户自定义脚本(aria2 wrapper a2 等)
export PATH="$HOME/bin:$PATH"
# 增加zoxide
eval "$(zoxide init zsh)"

#ruby
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export PATH="$(ruby -e 'puts Gem.bindir'):$PATH"

# bun completions
[ -s "/Users/fuzhuoqun/.bun/_bun" ] && source "/Users/fuzhuoqun/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# =====================================================
# Clash Verge 代理配置（端口: 7890）
# =====================================================

# 代理服务器地址
_PROXY_HTTP="http://127.0.0.1:7890"
_PROXY_SOCKS5="socks5://127.0.0.1:7890"

# 本地网络及域名不走代理
_NO_PROXY="localhost,127.0.0.1,::1,192.168.*,10.*,172.16.*,*.local,*.internal"

# -----------------------------------------------------
# 一键开启所有代理（终端环境变量 + Git 代理）
function proxy_all_on() {
    # 开启终端代理（环境变量）
    export http_proxy="$_PROXY_HTTP"
    export https_proxy="$_PROXY_HTTP"
    export all_proxy="$_PROXY_SOCKS5"
    
    export HTTP_PROXY="$_PROXY_HTTP"
    export HTTPS_PROXY="$_PROXY_HTTP"
    export ALL_PROXY="$_PROXY_SOCKS5"
    
    export no_proxy="$_NO_PROXY"
    export NO_PROXY="$_NO_PROXY"
    
    # 开启 Git 代理（写入 ~/.gitconfig）
    git config --global http.proxy "$_PROXY_HTTP"
    git config --global https.proxy "$_PROXY_HTTP"
    
    echo "✅ 已开启所有代理："
    echo "   - 终端代理（curl/wget 等）: $_PROXY_HTTP"
    echo "   - Git 代理（git push/lazygit）: $_PROXY_HTTP"
}

# -----------------------------------------------------
# 一键关闭所有代理（终端环境变量 + Git 代理）
function proxy_all_off() {
    # 关闭终端代理（环境变量）
    unset http_proxy https_proxy all_proxy
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
    unset no_proxy NO_PROXY
    
    # 关闭 Git 代理（从 ~/.gitconfig 中移除）
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    
    echo "❌ 已关闭所有代理（终端代理 + Git 代理）"
}

# -----------------------------------------------------
# 查看当前所有代理状态
function proxy_all_status() {
    echo "========== 终端代理环境变量 =========="
    echo "http_proxy  = $http_proxy"
    echo "https_proxy = $https_proxy"
    echo "all_proxy   = $all_proxy"
    echo "no_proxy    = $no_proxy"
    
    echo ""
    echo "========== Git 代理配置（全局） =========="
    http_proxy_git=$(git config --global --get http.proxy)
    https_proxy_git=$(git config --global --get https.proxy)
    if [[ -z "$http_proxy_git" && -z "$https_proxy_git" ]]; then
        echo "未设置任何 Git 代理"
    else
        [[ -n "$http_proxy_git" ]] && echo "http.proxy  = $http_proxy_git"
        [[ -n "$https_proxy_git" ]] && echo "https.proxy = $https_proxy_git"
    fi
}

# User aliases
alias bt='btop'
alias oc='opencode'
alias ff='~/.config/fastfetch/pokemon.sh'
alias lg='lazygit'
alias rsx='reasonix'
# 为代理命令设置简短别名
alias pon='proxy_all_on'
alias poff='proxy_all_off'
alias pst='proxy_all_status'

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="/opt/homebrew/opt/imagemagick-full/bin:$PATH"



# Added by MiniMax Code
export PATH="/Users/fuzhuoqun/.mavis/bin:$PATH"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"


# Kiro CLI pre block. Keep at the top of this file.
[[ -z "${ZELLIJ:-}" && -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh"






export EDITOR=nvim

# Hermes Agent — ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -z "${ZELLIJ:-}" && -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh"

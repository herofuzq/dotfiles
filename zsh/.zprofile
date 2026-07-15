
# Kiro CLI pre block. Keep at the top of this file.
[[ -z "${ZELLIJ:-}" && -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh"






export EDITOR=nvim

# Hermes Agent — ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"

# zide: IDE-like zellij layout
export PATH="$HOME/.config/zide/bin:$PATH"
# Use the fully configured global Yazi setup inside Zide.
export ZIDE_USE_YAZI_CONFIG=false


# Kiro CLI post block. Keep at the bottom of this file.
[[ -z "${ZELLIJ:-}" && -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh"

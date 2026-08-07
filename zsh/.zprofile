export EDITOR=nvim

# User-local CLI tools (Hermes, Grok, OfficeCLI, etc.)
export PATH="$HOME/.local/bin:$PATH"

# >>> Hermes Studio CLI shim >>>
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) export PATH="$HOME/bin:$PATH" ;;
esac
# <<< Hermes Studio CLI shim <<<

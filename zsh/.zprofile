# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/fuzhuoqun/.docker/bin"
# End of Docker Desktop section.

export EDITOR=nvim

# User-local CLI tools (Hermes, Grok, OfficeCLI, etc.)
export PATH="$HOME/.local/bin:$PATH"

# >>> Hermes Studio CLI shim >>>
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) export PATH="$HOME/bin:$PATH" ;;
esac
# <<< Hermes Studio CLI shim <<<

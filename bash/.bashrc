








. "$HOME/.cargo/env"



# Added by MiniMax Code
export PATH="$HOME/.mavis/bin:$PATH"



# Added by LM Studio CLI (lms)
export PATH="$PATH:$HOME/.lmstudio/bin"
# End of LM Studio CLI section



# >>> otty shell integration >>>
# Added by Otty — toggle in Settings > Shell > Shell Integration.
# Inert unless launched by Otty (it sets $OTTY_SHELL_INTEGRATION).
if [ -n "$OTTY_SHELL_INTEGRATION" ] && [ -r "$OTTY_SHELL_INTEGRATION/otty-integration.bash" ]; then
  . "$OTTY_SHELL_INTEGRATION/otty-integration.bash"
fi
# <<< otty shell integration <<<

# Added by the BaseRT installer
export PATH="/Users/fuzhuoqun/.basert:$PATH"


# export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles


. "$HOME/.cargo/env"



# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/fuzhuoqun/.lmstudio/bin"
# End of LM Studio CLI section


# >>> otty bash-profile shim >>>
# Otty: login bash reads the profile, not ~/.bashrc — pull it in so
# the shell-integration block in ~/.bashrc is reached (e.g. in tmux).
if [ -f "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi
# <<< otty bash-profile shim >>>

# Added by the BaseRT installer
export PATH="/Users/fuzhuoqun/.basert:$PATH"

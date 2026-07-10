return {
    item = { name = "git_status" },
    repos = {
        { path = os.getenv("HOME") .. "/dotfiles",                   label = "dotfiles" },
        { path = os.getenv("HOME") .. "/Database/market-data-stack", label = "market" },
        { path = os.getenv("HOME") .. "/Trade",                      label = "trade" },
    },
}

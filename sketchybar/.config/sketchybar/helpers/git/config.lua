return {
    item = { name = "git_status" },
    repos = {
        { path = os.getenv("HOME") .. "/dotfiles",                   label = "dotfiles" },
        { path = os.getenv("HOME") .. "/Database/market-data-stack", label = "market" },
        { path = os.getenv("HOME") .. "/Documents/Obsidian/Marine 的笔记", label = "obsidian" },
        { path = os.getenv("HOME") .. "/Skill/Work",                 label = "skills" },
    },
}

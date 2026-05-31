#!/bin/bash
# Pokefetch — 宝可梦精灵图 + fastfetch 系统信息
# 现在由 pokemon.py 驱动，支持编号 + 闪光 + 随机形态
exec python3 "${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/pokemon.py" "$@"

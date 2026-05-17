#!/bin/bash
# 每 5 秒由 sketchybar routine 调用
# nowplaying-cli 对 QQ音乐不返回 app/state，用 title 是否存在判断
# 只更新 bar item 的显示/隐藏和图标颜色，popup 内容在点击时由 Lua 回调更新

TITLE=$(nowplaying-cli get title 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
STATE=$(nowplaying-cli get state 2>/dev/null | tr -d '[:space:]')

if [ -z "$TITLE" ] || [ "$TITLE" = "null" ]; then
  sketchybar --set "$NAME" drawing=off popup.drawing=off
  exit 0
fi

sketchybar --set "$NAME" drawing=on icon.color=0xfff38ba8

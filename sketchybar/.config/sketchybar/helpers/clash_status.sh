#!/bin/bash
# 查询 Clash Verge TUN + 系统代理状态
# 输出: all / tun / sys / off / nod
#   all - TUN + 系统代理都开
#   tun - 仅 TUN 开
#   sys - 仅系统代理开
#   off - 都关
#   nod - Clash Verge 未运行

SOCKET="${CLASH_SOCKET:-/tmp/verge/verge-mihomo.sock}"

# Clash Verge 未运行
[ -S "$SOCKET" ] || { echo "nod"; exit 0; }

TUN_STATE="off"
if command -v jq &>/dev/null; then
	TUN_STATE=$(curl -s --max-time 2 --unix-socket "$SOCKET" \
		http://localhost/configs 2>/dev/null \
		| jq -r '.tun.enable // false | if . then "on" else "off" end' 2>/dev/null)
fi

# 系统代理状态: HTTP 或 HTTPS 任一开启即视为系统代理开启
# (scutil --proxy 是本地查询，不会卡住，无需 timeout)
SYS_STATE="off"
if scutil --proxy 2>/dev/null | grep -qE 'HTTPEnable : 1|HTTPSEnable : 1'; then
	SYS_STATE="on"
fi

if [ "$TUN_STATE" = "on" ] && [ "$SYS_STATE" = "on" ]; then
	echo "all"
elif [ "$TUN_STATE" = "on" ]; then
	echo "tun"
elif [ "$SYS_STATE" = "on" ]; then
	echo "sys"
else
	echo "off"
fi

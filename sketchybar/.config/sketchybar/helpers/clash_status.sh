#!/bin/bash
# 查询 Clash Verge TUN + 系统代理状态
# 输出: all / tun / sys / off / nod
#   all - TUN + 系统代理都开
#   tun - 仅 TUN 开
#   sys - 仅系统代理开
#   off - 都关
#   nod - Clash Verge 未运行
#
# 依赖：curl；TUN 解析优先 jq（推荐 brew install jq），无 jq 时用粗 grep。

SOCKET="${CLASH_SOCKET:-/tmp/verge/verge-mihomo.sock}"

[ -S "$SOCKET" ] || { echo "nod"; exit 0; }

TUN_STATE="off"
CONFIGS=$(curl -s --max-time 2 --unix-socket "$SOCKET" http://localhost/configs 2>/dev/null) || CONFIGS=""

if [ -n "$CONFIGS" ]; then
	if command -v jq &>/dev/null; then
		TUN_STATE=$(printf '%s' "$CONFIGS" | jq -r '.tun.enable // false | if . then "on" else "off" end' 2>/dev/null) || TUN_STATE="off"
	else
		# 无 jq：压缩空白后匹配 "tun":{..."enable":true（非严格，推荐安装 jq）
		COMPACT=$(printf '%s' "$CONFIGS" | tr -d ' \n\t\r')
		case "$COMPACT" in
			*'"tun":{'*'"enable":true'*) TUN_STATE="on" ;;
		esac
	fi
fi

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

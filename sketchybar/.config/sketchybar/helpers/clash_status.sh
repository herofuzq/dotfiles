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

# 查找可用的 Python 解释器
PYTHON=""
if command -v python3 &>/dev/null; then
	PYTHON="python3"
elif command -v python &>/dev/null; then
	PYTHON="python"
fi

if [ -n "$PYTHON" ]; then
	TUN_STATE=$(curl -s --max-time 2 --unix-socket "$SOCKET" \
		http://localhost/configs 2>/dev/null \
		| $PYTHON -c "
import sys, json
try:
    print('on' if json.load(sys.stdin)['tun']['enable'] else 'off')
except Exception:
    print('off')
" 2>/dev/null)
else
	TUN_STATE="off"
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

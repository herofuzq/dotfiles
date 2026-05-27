#!/bin/bash
# 查询 Clash Verge TUN 代理状态，输出 "on" 或 "off"
# 依赖：/tmp/verge/verge-mihomo.sock（Clash Verge Unix socket）

# 查找可用的 Python 解释器
PYTHON=""
if command -v python3 &>/dev/null; then
	PYTHON="python3"
elif command -v python &>/dev/null; then
	PYTHON="python"
fi

if [ -n "$PYTHON" ]; then
	STATUS=$(curl -s --max-time 2 --unix-socket /tmp/verge/verge-mihomo.sock \
		http://localhost/configs 2>/dev/null \
		| $PYTHON -c "import sys,json; print('on' if json.load(sys.stdin)['tun']['enable'] else 'off')" 2>/dev/null)
	echo "${STATUS:-off}"
else
	echo "off"
fi
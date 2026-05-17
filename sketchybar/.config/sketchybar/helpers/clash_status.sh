#!/bin/bash
# 查询 Clash Verge TUN 代理状态，输出 "on" 或 "off"
# 依赖：/tmp/verge/verge-mihomo.sock（Clash Verge Unix socket）

STATUS=$(curl -s --max-time 2 --unix-socket /tmp/verge/verge-mihomo.sock \
    http://localhost/configs 2>/dev/null \
    | python3 -c "import sys,json; print('on' if json.load(sys.stdin)['tun']['enable'] else 'off')" 2>/dev/null)

echo "${STATUS:-off}"

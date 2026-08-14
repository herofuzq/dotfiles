#!/bin/bash
# helper_apply.sh <build_dir> <target> <label> <marker> <log>
#
# 在调用方已持有的 per-spec lockf 所有权锁内执行（锁覆盖 make + 发布 +
# kickstart + marker 写入）。这里是唯一的 build + apply 权威路径：
#   1. 重新判断 freshness（make 幂等，拿到锁后仍由 make 决定是否重编）
#   2. make（必要时）
#   3. 确认 target 存在且可执行
#   —— label 为空（无 daemon 的 helper，如 cpu_load/menus/bar_height/dock_width）——
#   4. 到此为止，只构建不 apply
#   —— label 非空（有 launchd daemon 的 helper）——
#   4. 捕获 target 的 SHA-256
#   5. 对比 marker 里记录的 label + digest
#   6. 一致则 no-op 结束；mismatch 则同步 kickstart
#   7. kickstart 后再次确认 digest 未变化
#   8. 同目录临时文件写入后原子 rename marker
#   任何失败保持 marker 不变并返回非零；下次 reload 的 reconcile 自动重试
#   （at-least-once 语义）。

set -u

build_dir="$1"
target="$2"
label="$3"
marker="$4"
log="$5"

: > "$log" 2>/dev/null || true

if ! make -C "$build_dir" >> "$log" 2>&1; then
  echo "BUILD_FAIL" >> "$log"
  exit 2
fi

if [ ! -x "$target" ]; then
  echo "NO_TARGET: $target" >> "$log"
  exit 3
fi

if [ -z "$label" ]; then
  echo "BUILT" >> "$log"
  exit 0
fi

digest="$(/usr/bin/shasum -a 256 "$target" | awk '{ print $1 }')"
if [ -z "$digest" ]; then
  echo "DIGEST_FAIL" >> "$log"
  exit 4
fi

applied_label="$(sed -n '1p' "$marker" 2>/dev/null)"
applied_digest="$(sed -n '2p' "$marker" 2>/dev/null)"

if [ "$applied_label" = "$label" ] && [ "$applied_digest" = "$digest" ]; then
  echo "UP_TO_DATE $digest" >> "$log"
  exit 0
fi

echo "APPLYING $digest (was ${applied_digest:-none})" >> "$log"
if ! launchctl kickstart -k gui/"$(id -u)"/"$label" >> "$log" 2>&1; then
  echo "KICKSTART_FAIL $label" >> "$log"
  exit 5
fi

digest2="$(/usr/bin/shasum -a 256 "$target" | awk '{ print $1 }')"
if [ "$digest2" != "$digest" ]; then
  echo "DIGEST_CHANGED_DURING_KICKSTART" >> "$log"
  exit 6
fi

tmpmarker="${marker}.tmp.$$"
if ! printf '%s\n%s\n' "$label" "$digest" > "$tmpmarker"; then
  echo "MARKER_WRITE_FAIL" >> "$log"
  exit 7
fi
if ! mv -f "$tmpmarker" "$marker"; then
  echo "MARKER_RENAME_FAIL" >> "$log"
  exit 8
fi

echo "APPLIED $digest" >> "$log"
exit 0

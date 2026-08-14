#!/bin/bash
# helper_compile.sh <spec-id> <target> <source-count> <source...> -- <compiler...> @OUTPUT@
#
# Direct/manual make acquires the same per-spec lock as helper_build.lua.
# helper_apply.sh already owns that lock and exports the exact spec id, so the
# nested make may compile without trying to acquire it again.

set -u

usage() {
  echo "usage: helper_compile.sh <spec-id> <target> <source-count> <source...> -- <compiler...> @OUTPUT@" >&2
  exit 64
}

[ "$#" -ge 6 ] || usage

spec_id="$1"
target="$2"
source_count="$3"
shift 3

case "$spec_id" in
  ""|*[!A-Za-z0-9_.-]*) usage ;;
esac
[ -n "$target" ] || usage
target_name="${target##*/}"
if [ "$target_name" != "$spec_id" ]; then
  echo "helper_compile: target basename must match spec id: $spec_id -> $target" >&2
  exit 65
fi
case "$source_count" in
  ""|*[!0-9]*) usage ;;
esac
[ "$source_count" -gt 0 ] 2>/dev/null || usage
[ "$#" -ge $((source_count + 2)) ] || usage

sources=()
source_index=0
while [ "$source_index" -lt "$source_count" ]; do
  sources+=("$1")
  shift
  source_index=$((source_index + 1))
done

[ "${1-}" = "--" ] || usage
shift
[ "$#" -gt 0 ] || usage

output_count=0
for argument in "$@"; do
  if [ "$argument" = "@OUTPUT@" ]; then
    output_count=$((output_count + 1))
  fi
done
[ "$output_count" -eq 1 ] || usage

if [ "${TMPDIR+x}" = "x" ]; then
  tmp_root="$TMPDIR"
else
  tmp_root="/tmp"
fi
while [ "${tmp_root%/}" != "$tmp_root" ]; do
  tmp_root="${tmp_root%/}"
done
lock_path="${tmp_root}/sketchybar_build_lock.${spec_id}"

if [ "${SKETCHYBAR_BUILD_LOCK_HELD-}" != "$spec_id" ]; then
  SKETCHYBAR_BUILD_LOCK_HELD="$spec_id" \
    exec /usr/bin/lockf -k "$lock_path" "$0" "$spec_id" "$target" "$source_count" "${sources[@]}" -- "$@"
fi

target_dir="$(dirname "$target")"
[ -d "$target_dir" ] || {
  echo "helper_compile: target directory is missing: $target_dir" >&2
  exit 65
}

source_digest() {
  local listing
  listing="$(/usr/bin/shasum -a 256 "${sources[@]}")" || return 1
  printf '%s' "$listing" | /usr/bin/shasum -a 256 | awk '{ print $1 }'
}

staging=""
backup=""
had_target=0
publish_in_progress=0

restore_previous_target() {
  if [ "$publish_in_progress" -ne 1 ]; then return 0; fi
  if [ "$had_target" -eq 1 ]; then
    if [ -z "$backup" ] || ! /bin/mv -f -- "$backup" "$target"; then
      echo "helper_compile: failed to restore previous target: $spec_id" >&2
      return 1
    fi
    backup=""
  else
    rm -f -- "$target" || return 1
  fi
  publish_in_progress=0
  return 0
}

cleanup() {
  restore_previous_target || true
  if [ -n "$staging" ]; then
    rm -f -- "$staging" 2>/dev/null || true
  fi
  if [ -n "$backup" ]; then
    rm -f -- "$backup" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

reenter_make() {
  local retry_count="${SKETCHYBAR_BUILD_RETRY_COUNT:-0}"
  case "$retry_count" in
    ""|*[!0-9]*) retry_count=0 ;;
  esac
  if [ "$retry_count" -ge 2 ]; then
    echo "helper_compile: sources kept changing after 3 attempts: $spec_id" >&2
    exit 70
  fi
  case "${MAKELEVEL-}" in
    ""|*[!0-9]*)
      echo "helper_compile: cannot re-enter make outside a make recipe: $spec_id" >&2
      exit 70
      ;;
  esac
  if [ "$MAKELEVEL" -le 0 ]; then
    echo "helper_compile: cannot re-enter make outside a make recipe: $spec_id" >&2
    exit 70
  fi
  SKETCHYBAR_BUILD_RETRY_COUNT=$((retry_count + 1)) \
    exec /usr/bin/make -B "$target"
}

before="$(source_digest)" || {
  echo "helper_compile: source digest failed before compile: $spec_id" >&2
  exit 66
}
[ -n "$before" ] || {
  echo "helper_compile: empty source digest before compile: $spec_id" >&2
  exit 66
}

staging="$(mktemp "$target_dir/.${target_name}.new.XXXXXX")" || {
  echo "helper_compile: cannot create target-adjacent staging file: $target" >&2
  exit 67
}

compiler=()
for argument in "$@"; do
  if [ "$argument" = "@OUTPUT@" ]; then
    compiler+=("$staging")
  else
    compiler+=("$argument")
  fi
done

if ! "${compiler[@]}"; then
  echo "helper_compile: compiler failed: $spec_id" >&2
  exit 68
fi
[ -f "$staging" ] && [ -x "$staging" ] || {
  echo "helper_compile: compiler output is missing or not executable: $spec_id" >&2
  exit 68
}

after="$(source_digest)" || {
  echo "helper_compile: source digest failed after compile: $spec_id" >&2
  exit 66
}
[ -n "$after" ] || {
  echo "helper_compile: empty source digest after compile: $spec_id" >&2
  exit 66
}

if [ "$before" != "$after" ]; then
  rm -f -- "$staging" || exit 69
  staging=""
  reenter_make
fi

if [ -e "$target" ]; then
  [ -f "$target" ] || {
    echo "helper_compile: target is not a regular file: $target" >&2
    exit 69
  }
  backup="$(mktemp "$target_dir/.${target_name}.previous.XXXXXX")" || {
    echo "helper_compile: cannot create target backup path: $target" >&2
    exit 69
  }
  rm -f -- "$backup" || exit 69
  /bin/ln "$target" "$backup" || {
    echo "helper_compile: cannot retain previous target: $spec_id" >&2
    exit 69
  }
  had_target=1
fi

publish_in_progress=1
if [ -d "$target" ] || ! mv -f -- "$staging" "$target"; then
  echo "helper_compile: atomic publish failed: $spec_id" >&2
  exit 69
fi
staging=""

published="$(source_digest)" || {
  restore_previous_target || exit 69
  reenter_make
}
[ -n "$published" ] || {
  restore_previous_target || exit 69
  reenter_make
}
if [ "$published" != "$after" ]; then
  restore_previous_target || exit 69
  reenter_make
fi

publish_in_progress=0
if [ -n "$backup" ]; then
  rm -f -- "$backup" || exit 69
  backup=""
fi
exit 0

#!/usr/bin/env bash
# common/atomic-write.sh — HARNESS-MSC-001 L? atomic-write helper (P0-3)
#
# Role: tmp-file → rename 패턴으로 타세션 경합에서 쓰기를 원자화한다.
#
# Usage:
#   atomic-write.sh <target-path> < <content-stream>
#   atomic-write.sh --if-not-exists <target-path> < <content>
#
# Env:
#   HARNESS_ATOMIC_WRITE_IF_NOT_EXISTS=1 → target 존재 시 abort (skip overwrite)
#
# Exit codes:
#   0: 쓰기 성공
#   1: 인자 오류
#   2: --if-not-exists 또는 env 활성화 + target 이미 존재
#   3: 쓰기 실패 (권한, 디스크, tmp→rename 실패)
#
# Reference: docs/PHASE-P7-multi-session-hardening.md §3.3

set -u

IF_NOT_EXISTS=0
if [ "${1:-}" = "--if-not-exists" ]; then
  IF_NOT_EXISTS=1
  shift
fi
[ "${HARNESS_ATOMIC_WRITE_IF_NOT_EXISTS:-0}" = "1" ] && IF_NOT_EXISTS=1

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "usage: $0 [--if-not-exists] <target-path> < <content>" >&2
  exit 1
fi

# if-not-exists 가드
if [ $IF_NOT_EXISTS -eq 1 ] && [ -e "$TARGET" ]; then
  echo "atomic-write: target exists — abort ($TARGET)" >&2
  exit 2
fi

# 디렉토리 준비
mkdir -p "$(dirname "$TARGET")" 2>/dev/null

# tmp 에 쓰고 rename
TMP="${TARGET}.tmp.$$"
if cat > "$TMP" 2>/dev/null; then
  # atomic rename (POSIX mv 는 같은 파일시스템 내에서는 원자적)
  if mv "$TMP" "$TARGET" 2>/dev/null; then
    exit 0
  else
    echo "atomic-write: rename failed ($TMP → $TARGET)" >&2
    rm -f "$TMP"
    exit 3
  fi
else
  echo "atomic-write: tmp write failed ($TMP)" >&2
  rm -f "$TMP"
  exit 3
fi

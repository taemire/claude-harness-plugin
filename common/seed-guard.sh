#!/usr/bin/env bash
# common/seed-guard.sh — HARNESS-MSC-001 L? seed/restore 가드 (P0-4)
#
# Role: archive / templates 에서 활성 경로로 seed 또는 restore 하기 전에
#       타세션 활동 + 기존 파일 존재 여부를 확인하고, 활성 타세션이 있으면
#       abort 한다. HARNESS_FORCE_RESTORE=1 로 우회 가능.
#
# Usage:
#   seed-guard.sh <source-path> <target-path>
#
# Env:
#   HARNESS_FORCE_RESTORE=1  → 타세션 활성이어도 강제 진행
#   HARNESS_SESSION_STALE_SECONDS (default 600) — stale 판정 threshold
#
# Exit codes:
#   0: seed 완료 (또는 target 이미 존재하고 skip)
#   1: 인자 오류
#   2: 타세션 활성 감지 → abort (FORCE_RESTORE 미설정)
#   3: 복사 실패
#
# Reference: docs/PHASE-P7-multi-session-hardening.md §3.4

set -u

SOURCE="${1:-}"
TARGET="${2:-}"

if [ -z "$SOURCE" ] || [ -z "$TARGET" ]; then
  echo "usage: $0 <source-path> <target-path>" >&2
  exit 1
fi

if [ ! -f "$SOURCE" ]; then
  echo "seed-guard: source not found ($SOURCE)" >&2
  exit 1
fi

# 플러그인 root 탐지 (본 스크립트 기준 상대)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_CMD="${SCRIPT_DIR}/session-registry.sh"

# target 이미 존재하는 경우: 타세션 활성 여부 확인
if [ -e "$TARGET" ]; then
  if [ "${HARNESS_FORCE_RESTORE:-0}" = "1" ]; then
    echo "seed-guard: HARNESS_FORCE_RESTORE=1 — proceeding (target will be overwritten)"
  else
    # 타세션 활성 검사
    if [ -x "$REGISTRY_CMD" ]; then
      others="$("$REGISTRY_CMD" others 2>/dev/null || echo "[]")"
      # jq 있으면 count, 없으면 session_id 문자열 수 헤아림
      local_count=0
      if command -v jq >/dev/null 2>&1; then
        local_count=$(echo "$others" | jq 'length' 2>/dev/null || echo 0)
      else
        local_count=$(echo "$others" | grep -c '"session_id"' || echo 0)
      fi
      if [ "${local_count:-0}" -gt 0 ]; then
        cat >&2 <<EOF
seed-guard: target already exists AND other active session(s) detected
  source:  $SOURCE
  target:  $TARGET
  active others: $local_count
  policy: docs/PHASE-P7-multi-session-hardening.md §3.4
  override: HARNESS_FORCE_RESTORE=1 $0 "$SOURCE" "$TARGET"
EOF
        exit 2
      fi
    fi
    # 타세션 없고 FORCE 도 아니면 — 기본은 skip (non-destructive default)
    echo "seed-guard: target exists — skip (HARNESS_FORCE_RESTORE=1 to overwrite)"
    exit 0
  fi
fi

# 디렉토리 준비 + 복사
mkdir -p "$(dirname "$TARGET")" 2>/dev/null
if cp "$SOURCE" "$TARGET" 2>/dev/null; then
  echo "seed-guard: seeded $SOURCE → $TARGET"
  exit 0
else
  echo "seed-guard: copy failed ($SOURCE → $TARGET)" >&2
  exit 3
fi

#!/usr/bin/env bash
# common/extract_bl_id.sh — v3.6 Task-ID resolver (generic, prefix-aware)
#
# Usage:
#   extract_bl_id.sh <request_string>
#
# Task-ID prefix 결정 우선순위:
#   1) HARNESS_BL_PREFIX env (SessionStart hook 이 .harness/config.yaml 에서 export)
#   2) 기본값 "BL"
#
# 해결 우선순위:
#   1) request_string 의 첫 번째 `<PREFIX>-<digits>` (대문자 규약)
#   2) `git log --oneline -n 10` 의 첫 번째 `<PREFIX>-<digits>`
#   3) `gh issue list` 의 첫 번째 `<PREFIX>-<digits>` (GH_DISABLED=1 이면 skip)
#   4) fallback: `<PREFIX>-UNKNOWN-YYYYMMDD-HHMM`
#
# 항상 exit 0. stdout 단일 결과 원칙 (stderr 에 디버그 안 냄).
#
# Examples:
#   HARNESS_BL_PREFIX=BL     → BL-123, BL-UNKNOWN-20260420-2205
#   HARNESS_BL_PREFIX=TICKET → TICKET-456, TICKET-UNKNOWN-20260420-2205
#   HARNESS_BL_PREFIX=TASK   → TASK-7, TASK-UNKNOWN-20260420-2205

set -uo pipefail

PREFIX="${HARNESS_BL_PREFIX:-BL}"
# sanitize — A-Z0-9_ 만 허용 (regex 안전성)
PREFIX=$(echo "$PREFIX" | tr -cd 'A-Za-z0-9_' | tr '[:lower:]' '[:upper:]')
[ -z "$PREFIX" ] && PREFIX="BL"

_first_id() {
  # stdin 에서 첫 번째 <PREFIX>-<digits> 토큰만 출력. 없으면 빈 문자열.
  grep -oE "${PREFIX}-[0-9]+" 2>/dev/null | head -n1 || true
}

main() {
  local request="${1:-}"
  local out=""

  # 1) request string
  if [ -n "$request" ]; then
    out=$(printf '%s' "$request" | _first_id)
    if [ -n "$out" ]; then
      printf '%s\n' "$out"
      exit 0
    fi
  fi

  # 2) git log
  if command -v git >/dev/null 2>&1; then
    out=$(git log --oneline -n 10 2>/dev/null | _first_id)
    if [ -n "$out" ]; then
      printf '%s\n' "$out"
      exit 0
    fi
  fi

  # 3) gh issue list (선택적)
  if [ "${GH_DISABLED:-0}" != "1" ] && command -v gh >/dev/null 2>&1; then
    out=$(gh issue list --limit 20 --state open 2>/dev/null | _first_id)
    if [ -n "$out" ]; then
      printf '%s\n' "$out"
      exit 0
    fi
  fi

  # 4) fallback — auto-generated task id (OMC mission 스타일)
  # segment "TASK" 는 "자동 할당된 일감" 을 뜻함. 사용자가 BL/이슈 번호 없이
  # 자연어로 요청해도 하네스가 즉시 진행할 수 있도록 <PREFIX>-TASK-YYYYMMDD-HHMM
  # 형태로 고유 네임스페이스 부여.
  printf '%s-TASK-%s\n' "$PREFIX" "$(date +%Y%m%d-%H%M)"
  exit 0
}

main "$@"

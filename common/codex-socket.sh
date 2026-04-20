#!/usr/bin/env bash
# common/codex-socket.sh — HARNESS-MSC-001 P1-8 codex app-server per-session socket
#
# Role: codex app-server 의 단일 broker socket (`/tmp/codex-broker.sock`) 에서
#       복수 세션이 동시 호출 시 경합 가능. 세션별 socket path 를 반환한다.
#
# Usage:
#   SOCK=$(bash common/codex-socket.sh)
#   codex --app-server-socket "$SOCK" ...
#
# Env:
#   HARNESS_CODEX_PER_SESSION_SOCKET=1  → 활성화 (기본 비활성)
#   CLAUDE_SESSION_ID                    → per-session path 구성에 사용
#   TMPDIR                               → socket 디렉토리 (기본 /tmp)
#
# Output: socket path 를 stdout 에 한 줄.
#   - env 비활성 시: 기존 기본 경로 (codex 기본 socket 위치) 를 그대로 출력
#   - env 활성 시: $TMPDIR/codex-<session-id>.sock
#
# Reference: docs/PHASE-P7-multi-session-hardening.md §3.6

set -u

if [ "${HARNESS_CODEX_PER_SESSION_SOCKET:-0}" != "1" ]; then
  # 기본 경로 유지 — codex 의 기본 socket 사용
  echo ""
  exit 0
fi

TMPDIR_VAL="${TMPDIR:-/tmp}"
# trailing slash 제거
TMPDIR_VAL="${TMPDIR_VAL%/}"

SESSION_ID="${CLAUDE_SESSION_ID:-default}"
# sanitize — 파일명으로 안전한 문자만
SAFE_ID=$(echo "$SESSION_ID" | tr -cd 'A-Za-z0-9._-')
[ -z "$SAFE_ID" ] && SAFE_ID="default"

echo "${TMPDIR_VAL}/codex-${SAFE_ID}.sock"
exit 0

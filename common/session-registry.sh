#!/usr/bin/env bash
# common/session-registry.sh — HARNESS-MSC-001 L4 active-sessions.json helper
#
# Role: .harness/active-sessions.json 읽기/쓰기
# Subcommands:
#   register [bl-id] [phase]  — 현재 PID + profile 등록 (기존 엔트리 replace)
#   heartbeat                 — last_heartbeat 갱신
#   list                      — 활성 세션 나열 (stale 제외)
#   others                    — 자기 제외 활성 세션 나열
#   unregister                — 자기 엔트리 제거 (Stop hook)
#   prune                     — stale (> HARNESS_SESSION_STALE_SECONDS) 제거
#
# Design: fail-open (exit 0 항상). jq 우선, 없으면 line-oriented fallback.
# Plugin path: ${CLAUDE_PLUGIN_ROOT}/common/session-registry.sh
# Registry:   ${CLAUDE_PROJECT_DIR}/.harness/active-sessions.json (gitignored)
#
# Reference: docs/PHASE-P7-multi-session-hardening.md §3.2

set -u

REGISTRY="${CLAUDE_PROJECT_DIR:-$(pwd)}/.harness/active-sessions.json"
STALE_SECONDS="${HARNESS_SESSION_STALE_SECONDS:-600}"

# ─────────────────────────────────────────────────────────
detect_profile() {
  local home_hint="${HOME}"
  case "$home_hint" in
    */claude-nonstop/profiles/default*) echo "default" ;;
    */claude-nonstop/profiles/second*)  echo "second" ;;
    */claude-nonstop/profiles/third*)   echo "third" ;;
    */claude-nonstop/profiles/fourth*)  echo "fourth" ;;
    *) echo "${CLAUDE_PROFILE_NAME:-unknown}" ;;
  esac
}

detect_session_id() {
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    echo "$CLAUDE_SESSION_ID"
  elif [ -n "${TERM_SESSION_ID:-}" ]; then
    echo "term-${TERM_SESSION_ID:0:8}"
  else
    echo "pid-$$"
  fi
}

iso_now() {
  date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/'
}

has_jq() { command -v jq >/dev/null 2>&1; }

ensure_registry() {
  if [ ! -f "$REGISTRY" ]; then
    mkdir -p "$(dirname "$REGISTRY")"
    echo '{"sessions":[]}' > "$REGISTRY"
  fi
}

# ─────────────────────────────────────────────────────────
cmd_register() {
  ensure_registry
  local bl="${1:-}"
  local phase="${2:-}"
  local sid; sid=$(detect_session_id)
  local profile; profile=$(detect_profile)
  local pid=$$
  local now; now=$(iso_now)

  if has_jq; then
    local tmp="${REGISTRY}.tmp.$$"
    jq --arg sid "$sid" \
       --arg profile "$profile" \
       --argjson pid "$pid" \
       --arg bl "$bl" \
       --arg phase "$phase" \
       --arg now "$now" \
       '.sessions = ([.sessions[]? | select(.session_id != $sid)] + [{
          session_id: $sid,
          profile: $profile,
          pid: $pid,
          started_at: $now,
          bl_id: $bl,
          phase: $phase,
          last_heartbeat: $now
       }])' "$REGISTRY" > "$tmp" 2>/dev/null && mv "$tmp" "$REGISTRY" || {
      rm -f "$tmp"
    }
  else
    local line
    line=$(printf '{"session_id":"%s","profile":"%s","pid":%d,"started_at":"%s","bl_id":"%s","phase":"%s","last_heartbeat":"%s"}' \
      "$sid" "$profile" "$pid" "$now" "$bl" "$phase" "$now")
    if grep -q '"sessions":\[\]' "$REGISTRY" 2>/dev/null; then
      sed -i.bak "s|\"sessions\":\[\]|\"sessions\":[${line}]|" "$REGISTRY"
    else
      sed -i.bak "s|\]}\$|,${line}]}|" "$REGISTRY"
    fi
    rm -f "${REGISTRY}.bak"
  fi
  echo "$sid"
}

cmd_heartbeat() {
  ensure_registry
  local sid; sid=$(detect_session_id)
  local now; now=$(iso_now)
  if has_jq; then
    local tmp="${REGISTRY}.tmp.$$"
    jq --arg sid "$sid" --arg now "$now" \
       '.sessions |= map(if .session_id == $sid then .last_heartbeat = $now else . end)' \
       "$REGISTRY" > "$tmp" 2>/dev/null && mv "$tmp" "$REGISTRY" || rm -f "$tmp"
  fi
}

cmd_list() {
  ensure_registry
  if has_jq; then
    local cutoff=$(( $(date +%s) - STALE_SECONDS ))
    jq --argjson cutoff "$cutoff" '
      .sessions
      | map(select((.last_heartbeat | sub(":([0-9]{2})$"; "\\1") | strptime("%Y-%m-%dT%H:%M:%S%z") | mktime) >= $cutoff))
    ' "$REGISTRY" 2>/dev/null || cat "$REGISTRY"
  else
    cat "$REGISTRY"
  fi
}

cmd_others() {
  ensure_registry
  local self; self=$(detect_session_id)
  if has_jq; then
    local cutoff=$(( $(date +%s) - STALE_SECONDS ))
    jq --arg self "$self" --argjson cutoff "$cutoff" '
      .sessions
      | map(select(.session_id != $self))
      | map(select((.last_heartbeat | sub(":([0-9]{2})$"; "\\1") | strptime("%Y-%m-%dT%H:%M:%S%z") | mktime) >= $cutoff))
    ' "$REGISTRY" 2>/dev/null || echo "[]"
  else
    cat "$REGISTRY"
  fi
}

cmd_unregister() {
  ensure_registry
  local sid; sid=$(detect_session_id)
  if has_jq; then
    local tmp="${REGISTRY}.tmp.$$"
    jq --arg sid "$sid" '.sessions |= map(select(.session_id != $sid))' \
       "$REGISTRY" > "$tmp" 2>/dev/null && mv "$tmp" "$REGISTRY" || rm -f "$tmp"
  fi
}

cmd_prune() {
  ensure_registry
  if has_jq; then
    local cutoff=$(( $(date +%s) - STALE_SECONDS ))
    local tmp="${REGISTRY}.tmp.$$"
    jq --argjson cutoff "$cutoff" '
      .sessions |= map(select((.last_heartbeat | sub(":([0-9]{2})$"; "\\1") | strptime("%Y-%m-%dT%H:%M:%S%z") | mktime) >= $cutoff))
    ' "$REGISTRY" > "$tmp" 2>/dev/null && mv "$tmp" "$REGISTRY" || rm -f "$tmp"
  fi
}

# ─────────────────────────────────────────────────────────
case "${1:-list}" in
  register)   shift; cmd_register "$@" ;;
  heartbeat)  cmd_heartbeat ;;
  list)       cmd_list ;;
  others)     cmd_others ;;
  unregister) cmd_unregister ;;
  prune)      cmd_prune ;;
  *) echo "usage: $0 {register|heartbeat|list|others|unregister|prune} [bl-id phase]" >&2; exit 0 ;;
esac

exit 0

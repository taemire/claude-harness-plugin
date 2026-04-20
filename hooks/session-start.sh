#!/usr/bin/env bash
# claude-harness-plugin — SessionStart hook
# 역할:
#   1) L2 link-farm — ${CLAUDE_PROJECT_DIR}/.harness/overrides/agents/*.md
#                     → ${CLAUDE_PROJECT_DIR}/.claude/agents/*.md (symlink)
#   2) L3 semver 호환성 검사 — override-manifest.compatible_base_version
#                              vs plugin.json.version
#
# 디자인: fail-open. override 파일 없어도 세션 정상 시작. exit 0 항상.
# 참조: docs/PHASE-P3-session-start-hook.md, docs/PLAN-v1.0.md §3.2 / §3.3

set -u
# -e 는 사용하지 않음 (fail-open 보장)

# ─────────────────────────────────────────────────────────
# [1] 환경 검사
# ─────────────────────────────────────────────────────────
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  # 프로젝트 루트 정보 없음 — silent 종료
  exit 0
fi

OVERRIDES_DIR="${CLAUDE_PROJECT_DIR}/.harness/overrides"
AGENTS_TARGET="${CLAUDE_PROJECT_DIR}/.claude/agents"
MANIFEST="${OVERRIDES_DIR}/override-manifest.json"

# OVERRIDES_DIR 자체가 없으면 아무것도 할 일 없음
if [ ! -d "$OVERRIDES_DIR" ]; then
  exit 0
fi

# ─────────────────────────────────────────────────────────
# 유틸: JSON 필드 읽기 (jq 우선, 없으면 grep fallback)
# ─────────────────────────────────────────────────────────
read_json_field() {
  local file="$1"
  local field="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r ".${field} // empty" "$file" 2>/dev/null
  else
    # grep fallback — 단순 "field": "value" 패턴만
    grep -oE "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
      | head -1 \
      | sed -E "s/.*:[[:space:]]*\"([^\"]*)\"/\1/"
  fi
}

# ─────────────────────────────────────────────────────────
# [2] L3 semver 호환성 검사
# ─────────────────────────────────────────────────────────
check_semver_compat() {
  [ -f "$MANIFEST" ] || return 0  # manifest 없으면 skip

  local required
  required="$(read_json_field "$MANIFEST" "compatible_base_version")"
  [ -z "$required" ] && return 0  # 필드 없으면 skip

  # plugin.json 위치 — CLAUDE_PLUGIN_ROOT 또는 스크립트 기준
  local plugin_json=""
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
    plugin_json="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
  else
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "${script_dir}/../.claude-plugin/plugin.json" ]; then
      plugin_json="${script_dir}/../.claude-plugin/plugin.json"
    fi
  fi

  [ -z "$plugin_json" ] && return 0  # 찾을 수 없으면 skip

  local current
  current="$(read_json_field "$plugin_json" "version")"
  [ -z "$current" ] && return 0

  # semver 파싱 — MAJOR.MINOR.PATCH
  local cur_major cur_minor
  cur_major="$(echo "$current" | awk -F. '{print $1}')"
  cur_minor="$(echo "$current" | awk -F. '{print $2}')"

  # required 앞 연산자 파싱
  local op required_clean
  case "$required" in
    \~*) op="tilde"; required_clean="${required#\~}" ;;
    \^*) op="caret"; required_clean="${required#\^}" ;;
    =*)  op="equal"; required_clean="${required#=}"  ;;
    [0-9]*) op="equal"; required_clean="$required"   ;;
    *) op="unsupported"; required_clean="$required"  ;;
  esac

  local req_major req_minor
  req_major="$(echo "$required_clean" | awk -F. '{print $1}')"
  req_minor="$(echo "$required_clean" | awk -F. '{print $2}')"

  local compatible="yes"
  case "$op" in
    tilde) # ~x.y → major=x && minor=y
      [ "$cur_major" = "$req_major" ] && [ "$cur_minor" = "$req_minor" ] || compatible="no"
      ;;
    caret) # ^x.y → major=x && minor>=y
      if [ "$cur_major" = "$req_major" ] && [ "$cur_minor" -ge "$req_minor" ] 2>/dev/null; then
        compatible="yes"
      else
        compatible="no"
      fi
      ;;
    equal) # 정확 일치
      [ "$current" = "$required_clean" ] || compatible="no"
      ;;
    *) # unsupported range — 정보성 경고
      echo "[harness plugin v${current}] ℹ️  compatible_base_version=\"${required}\" 는 bash 간이 파서가 해석 불가한 형식입니다 (지원: ~ ^ =). 검사 skip."
      return 0
      ;;
  esac

  if [ "$compatible" = "no" ]; then
    cat <<EOF
[harness plugin v${current}] ⚠️ override compat warning
  override-manifest.json: compatible_base_version = "${required}"
  plugin.json:            version = "${current}"
  → 버전 범위 불일치. 마이그레이션 가이드: docs/MIGRATION-v${req_major}.${req_minor}-to-v${cur_major}.${cur_minor}.md (있는 경우)
  (경고만 — 파이프라인은 계속 진행됩니다)
EOF
  fi
}

# ─────────────────────────────────────────────────────────
# [3] L2 link-farm
# ─────────────────────────────────────────────────────────
do_link_farm() {
  local src_dir="${OVERRIDES_DIR}/agents"
  [ -d "$src_dir" ] || return 0  # agents/ 없으면 skip

  # target 디렉토리 생성
  mkdir -p "$AGENTS_TARGET"

  local linked=0
  local skipped=0
  local failed=0
  local linked_names=""

  # bash 3.2 호환 — for 루프 + nullglob 없이 처리
  for src in "$src_dir"/*.md; do
    # *.md 매칭 없을 때 literal "*.md" 처리
    [ -f "$src" ] || continue

    local base
    base="$(basename "$src")"
    local dst="${AGENTS_TARGET}/${base}"

    # 이미 존재하는데 symlink 가 아니면 skip (non-destructive)
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "[harness plugin] ⚠️ ${base}: 기존 non-symlink 파일 존재 — skip (수동 정리 후 재시도)"
      skipped=$((skipped + 1))
      continue
    fi

    # ln -sf 시도
    if ln -sf "$src" "$dst" 2>/dev/null; then
      linked=$((linked + 1))
      linked_names="${linked_names}${base} "
    else
      # Windows / symlink 권한 부족 → cp fallback
      if cp -f "$src" "$dst" 2>/dev/null; then
        linked=$((linked + 1))
        linked_names="${linked_names}${base}(copy) "
      else
        failed=$((failed + 1))
      fi
    fi
  done

  if [ $linked -gt 0 ] || [ $failed -gt 0 ] || [ $skipped -gt 0 ]; then
    # plugin version 재조회 (메시지용)
    local msg_ver="?"
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
      msg_ver="$(read_json_field "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" version)"
    fi
    echo "[harness plugin v${msg_ver}] ✅ link-farm configured"
    echo "  source:  ${src_dir}/"
    echo "  target:  ${AGENTS_TARGET}/"
    echo "  linked:  ${linked} file(s) ${linked_names}"
    [ $skipped -gt 0 ] && echo "  skipped: ${skipped} (non-symlink 충돌)"
    [ $failed -gt 0 ]  && echo "  failed:  ${failed}"
  fi
}

# ─────────────────────────────────────────────────────────
# 메인 흐름
# ─────────────────────────────────────────────────────────
check_semver_compat
do_link_farm

exit 0

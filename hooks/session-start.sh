#!/usr/bin/env bash
# claude-harness-plugin — SessionStart hook
# 역할:
#   0) L0 config loader — ${CLAUDE_PROJECT_DIR}/.harness/config.yaml
#                         → HARNESS_* env via CLAUDE_ENV_FILE
#   1) L2 link-farm — ${CLAUDE_PROJECT_DIR}/.harness/overrides/agents/*.md
#                     → ${CLAUDE_PROJECT_DIR}/.claude/agents/*.md (symlink)
#   2) L3 semver 호환성 검사 — override-manifest.compatible_base_version
#                              vs plugin.json.version
#
# 디자인: fail-open. config/override 파일 없어도 세션 정상 시작. exit 0 항상.
# 참조: docs/PHASE-P1-v2-config-yaml.md, docs/PHASE-P3-session-start-hook.md,
#       docs/PLAN-v1.0.md §3.1 / §3.2 / §3.3

set -u
# -e 는 사용하지 않음 (fail-open 보장)

# ─────────────────────────────────────────────────────────
# [1] 환경 검사
# ─────────────────────────────────────────────────────────
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
  # 프로젝트 루트 정보 없음 — silent 종료
  exit 0
fi

HARNESS_CONFIG="${CLAUDE_PROJECT_DIR}/.harness/config.yaml"
OVERRIDES_DIR="${CLAUDE_PROJECT_DIR}/.harness/overrides"
AGENTS_TARGET="${CLAUDE_PROJECT_DIR}/.claude/agents"
MANIFEST="${OVERRIDES_DIR}/override-manifest.json"

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
# [0] L0 config loader — .harness/config.yaml 을 HARNESS_* env 로 export
# ─────────────────────────────────────────────────────────
#
# 3단 cascade:
#   L0. .harness/config.yaml              (최우선, project-local SSOT)
#   L1. (pluginConfigs — Claude Code 가 자체 처리, hook 불개입)
#   L2. plugin.json.userConfig.<key>.default (CLAUDE_ENV_FILE 미기록 — Claude Code 가 알아서 resolve)
#
# Hook 은 L0 만 처리. L1/L2 는 Claude Code 런타임의 ${user_config.*} 가 담당.
# SKILL.md 는 ${HARNESS_*:-default} 패턴으로 env 우선 + literal fallback.
export_env() {
  local name="$1"
  local value="$2"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export ${name}=\"${value}\"" >> "$CLAUDE_ENV_FILE"
  fi
}

load_harness_config() {
  [ -f "$HARNESS_CONFIG" ] || return 0  # yaml 없으면 skip (fail-open)

  # 순수 bash YAML 파서 — 우리 스키마는 flat "harness:" 블록의 2-space indent 만 지원
  # 지원 형식:
  #   harness:
  #     key: value
  #     key: "quoted value"
  # 미지원: 중첩, 배열, 멀티라인 (v0.5.0 스코프)
  local exported=0
  local exported_keys=""
  local in_harness_block=0

  while IFS= read -r line || [ -n "$line" ]; do
    # 주석/빈 줄 skip
    case "$line" in
      \#*|"") continue ;;
    esac

    # "harness:" 섹션 진입
    if [[ "$line" =~ ^harness[[:space:]]*: ]]; then
      in_harness_block=1
      continue
    fi

    # 다른 최상위 섹션 진입 시 harness 블록 종료 (custom:, schema_version: 등)
    if [[ "$line" =~ ^[a-zA-Z_] ]]; then
      in_harness_block=0
      continue
    fi

    # harness 블록 내부 — 2-space indent 의 "  key: value"
    if [ $in_harness_block -eq 1 ]; then
      if [[ "$line" =~ ^[[:space:]]+([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local raw_val="${BASH_REMATCH[2]}"
        # trim trailing whitespace + 인용부호 제거
        raw_val="${raw_val%"${raw_val##*[![:space:]]}"}"
        raw_val="${raw_val#\"}"; raw_val="${raw_val%\"}"
        raw_val="${raw_val#\'}"; raw_val="${raw_val%\'}"
        [ -z "$raw_val" ] && continue

        # 키 sanitize (이미 정규식에서 영숫자+_ 로 제한)
        local key_upper
        key_upper=$(echo "$key" | tr '[:lower:]' '[:upper:]')

        # harness_mode_default 는 HARNESS_MODE_DEFAULT 로 단축 (HARNESS_HARNESS_* 중복 방지)
        local final_name="HARNESS_${key_upper}"
        [ "$key_upper" = "HARNESS_MODE_DEFAULT" ] && final_name="HARNESS_MODE_DEFAULT"

        export_env "$final_name" "$raw_val"
        exported=$((exported + 1))
        exported_keys="${exported_keys}${final_name} "
      fi
    fi
  done < "$HARNESS_CONFIG"

  if [ $exported -gt 0 ]; then
    local msg_ver="?"
    if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
      msg_ver="$(read_json_field "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" version)"
    fi
    echo "[harness plugin v${msg_ver}] ⚙️  config loaded from .harness/config.yaml"
    echo "  exported: ${exported_keys}"
  fi
}

# ─────────────────────────────────────────────────────────
# [2] L3 semver 호환성 검사
# ─────────────────────────────────────────────────────────
check_semver_compat() {
  [ -d "$OVERRIDES_DIR" ] || return 0  # overrides 디렉토리 없으면 skip
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
  [ -d "$OVERRIDES_DIR" ] || return 0  # overrides 디렉토리 없으면 skip
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
# [4] L0' — per-session config override (v0.6 / P1-7)
# ─────────────────────────────────────────────────────────
#
# .harness/session-<session-id>.yaml 이 존재하면 공유 config.yaml 위에 덮어쓴다.
# (per-session 임시 모드/BL-ID lock 등)
load_session_override() {
  local sid="${CLAUDE_SESSION_ID:-}"
  [ -z "$sid" ] && return 0
  local sess_cfg="${CLAUDE_PROJECT_DIR}/.harness/session-${sid}.yaml"
  [ -f "$sess_cfg" ] || return 0

  # config.yaml 과 동일한 파서 재사용 — 단순히 HARNESS_CONFIG 를 치환 후 재호출
  local saved_config="$HARNESS_CONFIG"
  HARNESS_CONFIG="$sess_cfg"
  load_harness_config  # 같은 bash YAML 파서로 덮어쓰기
  HARNESS_CONFIG="$saved_config"

  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "[harness plugin] 📦 per-session override applied: .harness/session-${sid}.yaml"
  fi
}

# ─────────────────────────────────────────────────────────
# [5] L4 — session registry register (v0.6 / P0-2)
# ─────────────────────────────────────────────────────────
register_active_session() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local registry="${script_dir}/../common/session-registry.sh"
  [ -x "$registry" ] || return 0
  "$registry" prune >/dev/null 2>&1 || true
  local bl="${HARNESS_BL_ID:-unscoped}"
  "$registry" register "$bl" "starting" >/dev/null 2>&1 || true
}

# ─────────────────────────────────────────────────────────
# [6] L5 — multi-session preflight (v0.6 / HARNESS-MSC-001)
# ─────────────────────────────────────────────────────────
preflight_multi_session() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local registry="${script_dir}/../common/session-registry.sh"
  [ -x "$registry" ] || return 0

  # [6a] 타세션 감지 (jq 있을 때만 정밀)
  if command -v jq >/dev/null 2>&1; then
    local others; others=$("$registry" others 2>/dev/null)
    if [ -n "$others" ] && [ "$others" != "[]" ]; then
      local count; count=$(echo "$others" | jq 'length' 2>/dev/null || echo 0)
      if [ "${count:-0}" -gt 0 ]; then
        echo "[harness plugin] ⚠️  multi-session detected (N=${count})"
        echo "$others" | jq -r '.[] | "  · \(.session_id) (\(.profile)) · bl_id=\(.bl_id // "—") · phase=\(.phase // "—") · heartbeat=\(.last_heartbeat)"' 2>/dev/null
        echo "  policy: PHASE-P7 §3.2 · override-manifest.json compatible_base_version ~0.6"
      fi
    fi
  fi

  # [6b] 최근 .harness/<type>/ 쓰기 감지 (< 10분)
  local stale="${HARNESS_SESSION_STALE_SECONDS:-600}"
  local now_s; now_s=$(date +%s)
  local cutoff_s=$(( now_s - stale ))
  local cutoff_iso
  cutoff_iso=$(date -r "$cutoff_s" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$cutoff_s" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "")
  if [ -n "$cutoff_iso" ]; then
    local hits=""
    local dir
    for dir in feature ui generic; do
      local harness_dir="${CLAUDE_PROJECT_DIR}/.harness/${dir}"
      [ -d "$harness_dir" ] || continue
      local found
      found=$(find "$harness_dir" -maxdepth 3 -type f \( -name "SPEC.md" -o -name "SELF_CHECK*.md" -o -name "QA_REPORT*.md" -o -name "SPRINT_CONTRACT.md" \) -newermt "$cutoff_iso" 2>/dev/null | head -5)
      [ -n "$found" ] && hits="${hits}${found}\n"
    done
    if [ -n "$hits" ]; then
      echo "[harness plugin] ⚠️  recent harness writes (< ${stale}s):"
      printf '%b' "$hits" | sed 's|^|  · |'
    fi
  fi

  # [6c] archive-restore drift 감지 (SPEC.md == archive/*.md 바이트 동일)
  local dir
  for dir in feature ui generic; do
    local spec="${CLAUDE_PROJECT_DIR}/.harness/${dir}/SPEC.md"
    local archive_dir="${CLAUDE_PROJECT_DIR}/.harness/${dir}/archive"
    [ -f "$spec" ] || continue
    [ -d "$archive_dir" ] || continue
    local arc
    while IFS= read -r arc; do
      [ -f "$arc" ] || continue
      if cmp -s "$spec" "$arc" 2>/dev/null; then
        echo "[harness plugin] 🚨 SPEC drift suspect"
        echo "  .harness/${dir}/SPEC.md  ==  ${arc#${CLAUDE_PROJECT_DIR}/}  (bytes identical)"
        echo "  hint: another session may have restored archive over active SPEC"
        echo "  remediation: git log -p -- .harness/${dir}/SPEC.md"
      fi
    done < <(find "$archive_dir" -maxdepth 3 -type f -name "SPEC*.md" 2>/dev/null | head -20)
  done
}

# ─────────────────────────────────────────────────────────
# 메인 흐름
# ─────────────────────────────────────────────────────────
load_harness_config      # L0  — config.yaml → HARNESS_* env
load_session_override    # L0' — session-<id>.yaml 덮어쓰기 (v0.6)
check_semver_compat      # L3  — override-manifest semver 검사
do_link_farm             # L2  — agents/ → .claude/agents/ link-farm
register_active_session  # L4  — active-sessions.json (v0.6)
preflight_multi_session  # L5  — multi-session 경고 출력 (v0.6)

exit 0

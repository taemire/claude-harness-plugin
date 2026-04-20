# PHASE-P1-v2 — `.harness/config.yaml` 프로젝트 설정 SSOT

> **참조 SSOT**: [PLAN-v1.0.md §3.1 L1 변수 주입 레이어](./PLAN-v1.0.md#31-l1--변수-주입-레이어)
> **릴리즈 대상**: v0.5.0 (P1 v1 upgrade)
> **선행 버전**: v0.4.4 (userConfig in plugin.json — 유지, fallback 으로 격하)
> **v1 참조**: [PHASE-P1-userConfig.md](./PHASE-P1-userConfig.md) — 기존 Claude Code pluginConfigs 기반 구현

---

## 0. Executive Summary

기존 L1 변수 주입 레이어는 Claude Code 의 `.claude/settings.json.pluginConfigs.harness.options` 에 값을 저장했다. 이 위치는 Claude Code 런타임이 소유하는 git-untracked 영역이라 프로젝트 재구성 시 재입력 필요하고, 팀 확장/다른 환경으로 이식 시 수동 전파가 필요하다.

v0.5.0 에서 **`.harness/config.yaml`** 을 프로젝트 설정의 **1차 SSOT** 로 격상한다. Claude Code pluginConfigs 는 2차 fallback, plugin.json userConfig default 는 3차 fallback 으로 유지되어 비파괴적 전환.

## 1. Scope

**In Scope**:
- `.harness/config.yaml` 스키마 확정
- `hooks/session-start.sh` 에 L0 config loader 추가 (3단 cascade)
- `HARNESS_*` 환경 변수 export via `CLAUDE_ENV_FILE`
- SKILL.md 치환점을 `${user_config.*}` → `${HARNESS_*:-default}` 로 전환
- `templates/config.yaml.example` starter 제공
- 기존 `/plugin config harness` 경로는 유지 (Claude Code UI 호환)

**Out of Scope** (이후 phase):
- YAML → JSON 마이그레이션 툴 (현 단계는 YAML 만)
- Validator skill (스키마 유효성 검증, v0.7+ 예정)
- UI 에디터 (VS Code extension 등, 해당 없음)
- `custom:` 네임스페이스 아래 필드의 자동 discovery (v0.6+)

## 2. `.harness/config.yaml` 스키마

### 2.1 필수 구조

```yaml
schema_version: "1.0"   # 필수

harness:                # 필수, plugin.json userConfig 미러링 섹션
  project_name: <string>
  bl_prefix: <string>                # default: "BL"
  eval_criteria_path: <string>
  harness_mode_default: <string>     # default: "standard"

custom:                 # 선택, 프로젝트 자유 확장
  <key>: <value>
  ...
```

### 2.2 예시 (Portal Hub 기준)

```yaml
schema_version: "1.0"

harness:
  project_name: tsgroup-portal-hub
  bl_prefix: BL
  eval_criteria_path: .harness/overrides/eval_criteria.md
  harness_mode_default: standard

custom:
  phoenix_ui_layers: 5
  qg_ui_coverage_min: 95
  spa_preservation_rules: [S-01, S-02, S-03, S-04, S-05, S-06, S-07]
  plan_source: docs/implementation-plan/archive
```

### 2.3 환경 변수 명명 규약

`harness.<key>` → `HARNESS_<KEY>` (대문자 snake)

| YAML 키 | 환경 변수 |
|:--|:--|
| `harness.project_name` | `HARNESS_PROJECT_NAME` |
| `harness.bl_prefix` | `HARNESS_BL_PREFIX` |
| `harness.eval_criteria_path` | `HARNESS_EVAL_CRITERIA_PATH` |
| `harness.harness_mode_default` | `HARNESS_MODE_DEFAULT` |

`custom.<key>` → v0.5.0 은 자동 export 미지원. 향후 v0.6+ 에서 `HARNESS_CUSTOM_<KEY>` 지원 예정.

## 3. Resolution Priority (3단 cascade)

```
┌─────────────────────────────────────────────────┐
│ L0. ${CLAUDE_PROJECT_DIR}/.harness/config.yaml  │ ← 최우선 (프로젝트 SSOT)
└─────────────────────────────────────────────────┘
              ↓ (키 없음 시)
┌─────────────────────────────────────────────────┐
│ L1. .claude/settings.json.pluginConfigs.harness │ ← Claude Code UI 입력값
│     .options                                    │   (v0.4.x 호환)
└─────────────────────────────────────────────────┘
              ↓ (키 없음 시)
┌─────────────────────────────────────────────────┐
│ L2. plugin.json.userConfig.<key>.default        │ ← plugin 기본값
└─────────────────────────────────────────────────┘
```

Hook 은 위 순서로 값을 찾아 `HARNESS_*` 환경 변수를 `CLAUDE_ENV_FILE` 에 기록한다.

## 4. 구현 — `hooks/session-start.sh` 확장

### 4.1 의사 코드

```bash
load_harness_config() {
  local cfg="${CLAUDE_PROJECT_DIR}/.harness/config.yaml"

  # L0 — yaml (python3 stdlib 활용, macOS/Linux 기본 포함)
  declare -A yaml_vals=()
  if [ -f "$cfg" ] && command -v python3 >/dev/null 2>&1; then
    while IFS='=' read -r key val; do
      yaml_vals["$key"]="$val"
    done < <(python3 -c "
import sys, yaml
try:
    with open('$cfg') as f:
        d = yaml.safe_load(f) or {}
    for k, v in (d.get('harness') or {}).items():
        print(f'{k}={v}')
except Exception:
    pass
" 2>/dev/null)
  fi

  # 키별 cascade resolve
  for key in project_name bl_prefix eval_criteria_path harness_mode_default; do
    val="${yaml_vals[$key]:-}"

    # L1 fallback — Claude Code pluginConfigs (미구현, 차후 skip)
    # L2 fallback — plugin.json default
    if [ -z "$val" ]; then
      val=$(get_plugin_default "$key")
    fi

    [ -n "$val" ] && export_env "HARNESS_${key^^}" "$val"
  done
}
```

### 4.2 YAML 파싱 전략

**우선순위**:
1. **python3 + PyYAML** — macOS (brew python3) 에 PyYAML 기본 내장 아님 → `pip install pyyaml` 필요. 미설치 시 fallback
2. **yq** (외부 툴) — 선택적
3. **간이 bash 파서** — `key: value` 형식의 단순 YAML 만 지원, 중첩/배열 미지원

**v0.5.0 접근**: python3 + PyYAML 시도 → 실패 시 **경고 후 L1 (pluginConfigs) 로 fallback**. 사용자에게 `pip install pyyaml` 설치 안내.

### 4.3 `CLAUDE_ENV_FILE` 사용

SessionStart hook 은 `CLAUDE_ENV_FILE` 변수를 통해 세션 전역 env 를 설정 가능.

```bash
export_env() {
  local name="$1"
  local value="$2"
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export ${name}=\"${value}\"" >> "$CLAUDE_ENV_FILE"
  fi
}
```

## 5. SKILL.md 치환 규약 전환

### 5.1 대상 파일 & 치환 포인트

| 파일 | 현재 (v0.4.4) | 변경 후 (v0.5.0) |
|:--|:--|:--|
| `skills/run/SKILL.md` L33 | `${user_config.bl_prefix}-123` | `${HARNESS_BL_PREFIX:-BL}-123` |
| `skills/run/SKILL.md` L37 | `${user_config.bl_prefix}-456` | `${HARNESS_BL_PREFIX:-BL}-456` |
| `skills/resume/SKILL.md` L63 | `${user_config.bl_prefix}-123` | `${HARNESS_BL_PREFIX:-BL}-123` |
| `skills/resume/SKILL.md` L66 | `${user_config.bl_prefix}-456` | `${HARNESS_BL_PREFIX:-BL}-456` |
| `skills/resume/SKILL.md` L69 | `${user_config.bl_prefix}-999` | `${HARNESS_BL_PREFIX:-BL}-999` |

총 5개 치환점. `:-BL` fallback 으로 env 미설정 시 원래 동작과 동일 출력.

### 5.2 Claude Code 런타임 지원 확인

Claude Code SKILL.md 내 `${ENV_VAR:-default}` 패턴은 shell-style expansion 으로 공식 지원 (hook env + 세션 env 포괄).

## 6. 수용 기준 (AC)

| # | 기준 | 검증 방법 |
|:-:|:--|:--|
| AC-1 | `.harness/config.yaml` 없는 프로젝트에서 default (BL 등) 로 렌더링 | 새 프로젝트에서 `/harness:run` → "BL-123 sample" 출력 |
| AC-2 | `.harness/config.yaml` `bl_prefix: TASK` 설정 프로젝트에서 "TASK-123" 출력 | Portal Hub 대안 프로젝트로 검증 |
| AC-3 | PyYAML 미설치 환경에서 warning 출력 + fallback | 수동 `pip uninstall pyyaml` 후 확인 |
| AC-4 | yaml 파일 malformed 시 hook 무오류 통과 (fail-open) | 고의로 깨진 yaml 배치 후 세션 시작 |
| AC-5 | 기존 `.claude/settings.json` pluginConfigs 사용자 영향 없음 | v0.4.4 설정한 프로젝트에서 v0.5.0 업그레이드 후 동작 동일 |
| AC-6 | Hook 실행 시간 < 500ms (yaml 파싱 포함) | `time hooks/session-start.sh` |

## 7. 마이그레이션 경로 (v0.4.x → v0.5.0)

### 7.1 기존 pluginConfigs 사용자

**영향 없음**. hook 이 `.harness/config.yaml` 미존재 시 기존 `${user_config.*}` 경로와 동등한 fallback 제공.

### 7.2 프로젝트를 `.harness/config.yaml` 로 이관

```bash
# 1. templates 복사
cp ${CLAUDE_PLUGIN_ROOT}/templates/config.yaml.example \
   ${CLAUDE_PROJECT_DIR}/.harness/config.yaml

# 2. 프로젝트 값 편집
$EDITOR ${CLAUDE_PROJECT_DIR}/.harness/config.yaml

# 3. git 추가
cd ${CLAUDE_PROJECT_DIR} && git add .harness/config.yaml && git commit -m "chore: harness config"

# 4. 세션 재시작 → hook 이 HARNESS_* env 설정

# 5. (선택) .claude/settings.json.pluginConfigs.harness 제거
```

## 8. 리스크 & 완화

| # | 리스크 | 완화 |
|:--|:--|:--|
| R-01 | PyYAML 미설치 환경 | 공식 docs 에 `pip install pyyaml` 안내. fallback 경로 제공. 향후 간이 bash 파서 추가 검토 |
| R-02 | SKILL.md 치환 규약 변경 = minor-breaking | plugin.json userConfig 유지 + `:-default` fallback 으로 무설정 환경 영향 0 |
| R-03 | `.harness/config.yaml` 민감 정보 저장 우려 | schema 는 프로젝트 식별자만 지원. 민감 필드는 `.claude/settings.json` + `sensitive: true` 로 유지 권고 |
| R-04 | 여러 프로젝트에서 동시 사용 시 env var 오염 | Claude Code 는 세션별 env 격리 (공식) — 영향 없음 |
| R-05 | `custom:` 섹션이 v0.5.0 에서 미사용 | schema_version 으로 향후 확장 지원 명시. v0.6+ 에서 `HARNESS_CUSTOM_*` 도입 예정 |

## 9. 롤백 전략

- **hook 오작동 시**: `load_harness_config` 함수만 주석 처리 + patch 재출시 → SKILL.md `:-default` 가 정상 fallback
- **yaml 파싱 전체 제거**: hook 에서 loader 호출만 제거. env var 미설정 → `:-default` 로 v0.4.x 와 동등 동작

## 10. 테스트 프로시저 (수동)

```bash
# 1. 테스트 프로젝트 준비
mkdir -p /tmp/test-harness-v5/.harness
cat > /tmp/test-harness-v5/.harness/config.yaml <<EOF
schema_version: "1.0"
harness:
  project_name: my-test
  bl_prefix: TASK
EOF

# 2. hook 수동 실행
CLAUDE_PROJECT_DIR=/tmp/test-harness-v5 \
CLAUDE_PLUGIN_ROOT=/Users/msjang/wdata/dev/project/claude-harness-plugin \
CLAUDE_ENV_FILE=/tmp/test-env \
/Users/msjang/wdata/dev/project/claude-harness-plugin/hooks/session-start.sh

# 3. env 확인
cat /tmp/test-env  # → export HARNESS_PROJECT_NAME="my-test" 등
```

## 11. Revision Log

| 일자 | 변경 |
|:--|:--|
| 2026-04-20 | v1.0 최초 작성 — `.harness/config.yaml` 스키마 + 3단 cascade + SKILL 치환 규약 |

# PHASE-P7 — Multi-Session Hardening (v0.6.0)

> **문서 유형**: Phase 상세 스펙 (PLAN-v1.0.md §5 의 P7 확장)
> **릴리즈 대상**: claude-harness-plugin v0.6.0
> **작성일**: 2026-04-20
> **근거 실측**: TSGroup Portal Hub BL-306 세션 (2026-04-20 17:14:18 SPEC.md silent overwrite 사건)
> **상세 분석**: `$PORTAL_HUB/.harness/feature/MULTI_SESSION_CONTENTION_REPORT.md`
> **프로젝트 레벨 문서화**: `$PORTAL_HUB/docs/specs/HARNESS_MULTI_SESSION_CONTENTION.md` (HARNESS-MSC-001)
> **프로젝트 레벨 Phase 1 완료 커밋**: `317a754` · `909f947` · `9f9afc1` · `6410f4b` (Portal Hub repo)

## 0. 배경 & 목적

claude-harness-plugin v0.5.0 까지의 설계는 **단일 세션 단일 BL** 전제였다. 그러나 claude-nonstop 멀티 프로파일 환경에서 동일 프로젝트를 다중 Claude 세션이 공유하는 경우가 실사용상 흔해졌고, **공유 네임스페이스 (`.harness/feature/SPEC.md` 등) 가 silent overwrite 되는 사건이 실측**되었다.

Phase 1 (프로젝트 레벨) 은 Portal Hub 에서 override hook/helper/doc 으로 선제 대응했다. 본 Phase 7 은 이를 **플러그인 SSOT** 로 격상시켜 모든 플러그인 사용자가 기본 혜택을 누리도록 한다.

## 1. 범위 (v0.6.0 Deliverables)

| # | 항목 | 파일 | 설계 원칙 |
|:-:|:--|:--|:--|
| **P0-1** | BL-ID 네임스페이스 격리 | `skills/run/SKILL.md` (경로 상수 18곳) · `skills/uiux/SKILL.md` · `skills/resume/SKILL.md` · `hooks/session-start.sh` (마이그레이션 메시지) | `.harness/<type>/<BL-ID>/SPEC.md` 형태. `<BL-ID>` 는 `common/extract_bl_id.sh` 로 해결 (프로젝트 SSOT 활용) |
| **P0-2** | Session registry 플러그인 내장 | `hooks/session-start.sh` §[4] + `common/session-registry.sh` | `.harness/active-sessions.json` 읽기/쓰기. Portal Hub 의 프로젝트 레벨 helper 를 플러그인 SSOT 로 흡수 |
| **P0-3** | Atomic-write helper | `common/atomic-write.sh` | `tmp → rename` 패턴 래퍼. SKILL.md 는 이 helper 를 통한 쓰기 권장 |
| **P0-4** | Seed/restore 가드 + `.harness/templates/` 분리 | `common/seed-guard.sh` · `templates/<type>/` | 활성 경로 덮어쓰기 전 confirm. `--force-restore` 플래그 요구 |
| **P1-7** | config.yaml 분리 (공유/세션별) | `hooks/session-start.sh` L0 확장 | `harness.*` 공유 + `.harness/session-<id>.yaml` per-session override |
| **P1-8** | Codex app-server per-session socket | `common/codex-socket.sh` | `$TMPDIR/codex-<session-id>.sock` 자동 선택 |

### 1.1 Non-Goals

- 기존 v0.5 설치 파괴적 변경 **없음** (migration flag 로 단계적 전환)
- `.harness/feature/SPEC.md` (레거시 평면 경로) 는 v0.6 에서 **fallback 지원 유지**. v0.7 에서 deprecation warning, v1.0 에서 제거
- Windows symlink 제약 해소는 범위 외 (기존 cp fallback 유지)

## 2. 아키텍처 변경

### 2.1 디렉토리 구조 before/after

**Before (v0.5)**:
```
.harness/
├── feature/
│   ├── SPEC.md                    ← 공유 네임스페이스 (충돌 위험)
│   ├── SELF_CHECK.md
│   ├── QA_REPORT.md
│   ├── agents/
│   └── archive/
├── ui/… (동일 구조)
└── generic/…
```

**After (v0.6)**:
```
.harness/
├── feature/
│   ├── <BL-ID>/                   ← NEW: BL-ID 네임스페이스
│   │   ├── SPEC.md
│   │   ├── SELF_CHECK.md
│   │   ├── QA_REPORT.md
│   │   └── SPRINT_CONTRACT.md
│   ├── agents/                    ← 공유 (에이전트 정의)
│   └── archive/                   ← 공유 (이전 BL 보존)
├── ui/…
├── generic/…
├── templates/                     ← NEW: seed 원본 (.harness/<type>/ 복사 대상)
│   ├── feature/
│   ├── ui/
│   └── generic/
├── active-sessions.json           ← NEW: 세션 레지스트리 (gitignored)
├── session-<id>.yaml              ← NEW: per-session config override (optional)
└── config.yaml                    ← 공유 (harness.* / custom.*)
```

### 2.2 BL-ID 해결 전략

1. **명시 지정**: `/harness:run "BL-306 feature"` → `common/extract_bl_id.sh "BL-306 feature"` → `BL-306`
2. **git log fallback**: 첫 번째 커밋의 BL-ID (이미 v0.5 구현)
3. **final fallback**: `BL-UNKNOWN-<YYYYMMDD-HHMM>` (기존 동작)

SKILL.md 내부에서 `<BL-ID>` 플레이스홀더는 **skill 진입 직후 1회** 해결되고 이후 모든 경로에 고정 삽입.

### 2.3 session-start.sh 확장

```bash
main 흐름 (v0.6):
  load_harness_config           # L0 — config.yaml (기존)
  load_session_override         # L0' — session-<id>.yaml 존재 시 L0 위에 덮어쓰기 (신규)
  check_semver_compat           # L3 (기존)
  do_link_farm                  # L2 (기존)
  register_active_session       # L4 — active-sessions.json (신규)
  preflight_multi_session       # L5 — 타세션 감지 + drift 경고 (신규)

exit 0
```

## 3. 구현 세부

### 3.1 P0-1 — BL-ID 네임스페이스 격리

#### 3.1.1 skills/run/SKILL.md 변경

v0.5 의 18곳 경로 참조를 BL-ID 해결 후 주입하는 방식으로 치환:

```markdown
# v0.5 (Before)
결과를 .harness/feature/SPEC.md 파일로 저장하라.

# v0.6 (After)
결과를 .harness/feature/<BL-ID>/SPEC.md 파일로 저장하라.
(<BL-ID> 는 단계 0 에서 해결된 값. 예: BL-306)
```

skill 상단에 **단계 0.5 (BL-ID 해결)** 추가:

```markdown
### 단계 0.5: BL-ID 해결 (v0.6 신규)

다음을 실행하여 BL-ID 를 해결하라:
  BL_ID=$(bash ${CLAUDE_PLUGIN_ROOT}/common/extract_bl_id.sh "[사용자 요청 원문]")

이후 모든 경로에서 <BL-ID> 를 이 값으로 치환:
  .harness/feature/<BL-ID>/SPEC.md
  .harness/feature/<BL-ID>/SELF_CHECK.md
  .harness/feature/<BL-ID>/QA_REPORT.md
  ...

만약 BL_ID=BL-UNKNOWN-* 이면:
  - 사용자에게 BL 미식별 경고 출력
  - unscoped 네임스페이스 (`.harness/feature/_unscoped/`) 사용
  - 활성 세션 레지스트리에도 bl_id="unscoped" 로 기록
```

#### 3.1.2 fallback 지원 (deprecation 단계)

v0.6 에서는 레거시 `.harness/feature/SPEC.md` 경로도 여전히 읽기 지원. SessionStart hook 이 발견하면 안내:

```
[harness plugin v0.6.0] 📦 legacy flat layout detected
  .harness/feature/SPEC.md (legacy) — v0.7 에서 deprecated, v1.0 에서 제거
  권장 migration: bash common/migrate-to-bl-namespace.sh
```

### 3.2 P0-2 — Session registry 플러그인 내장

`common/session-registry.sh` (새 파일, Portal Hub 의 프로젝트 레벨 구현을 플러그인 SSOT 로 흡수):

```bash
# common/session-registry.sh — HARNESS-MSC-001 L4
# subcmds: register | heartbeat | list | others | unregister | prune
# registry path: ${CLAUDE_PROJECT_DIR}/.harness/active-sessions.json
# stale window: $HARNESS_SESSION_STALE_SECONDS (default 600)
```

hook 통합 (`hooks/session-start.sh` 말미에 추가):

```bash
register_active_session() {
  local bl_id="${HARNESS_BL_ID:-unscoped}"
  local phase="starting"
  "${script_dir}/../common/session-registry.sh" prune >/dev/null 2>&1
  "${script_dir}/../common/session-registry.sh" register "$bl_id" "$phase" >/dev/null 2>&1
}

preflight_multi_session() {
  # 10분 내 타세션 감지 시 경고 출력 (fail-open)
  local others
  others="$("${script_dir}/../common/session-registry.sh" others 2>/dev/null)"
  [ -z "$others" ] || [ "$others" = "[]" ] && return 0
  echo "[harness plugin v${msg_ver}] ⚠️  multi-session detected"
  # ... (상세 출력)
}
```

Stop hook (플러그인 hooks.json 에 Stop matcher 추가):

```json
"Stop": [
  { "matcher": ".*", "hooks": [
    { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/common/session-registry.sh unregister", "timeout": 5 }
  ]}
]
```

### 3.3 P0-3 — Atomic-write helper

`common/atomic-write.sh`:

```bash
# common/atomic-write.sh <target-path> <<content
# atomic write via tmp→rename. tmp is "<target>.tmp.<pid>".
# if target exists and HARNESS_ATOMIC_WRITE_IF_NOT_EXISTS=1 → abort.
```

SKILL.md 의 Write 지시부 변경:

```markdown
Write 대신 다음 헬퍼 사용 (atomic write):
  bash ${CLAUDE_PLUGIN_ROOT}/common/atomic-write.sh \
       .harness/feature/<BL-ID>/SPEC.md < content
```

(선택적 적용. 기존 Write 도 compatibility 유지. 핵심 파일만 atomic 권장.)

### 3.4 P0-4 — Seed/restore 가드 + templates/ 분리

`common/seed-guard.sh`:

```bash
# common/seed-guard.sh <source-template> <target-path>
# 1. target 존재 여부 확인
# 2. 존재하면 타세션 activity 여부 확인 (session-registry.sh others)
# 3. 활성 타세션 없음 + HARNESS_FORCE_RESTORE=1 → 허용
# 4. 활성 타세션 있음 → abort + "--force-restore 필요" 메시지
```

`templates/<type>/` 구조:

```
templates/
├── feature/
│   └── SPEC.template.md
├── ui/
│   └── SPEC.template.md
└── generic/
    └── SPEC.template.md
```

SKILL.md 의 seed 지시는 `common/seed-guard.sh` 경유:

```markdown
만약 SPEC.md 가 없으면 seed-guard 를 통해 템플릿 복사:
  bash ${CLAUDE_PLUGIN_ROOT}/common/seed-guard.sh \
       ${CLAUDE_PLUGIN_ROOT}/templates/feature/SPEC.template.md \
       .harness/feature/<BL-ID>/SPEC.md
```

### 3.5 P1-7 — config.yaml 분리 (공유/세션별)

`hooks/session-start.sh` L0 확장:

```bash
load_harness_config         # 기존 — .harness/config.yaml (공유)
load_session_override       # 신규 — .harness/session-${HARNESS_SESSION_ID}.yaml (덮어쓰기)
```

`session-${id}.yaml` 예시:

```yaml
# per-session config override — CLAUDE_SESSION_ID 기준 자동 로드
harness:
  harness_mode_default: pro   # 이 세션만 pro 모드 강제
custom:
  bl_id_lock: BL-306          # 이 세션은 BL-306 에만 작업
```

`.gitignore` 에 `session-*.yaml` 추가 권장 (각 세션별 휘발성).

### 3.6 P1-8 — Codex per-session socket

`common/codex-socket.sh`:

```bash
# codex app-server 가 단일 socket(broker.sock) 에서 FIFO 처리하면 세션 간 경합.
# 대안: session-id 기반 per-session socket path 선택.
# 사용: codex --app-server-socket "$(bash codex-socket.sh)"
CODEX_SOCKET="${TMPDIR:-/tmp}/codex-${CLAUDE_SESSION_ID:-default}.sock"
echo "$CODEX_SOCKET"
```

기존 `common/codex_invoke.sh` 에 통합 (env `HARNESS_CODEX_PER_SESSION_SOCKET=1` 시 per-session).

## 4. 마이그레이션 가이드 (v0.5 → v0.6)

### 4.1 자동 마이그레이션

`common/migrate-to-bl-namespace.sh` (v0.6 신규):

```bash
# legacy: .harness/feature/SPEC.md (BL-ID 미식별)
# 1. extract_bl_id.sh 로 BL-ID 해결 시도
# 2. .harness/feature/<BL-ID>/ 디렉토리 생성
# 3. git mv 로 경로 이동 (히스토리 보존)
# 4. 실패 시 .harness/feature/_unscoped/ 로 이동
```

### 4.2 수동 조치

- `.gitignore` 에 `.harness/active-sessions.json` + `.harness/session-*.yaml` 추가
- override-manifest.json 의 `compatible_base_version` 을 `~0.6` 으로 갱신 (v0.5 호환 선언이면 경고 출력 — 블로킹 없음)

## 5. 수용 기준 (AC)

| # | 기준 | 검증 |
|:-:|:--|:--|
| AC-1 | `.harness/feature/<BL-ID>/SPEC.md` 가 새 기본 경로로 동작 | `/harness:run "BL-123 feature"` 실행 후 파일 위치 확인 |
| AC-2 | v0.5 기존 설치 fallback 동작 | 레거시 경로에 있는 SPEC.md 를 skill 이 읽을 수 있음 |
| AC-3 | `active-sessions.json` 자동 register/unregister | SessionStart → 엔트리 추가, Stop → 제거 |
| AC-4 | 타세션 감지 시 경고 출력 | 2개 claude 세션 동시 시작 시 preflight 경고 |
| AC-5 | SPEC drift 감지 | SPEC.md == archive/*.md bytes 동일 시 경고 |
| AC-6 | atomic-write helper 단위테스트 | tmp 생성 → rename → 원본 무결 |
| AC-7 | seed-guard: 타세션 활성 시 restore abort | session register 후 seed-guard 호출 → abort |
| AC-8 | session-<id>.yaml 덮어쓰기 동작 | override 파일 존재 시 공유 config 대신 사용 |
| AC-9 | per-session codex socket 선택 | env 활성화 + 세션별 socket path 확인 |
| AC-10 | 프로젝트 override (Portal Hub) 와 공존 | 플러그인 기본 + 프로젝트 override 양쪽 작동 |

## 6. 리스크 & 완화

| 리스크 | 영향 | 완화 |
|:--|:--|:--|
| **R-P7-01** BL-ID 해결 실패 시 모든 skill 동작 정지 | 고 | `BL-UNKNOWN-*` fallback 유지 + `_unscoped` namespace |
| **R-P7-02** 기존 사용자 v0.5 → v0.6 시 경로 붕괴 | 고 | fallback 지원 + migration script + 2단계 deprecation (v0.7 warn, v1.0 remove) |
| **R-P7-03** hook 실행 시간 증가 (registry + preflight 추가) | 중 | jq 없을 때 grep fallback 으로 빠른 경로. 총 < 500ms 유지 |
| **R-P7-04** active-sessions.json 손상 | 저 | 손상 감지 시 초기화 + prune. fail-open |
| **R-P7-05** Windows 환경에서 socket / PID / symlink 제약 | 중 | 기존 cp fallback 패턴 유지. codex-socket 은 env 로 opt-in |

## 7. 릴리즈 절차

1. `feature/v0.6-multi-session-hardening` 브랜치에서 구현 (atomic commits)
2. 각 P 항목별 커밋 분리 (docs, common/, hooks/, skills/, templates/, version bump)
3. 로컬 smoke test — 3 시나리오 (happy path / 타세션 감지 / legacy fallback)
4. Portal Hub 에서 통합 테스트 — override-manifest compatible_base_version 갱신 + plugin update 시뮬레이션
5. `main` merge + tag v0.6.0 + push
6. Portal Hub override-manifest 를 `~0.6` 으로 sync 커밋

## 8. 참조

- PLAN-v1.0.md §4 (릴리즈 로드맵) · §5 (Phase 상세) · §7 (리스크 R-01~R-07)
- PHASE-P1-v2-config-yaml.md (L0 config loader 기존)
- PHASE-P3-session-start-hook.md (hook 구조 기존)
- `$PORTAL_HUB/docs/specs/HARNESS_MULTI_SESSION_CONTENTION.md` (프로젝트 레벨 SSOT)
- `$PORTAL_HUB/.harness/feature/MULTI_SESSION_CONTENTION_REPORT.md` (실측 증거)

---

**끝.** 본 문서는 v0.6.0 릴리즈와 함께 PLAN-v1.0.md §4 테이블에서 v0.6.0 항목을 "Starter templates" → "Multi-Session Hardening" 으로 재배정하는 것과 연동한다. "Starter templates" 는 v0.7 로 이관.

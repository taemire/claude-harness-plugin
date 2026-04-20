# CHANGELOG — claude-harness-plugin

## [0.4.4] — 2026-04-20

### Fixed — 슬래시 커맨드 이중 네임스페이스 (BL-307 후속)
- v0.4.3 에서 `commands/harness/{run,uiux,resume}.md` 서브디렉토리 구조로 배포했으나 Claude Code 의 command 네임스페이스 규칙에 따라 **이중 프리픽스** 적용됨:
  - 의도: `/harness:run` (plugin 이름 + 파일 이름)
  - 실측: `/harness:harness:run` (plugin 이름 + 서브디렉토리 이름 + 파일 이름)
  - 추가 증상: 같은 스킬들이 `/run`, `/uiux`, `/resume` 으로 프리픽스 없이 중복 노출. `/harness` 자동완성 시 6개 중복 항목 표시
- v0.4.4 에서 `commands/` 하위로 flatten:
  - `commands/harness/run.md`    → `commands/run.md`
  - `commands/harness/uiux.md`   → `commands/uiux.md`
  - `commands/harness/resume.md` → `commands/resume.md`
- 결과: `/harness:run`, `/harness:uiux`, `/harness:resume` 3개 정상 노출. 중복/이중 프리픽스 해소

### Notes
- command shim 내용은 변경 없음 (스킬 `harness:run` 위임 + 프리플라이트 지시 유지)
- **실측 절차**: `/plugin update harness` → 캐시 0.4.4 동기화 → 신규 세션 시작 → `/harness` 입력 시 `/harness:run · /harness:uiux · /harness:resume` 3개만 노출 확인
- v0.4.3 는 effectively yanked (이중 네임스페이스로 인해 사용자 경험 손상). 단 v0.4.3 의 `commands/` 도입 자체는 올바른 방향이었으므로 완전 롤백 대신 구조만 수정

### Retrospective — v0.4.2 CHANGELOG 엔트리 소급 기록
- v0.4.2 (2026-04-20) 커밋 `a16b4b6` 이 `plugin.json` `userConfig.<key>.title` 필드 추가(hotfix)만 수행하고 CHANGELOG 엔트리를 남기지 않음. 본 릴리즈 시점에 소급 기록:
  - **Fixed**: Claude Code plugin spec 이 각 `userConfig` 엔트리에 `title` (string) 필수로 요구. 누락 시 `/plugin install` manifest validation 실패. project_name / bl_prefix / eval_criteria_path / harness_mode_default 4 필드에 한글 title 추가
  - 이후 CHANGELOG 는 모든 릴리즈에 블록 누락 없이 기록 (거버넌스 §9.3 재확인)

## [0.4.3] — 2026-04-20

### Fixed — 슬래시 커맨드 미노출 (BL-307)
- v0.4.2 까지 플러그인이 `skills/{run,uiux,resume}/` 만 배포하고 `commands/` 디렉토리를 제공하지 않아, 공식 문서(CLAUDE.md §Harness & Long Pipelines) 가 광고한 `/harness:run · /harness:uiux · /harness:resume` 슬래시 커맨드가 `Unknown command` 로 실패하거나 `/` 자동완성에 노출되지 않음.
- 증상 재현: `/harness:uiux scan --feature=document-drive` 입력 → `Unknown command: /harness:uiux`. `/reload-plugins` 후에도 슬래시 프리픽스 진입로 부재.

### Added — `commands/harness/{run,uiux,resume}.md`
- `commands/harness/run.md` — `/harness:run` 진입 래퍼. 스킬 `harness:run` 호출 + `CLAUDE.md §사전 점검 프리플라이트` 준수 지시
- `commands/harness/uiux.md` — `/harness:uiux` 진입 래퍼. 하위 명령(scan/inventory/matrix/probe-gen/execute/gap/feedback/plan/check/report/full/setup) + QG-01~05 준수 지시
- `commands/harness/resume.md` — `/harness:resume` 진입 래퍼. `--bl-id` 자동 탐색 규약 + awaiting_user 전환 규약 스킬 위임

### Notes
- **실측 절차**: `/plugin update harness` → 캐시 0.4.3 동기화 → 신규 세션 시작 → `/` 입력 시 `/harness:run · /harness:uiux · /harness:resume` 자동완성 노출 확인
- 기존 스킬 번들(`skills/{run,uiux,resume}/SKILL.md`) 은 **변경 없음** — 슬래시 커맨드는 shim 이며 실제 로직은 스킬 재사용
- 관련 이슈: `tsgroup-portal-hub` 백로그 BL-307

## [0.4.1] — 2026-04-20

### Fixed — hotfix: 공식 hook 스펙 준수
- v0.4.0 의 hook 등록이 Claude Code 공식 규격과 불일치하여 런타임에서 트리거되지 않음. 공식 가이드 재확인 후 전면 재배선:
  - ❌ v0.4.0: `plugin.json.hooks.SessionStart = "hooks/session-start.sh"` (스칼라, plugin.json 내부)
  - ✅ v0.4.1: 신규 `hooks/hooks.json` — `{ description, hooks: { SessionStart: [{matcher, hooks:[{type, command, timeout}]}] } }` (배열, `${CLAUDE_PLUGIN_ROOT}` 기준 절대경로, `type: "command"` + `timeout: 30`)
  - matcher 2개 등록: `startup` (신규 세션) + `resume` (`--resume` / `--continue` / `/resume`). `/clear`, `compact` 는 이미 link-farm 구성된 상태라 재실행 불필요

### Removed
- `.claude-plugin/plugin.json` 의 `hooks` 필드 제거 (스펙 오류로 무효)

### Added
- `hooks/hooks.json` — Claude Code 공식 plugin hook 스펙 준수 형태

### Notes
- **실측 절차**: `/plugin update harness` 또는 Claude 세션 재시작 → 캐시 0.4.1 동기화 → `.harness/overrides/agents/*.md` 더미 파일 배치 → 새 세션 시작 → stdout 에 `✅ link-farm configured` 확인
- 공식 hook 스펙 참조: https://code.claude.com/docs/en/hooks (SessionStart matchers: startup / resume / clear / compact)
- v0.4.0 는 **yanked** 로 간주 (동일 태그에서 런타임 트리거 불가). v0.4.1 을 최소 기능 버전으로 사용할 것

## [0.4.0] — 2026-04-20

### Added
- **L2 Agent Replace 레이어 + L3 호환성 게이트 (P3 완료)**
  - `hooks/session-start.sh` (~160줄, bash 3.2 호환) — 세션 시작 시 자동 실행
    - [L2] link-farm: `${CLAUDE_PROJECT_DIR}/.harness/overrides/agents/*.md` → `${CLAUDE_PROJECT_DIR}/.claude/agents/` 심볼릭 링크 (Claude Code subagent 우선순위 3(.claude/agents) > 5(plugin agents) 활용). Windows 권한 부족 시 `cp` fallback
    - [L3] semver 검사: `override-manifest.json.compatible_base_version` vs `plugin.json.version`. `~` `^` `=` 연산자 지원 (간이 파서). 불일치 시 경고 stdout (블로킹 없음)
    - fail-open 원칙: override 파일 없거나 manifest 없어도 silent 통과
    - 재실행 멱등 (symlink 재생성만 수행)
    - jq 가용 시 우선 사용, 없으면 grep fallback
  - `.claude-plugin/plugin.json` 에 `"hooks": { "SessionStart": "hooks/session-start.sh" }` 필드 신설
  - `docs/schemas/override-manifest.schema.json` — JSON Schema draft-07 (schema_version / compatible_base_version / overrides[] / created_at / last_verified_base_version)
- `docs/PHASE-P3-session-start-hook.md` — P3 상세 스펙 (흐름도 · semver 파서 · AC 7 · 리스크 6)

### Changed
- `docs/PLAN-v1.0.md`: §5 P3 체크박스 완료 + §4 v0.4.0 로드맵 ✅ 마킹 + Revision v1.0-r4

### Notes
- 스모크 테스트 통과: happy path (link-farm 생성) / semver 불일치 (경고 출력) / no-overrides (silent) 3 시나리오 검증
- **첫 런타임 검증 필요**: Claude Code 실제 세션에서 SessionStart hook 이 트리거되는지 확인. 트리거 안 되면 대안 event (`UserPromptSubmit` 최초 1회) 로 폴백 설계 예정
- 다음 릴리즈: P4 (Starter templates) 또는 `/harness:resume` 본체 구현 (BL-304 완료 의존)

## [0.3.0] — 2026-04-20

### Added
- **L1 변수 주입 레이어 (P1 완료)**: `.claude-plugin/plugin.json` 에 `userConfig` 블록 신설. 4 키 선언
  - `project_name` (string, default `""`, 프로젝트 이름)
  - `bl_prefix` (string, default `"BL"`, 백로그 ID 접두사)
  - `eval_criteria_path` (string, default `""`, 도메인 평가 기준 파일 경로)
  - `harness_mode_default` (string, default `"standard"`, 기본 실행 모드)
- `docs/PHASE-P1-userConfig.md` — P1 상세 스펙 (스키마 확정 · 치환점 규약 · 수용 기준 6개 · 리스크 완화)

### Changed
- **SKILL.md 치환점 삽입 (P2 완료)**: 하드코딩된 프로젝트 특화 값을 `${user_config.*}` 치환점으로 전환
  - `skills/run/SKILL.md`: `BL-123`/`BL-456` → `${user_config.bl_prefix}-123/456`, `components/portal/` → `components/`
  - `skills/uiux/SKILL.md`: `portal.code.myds.me:8443` → `your-app.example.com` (generic placeholder)
  - `skills/resume/SKILL.md`: `BL-123`/`BL-456`/`BL-999` → `${user_config.bl_prefix}-123/456/999`
- `docs/PLAN-v1.0.md`: §5 P1/P2 체크박스 완료 처리 + Revision Log 엔트리 추가

### Notes
- **Non-breaking minor bump** — v0.2.x 설치 dry run 결과와 동일 출력 (bl_prefix default `BL` fallback)
- 다음 릴리즈 v0.4.0 에서 **L2 Agent Replace 레이어** (P3 SessionStart hook + link-farm) 착수
- Claude Code runtime 의 `${user_config.KEY}` resolve 동작은 릴리즈 후 세션 dry run 으로 AC-3/AC-4 검증 필요

## [0.2.2] — 2026-04-20

### Changed
- `docs/PLAN-v1.0.md` 거버넌스 섹션 재편 — **1인 운영 · 로컬 우선** 운영 모델 반영
  - Executive Summary 에 "운영 모델" 서브섹션 신설 (1인 운영 / local-first / GitHub = 백업 / fast iteration loop)
  - §9.4 "Issue 라벨 컨벤션" → "개발 플로우 (로컬 우선)" 로 대체: main 직접 커밋 / PR 없음 / issue tracker 미사용
  - §9.5 신설: 외부 adopter 발생 시 거버넌스 전환 조건 (adopter ≥ 1 / stars ≥ 10 / v1.0 GA)
  - §6.2 성공 KPI 를 Tier 1 (1인 운영 필수) + Tier 2 (외부 adopter 시 추가) 로 분리

### Notes
- 운영 철학 명문화: "필요가 발견되면 로컬 clone 에서 그 자리에서 fix → push (백업) → 즉시 사용" 의 fast iteration 을 격식보다 우선
- v0.3.0 착수 계획은 불변

## [0.2.1] — 2026-04-20

### Added
- `docs/PLAN-v1.0.md` — **하네스 개선 프로젝트 SSOT Living Document**. 3-레이어 아키텍처(L1 변수 주입 · L2 Agent Replace · L3 호환성 게이트), v0.3~v1.0 릴리즈 로드맵 (9 milestones), 6 phase 상세 (P1~P6), 7 리스크 + 완화, 6 Plan Quality Gate 포함
- `docs/README.md` — 문서 인덱스 + 작성 규칙 (Living Document / SSOT 우선 / Revision Log 필수)
- README `## 로드맵` 섹션을 PLAN-v1.0 연동형 테이블로 확장 (v0.1~v1.0 마일스톤)

### Notes
- 이번 릴리즈는 **문서-only** (patch 증가). 런타임 동작 불변
- 다음 릴리즈 v0.3.0 부터 PLAN 에 정의된 phase P1~P3 구현 착수 예정

## [0.2.0] — 2026-04-20

### Changed
- **BREAKING (plugin 내부 경로)**: SKILL.md / README / CHANGELOG 전반에서 `${CLAUDE_PROJECT_DIR}/harness/` · `harness/common/` 등 경로를 `.harness/` 로 일괄 치환 (SKILL.md 3종 + README + CHANGELOG 본문, 총 100+ 라인). TSGroup Portal Hub BL-305 의 `.harness/` 통일 로드맵에 맞춤
- `plugin.json.version` 을 **플러그인 버전의 단일 SSOT** 로 확정. `marketplace.json` 의 `metadata.version` 및 `plugins[0].version` 은 이 값을 따라 수동 동기화

### Added
- `.claude-plugin/marketplace.json` — 로컬 마켓플레이스 매니페스트 (로컬 캐시 / 원격 공용)
- README `## 버전 SSOT 규칙` 섹션 — plugin.json → marketplace.json 수동 sync 규약 명문화

### Notes
- 유저 레벨 deprecation stub (`~/.claude/skills/portal-harness/`, `uiux-harness/`) 은 그대로 유지. 2026-10-19 까지 6개월 공존
- `/harness:resume` 본체 구현은 프로젝트 측 체크포인트 엔진(BL-304) 완료에 따라 별도 릴리즈 예정

## [0.1.0] — 2026-04-19

### Added
- 플러그인 스켈레톤 초기화 (`.claude-plugin/plugin.json`, README, LICENSE, CHANGELOG)
- `skills/run/SKILL.md` — 현재 프로젝트 혼합 벤더 하네스 (기존 `~/.claude/skills/portal-harness/SKILL.md` v3.5 이전). `/harness:run` 으로 호출
- `skills/uiux/SKILL.md` — 100% UI 커버리지 6단계 PDCA 하네스 (기존 `~/.claude/skills/uiux-harness/SKILL.md` v2 이전). `/harness:uiux` 로 호출
- `skills/resume/SKILL.md` — 체크포인트 기반 자동 재개 stub. 본체 구현은 차기 버전에서 구현

### Migration Notes
- 기존 `/portal-harness`, `/uiux-harness` user-level 스킬은 **deprecation stub** 으로 전환. 6개월 유지 후 제거 예정
- 프로젝트 `.claude/settings.json` 에 `extraKnownMarketplaces.harness-local` 등록 필요
- SKILL.md 내부 경로는 현 상태(`harness/<type>/...`) 유지 — 추후 `.harness/` 일괄 rename 시 함께 치환 (차기 버전 → v0.2.0 에서 수행 완료)

### Context
- 혼합 벤더(Claude Code + Codex CLI) 품질 보증 파이프라인과 100% UI 커버리지 하네스를 재사용 가능한 플러그인으로 분리
- 체크포인트 기반 자동 재개(resume) 는 프로젝트 측에서 `.harness/common/*.sh` 4종을 준비한 경우 활성화된다

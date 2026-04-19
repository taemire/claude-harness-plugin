# PLAN v1.0 — claude-harness-plugin 장기 개선 로드맵

> **문서 유형**: Living Document (SSOT)
> **작성일**: 2026-04-20
> **현재 버전**: v0.2.0
> **목표 버전**: v1.0.0
> **소유자**: @JangMinSeok (GitHub: `taemire`)
> **참조 SSOT**: [plugin.json](../.claude-plugin/plugin.json) · [CHANGELOG.md](../CHANGELOG.md) · [README.md](../README.md)

---

## 0. Executive Summary

`claude-harness-plugin` 은 Claude Code 용 품질 보증 파이프라인 플러그인이다. 초기 v0.1~0.2 단계에서는 3개 스킬(run/uiux/resume) 을 네임스페이스로 번들링하는 데 집중했으나, 실사용 과정에서 **사용자가 프로젝트마다 원하는 커스터마이징이 plugin fork 없이 불가능**하다는 한계가 드러났다.

본 플랜은 플러그인을 **base 프레임워크 + 프로젝트 커스터마이징 레이어** 2단 구조로 재편하여, `/plugin update` 실행 시에도 프로젝트 고유 설정이 유실되지 않는 **upgrade-safe 아키텍처**를 달성하는 것을 목표로 한다.

### 운영 모델 (중요)

- **1인 운영 프로젝트** — 소유자(@JangMinSeok) 단독 개발·사용
- **로컬 우선(local-first)** — 로컬 체크아웃에서 수정 → 즉시 사용 → 검증 → GitHub push
- **GitHub 은 백업** — main 에 직접 커밋·push. PR / issue tracker / 브랜치 전략은 현시점 비적용
- **Fast iteration loop** — 로컬 사용 중 필요가 발생하면 그 자리에서 개선하여 바로 쓴다 (격식보다 속도)
- GitHub issue 기반 관리는 **외부 adopter 가 생기거나 v1.0 GA 시점에 재검토** (§9 참조)

### 핵심 가치

1. **하나의 기본 틀, 자유로운 확장** — 플러그인은 범용 뼈대만 제공, 프로젝트는 `.harness/overrides/` 로 덮어씀
2. **업그레이드 안전성** — 플러그인 버전 bump 가 프로젝트 커스터마이징을 파손하지 않음
3. **구조적 투명성** — 무엇이 base 이고 무엇이 프로젝트 고유인지 세션 시작 시 즉시 확인 가능
4. **즉시 가용성** — 필요가 발견되면 로컬 clone 에서 fix → push 까지 하나의 iteration 으로 처리 (대기·심사 없음)

---

## 1. 현재 상태 (v0.2.0, 2026-04-20 기준)

### 1.1 제공 기능

| 스킬 | 호출 | 상태 |
|---|---|---|
| `/harness:run` | Planner → Codex Plan Review → Generator → Build Gate → Codex Quick Review → Evaluator ∥ Codex Adversarial → R2 Refinement → Post-Refactor Verification | ✅ 정식 |
| `/harness:uiux` | UI primitive inventory → matrix → probe-gen → execute → gap → catalog feedback (6단계 PDCA) | ✅ 정식 |
| `/harness:resume` | 체크포인트 기반 자동 재개 (`.harness/checkpoints/{BL-ID}/state.json`) | 🟡 Stub (본체는 TSGroup Portal Hub BL-304 완료 후) |

### 1.2 구조

```
claude-harness-plugin/
├── .claude-plugin/
│   ├── plugin.json              ← 버전 SSOT
│   └── marketplace.json         ← 로컬 마켓플레이스 매니페스트
├── CHANGELOG.md
├── LICENSE
├── README.md
├── docs/                        ← 📍 이 플랜이 들어갈 위치 (신규)
└── skills/
    ├── run/SKILL.md
    ├── uiux/SKILL.md
    └── resume/SKILL.md
```

### 1.3 알려진 한계

| # | 한계 | 영향 |
|---|---|---|
| **L-01** | 프로젝트별 커스터마이징 (프로젝트명/BL 접두사/도메인 평가 기준) 을 plugin fork 없이 못함 | 로컬 copy 를 손수 패치 → `/plugin update` 시 유실 위험 |
| **L-02** | SKILL.md 내 BL-ID 예시 하드코딩 (`BL-123 sample infra feature`) | 프로젝트 도메인과 어긋나 독해성 저하 |
| **L-03** | Planner/Evaluator agent 의 시스템 프롬프트 템플릿을 프로젝트가 보강 불가 | 도메인 특화 합격 기준 주입 어려움 |
| **L-04** | 버전 호환성 검사 없음 | 사용자가 커스터마이징 후 plugin bump 시 silent breakage |
| **L-05** | `/harness:resume` 본체 미구현 | 현재 stub 만 존재 |

---

## 2. 비전 & 설계 원칙

### 2.1 비전

> "**하나의 기본 틀을 플러그인으로 제공하되, 하네스는 사용자가 얼마든지 고쳐 쓸 수 있는 구조적 이점을 가져간다.**"

### 2.2 설계 원칙

1. **Base Framework Immutability** — plugin 저장소 파일은 프로젝트 실행 중 수정하지 않는다
2. **Project Sovereignty** — 프로젝트의 `.harness/overrides/` 는 plugin 보다 항상 우선한다
3. **Upgrade Safety** — plugin 버전이 bump 되어도 프로젝트 커스터마이징은 유실되지 않는다
4. **Fail-Open Defaults** — 커스터마이징 파일 부재 시 base 기본값으로 정상 동작
5. **Explicit > Implicit** — 커스터마이징 포인트는 plugin.json `userConfig` 에 명시 선언, 감춰진 컨벤션 금지
6. **Zero Fork Goal** — 프로젝트가 plugin 을 fork 할 필요가 없어야 한다 (궁극 KPI)

### 2.3 Non-Goals (명시적 제외 범위)

- ❌ 다국어 리소스 파일 분리 (SKILL.md 자체가 한국어·영어 혼용 상태 유지)
- ❌ plugin 이 프로젝트 빌드·테스트를 수행 (그건 프로젝트 Taskfile 책임)
- ❌ GUI 설정 툴 (CLI + settings.json 편집으로 충분)

---

## 3. 타겟 아키텍처 (3-레이어)

```
┌─────────────────────────────────────────────────────────────────┐
│  L1. 변수 주입 레이어  (plugin.json userConfig ↔ settings.json)  │
│      ${user_config.project_name} / ${user_config.bl_prefix} …   │
└─────────────────────────────────────────────────────────────────┘
              ↓ base 가 참조 · 프로젝트가 값 주입
┌─────────────────────────────────────────────────────────────────┐
│  L2. Agent Replace 레이어  (.harness/overrides/agents/ → .claude/agents/)│
│      planner.md / evaluator.md 완전 대체 (subagent priority 3 > 5)│
└─────────────────────────────────────────────────────────────────┘
              ↓ hook 이 시작 시 link-farm 구성
┌─────────────────────────────────────────────────────────────────┐
│  L3. 버전 호환성 게이트  (.harness/overrides/override-manifest.json)│
│      compatible_base_version: "~0.3" → SessionStart hook semver 검사│
└─────────────────────────────────────────────────────────────────┘
```

### 3.1 L1 — 변수 주입 레이어

**목적**: 프로젝트명, BL-ID 접두사, 평가 기준 파일 경로 같은 스칼라 값을 선언적으로 커스터마이징

**plugin.json 추가 필드** (예시):
```json
{
  "userConfig": {
    "project_name": {
      "description": "프로젝트 이름 (예: tsgroup-portal-hub, my-saas-app)",
      "sensitive": false
    },
    "bl_prefix": {
      "description": "백로그 ID 접두사",
      "sensitive": false,
      "default": "BL"
    },
    "eval_criteria_path": {
      "description": "도메인 평가 기준 파일 경로 (프로젝트 루트 기준, 선택)",
      "sensitive": false
    },
    "harness_mode_default": {
      "description": "기본 실행 모드 (lite|standard|pro|ultra)",
      "sensitive": false,
      "default": "standard"
    }
  }
}
```

**SKILL.md 에서 참조**:
```markdown
예시:
/harness:run "${user_config.bl_prefix}-023 구독 인프라" --codex --codex-level=pro
```

**값 저장 위치**: `.claude/settings.json` 의 `pluginConfigs[harness].options` — project scope.

**수용 범위**: 스칼라 (string/number/boolean) 만. 복잡 구조는 L2 로 위임.

### 3.2 L2 — Agent Replace 레이어

**목적**: planner/evaluator/generator 같은 **구조 단위** 를 프로젝트가 통째로 대체 가능하도록 지원

**동작 원리** (Claude Code subagent 우선순위 3 > 5 활용):
```
{project_dir}/.harness/overrides/agents/planner.md  ← 프로젝트 소유
                        ↓ SessionStart hook 이 심볼릭 링크
{project_dir}/.claude/agents/planner.md             ← Claude Code 가 인식
                        ↓ priority 3 (project) > priority 5 (plugin)
plugin 이 기본 제공한 agents/planner.md 를 완전 대체
```

**`SessionStart` hook 책임**:
1. `${CLAUDE_PROJECT_DIR}/.harness/overrides/agents/*.md` 스캔
2. 각 파일을 `${CLAUDE_PROJECT_DIR}/.claude/agents/` 에 **심볼릭 링크** 생성 (멱등)
3. plugin base agent 와 이름 충돌 시 로그로 "overridden" 기록

**link-farm 전략 근거**:
- 복사 (copy) 보다 **링크** 선호 — 프로젝트가 override 파일을 편집하면 즉시 반영
- `.claude/agents/` 가 `.gitignore` 되어 있어도 OK — override 원본은 `.harness/overrides/` 에 존재

### 3.3 L3 — 버전 호환성 게이트

**목적**: plugin 이 v0.3 → v0.4 로 올라갔을 때 v0.3 호환 override 가 자동 감지되도록

**`.harness/overrides/override-manifest.json` 스키마**:
```json
{
  "compatible_base_version": "~0.3",
  "overrides": [
    { "type": "agent", "name": "planner", "reason": "도메인 평가 기준 추가" },
    { "type": "agent", "name": "evaluator", "reason": "Phoenix UI a11y 체크 강제" }
  ],
  "created_at": "2026-05-01",
  "last_verified_base_version": "0.3.0"
}
```

**`SessionStart` hook 의 semver 검사**:
1. `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 에서 `version` 읽기
2. `${CLAUDE_PROJECT_DIR}/.harness/overrides/override-manifest.json` 에서 `compatible_base_version` 읽기
3. `semver satisfies` 체크
4. **미충족 시** Claude 컨텍스트에 경고 stdout:
   ```
   ⚠️ harness plugin v0.4.0 감지. override-manifest.json 은 ~0.3 호환성 선언.
      마이그레이션 가이드: docs/MIGRATION-v0.3-to-v0.4.md 참조
   ```

**경고는 블로킹하지 않음** — 사용자가 의식적으로 "알고 쓰는 것" 을 존중.

---

## 4. 릴리즈 로드맵

| 버전 | 마일스톤 | 목표 |
|:--|:--|:--|
| **v0.2.0** (완료) | `.harness/` 경로 통일 + plugin.json SSOT 확정 | ✅ 2026-04-20 릴리즈 |
| **v0.3.0** | **L1 변수 주입 레이어 + L3 호환성 게이트** | Non-breaking, additive |
| **v0.4.0** | **L2 Agent Replace 레이어** (SessionStart hook + link-farm) | Non-breaking |
| **v0.5.0** | `/harness:resume` 본체 구현 (체크포인트 엔진) | TSGroup Portal Hub BL-304 완료 의존 |
| **v0.6.0** | **Starter templates** (`templates/overrides-starter/`) + README 커스터마이징 가이드 | 신규 사용자 onboarding |
| **v0.7.0** | **Evaluation criteria override** 전용 파이프라인 (L1 eval_criteria_path 활용) | 도메인 특화 합격 기준 |
| **v0.8.0** | **Cross-project migration tool** — 기존 portal-harness user-skill 을 overrides 로 자동 변환 | deprecation 마무리 |
| **v0.9.0** | **Telemetry opt-in** (선택) — 사용자 동의 시 사용 패턴 수집 | 데이터 기반 개선 |
| **v1.0.0** | **GA release** — API 안정화, 파괴적 변경 동결, semver major 약속 | Anthropic 공식 마켓플레이스 등록 검토 |

### 4.1 버전 별 Non-goal

- v0.3~0.6: **파괴적 변경 없음**. 모든 기존 v0.2 설치 정상 동작 보장
- v0.7~0.9: 새 기능은 opt-in, 기본 동작 유지
- v1.0: API stable lock-in

---

## 5. Phase 상세 (v0.3.0 착수 기준)

### P1 — userConfig 스키마 확정

**작업**:
- [ ] `plugin.json` 에 `userConfig` 4개 키 선언 (`project_name`, `bl_prefix`, `eval_criteria_path`, `harness_mode_default`)
- [ ] 각 키 description 한/영 bilingual 주석
- [ ] `default` 값이 있는 키는 미설정 시 fallback 검증

**수용 기준**: `claude plugin config harness` 실행 시 대화형 프롬프트로 값 수집 가능

### P2 — SKILL.md 치환점 삽입

**작업**:
- [ ] `skills/run/SKILL.md` 내 하드코딩 `BL-123`, `BL-456` 등을 `${user_config.bl_prefix}-023`, `${user_config.bl_prefix}-029` 등으로 전환
- [ ] `skills/uiux/SKILL.md` 프로젝트 루트 언급 부분을 `${user_config.project_name}` 참조로 변경
- [ ] `skills/resume/SKILL.md` 는 stub 이므로 최소 변경만

**수용 기준**: v0.2 설치에서도 fallback (BL default) 로 자연스럽게 렌더링

### P3 — SessionStart hook 구현

**작업**:
- [ ] `hooks/session-start.sh` 신규 작성 (~80줄)
  - link-farm: `.harness/overrides/agents/*.md` → `.claude/agents/` 심볼릭 링크 (bash `ln -sf`)
  - semver 검사: `plugin.json.version` vs `override-manifest.compatible_base_version`
  - 경고 stdout 포맷 표준화
- [ ] `plugin.json` 에 `"hooks": { "SessionStart": "hooks/session-start.sh" }` 추가
- [ ] macOS + Linux bash 양쪽 테스트

**수용 기준**:
- override 파일 없을 때 무경고 무오작동 (fail-open)
- override 파일 있을 때 `.claude/agents/` 에 심볼릭 링크 생성
- 호환성 미충족 시 경고 출력 (블로킹 없음)

### P4 — Starter templates

**작업**:
- [ ] `templates/overrides-starter/override-manifest.json` — 최소 필드 포함 예시
- [ ] `templates/overrides-starter/agents/planner.md.example` — base planner.md 기반 주석 가이드
- [ ] `templates/overrides-starter/README.md` — "이 디렉토리를 `{project}/.harness/overrides/` 로 복사하세요"

**수용 기준**: 신규 사용자가 5분 내 첫 override 실행 가능

### P5 — docs/MIGRATION-v0.2-to-v0.3.md

**작업**:
- [ ] 기존 v0.2 사용자가 v0.3 로 안전 이행하는 단계별 가이드
- [ ] 하드코딩 fork 를 override 레이어로 전환하는 변환 sed 스크립트 첨부
- [ ] Portal Hub case study 포함

**수용 기준**: Portal Hub `.claude/skills/auto-route/` fork 가 이 가이드 따라 override 로 이관 성공

### P6 — README 섹션 확장

**작업**:
- [ ] `## 커스터마이징 가이드` 섹션 신설
- [ ] 3-레이어 아키텍처 시각화
- [ ] FAQ (override 파일이 gitignore 되는가? base version bump 시 어떻게 되는가?)

**수용 기준**: GitHub README 만 보고도 override 설계 이해 가능

---

## 6. 품질 게이트 & 성공 기준

### 6.1 Plan Quality Gate (PQG) — 각 phase 종료 시 필수 점검

| 게이트 | 기준 | 집행 |
|---|---|---|
| **PQG-01** | v0.2 설치에서 regression 0건 | CI `plugin install harness@0.2.0 && claude --plugin harness run --dry-run` 성공 |
| **PQG-02** | override 파일 부재 시 기본 동작 불변 | `.harness/overrides/` 없는 프로젝트에서 run/uiux/resume 결과 diff = 0 |
| **PQG-03** | override 파일 존재 시 정확히 반영 | starter template 복사 → planner agent 가 override 버전으로 실행됨을 로그로 확인 |
| **PQG-04** | 호환성 위반 시 경고만 + 블로킹 없음 | `compatible_base_version: "~0.1"` + plugin v0.3 으로 실행 → 경고 출력, 파이프라인 완주 |
| **PQG-05** | 문서 동기화 | README / CHANGELOG / plugin.json / 본 PLAN 버전 필드 일치 |

### 6.2 성공 KPI (v1.0.0 진입 조건)

**Tier 1 — 필수 (1인 운영 기준)**:
- ✅ Zero-fork 달성: TSGroup Portal Hub 프로젝트가 plugin fork 없이 BL-023/BL-029 예시 커스터마이징 완료
- ✅ `/plugin update harness` 실행 후 프로젝트 커스터마이징 유실 사례 0건
- ✅ 본인이 관리하는 3개 이상 서로 다른 프로젝트에서 override 로 정상 동작 (다양성 내재 검증)

**Tier 2 — 외부 adopter 발생 시 추가 적용** (§9.5 조건 충족 후):
- ✅ 외부 사용자 ≥ 1명 확인 + "커스터마이징이 안 된다" 유형 이슈 30일간 0건
- ✅ v1.0 API stable lock-in 선언 + 향후 breaking change 는 major bump 로만 허용

---

## 7. 리스크 & 완화

| 리스크 | 영향 | 완화 |
|---|---|---|
| **R-01** Claude Code [Issue #25209](https://github.com/anthropics/claude-code/issues/25209) — skill same-name shadowing 버그 | skill 레벨 override 불안정 | skill 레벨 override 를 **설계에서 제외**. agent 레벨만 사용 (이미 반영됨) |
| **R-02** `disableSkillShellExecution` 정책이 hook 을 차단 | SessionStart hook 미실행 | link-farm 을 skill 진입점에서도 최초 1회 실행되도록 dual-path (hook + lazy init) 구성 |
| **R-03** SSSymlink 지원 안 하는 환경 (Windows 기본, WSL 일부 config) | `.claude/agents/` 링크 생성 실패 | fallback: 복사 (copy) + modification time 체크로 변경 감지 |
| **R-04** `userConfig` 값이 `.claude/settings.json` 에 평문 저장 | 민감 정보 노출 우려 | `sensitive: true` 필드는 macOS keychain 저장. 현재 설계에는 민감 필드 미포함 — 향후 추가 시 반영 |
| **R-05** hook 실행이 Claude Code 세션 시작 지연 (> 500ms) | UX 저하 | hook 실행 시간 측정 + 300ms 초과 시 경고. link-farm 병렬화 (bash `&`) |
| **R-06** override 파일 문법 오류로 agent 파싱 실패 | 해당 agent 호출 시 예외 | override-manifest 에 `schema_version` + validator script 추가. PQG-06 에서 검증 |
| **R-07** 사용자가 override 를 만들었지만 git 으로 커밋하지 않음 | 팀 공유 실패 | README 에 "`.harness/overrides/` 는 git 커밋 대상" 강조 섹션 + `.gitignore` 템플릿 제공 |

---

## 8. v0.2 → v0.3 마이그레이션 요약

```bash
# 1. plugin update
claude /plugin update harness

# 2. 프로젝트에 override 디렉토리 초기화
cp -r ${CLAUDE_PLUGIN_ROOT}/templates/overrides-starter .harness/overrides

# 3. 프로젝트 값 설정
claude plugin config harness
# → project_name: my-project
# → bl_prefix: BL
# → eval_criteria_path: .harness/overrides/eval_criteria.md  (optional)

# 4. 필요 시 agent 오버라이드 편집
$EDITOR .harness/overrides/agents/planner.md

# 5. 세션 시작 → SessionStart hook 이 자동으로 link-farm 구성
```

기존 plugin fork 사용자를 위한 자동 변환 스크립트는 `docs/MIGRATION-v0.2-to-v0.3.md` (P5 산출물) 에서 제공.

---

## 9. 거버넌스 (1인 운영 · 로컬 우선)

### 9.1 본 플랜 문서 관리 규칙

- 이 파일(`docs/PLAN-v1.0.md`) 이 **플러그인 개선 프로젝트의 SSOT** 다
- 모든 structural 변경 (새 phase 추가, 로드맵 수정, 아키텍처 변경) 은 이 문서를 먼저 갱신한 후 커밋
- `docs/` 하위에 phase 별 세부 스펙(`PHASE-P1-userConfig.md` 등) 을 필요 시 추가, 단 본 문서가 항상 top-level index
- **Living Document 원칙**: 기간성 정보 (예: "2026-04-20 기준") 는 날짜 명시. 결정 철회 시 history 보존

### 9.2 버전 bump 정책

- **patch (0.x.y)**: 문서 수정, 버그 수정, non-breaking 내부 리팩터링
- **minor (0.x.0)**: 새 phase 완료, 새 userConfig 키 추가, 새 override 타입 지원
- **major (x.0.0)**: L1/L2/L3 스키마 변경 등 파괴적 변경. v1.0.0 이후로 예약
- 연속된 문서 수정이 하루 안에 여러 번 있을 경우 **마지막 patch 에 통합** 하여 bump 노이즈를 줄인다

### 9.3 Changelog 작성 규칙

- 모든 릴리즈는 `CHANGELOG.md` 에 `[major.minor.patch] — YYYY-MM-DD` 블록 추가
- `### Added / Changed / Fixed / Notes` 섹션 구분
- 본 PLAN 에 정의된 phase 번호 (`P3 완료`) 를 반드시 언급

### 9.4 개발 플로우 (로컬 우선 · 1인 운영)

- **브랜치 전략**: `main` 직접 커밋. feature 브랜치 / PR 없음
- **커밋 단위**: 의미 단위 atomic. 하나의 커밋은 하나의 목적 (docs / feat / fix / refactor)
- **푸시 타이밍**: 로컬에서 기능이 동작하고 의미 있는 커밋 단위가 쌓이면 즉시 `git push origin main` (백업 목적)
- **태그**: 의미 있는 마일스톤만 annotated tag (`v0.2.1`, `v0.3.0`). 문서 patch 는 태그 생략 가능
- **Issue tracker / 라벨**: 현시점 **미사용**. 로드맵·phase 는 이 PLAN 문서가 단일 추적 매체
- **사용 중 발견한 개선점**: 로컬 clone 에서 그 자리에서 fix → 빌드 필요 없음 (markdown + bash) → `/plugin update` 로 즉시 반영 → 검증 → 백업 push

### 9.5 외부 adopter 발생 시 거버넌스 전환 기준

아래 조건 **중 하나** 충족 시 본 §9 를 개정하여 issue tracker + PR 워크플로우를 활성화:

- 본인 외 활성 사용자 1명 이상 확인 (external adopter)
- GitHub Stars ≥ 10 또는 fork ≥ 3
- v1.0.0 GA 릴리즈 시점 도달

그 전까지는 **속도 > 격식** 원칙으로 운영한다. GitHub 는 백업·공유 창구이며 협업 도구가 아니다.

---

## 10. 참고자료

### 10.1 공식 Claude Code Docs

- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) — userConfig, hooks, 환경 변수
- [Create custom subagents](https://code.claude.com/docs/en/sub-agents) — 5단계 우선순위 테이블
- [Extend Claude with skills](https://code.claude.com/docs/en/skills) — skill resolution, string substitutions
- [Claude Code settings](https://code.claude.com/docs/en/settings) — `CLAUDE_PROJECT_DIR` 확인

### 10.2 관련 Issue / Bug

- [Issue #25209 — Project-level skills with same name show both instead of overriding](https://github.com/anthropics/claude-code/issues/25209)

### 10.3 비교 시스템 참고

- [ESLint shared config 패턴 — LogRocket](https://blog.logrocket.com/reduce-effort-shared-eslint-prettier-configs/)
- [Terraform Override Files](https://developer.hashicorp.com/terraform/language/files/override)
- [NixOS Overlays](https://nixos.wiki/wiki/Overlays)
- [VS Code Settings scope 계층](https://code.visualstudio.com/docs/configure/settings)
- [Homebrew Taps 이름 충돌 패턴](https://docs.brew.sh/Taps)

### 10.4 리서치 Artifacts

- NotebookLM notebook ID: `0d64fdfc-4b00-484c-843f-112ee7fada2d` — Claude Code Plugin Override Architecture Research (10 sources)
- 리서치 실행 일자: 2026-04-20 (nlm-researcher agent)

---

## 11. Revision Log

| 일자 | 버전 | 변경 | 담당 |
|---|---|---|---|
| 2026-04-20 | **v1.0** | 최초 작성 — 3-레이어 아키텍처 + v0.3~v1.0 로드맵 + 7 리스크 + 6 PQG | @JangMinSeok (Claude-assisted) |
| 2026-04-20 | v1.0-r2 | Executive Summary 에 "운영 모델 (1인 운영 · local-first)" 섹션 신설. §9.4 를 "Issue 라벨 컨벤션" → "개발 플로우 (로컬 우선)" 로 대체. §9.5 외부 adopter 시 거버넌스 전환 조건 신설. §6.2 KPI 를 Tier 1 (필수) / Tier 2 (외부 adopter 시) 로 분리 | @JangMinSeok (Claude-assisted) |

---

> 다음 액션: v0.3.0 P1 (userConfig 스키마 확정) 착수 — 별도 PR 로 진행.

# CHANGELOG — claude-harness-plugin

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

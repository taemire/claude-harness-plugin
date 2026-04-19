# CHANGELOG — claude-harness-plugin

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

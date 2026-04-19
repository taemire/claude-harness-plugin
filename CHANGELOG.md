# CHANGELOG — claude-harness-plugin

## [0.1.0] — 2026-04-19

### Added
- 플러그인 스켈레톤 초기화 (`.claude-plugin/plugin.json`, README, LICENSE, CHANGELOG)
- `skills/run/SKILL.md` — 현재 프로젝트 혼합 벤더 하네스 (기존 `~/.claude/skills/portal-harness/SKILL.md` v3.5 이전). `/harness:run` 으로 호출
- `skills/uiux/SKILL.md` — 100% UI 커버리지 6단계 PDCA 하네스 (기존 `~/.claude/skills/uiux-harness/SKILL.md` v2 이전). `/harness:uiux` 로 호출
- `skills/resume/SKILL.md` — 체크포인트 기반 자동 재개 stub. 본체 구현은 차기 버전에서 구현

### Migration Notes
- 기존 `/portal-harness`, `/uiux-harness` user-level 스킬은 **deprecation stub** 으로 전환. 6개월 유지 후 제거 예정
- 프로젝트 `.claude/settings.json` 에 `extraKnownMarketplaces.harness-local` 등록 필요
- SKILL.md 내부 경로는 현 상태(`harness/<type>/...`) 유지 — 추후 `.harness/` 일괄 rename 시 함께 치환 (차기 버전)

### Context
- 혼합 벤더(Claude Code + Codex CLI) 품질 보증 파이프라인과 100% UI 커버리지 하네스를 재사용 가능한 플러그인으로 분리
- 체크포인트 기반 자동 재개(resume) 는 프로젝트 측에서 `harness/common/*.sh` 4종을 준비한 경우 활성화된다

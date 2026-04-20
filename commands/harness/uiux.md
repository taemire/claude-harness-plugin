---
description: UI/UX 테스트 하네스 — 정적 UI primitive inventory → 행렬 전개 → Playwright outcome probe 자동 생성 → 실행 → 갭 분석 → 카탈로그 피드백(6단계 PDCA). 100% UI 커버리지 품질 게이트 의무 준수
argument-hint: '[run|scan|inventory|matrix|probe-gen|execute|gap|feedback|plan|check|report|full|setup] [--feature=<name>] [--persona=admin|engineer|partner|customer] [--module=<id>] [--checks=a11y,perf,visual,responsive,i18n] [--coverage-gate=green|amber|off]'
---

사용자가 `/harness:uiux` 슬래시 커맨드로 UI/UX 테스트 하네스를 요청했습니다.

Raw slash-command arguments:
`$ARGUMENTS`

지침:
- 플러그인 스킬 `harness:uiux` 를 호출하여 위 인자를 그대로 전달하세요.
- 하위 명령(`scan`, `inventory`, `matrix`, `probe-gen`, `execute`, `gap`, `feedback`, `plan`, `check`, `report`, `full`, `setup`) 과 플래그를 스킬 내부 분기에 그대로 위임하세요.
- `CLAUDE.md §UI 테스트 커버리지 품질 게이트` (QG-01~QG-05) 를 준수하고, `full` 또는 `execute` 단계에서는 `CLAUDE.md §사전 점검 프리플라이트` 3개 리포트 후 사용자 "go" 확인을 대기하세요.

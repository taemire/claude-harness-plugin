---
description: 범용 혼합 벤더 하네스 워크플로우 v3.5 — Planner→Generator→Build Gate→Review→Evaluator→Adversarial 파이프라인
argument-hint: '[요청] [--type=ui|feature|qa] [--mode=lite|standard|pro|ultra] [--be-engine=codex|opus] [--fe-engine=opus|sonnet] [--plan-review=codex|none] [--xreview=codex|none]'
---

사용자가 `/harness:run` 슬래시 커맨드로 하네스 파이프라인을 요청했습니다.

Raw slash-command arguments:
`$ARGUMENTS`

지침:
- 플러그인 스킬 `harness:run` 을 호출하여 위 인자를 그대로 전달하세요.
- `CLAUDE.md §사전 점검 프리플라이트` 를 준수하세요 — 3개 리포트(남은 단계 & 토큰 예상치 / 현재 5시간 윈도우 사용률 / 중단권고점) 출력 후 사용자가 명시적으로 "go" 라고 답할 때까지 파이프라인 시작 금지.
- 사용자가 별도 사유로 직접 실행을 원하지 않으면 스킬 내부의 프리플라이트 흐름을 우선 수행하세요.

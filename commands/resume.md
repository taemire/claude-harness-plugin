---
description: 하네스 체크포인트 기반 자동 재개 — `.harness/checkpoints/{BL-ID}/state.json` 이 `status=paused` 인 최근 항목을 찾아 `resume_attempts` 증가 + artifacts 복원 + `current_phase` 부터 파이프라인 재개
argument-hint: '[--bl-id=BL-NNN]'
---

사용자가 `/harness:resume` 슬래시 커맨드로 체크포인트 기반 재개를 요청했습니다.

Raw slash-command arguments:
`$ARGUMENTS`

지침:
- 플러그인 스킬 `harness:resume` 을 호출하여 위 인자를 그대로 전달하세요.
- `--bl-id` 미지정 시 스킬이 `status=paused` 인 최근 체크포인트를 자동 탐색하도록 위임하세요.
- 최대 3회 재시도 후 `awaiting_user` 전환 규칙은 스킬 내부 규약을 따르며, 오케스트레이터는 별도로 건드리지 않습니다.
- 재개 후 실행될 페이즈가 대용량이라면 `CLAUDE.md §사전 점검 프리플라이트` 3개 리포트 후 사용자 "go" 확인을 먼저 요구하세요.

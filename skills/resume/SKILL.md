---
name: resume
description: 하네스 체크포인트 기반 자동 재개 . `.harness/checkpoints/{BL-ID}/state.json` 이 `status=paused` 인 최근 항목을 찾아 `resume_attempts` 증가 + `phase-NN-artifacts/` 복원 + `current_phase` 부터 파이프라인 재개. 최대 3회 시도 후 `awaiting_user` 로 전환. `/harness:resume [--bl-id=BL-NNN]` 형식.
argument-hint: "[--bl-id=BL-NNN] [--force] [--dry-run]"
---

# /harness:resume — 하네스 자동 재개 (stub, P3 f)

> **상태**: v0.1.0 스켈레톤. 본체는 **Green 구현 단계** 에서 구현. 이 스킬이 의존하는 shell 스크립트 4개 (`checkpoint_reader.sh`, `checkpoint_writer.sh`, `error_detector.sh`, `extract_bl_id.sh`) 의 **Red 테스트 (31 cases)** 는 이미 `.harness/common/tests/` 에 존재 — 테스트가 명세이다. Green 구현 완료 시 이 문서를 교체한다.

## 동작 요약 (설계 — P3)

1. **BL-ID 결정**
   - `--bl-id=BL-NNN` 명시 시: 그대로 사용
   - 미명시 시: `.harness/common/extract_bl_id.sh` 호출 → 최근 커밋/이슈/요청에서 auto-extract
   - fallback: 가장 최근 수정된 `.harness/checkpoints/BL-*/` 디렉토리

2. **상태 검증** — `.harness/common/checkpoint_reader.sh status BL-NNN`
   - `status != "paused"` → 거부 + 안내 (예: `completed` 는 `/harness-clean` 후 신규 실행)
   - `resume_attempts >= resume_max` (기본 3) → `status = "awaiting_user"` 로 전환 + 사용자 대기
   - `started_at > 7일` → stale 경고, `--force` 없으면 거부

3. **산출물 복원** — `phase-NN-artifacts/` → `.harness/<type>/` 로 rsync
   - 덮어쓰기 된 `SPEC.md / SELF_CHECK.md / QA_REPORT.md / output/` 을 중단 시점 상태로 되돌린다

4. **파이프라인 재개** — `state.json.current_phase` 부터 `/harness:run` 의 내부 흐름 이어감
   - 이미 완료된 phase 는 skip (멱등성)
   - 각 phase 완료 시 `checkpoint_writer.sh phase-complete ...` 호출

5. **로깅** — `resume-log.json.attempts` 에 시도 기록 append
   ```json
   {
     "attempted_at": "2026-04-19T23:30:00Z",
     "from_phase": "evaluator",
     "previous_pause_reason": "rate_limit_error",
     "outcome": "success|paused-again|failed"
   }
   ```

## 옵션

| 옵션 | 기본 | 설명 |
|:--|:--|:--|
| `--bl-id=BL-NNN` | auto | 재개 대상 명시 |
| `--force` | false | stale 체크포인트 (7일+) 경고 무시 |
| `--dry-run` | false | 실제 Agent 호출 없이 복원 + next_phase 만 리포트 |
| `FORCE_GO=1` (env) | 0 | context/5hr 프리체크 무시 (CLAUDE.md §Harness Q5 규칙) |

## 의존성 (shell 스크립트 4종)

- `.harness/common/checkpoint_writer.sh`
- `.harness/common/checkpoint_reader.sh`
- `.harness/common/error_detector.sh`
- `.harness/common/extract_bl_id.sh`

모두 Green 구현 단계에서 구현 예정. 현재는 Red 테스트만 존재.

## 실행 예시 (설계)

```bash
/harness:resume
# → latest paused checkpoint 자동 탐색
# → ${HARNESS_BL_PREFIX:-BL}-123, current_phase=evaluator, resume_attempts=0
# → 스냅샷 복원, evaluator 부터 재개

/harness:resume --bl-id=${HARNESS_BL_PREFIX:-BL}-456 --dry-run
# → 복원만 수행, next_phase 리포트

/harness:resume --bl-id=${HARNESS_BL_PREFIX:-BL}-999 --force
# → 7일 이상 오래된 stale 체크포인트 강제 재개
```

## 관련 문서

- 설계 문서: 프로젝트 저장소에서 관리

- Red 테스트: `<project-root>/.harness/common/tests/*.sh` (31 cases)

## 제약 (v0.1.0 stub)

- 현재 이 스킬을 호출하면 **"아직 구현되지 않음. Green 완료 후 활성화됨"** 안내만 반환
- 실제 재개 동작은 의존 shell 스크립트 4개 구현 완료 전까지 수행 불가

# PHASE-P1 — userConfig 스키마 확정

> **참조 SSOT**: [PLAN-v1.0.md §3.1 L1 변수 주입 레이어](./PLAN-v1.0.md#31-l1--변수-주입-레이어) · [§5 P1](./PLAN-v1.0.md#p1--userconfig-스키마-확정)
> **릴리즈 대상**: v0.3.0
> **선행 phase**: 없음 (최초)
> **후행 phase**: P2 (SKILL.md 치환점 삽입) — P1 과 같은 릴리즈에 번들

---

## 0. Executive Summary

L1 변수 주입 레이어의 스키마를 확정한다. `plugin.json` 에 `userConfig` 블록을 선언하여 프로젝트별 스칼라 값 — 프로젝트명, 백로그 접두사, 평가 기준 경로, 기본 모드 — 을 플러그인 fork 없이 주입 가능하게 한다.

## 1. Scope

**In Scope**:
- `plugin.json` 에 `userConfig` 블록 추가 (4 키)
- 키별 description / type / default / sensitive 속성 정의
- SKILL.md 내부에서 `${user_config.KEY}` 참조 규칙 표준화
- v0.2.x 설치 대상 **fallback** 동작 보장 (default 값 또는 공란 처리)
- P2 의 SKILL.md 치환점 규칙 사전 정의

**Out of Scope** (P2 이후):
- SKILL.md 실제 치환 (P2)
- SessionStart hook 경유 변수 주입 (P3 예정, L2 Agent Replace 와 함께)
- 민감 값 (`sensitive: true`) 처리 — 현 릴리즈에선 미사용
- Runtime 유효성 검증 (P8 이후 validator skill 예정)

## 2. userConfig 스키마 (최종 확정)

### 2.1 키 테이블

| 키 | type | default | sensitive | 용도 |
|:--|:--|:--|:--|:--|
| `project_name` | string | `` (공란) | false | SKILL 내 프로젝트 식별 문구에 주입. `${user_config.project_name}` 참조 |
| `bl_prefix` | string | `BL` | false | 백로그 ID 접두사. `${user_config.bl_prefix}-123` → `BL-123` (default) 또는 `TASK-123` 등 |
| `eval_criteria_path` | string | `` (공란) | false | 도메인 평가 기준 파일 경로 (프로젝트 루트 기준). 지정 시 Evaluator agent 가 추가 로드 |
| `harness_mode_default` | string | `standard` | false | 기본 실행 모드. `lite \| standard \| pro \| ultra` |

### 2.2 plugin.json 구현 형태

```json
{
  "name": "harness",
  "version": "0.3.0",
  "userConfig": {
    "project_name": {
      "description": "프로젝트 이름 (예: tsgroup-portal-hub, my-saas-app). SKILL 출력 문구에 삽입됨.",
      "type": "string",
      "default": "",
      "sensitive": false
    },
    "bl_prefix": {
      "description": "백로그/이슈 ID 접두사 (예: BL, TASK, TICKET). 기본 BL.",
      "type": "string",
      "default": "BL",
      "sensitive": false
    },
    "eval_criteria_path": {
      "description": "도메인 평가 기준 파일 경로 (프로젝트 루트 기준, 선택). 지정 시 Evaluator 가 추가 로드.",
      "type": "string",
      "default": "",
      "sensitive": false
    },
    "harness_mode_default": {
      "description": "기본 실행 모드 (lite | standard | pro | ultra). 미지정 시 standard.",
      "type": "string",
      "default": "standard",
      "sensitive": false
    }
  }
}
```

### 2.3 값 저장 & 해석 위치

- **스키마 선언**: `plugin.json` (plugin 저장소 내부)
- **값 저장**: `.claude/settings.json` 의 `pluginConfigs.harness.options` (project scope)
- **참조 치환**: Claude Code runtime 이 SKILL.md 읽기 시 `${user_config.KEY}` 를 resolve
  - 값 설정 시: 설정값 사용
  - 값 미설정 시: `default` 값으로 fallback
  - `default` 도 공란 시: 빈 문자열로 치환

## 3. 치환점 규칙 (P2 가 따를 규약)

### 3.1 교체 대상 패턴

| 원본 | 치환 후 | 이유 |
|:--|:--|:--|
| `BL-123` / `BL-456` / `BL-999` | `${user_config.bl_prefix}-123` / `${user_config.bl_prefix}-456` / `${user_config.bl_prefix}-999` | 프로젝트 고유 ID 접두사 반영 |
| `components/portal/` | `components/` | Portal Hub 특화 → generic 화 (디렉토리 하드코딩 제거) |
| `portal.code.myds.me:8443` | `your-app.example.com` | 특정 배포 URL → generic placeholder |

> **금지**: 이미 `${user_config.*}` 로 변환된 표현을 재변환하지 않는다. grep regex: `(?<!\$\{user_config\.)${user_config.*}` 패턴으로 이중 치환 방지.

### 3.2 치환 전 확인 사항

- P2 수행 시 각 SKILL.md 별로 `git diff` 로 변경 라인이 **정확히 3.1 테이블 기준**인지 확인
- fallback 렌더링: `bl_prefix` 미설정 프로젝트에서 `${user_config.bl_prefix}-123` 이 `BL-123` 으로 resolve 됨을 확인 (기존 v0.2 설치와 동일 결과)

### 3.3 후보였으나 미반영 (근거)

| 후보 | 미반영 이유 |
|:--|:--|
| `HARNESS_BASE_URL` userConfig 화 | 이미 bash 환경변수로 지원. SKILL 레벨 치환 불필요 |
| `project_name` SKILL 내부 강제 삽입 | v0.3 기본값이 공란. 사용자가 설정 시에만 자연스럽게 반영되도록 P2 에서 선택적 사용 |

## 4. Fallback & 호환성

### 4.1 v0.2.x 설치 → v0.3.0 자동 업그레이드

- `userConfig` 블록은 **추가**되는 필드이므로 v0.2.x 에 없던 것을 v0.3.0 이 읽으면 기본값 적용
- SKILL.md 의 `${user_config.bl_prefix}` 가 `BL` 로 resolve → 기존 하드코딩 `BL-123` 과 동일 출력
- **결론**: Breaking change 없음. minor bump (0.3.0) 로 충분

### 4.2 `${user_config.KEY}` resolve 실패 시 동작

- Claude Code runtime 이 문자열로 치환 — `undefined` 나 오류 발생하지 않고 공란 fallback
- (공식 스펙: [Skills — String substitutions](https://code.claude.com/docs/en/skills#available-string-substitutions))

## 5. 구현 체크리스트 (P1)

- [ ] `.claude-plugin/plugin.json` 에 `userConfig` 블록 추가 (위 §2.2 형태)
- [ ] `plugin.json` 의 `version` 을 `0.2.2` → `0.3.0` 으로 bump
- [ ] `.claude-plugin/marketplace.json` 의 `metadata.version` + `plugins[0].version` 동기화
- [ ] `CHANGELOG.md` 에 `[0.3.0] — YYYY-MM-DD` 블록 생성, `### Added` 아래 `userConfig` 도입 기술
- [ ] `docs/PLAN-v1.0.md` P1 체크박스 업데이트 + Revision Log 추가

## 6. 구현 체크리스트 (P2, 같은 릴리즈 번들)

- [ ] `skills/run/SKILL.md` L33, L37 — `BL-123` → `${user_config.bl_prefix}-123`, `BL-456` → `${user_config.bl_prefix}-456`
- [ ] `skills/run/SKILL.md` L410 — `components/portal/` → `components/`
- [ ] `skills/uiux/SKILL.md` L127 — `portal.code.myds.me:8443` → `your-app.example.com`
- [ ] `skills/resume/SKILL.md` L63, L66, L69 — BL-123/BL-456/BL-999 치환
- [ ] 치환 후 grep 으로 정확성 확인 (§3.1 테이블 7개 지점 전부 반영)
- [ ] `docs/PLAN-v1.0.md` P2 체크박스 업데이트

## 7. 수용 기준 (Acceptance Criteria)

| # | 기준 | 검증 방법 |
|:-:|:--|:--|
| AC-1 | `plugin.json` `userConfig` 블록이 4키 전부 포함 | `jq '.userConfig \| keys' .claude-plugin/plugin.json` 출력 4개 |
| AC-2 | `/plugin config harness` 실행 시 4키 대화형 입력 프롬프트 출력 | 수동 검증 |
| AC-3 | 공란 설정으로 `/harness:run` 호출 시 fallback 작동 — `BL-123` 예시 출력 | Claude Code 세션 dry run |
| AC-4 | `bl_prefix=TASK` 설정으로 호출 시 `TASK-123` 으로 출력 | 수동 검증 |
| AC-5 | 3개 SKILL.md 에서 7개 치환점 전부 반영 | `${user_config.*}` 직접 치환 5건 (run 2 + resume 3) — `grep -cE "\$\{user_config\." skills/*/SKILL.md` 합계 = 5. 나머지 2건은 generic 치환 (`components/portal/` → `components/` · `portal.code.myds.me:8443` → `your-app.example.com`). 통합 검증: `grep -nE "\\bBL-(123\|456\|999)\\b\|portal\.code\.myds\.me\|components/portal/" skills/*/SKILL.md` 결과 = 0 |
| AC-6 | v0.2.x 설치 dry run 결과와 v0.3.0 default 설정 dry run 결과 **출력 동일** | `diff` |

## 8. 리스크 & 완화

| 리스크 | 영향 | 완화 |
|:--|:--|:--|
| `${user_config.*}` 변수 기능이 실제 Claude Code runtime 에서 resolve 안 될 경우 | 치환점이 literal 로 남아 문서 흉해짐 | 릴리즈 전 Claude Code 세션에서 수동 resolve 확인 (AC-3/AC-4). 문제 시 P2 롤백 후 P1 만 minor 출시 |
| 사용자가 `bl_prefix` 를 규약 외 값(공백 포함 등) 입력 | SKILL 렌더링 왜곡 | v0.3.0 은 검증 없음 (스칼라 trust). 향후 validator skill 에서 처리 |
| 설정값이 `.claude/settings.json` 에 평문 저장 | 민감 정보 포함 시 유출 | 현 4키는 민감 아님. 향후 `sensitive: true` 필드 쓸 때 keychain 저장 확인 |

## 9. 롤백 전략

- **P1 만 문제 시**: `plugin.json` userConfig 블록만 제거 후 `0.3.0` → `0.3.1` patch 로 재출시
- **P2 치환 문제 시**: 해당 SKILL.md 만 git revert + patch bump
- **L1 전체 철회**: PLAN-v1.0 수정 → major breaking 사전 공지 → v0.4.0 에서 재설계

## 10. Revision Log

| 일자 | 변경 |
|:--|:--|
| 2026-04-20 | v1.0 최초 작성 — 4-key userConfig 스키마 + 7개 치환점 규약 확정 |

---
name: run
description: 범용 혼합 벤더 하네스 워크플로우 v3.5 (정식). Claude(Plan/FE/Arbit) + Codex(Plan Review/BE/Cross-Review) 혼합. UI/Feature/QA 파이프라인 자동 선택. `/harness:run [요청] [--type=ui|feature|qa] [--mode=lite|standard|pro|ultra] [--be-engine=codex|opus] [--fe-engine=opus|sonnet] [--plan-review=codex|none] [--xreview=codex|none]` 형식.
---

# 혼합 벤더 하네스 워크플로우 (v3.5 정식)

Claude Code 프로젝트를 위한 **혼합 벤더 품질 보증 파이프라인 (v3.5)**입니다.
Claude는 Plan/FE/Arbit, Codex는 Plan Review/BE/Cross-Review를 담당합니다.
> 아키텍처 정식 명세: `docs/specs/HARNESS_V3_5_ARCHITECTURE.md`
> 실측 근거: `docs/specs/HARNESS_V3_ALPHA_POC_RESULTS.md`
> 버전 계보: v1 → v2 → **v3.5 (기본)**
> Gemini는 정식 파이프라인에서 **제외** (5파일 이하 프로토타입에만 한정 허용).

사용자의 요청을 분석하여 UI 하네스, Feature 하네스, 또는 QA 전수 테스트 하네스를 자동 선택하고 실행합니다.

---

## 실행 형식

```
/harness:run [요청 내용] [--type=ui|feature|qa] [--mode=lite|standard|pro] [--codex|--no-codex]
```

예시:
```
/harness:run "이슈 목록 필터 컴포넌트" --type=ui
/harness:run "이슈 목록 필터 컴포넌트" --type=ui --mode=pro   ← Sprint Contract + Live Test
/harness:run "댓글 알림 구독 기능 추가" --type=feature
/harness:run "릴리즈 다운로드 카드 UI 개선"    ← 자동 감지
/harness:run "파트너사 계약 만료 알림 시스템"  ← 자동 감지
/harness:run "파트너사 계약 만료 알림 시스템" --mode=pro --codex  ← Codex 강제 활성
/harness:run "${HARNESS_BL_PREFIX:-BL}-123 sample infra feature" --codex --codex-level=pro    ← Standard 모드 + Codex Pro 검토
/harness:run "전수 테스트" --type=qa            ← QA 전수 테스트
/harness:run --type=qa --scope=module:release   ← 모듈별 QA
/harness:run --type=qa --mode=sweep             ← 전체 sweep
/harness:run "${HARNESS_BL_PREFIX:-BL}-456 sample auth feature" --mode=ultra      ← 전 단계 Opus, 한 번에 고품질
/harness:run "복잡한 인증 시스템" --mode=ultra --codex  ← Ultra + Codex 강제
```

### 모드 선택 가이드 (v3.5 정식)

| 모드 | 파이프라인 | Codex 통합 | 언제 |
|---|---|---|---|
| **lite** | Generator → Evaluator | 없음 | 간단한 수정, 스타일 변경 |
| **standard** (기본) | Planner → **Codex Plan Review** → Generator(BE=Codex, FE=Claude) → RVG → **Codex XReview→FE** → Evaluator | Plan Review + Cross-Review | 대부분의 기능 |
| **pro** | Standard + Sprint Contract + Final Reviewer | Plan Review + Cross-Review + Adversarial + Rescue | 복잡한 기능, 실행 검증 필요 |
| **ultra** | Pro + 전 단계 Opus 승격 | 전체 활성 | 복잡한 코드베이스, 한 번에 고품질 구현 |

### v3.5 엔진 플래그 (정식)

| 플래그 | 기본 | 옵션 | 설명 |
|---|---|---|---|
| `--be-engine` | `codex` | `codex \| opus` | BE Generator. Codex 미가용 시 opus 자동 폴백 |
| `--fe-engine` | `opus` (ultra/pro) / `sonnet` (standard) | `opus \| sonnet` | FE Generator. Claude 계열만 (Gemini 금지) |
| `--plan-review` | `codex` | `codex \| none` | Codex Plan Deep Review (구조적 drift 조기 감지) |
| `--xreview` | `codex` | `codex \| none` | Codex Cross-Review (FE 산출물 API contract 검증) |
| `--arbiter` | `opus` | `opus \| sonnet` | Final Reviewer / Arbiter |

### Codex 통합 레거시 플래그 (호환성)

| 플래그 | 동작 |
|---|---|
| `--codex` | Codex 강제 활성화 (가용성 점검 건너뜀, Plan Review + BE + XReview 전부 codex) |
| `--no-codex` | Codex 비활성화 — v2 호환 모드로 downgrade. Plan Review/BE/XReview 모두 opus로 수행 |
| 미지정 | 자동 가용성 점검 (`.harness/common/v3_5_env.sh` 로드 + `codex --version` 확인) |

### 환경 로드

```bash
source .harness/common/v3_5_env.sh       # .secrets/harness-v3.credentials + v3.5 엔진 기본값
```

- `$HARNESS_VERSION=v3.5` 강제
- `$HARNESS_ENGINE_BACKEND=codex`, `$HARNESS_ENGINE_UI=claude`, `$HARNESS_ENGINE_ARBITER=opus`
- `$HARNESS_GEMINI_ALLOWED_SCOPE=prototype-only` — 정식 파이프라인에서 Gemini 자동 호출 금지
- Credentials 파일의 `HARNESS_ENGINE_UI=gemini` 등은 **무시**하고 v3.5 정식값 강제

### Codex 호출 헬퍼

```bash
.harness/common/codex_invoke.sh <prompt_file> <log_file> [reasoning=medium|low|high]
```

- stdin-from-file 패턴으로 `codex exec` hang 방지 (PoC에서 발견)
- `reasoning=medium` 기본 (high는 token 폭발 — 13.5k/probe 실측)
- 벽시계 + exit code 자동 로깅

### Codex 검토 수준 플래그

| 플래그 | 동작 |
|---|---|
| `--codex-level=standard` | 모드에 따른 Codex 통합 (아래 테이블 참조) |
| `--codex-level=pro` | **기본값** — Standard 모드에서도 Pro 수준 Codex 검토 활성화 (Adversarial + Rescue). Sprint Contract/Final Reviewer(Claude Opus) 없이 Codex 검토만 상향 |

> `--codex-level=pro`가 기본값이다. "Claude 파이프라인은 standard, Codex 검토만 pro"로 동작한다.
> Pro 모드의 Sprint Contract/Final Reviewer는 추가되지 않으므로 비용은 Codex API 호출분만 증가.
> `--codex-level`은 `--codex`/`--no-codex`와 독립적이다. `--no-codex`가 지정되면 `--codex-level`은 무시.

### QA 하네스 전용 모드

| 모드 | 파이프라인 | 언제 |
|---|---|---|
| **analyze** | Analyzer만 | 현황 파악, 리포트만 |
| **standard** (기본) | Analyzer → Generator → Validator | 갭 분석 + 테스트 생성 |
| **sweep** | Analyzer → Generator → Validator (반복) | 전수 검사, 모든 갭 해소 |

### QA 하네스 스코프 옵션

| 옵션 | 설명 |
|---|---|
| `--scope=full` | 전체 프로젝트 (기본) |
| `--scope=module:<name>` | 특정 모듈만 |
| `--scope=layer:<name>` | 특정 레이어만 (domain/usecase/repository/api) |
| `--scope=frontend` | FE 전체 |
| `--scope=e2e` | E2E 시나리오만 |

---

## Codex 통합 (Cross-Vendor 보조 품질 레이어)

OpenAI Codex (GPT-5.4)를 Claude 에이전트 파이프라인의 **보조 품질 레이어**로 편입합니다.
Codex는 Claude를 대체하지 않고 보완하며, 미설치/미인증 시에도 하네스가 정상 동작합니다 (graceful degradation).

### 삽입 지점 4개

| 삽입 지점 | 모드 | 역할 | 호출 |
|---|---|---|---|
| **Planner 완료 후 Plan Deep Review** | ultra | SPEC 보안/테스트 갭 사전 보강 → SPEC.md 병합 | `/codex:rescue --wait` (plan-review) |
| **Build Gate 후 Quick Review** | standard, pro | Evaluator 전 기본 결함 조기 차단 | `/codex:review --wait` |
| **R3+ 교착 시 Rescue** | pro 또는 `--codex-level=pro` | Claude 블라인드스팟 돌파 (독립 구현) | `/codex:rescue --wait --write` |
| **Evaluator 합격 후 Adversarial** | pro 또는 `--codex-level=pro` (feature) | auth/data-loss/race 공격적 검증 | `/codex:adversarial-review --wait` |

> UI 하네스에서는 Adversarial Review 미적용 (보안 위험도가 낮으므로). Plan Deep Review는 UI 하네스에서 a11y/testability 갭에 집중.
> Codex 호출 실패는 **하네스를 차단하지 않음** — 항상 "skipped" 기록 후 진행.

### 모드별 Codex 통합 수준

| 모드 | Plan Deep Review | Quick Review | Adversarial | Rescue | Claude 모델 |
|---|---|---|---|---|---|
| lite | - | - | - | - | Sonnet |
| standard | - | O | - | - | Opus(Plan) + Sonnet(Gen/Eval) |
| standard + `--codex-level=pro` | - | O | O (feature) | O (R3+) | Opus(Plan) + Sonnet(Gen/Eval) |
| pro | - | O | O (feature) | O (R3+) | Opus(Plan/Contract/Final) + Sonnet(Gen/Eval) |
| **ultra** | **O** | **O** | **O (항상)** | **O (R2+)** | **전 단계 Opus** |

> `--codex-level=pro`는 standard 모드의 Codex 통합만 pro 수준으로 상향한다.
> Claude 파이프라인 자체(Sprint Contract, Final Reviewer)는 변경되지 않는다.
> **Ultra 모드**: Planner 완료 직후 Codex Plan Deep Review로 SPEC 보강 → 전 단계 Opus + Codex 강제 활성. Rescue 임계값을 R3→R2로 낮춤 (빠른 돌파).
> Ultra는 `--codex` 암묵 적용. `--no-codex`와 함께 사용 시 Plan Deep Review 포함 Codex 전체 비활성.

### 관련 파일

- `.harness/common/codex_availability.md` — 공유 가용성 점검 지시서
- `.harness/feature/agents/codex_adversarial_reviewer.md` — 적대적 리뷰 에이전트 정의
- `.harness/feature/agents/codex_rescue_strategy.md` — 교착 구출 전략
- `.harness/feature/agents/merged_review_template.md` — 병합 리뷰 템플릿

---

## 1단계: 하네스 타입 결정

`--type=ui`, `--type=feature`, 또는 `--type=qa`가 명시되었으면 그것을 따릅니다.
명시되지 않은 경우 아래 기준으로 자동 판단합니다:

**QA 하네스 신호** (아래 키워드가 있으면 QA):
- 테스트, 커버리지, 전수, QA, 검증, 테스트 갭, 커버리지 분석
- 단위 테스트, 통합 테스트, E2E, 회귀 테스트
- 테스트 생성, 테스트 추가, 미테스트 코드

**UI 하네스 신호** (아래 키워드가 있으면 UI):
- 컴포넌트, 화면, UI, 페이지, 레이아웃, 디자인, 카드, 테이블, 모달, 폼
- 개선, 리디자인, 스타일, 반응형, 다크모드
- 버튼, 아이콘, 뱃지, 탭, 드롭다운

**Feature 하네스 신호** (아래 키워드가 있으면 Feature):
- 기능 추가, 구현, 개발, 시스템, 도메인
- GraphQL, API, 백엔드, 쿼리, 뮤테이션
- 알림, 구독, 권한, 통계, 이력, 로그
- 데이터베이스, 마이그레이션, 테이블

**판단 불가 시**: 사용자에게 "UI 컴포넌트 개발인가요, 백엔드 기능 개발인가요, 아니면 테스트 커버리지 개선인가요?" 를 물어보세요.

결정된 타입을 사용자에게 먼저 알립니다:
```
🎯 하네스 타입: [UI / Feature / QA]
이유: [판단 근거 한 줄]
```

---

## Stall Detection (Watchdog Protocol)

> **필수 참조**: 서브에이전트 호출 전에 `.harness/common/watchdog_protocol.md`를 읽어라.

모든 서브에이전트 호출 시 아래 패턴을 **반드시** 적용한다:

### 호출 패턴

```
# 에이전트 + 타이머를 동시에 백그라운드로 시작
Agent({ name: "{agent-name}", run_in_background: true, model: "...", prompt: "..." })
Bash({ command: "sleep 180", run_in_background: true })
```

### 타이머 완료 알림 수신 시 처리 규칙

타이머 완료 알림을 받았을 때 **반드시 에이전트 완료 여부를 먼저 확인**한다:

| 에이전트 상태 | 조치 |
|---|---|
| **이미 완료됨** (완료 통보 수신했음) | **아무것도 출력하지 말고 무시한다.** 파이프라인 계속 진행. |
| **아직 실행 중** (완료 통보 없음) | 아래 에스컬레이션 단계 실행 |

> **중요**: 타이머가 완료되어도 에이전트가 이미 완료된 경우에는 어떤 메시지도 출력하지 않는다. "불필요" 같은 상태 메시지도 생략한다.

### 3단계 에스컬레이션 (에이전트가 아직 실행 중인 경우만)

| Phase | 경과 시간 | 조치 |
|---|---|---|
| **Nudge** | T+3min | `SendMessage(to: "{agent-name}", message: "계속")` + Timer 2 (`sleep 120`) |
| **Warning** | T+5min | `SendMessage(to: "{agent-name}", message: "현재 작업을 계속 진행하세요.")` + Timer 3 (`sleep 120`) |
| **Escalate** | T+7min | 사용자에게 `"⚠️ Hard freeze 의심: {agent-name} 7분 무응답. Ctrl+C로 세션 종료 후 재시도하세요."` 출력 |

### Heartbeat 주입

모든 서브에이전트 프롬프트 **끝에** 아래를 추가한다:

```
--- Watchdog Heartbeat ---
매 5개 도구 호출(Read/Write/Edit/Bash/Grep 등)마다 아래 형식으로 진행 상태를 텍스트 출력하라:
  "--- checkpoint {N} | {현재 작업 요약} ---"
이것은 Stall Detection 모니터링용이다. 생략하지 마라.
```

### 에이전트별 Phase 1 타이머

| 에이전트 | Phase 1 (Nudge) |
|---|---|
| Planner (Opus) | `sleep 180` (3min) |
| Generator (Sonnet) | `sleep 240` (4min) |
| Generator (Opus/Ultra) | `sleep 300` (5min) |
| Evaluator | `sleep 180` (3min) |
| Final Reviewer | `sleep 180` (3min) |

> Codex 슬래시 명령(`/codex:*`)은 Watchdog 대상이 아니다 (별도 타임아웃 내장).

### Freeze 후 복구

- **Soft stall** (Nudge 후 재개): 정상 진행. 완료 보고에 `"Watchdog: soft stall recovered"` 기록
- **Hard freeze** (Escalate 도달): 새 세션에서 재실행. 기존 산출물(SPEC.md, output/) 재활용하여 freeze된 단계부터 재개

---

## 2단계: 하네스 실행

결정된 타입에 따라 아래 파이프라인을 실행합니다.
**각 에이전트는 반드시 독립된 서브에이전트(Agent 도구)로 호출하며, Watchdog 패턴(name + run_in_background + timer)을 적용합니다.**

---

### UI 하네스 파이프라인

**프로젝트 루트**: `${CLAUDE_PROJECT_DIR}`

#### ① Planner 서브에이전트 호출

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/planner.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/evaluation_criteria.md

프로젝트 컨텍스트 파악:
- ${CLAUDE_PROJECT_DIR}/web/src/components/ 구조 파악
- ${CLAUDE_PROJECT_DIR}/web/src/graphql/ 기존 쿼리 확인

사용자 요청: [요청 내용]

결과를 ${CLAUDE_PROJECT_DIR}/.harness/ui/SPEC.md 로 저장하라.
```

#### ①.5 Codex Plan Deep Review (ultra 모드 전용)

> **ultra 모드에서만 실행.** `--no-codex` 지정 시 스킵 ("Plan Deep Review: skipped" 기록 후 진행).

Planner가 SPEC.md를 저장한 직후, Codex가 설계 단계 갭을 검토하고 SPEC에 반영합니다.

`/codex:rescue` 서브에이전트를 호출하되, 아래 프롬프트를 전달합니다:

```
Read ${CLAUDE_PROJECT_DIR}/.harness/ui/SPEC.md

이 UI 컴포넌트 설계 명세를 검토하고 다음 항목의 갭을 찾아라:
1. 접근성(a11y) — WCAG 2.1 AA 기준 누락 항목 (aria-label, keyboard nav, focus trap 등)
2. 테스트 가능성 — data-testid/aria-role 누락, KeepAlive 필요 여부
3. SPA 상태 보존 — useFormDraftStore/URL searchParams/KeepAlive 적용 누락
4. 엣지 케이스 — 로딩/에러/빈 상태 처리 누락

결과를 ${CLAUDE_PROJECT_DIR}/.harness/ui/SPEC.md 파일 끝에
## Codex Plan Review
섹션으로 추가하라. 기존 내용은 수정하지 마라.
```

Codex 호출 실패 시 하네스를 차단하지 않음 — "Plan Deep Review: skipped" 기록 후 ② 진행.

#### ② Generator 서브에이전트 호출 (최초)

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/generator.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/SPEC.md

프로젝트 컨텍스트:
- ${CLAUDE_PROJECT_DIR}/web/src/components/ui/ 의 shadcn 컴포넌트 목록 확인
- ${CLAUDE_PROJECT_DIR}/web/src/store/ 스토어 구조 확인

전체 기능을 구현하고 결과를 ${CLAUDE_PROJECT_DIR}/.harness/ui/output/ 에 저장하라.
완료 후 ${CLAUDE_PROJECT_DIR}/.harness/ui/SELF_CHECK.md 를 작성하라.
```

#### ③ Evaluator 서브에이전트 호출

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/evaluator.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/SPEC.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/output/ 의 모든 파일

검수 후 결과를 ${CLAUDE_PROJECT_DIR}/.harness/ui/QA_REPORT.md 로 저장하라.
```

#### ② Generator 피드백 반영 (2회차 이상)

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/generator.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/SPEC.md
- ${CLAUDE_PROJECT_DIR}/.harness/ui/output/ 의 현재 파일들 (현재 코드)
- ${CLAUDE_PROJECT_DIR}/.harness/ui/QA_REPORT.md (QA 피드백)

QA 피드백의 "구체적 개선 지시"를 모두 반영하여 output/ 파일을 수정하라.
"방향 판단"이 "완전히 다른 접근 시도"이면 컴포넌트 구조 자체를 재설계하라.
수정 후 SELF_CHECK.md를 업데이트하라.
```

---

### Feature 하네스 파이프라인

**프로젝트 루트**: `${CLAUDE_PROJECT_DIR}`

#### ① Planner 서브에이전트 호출

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/planner.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/evaluation_criteria.md

프로젝트 컨텍스트 파악:
- ${CLAUDE_PROJECT_DIR}/internal/domain/ 기존 엔티티 구조
- ${CLAUDE_PROJECT_DIR}/internal/api/graphql/schema/ 기존 스키마
- ${CLAUDE_PROJECT_DIR}/go.mod 의존성 확인

사용자 요청: [요청 내용]

결과를 ${CLAUDE_PROJECT_DIR}/.harness/feature/SPEC.md 로 저장하라.
```

#### ①.5 Codex Plan Deep Review (ultra 모드 전용)

> **ultra 모드에서만 실행.** `--no-codex` 지정 시 스킵 ("Plan Deep Review: skipped" 기록 후 진행).

Planner가 SPEC.md를 저장한 직후, Codex가 설계 단계 보안/테스트 갭을 검토하고 SPEC에 반영합니다.

`/codex:rescue` 서브에이전트를 호출하되, 아래 프롬프트를 전달합니다:

```
Read ${CLAUDE_PROJECT_DIR}/.harness/feature/SPEC.md

이 백엔드 기능 설계 명세를 검토하고 다음 항목의 갭을 찾아라:
1. 보안 위협 (OWASP Top 10) — SQL Injection, JWT 탈취, IDOR, 권한 우회 누락 항목
2. 인증/인가 — role-based access (SUPER_ADMIN~AGENT) 적용 누락, API Key 검증
3. 테스트 전략 — 단위/통합/E2E 커버리지 갭, 누락된 happy path/error path
4. 엣지 케이스 — 동시성(race condition), 트랜잭션 롤백, 빈 결과 처리
5. GraphQL 보안 — N+1 쿼리, 과도한 깊이/복잡도 제한 누락

결과를 ${CLAUDE_PROJECT_DIR}/.harness/feature/SPEC.md 파일 끝에
## Codex Plan Review
섹션으로 추가하라. 기존 내용은 수정하지 마라.
각 갭 항목은 Generator가 구현 시 반드시 반영해야 할 **보강 지시** 형태로 기술하라.
```

Codex 호출 실패 시 하네스를 차단하지 않음 — "Plan Deep Review: skipped" 기록 후 ② 진행.

#### ② Generator 서브에이전트 호출 (최초)

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/generator.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/SPEC.md

프로젝트 컨텍스트:
- ${CLAUDE_PROJECT_DIR}/internal/domain/ 기존 패턴 참조
- ${CLAUDE_PROJECT_DIR}/internal/repository/ sqlc 패턴 참조
- ${CLAUDE_PROJECT_DIR}/internal/api/graphql/ resolver 패턴 참조
- ${CLAUDE_PROJECT_DIR}/web/src/components/ 컴포넌트 패턴 참조

전체 기능을 구현하고 결과를 ${CLAUDE_PROJECT_DIR}/.harness/feature/output/ 에 저장하라.
완료 후 ${CLAUDE_PROJECT_DIR}/.harness/feature/SELF_CHECK.md 를 작성하라.
```

#### ③ Evaluator 서브에이전트 호출

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/evaluator.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/SPEC.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/output/ 의 모든 파일

검수 후 결과를 ${CLAUDE_PROJECT_DIR}/.harness/feature/QA_REPORT.md 로 저장하라.
```

#### ② Generator 피드백 반영 (2회차 이상)

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/generator.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/SPEC.md
- ${CLAUDE_PROJECT_DIR}/.harness/feature/output/ 의 현재 파일들 (현재 코드)
- ${CLAUDE_PROJECT_DIR}/.harness/feature/QA_REPORT.md (QA 피드백)

QA 피드백의 "구체적 개선 지시"를 모두 반영하여 output/ 파일을 수정하라.
아키텍처 위반은 타협 없이 수정하라.
수정 후 SELF_CHECK.md를 업데이트하라.
```

---

### QA 전수 테스트 하네스 파이프라인

**프로젝트 루트**: `${CLAUDE_PROJECT_DIR}`

#### ① Analyzer 서브에이전트 호출 (model: opus)

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/analyzer.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/evaluation_criteria.md

프로젝트 루트: ${CLAUDE_PROJECT_DIR}

스코프: [full / module:xxx / layer:xxx / frontend / e2e]

분석 결과를 ${CLAUDE_PROJECT_DIR}/.harness/qa/COVERAGE_REPORT.md 로 저장하라.
```

**analyze 모드일 때**: 여기서 종료, COVERAGE_REPORT.md를 사용자에게 요약 보고.

#### ② Test Generator 서브에이전트 호출

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/generator.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/COVERAGE_REPORT.md

프로젝트 컨텍스트:
- ${CLAUDE_PROJECT_DIR}/internal/repository/sqlite/ 의 testhelper 패턴 참조
- ${CLAUDE_PROJECT_DIR}/internal/modules/release/tests/ 의 mock 패턴 참조
- ${CLAUDE_PROJECT_DIR}/web/src/hooks/ 의 FE 테스트 패턴 참조

COVERAGE_REPORT.md의 P0~P2 갭에 대해 테스트를 프로젝트 소스 트리에 직접 생성하라.
완료 후 ${CLAUDE_PROJECT_DIR}/.harness/qa/SELF_CHECK.md 를 작성하라.
```

**배치 분할 (갭 10개+ 시)**: P0 → P1 → P2 순서로 Generator를 배치 호출.

#### ②.5 Build Gate (자동)

```bash
cd ${CLAUDE_PROJECT_DIR}
go build ./... && go test ./... -count=1
```

빌드/테스트 실패 시 Generator에게 에러 로그와 함께 반환.

#### ③ Validator 서브에이전트 호출

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/validator.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/COVERAGE_REPORT.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/SELF_CHECK.md

생성된 테스트 파일들을 모두 읽고 검수하라.

결과를 ${CLAUDE_PROJECT_DIR}/.harness/qa/QA_REPORT.md 로 저장하라.
```

#### ② Generator 피드백 반영 (2회차 이상)

```
다음 파일들을 읽고 지시를 따라라:
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/generator.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/agents/evaluation_criteria.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/COVERAGE_REPORT.md
- ${CLAUDE_PROJECT_DIR}/.harness/qa/QA_REPORT.md (QA 피드백)

QA 피드백의 "구체적 개선 지시"를 모두 반영하여 테스트를 수정하라.
기존 테스트를 삭제하지 마라. 추가/수정만 허용.
수정 후 SELF_CHECK.md를 업데이트하라.
```

---

## 3단계: 판정 루프

각 Evaluator 호출 후 QA_REPORT.md를 읽어 판정을 확인합니다:

- **합격** → ④.5 Refactor → **④.7 Post-Refactor Verification** → ⑤ Final Review 또는 완료 보고
- **조건부/불합격** → Generator 피드백 반영 후 Evaluator 재호출
- **3회 반복 후 불합격** → 현재 상태 보고 + 미해결 이슈 목록 제공

### ④.7 Post-Refactor Verification Gate (Standard 이상)

> Refactor 패스 완료 후, Final Review 또는 완료 보고 **전에** 반드시 통과해야 하는 품질 게이트.
> Build Gate(②.5)가 "빌드되는가"를 검증한다면, 이 게이트는 "품질 기준을 충족하는가"를 검증한다.

#### Backend 검증 (Feature 하네스 — output/internal/ 파일 존재 시)

오케스트레이터가 Bash로 **순차 실행**:

```bash
cd ${CLAUDE_PROJECT_DIR}

# 1. TDD 기반 테스트 (race condition 포함)
go test ./... -race -count=1

# 2. 정적 분석 (golangci-lint)
golangci-lint run ./...

# 3. Go 취약점 체크
govulncheck ./...
```

**판정:**
- 3개 모두 PASS → Frontend 검증으로 진행 (또는 Backend-only면 ⑤로)
- `go test` 실패 → Generator에게 실패 로그 전달, 단계 ② 재실행
- `golangci-lint` critical/error → Generator에게 피드백 전달, 단계 ② 재실행
- `golangci-lint` warning만 → 정보성 기록, 진행
- `govulncheck` 취약점 발견 → 의존성/코드 수정 필요 시 Generator에게 전달, 단계 ② 재실행

#### Frontend 검증 (UI/Feature 하네스 — output/web/ 파일 존재 시)

오케스트레이터가 **`/harness:uiux` 스킬을 호출**하여 UI 품질을 검증:

```
/harness:uiux --target .harness/[ui|feature]/output/web/ --mode quick
```

검증 항목:
1. **접근성 (a11y)** — WCAG 2.1 AA 준수 (aria-label, keyboard nav, focus trap)
2. **Core Web Vitals** — LCP, FID, CLS 기준값
3. **시각적 회귀** — 스크린샷 비교 (기준 이미지 존재 시)
4. **반응형** — 모바일/태블릿/데스크톱 뷰포트
5. **i18n** — ko/en 번역 키 누락 확인

**판정:**
- 전체 PASS → ⑤ Final Review 또는 완료 보고로 진행
- a11y critical 위반 → Generator에게 피드백 전달, 단계 ② 재실행
- CWV 경고, i18n 누락 등 non-critical → 정보성 기록, 진행
- `/harness:uiux` 실행 실패 → "UI Verification: skipped" 기록, 진행 (차단 안 함)

---

## 완료 보고 형식

```
## 하네스 실행 완료

**타입**: [UI / Feature]
**결과물 경로**: .harness/[ui|feature]/output/
**Planner 설계 기능 수**: X개
**QA 반복 횟수**: X회

**최종 점수**:
- [UI: Phoenix UI X/10, 코드 품질 X/10, 기술 완성도 X/10, 기능성 X/10]
- [Feature: Clean Arch X/10, 코드 품질 X/10, 기술 완성도 X/10, 보안/테스트 X/10]
**가중 점수**: X.X / 10.0

**Codex Integration**: [enabled / unavailable ({이유})]
**Codex Plan Deep Review**: [merged X items / skipped] (Ultra 모드 전용)
**Codex Quick Review**: [approve / needs-attention / skipped]
**Codex Adversarial**: [approve / needs-attention / skipped] (Pro/Ultra feature만)
**Codex Rescue**: [used R{N} → {success/failed} / not needed / skipped]
**Watchdog**: [no stall / soft stall recovered at {단계} Phase {N} (T+{N}min) / hard freeze at {단계}, session restarted]
**Post-Refactor Verification**:
  - Backend: go test [PASS/FAIL], golangci-lint [PASS/X warnings/X errors], govulncheck [PASS/X vulns]
  - Frontend: /harness:uiux [PASS/a11y X critical/CWV warning/skipped]

**실행 흐름**:
1. Planner: [설계 내용 한 줄]
1.5. Codex Plan Deep Review: [보강 항목 수 + 핵심 갭] (Ultra 모드)
2. Generator R1: [구현 결과 한 줄]
3. Evaluator R1: [판정 + 핵심 피드백]
4. Generator R2: [수정 내용] (해당 시)
5. Codex Rescue: [사용 여부] (R3+ 교착 시)
6. Final Reviewer ∥ Codex Adversarial: [병합 판정] (Pro 모드)
...

**다음 단계**:
[UI] output/ → web/src/components/[layer]/ 복사 후 import 연결
[Feature] output/ 복사 → go-task generate → go test ./... → go-task build
[QA] go test ./... -race → 잔여 P2/P3 갭은 다음 Sprint 처리
```

### QA 전수 테스트 완료 보고 형식

```
## QA 전수 테스트 하네스 실행 완료

**스코프**: [full / module:xxx / ...]
**모드**: [analyze / standard / sweep]
**QA 반복 횟수**: X회

**커버리지 변화**:
| 레이어 | 이전 | 이후 | 변화 |
|---|---|---|---|
| Go 전체 | X% | Y% | +Z% |

**생성된 테스트**:
- Go 테스트 파일: X개 (Y개 테스트 함수)
- FE 테스트 파일: X개
- E2E 시나리오: X개

**갭 해소율**: P0 X/Y, P1 X/Y, P2 X/Y
**최종 점수**: X.X / 10.0
```

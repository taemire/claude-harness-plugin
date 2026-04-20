---
name: uiux
description: UI/UX 테스트 하네스 실행 — 정적 UI primitive inventory → 행렬 전개 → Playwright outcome probe 자동 생성 → 실행 → 갭 분석 → 카탈로그 피드백(6단계 PDCA) + 페르소나·a11y·CWV·visual·반응형·i18n 횡단 검사. 100% UI 커버리지 품질 게이트 의무 준수.
argument-hint: "[run|scan|inventory|matrix|probe-gen|execute|gap|feedback|plan|check|report|full|setup] [--feature=document-drive] [--persona=admin|engineer|partner|customer] [--module=issues|wiki|...] [--checks=a11y,perf,visual,responsive,i18n] [--coverage-gate=green|amber|off]"
trigger-patterns:
  - "UI 테스트"
  - "ui 테스트"
  - "UI테스트"
  - "웹 테스트"
  - "프론트엔드 테스트"
  - "FE 테스트"
  - "E2E 테스트"
  - "e2e 테스트"
  - "접근성 테스트"
  - "a11y 테스트"
  - "성능 테스트"
  - "CWV 테스트"
  - "시각적 회귀"
  - "visual regression"
  - "반응형 테스트"
  - "i18n 테스트"
  - "페르소나 테스트"
  - "하네스 실행"
  - "PDCA 사이클"
  - "UI/UX 검증"
  - "화면 테스트"
  - "브라우저 테스트"
  - "playwright 테스트"
  - "Playwright 테스트"
  - "uiux harness"
  - "UIUX 하네스"
  - "UI 인벤토리"
  - "UI 커버리지"
  - "UI coverage"
  - "dead UI"
  - "outcome probe"
---

# UI/UX 테스트 하네스 v2 (Inventory-Driven Coverage)

현재 프로젝트의 프론트엔드를 검증하는 통합 하네스. **구현된 모든 UI 구성 요소(체크박스·풀다운·팝업메뉴·토스트·다이얼로그·폼·링크·DnD·키보드)의 runtime 동작을 증명**하는 것이 임무이며, 목표 커버리지는 **100%**다.

> **필수 참조**: `docs/specs/UI_COVERAGE_QUALITY_GATE.md` (QG-UI-COVERAGE-001) — 100% UI 커버리지 헌장·임계값·PR 체크리스트·금지 사항 5건이 담긴 SSOT. 본 스킬은 그 문서의 **집행 도구**다.

핵심 산출물:
- `web/e2e/.harness/catalog/ui-primitives.json` — UI primitive 분류 + 행동 축 SSOT
- `web/e2e/.harness/inventory/<feature>.json` — 정적 스캔 결과
- `web/e2e/.harness/matrix/<feature>.json` — primitive × 상태 × 이벤트 × outcome 직교곱
- `web/e2e/.harness/scenarios/` — 자동 생성 또는 수제작 시나리오
- `web/e2e/.harness/reports/ui-coverage.md` — 커버리지 리포트 (Green/Amber/Red)

---

## 🎯 임무 (Charter)

1. **정적 UI 구성 요소 분석이 시작점이다.** assertion을 먼저 쓰지 말고, 구현된 요소를 먼저 전수 수집한다.
2. **모든 UI 요소(button, checkbox, dropdown, context-menu, toast, dialog, form, link, DnD 등)는 테스트 대상이다.** 가시성만 검증하는 테스트는 커버리지에 산입되지 않는다.
3. **outcome이 assertion의 단위다.** click / keyboard / dismiss 각각에 대해 (navigation | graphql-mutation | dialog-open | toast | state-change | focus-move | download | clipboard-write | url-searchparam | no-op-expected) 중 하나 이상을 runtime에서 증명한다.
4. **100% 커버리지까지는 PR 머지를 금지한다** (기본 Red 임계값 `UI_Coverage < 80%`). 초기 적용 시 Amber 80~95%로 단계적 전환 허용.

---

## 📋 Quality Gate 요약 (UI_COVERAGE_QUALITY_GATE.md §2)

| 레벨 | 기준 | 집행 |
|:---|:---|:---|
| Red | `UI_Coverage < 80%` OR Dead UI 1건+ | PR merge 차단 |
| Amber | `80% ≤ UI_Coverage < 95%` | 경고 + 후속 등록 |
| Green | `≥ 95%` + Dead UI 0 + a11y critical 0 | 통과 |
| Gold | `= 100%` + 횡단 5/5 | 릴리즈 태깅 자격 |

---

## 🔁 6단계 PDCA 워크플로우

```
[① Inventory] → [② Matrix] → [③ Probe-Gen] → [④ Execute] → [⑤ Gap] → [⑥ Catalog Feedback]
     ↑                                                                       │
     └──────────────────── 다음 사이클로 환류 ────────────────────────────┘
```

| 단계 | 커맨드 | 산출물 |
|:---|:---|:---|
| ① Inventory | `/harness:uiux inventory --feature=<name>` | `inventory/<name>.json` |
| ② Matrix | `/harness:uiux matrix --feature=<name>` | `matrix/<name>.json` |
| ③ Probe-Gen | `/harness:uiux probe-gen --feature=<name>` | `scenarios/auto/<name>-*.scenario.ts` |
| ④ Execute | `/harness:uiux execute` | `reports/harness-results.json` |
| ⑤ Gap | `/harness:uiux gap --feature=<name>` | `reports/ui-coverage.md` |
| ⑥ Feedback | `/harness:uiux feedback` | `catalog/ui-primitives.json` 갱신 |

통합 실행: `/harness:uiux scan --feature=<name>` (① → ⑥ 순차)

---

## 실행 형식

```
/harness:uiux scan --feature=document-drive    ← [권장] 6단계 전체 실행
/harness:uiux inventory --feature=X            ← ① 정적 스캔만
/harness:uiux matrix --feature=X               ← ② 행렬 전개만
/harness:uiux probe-gen --feature=X            ← ③ 시나리오 자동 생성만
/harness:uiux execute                          ← ④ 수제작+자동 시나리오 실행
/harness:uiux gap --feature=X                  ← ⑤ 갭/커버리지 분석만
/harness:uiux feedback                         ← ⑥ 카탈로그 피드백 반영

# 기존 명령 (legacy 호환)
/harness:uiux run                              ← ④와 동일
/harness:uiux run --persona=engineer
/harness:uiux plan                             ← NotebookLM 시나리오 강화
/harness:uiux check                            ← 횡단 검사(a11y+perf+visual+resp+i18n)만
/harness:uiux report                           ← 리포트만 재생성
/harness:uiux full                             ← PDCA 전체 + `--gh-issues` 가능
/harness:uiux setup                            ← NotebookLM 노트북 초기화
```

---

## 🏁 명령별 동작

사용자가 `/harness:uiux`를 호출하면 **아래 단계를 순서대로** 실행하라.

### 🆕 `scan` (권장, 6단계 통합) — `--feature=<name>` 필수

1. 프로젝트 루트 확인: `${CLAUDE_PROJECT_DIR}`
2. 서버/배포 대상 확인:
   - 로컬: `curl -sf http://localhost:8090/api/health > /dev/null`
   - 배포: `HARNESS_BASE_URL=https://your-app.example.com` 지정 시 원격 대상
3. 카탈로그 존재 확인: `web/e2e/.harness/catalog/ui-primitives.json`
4. **① Inventory**:
   ```bash
   cd web && npx tsx e2e/.harness/scripts/inventory-ui.ts \
     --feature=<name> --out=e2e/.harness/inventory/<name>.json
   ```
   결과 검증: `summary` 카운트 · `deadSuspects` 목록 즉시 출력
5. **② Matrix**:
   ```bash
   cd web && npx tsx e2e/.harness/scripts/generate-matrix.ts \
     --inventory=e2e/.harness/inventory/<name>.json \
     --out=e2e/.harness/matrix/<name>.json
   ```
6. **③ Probe-Gen**:
   ```bash
   cd web && npx tsx e2e/.harness/scripts/generate-probes.ts \
     --matrix=e2e/.harness/matrix/<name>.json \
     --out-dir=e2e/.harness/scenarios/auto
   ```
7. **④ Execute**:
   ```bash
   cd web && npx playwright test --config=e2e/.harness/playwright.harness.config.ts
   ```
8. **⑤ Gap**:
   ```bash
   cd web && npx tsx e2e/.harness/scripts/gap-analysis.ts \
     --inventory=e2e/.harness/inventory/<name>.json \
     --results=e2e/.harness/reports/harness-results.json \
     --out=e2e/.harness/reports/ui-coverage.md
   ```
9. **⑥ Feedback**: 새로 발견된 primitive 패턴·dead UI 휴리스틱을 카탈로그에 제안 (인간 리뷰 후 커밋)
10. 사용자에게 요약 보고 (아래 §리포트 포맷)

### `inventory` (① 단독)

대상 feature의 모든 `.ts`/`.tsx`를 스캔해 UI primitive 인스턴스를 수집. 각 hit는 `file:line + data-testid + 의심 dead UI 시그널`을 포함.

- 입력: `--feature=<name>` (예: `document-drive`)
- 출력: `web/e2e/.harness/inventory/<name>.json`
- 주 관심: `summary`(primitive별 개수), `deadSuspects`(placeholder/window-prompt 등)

### `matrix` (② 단독)

Inventory × 카탈로그로 직교곱 전개:
- primitive × states × interactions × outcomeCategory × persona → 검증 케이스 행렬
- 가중치(§UI_COVERAGE_QUALITY_GATE §2.2) 적용 우선순위 산정

### `probe-gen` (③ 단독)

Matrix 엔트리마다 Playwright 템플릿 시나리오를 emit:
- `outcomeCategory` 가 `navigation` 이면 URL assertion
- `graphql-mutation` 이면 `page.waitForRequest(/graphql/)` 대기
- `dialog-open` 이면 `getByRole('dialog').toBeVisible()`
- `toast` 이면 `[data-sonner-toast]` 또는 `role=status/alert` 텍스트 매치
- `no-op-expected` 는 명시 의도 — assertion 없이 통과 허용 (드문 케이스, 리뷰 필수)

생성된 파일은 `scenarios/auto/<feature>-<primitive>-<id>.scenario.ts` 패턴으로 저장. 수제 시나리오는 `scenarios/engineer/` 등 페르소나 폴더에 유지.

### `execute` (④)

기존 `run` 과 동일하나 자동 생성 시나리오를 포함. `--persona=XXX`로 필터링 가능.

### `gap` (⑤)

`inventory.json` 에 있지만 scenario 실행 기록이 없는 primitive를 "미커버"로 분류. outcome-없는-assertion-only 시나리오는 "formal but weak" 로 경고. dead UI runtime 확정 항목은 상단 보고.

출력: `reports/ui-coverage.md` (§UI_COVERAGE_QUALITY_GATE §7 포맷 준수)

판정:
- coverage ≥ 95 + deadUI = 0 → Green
- 80 ≤ coverage < 95 → Amber
- < 80 또는 deadUI ≥ 1 → Red (에러 exit code 1 → CI 차단)

### `feedback` (⑥)

실행 사이클 동안 수집한 신규 primitive·신규 dead UI 패턴·신규 outcome 축을 카탈로그 draft PR로 준비. 승인 후 `ui-primitives.json` 버전 bump.

### `plan` / `check` / `report` / `full` / `setup`

v1과 동일(상위 섹션). `full`은 6단계 PDCA + NotebookLM 강화 + GitHub 이슈 자동 생성을 포함한다.

---

## 📤 리포트 포맷 (필수)

실행 후 사용자에게 반드시 아래 구조로 보고:

```
## UI/UX 하네스 실행 결과 (v2 Inventory-Driven)

**대상**: feature=<name>  |  **배포**: vX.Y.Z.NNN  |  **사이클**: #N

### 커버리지
| 지표 | 값 | 게이트 |
|---|---|---|
| UI_Coverage | XX.X % | Green/Amber/Red |
| Inventory 총 hits | N |  |
| 테스트된 primitive | N |  |
| Dead UI 확정 | N |  |
| Dead UI 의심 | N |  |
| a11y critical | N | 0 필수 |

### Primitive별 커버리지
| primitive | inv | tested | % | 미커버 위치 |
|---|---|---|---|---|
| button | a | b | c% | file:line |
| checkbox | ... | ... | ... | ... |
| ... | | | | |

### Outcome 축별 통과율
- navigation: a/b
- graphql-mutation: a/b
- dialog-open: a/b
- toast: a/b
- state-change: a/b
- focus-move: a/b

### Dead UI (runtime 확정)
- [위치] 증상 → 권장 조치

### 개선 권고 (P0→P3)
1. [P0] ...

### 이전 사이클 대비
| 지표 | 이전 | 현재 | Δ |
|---|---|---|---|
```

---

## ⛔ 금지 사항 (QG-UI-COVERAGE-001 §5 정합)

| # | 금지 | 사유 |
|:--|:---|:---|
| QG-01 | `toBeVisible()`만 있는 시나리오를 커버리지로 인정 | outcome 미검증 |
| QG-02 | placeholder 핸들러(`onClick={() => onClose()}`) 프로덕션 머지 | dead UI 생성 |
| QG-03 | `window.prompt/confirm/alert` 신규 사용 | Playwright dismiss + deprecated |
| QG-04 | 카탈로그 미등재 primitive 도입 | 커버리지 계산 불가 |
| QG-05 | 근거 없는 `exemptions` 등재 | 게이트 무력화 |

---

## 주의사항

- 서버가 실행 중이어야 E2E 테스트 가능 (localhost:8090 또는 `HARNESS_BASE_URL` 로 원격)
- NotebookLM(`nlm`) 미설치 시 `feedback`는 graceful skip
- 첫 실행 시 visual baseline 자동 생성 (비교 없음)
- axe-core 미설치 시: `cd web && npm i -D @axe-core/playwright`
- `generate-matrix.ts` / `generate-probes.ts` / `gap-analysis.ts` 는 `inventory-ui.ts` 와 동일한 스크립트 디렉토리에 위치하며, 신규 도입 시 본 스킬 문서와 `UI_COVERAGE_QUALITY_GATE.md` 를 함께 업데이트

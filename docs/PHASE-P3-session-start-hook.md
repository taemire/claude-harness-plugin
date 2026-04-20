# PHASE-P3 — SessionStart hook (L2 Agent Replace + L3 호환성 게이트)

> **참조 SSOT**: [PLAN-v1.0.md §3.2 L2 Agent Replace](./PLAN-v1.0.md#32-l2--agent-replace-레이어) · [§3.3 L3 호환성 게이트](./PLAN-v1.0.md#33-l3--버전-호환성-게이트) · [§5 P3](./PLAN-v1.0.md#p3--sessionstart-hook-구현)
> **릴리즈 대상**: v0.4.0
> **선행 phase**: P1 (userConfig 스키마 — v0.3.0 완료), P2 (SKILL 치환점 — v0.3.0 완료)
> **후행 phase**: P4 (Starter templates, v0.5.0~v0.6.0 이관 가능)

---

## 0. Executive Summary

플러그인 세션 시작 시 실행되는 `hooks/session-start.sh` 를 도입하여 두 가지 역할을 수행한다.

1. **L2 link-farm 구성** — 프로젝트의 `.harness/overrides/agents/*.md` 를 `.claude/agents/` 로 심볼릭 링크. Claude Code subagent 우선순위 3(.claude/agents) > 5(plugin agents) 에 의해 plugin base agent 가 프로젝트 override 로 완전 대체된다.
2. **L3 semver 호환성 검사** — `override-manifest.json.compatible_base_version` 과 `plugin.json.version` 을 비교해 불일치 시 경고 stdout. 블로킹하지 않음.

## 1. Scope

**In Scope**:
- `hooks/session-start.sh` 신규 작성 (~100-150 줄)
- `plugin.json` 에 `hooks.SessionStart` 필드 추가
- `docs/schemas/override-manifest.schema.json` JSON Schema 정의
- macOS + Linux bash 4+ 기본 지원 (Windows 는 fallback 만)
- fail-open 원칙 준수 — override 파일 없어도 세션 정상 시작

**Out of Scope** (이후 phase):
- Starter template 배포 (P4)
- Validator skill (override 파일 문법 검증, v0.7+ 예정)
- `.harness/overrides/skills/` 지원 — skill override 는 Issue #25209 미해결이므로 보류
- Windows native PowerShell hook (bash WSL/Git Bash 만 지원)

## 2. 디자인

### 2.1 hook 등록 (plugin.json)

```json
{
  "hooks": {
    "SessionStart": "hooks/session-start.sh"
  }
}
```

Claude Code 가 세션 시작 시 이 스크립트를 실행한다. stdout 은 Claude 컨텍스트에 주입되고, exit code 는 무시된다 (fail-open 확정).

### 2.2 실행 환경

hook 실행 시 사용 가능한 환경 변수:

| 변수 | 의미 |
|:--|:--|
| `CLAUDE_PROJECT_DIR` | 세션의 프로젝트 루트 절대 경로 |
| `CLAUDE_PLUGIN_ROOT` | 플러그인 설치 경로 (이 리포지토리의 절대 경로) |
| `CLAUDE_PLUGIN_DATA` | 플러그인 persistent data 디렉토리 |
| `CLAUDE_SESSION_ID` | 현재 세션 ID |

### 2.3 실행 흐름

```
[1] 환경 검사
    ├─ CLAUDE_PROJECT_DIR 없으면 fail-open 종료 (정상 0)
    └─ OVERRIDES_DIR=${CLAUDE_PROJECT_DIR}/.harness/overrides 변수 설정

[2] override-manifest.json semver 검사 (L3)
    ├─ 파일 없으면 skip (경고 없음)
    ├─ compatible_base_version 읽기
    ├─ plugin.json version 읽기 (CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json)
    └─ semver 불일치 시 경고 stdout

[3] agents/ link-farm (L2)
    ├─ OVERRIDES_DIR/agents/ 디렉토리 없으면 skip
    ├─ TARGET=${CLAUDE_PROJECT_DIR}/.claude/agents 생성 (mkdir -p)
    ├─ OVERRIDES_DIR/agents/*.md 각각에 대해
    │   └─ ln -sf <절대경로> TARGET/<basename>
    │       fail 시 cp <절대경로> TARGET/<basename> (Windows fallback)
    └─ 완료 후 카운트 로그

[4] 정상 exit 0
```

### 2.4 semver 매칭 로직

- `compatible_base_version: "~0.4"` → major+minor 일치 요구 (0.4.x 모두 허용, 0.5.0 불허)
- `compatible_base_version: "^0.4"` → major 일치 + minor 이상 (0.4.x, 0.5.0 허용, 1.0.0 불허)
- `compatible_base_version: ">=0.3 <0.5"` → 범위 표기

**bash 구현**: `node` 나 외부 semver 라이브러리에 의존하지 않는다. 간이 파서:
1. `compatible_base_version` 앞 연산자 (`~`, `^`, `>=`, `<`, 생략=정확일치) 파싱
2. plugin version 을 `MAJOR.MINOR.PATCH` 로 분해
3. 연산자별 단순 비교 (`~x.y` → major=x && minor=y, `^x.y` → major=x && minor>=y)

복잡한 semver 범위 (`>=0.3 <0.5`) 는 v0.4.0 에서 미지원 — 단순 `~`, `^`, `=` 만 지원. 향후 node 감지 시 `semver` 패키지로 위임 옵션 검토.

### 2.5 link-farm vs copy 정책

| 환경 | 방법 | 이유 |
|:--|:--|:--|
| macOS, Linux | `ln -sf` 심볼릭 링크 | 프로젝트가 override 편집 시 즉시 반영. 업데이트 불필요 |
| Windows (Git Bash) | `ln -sf` 시도 → 실패 시 `cp` | Windows symlink 권한 제약 회피 |
| 링크 대상이 이미 non-link 파일 | skip + 경고 | 사용자가 수동으로 관리하는 파일 덮어쓰지 않음 |

### 2.6 경고 포맷 (stdout)

```
[harness plugin v0.4.0] ⚠️ override compat warning
  override-manifest.json: compatible_base_version = "~0.3"
  plugin.json:            version = "0.4.0"
  → major/minor mismatch. 마이그레이션 가이드: docs/MIGRATION-v0.3-to-v0.4.md
  (경고만 — 파이프라인은 계속 진행됩니다)
```

```
[harness plugin v0.4.0] ✅ link-farm configured
  source:  /Users/.../.harness/overrides/agents/ (3 files)
  target:  /Users/.../.claude/agents/
  planner.md, evaluator.md, generator.md linked
```

## 3. override-manifest.json 스키마 (L3)

### 3.1 예시

```json
{
  "schema_version": "1.0",
  "compatible_base_version": "~0.4",
  "overrides": [
    {
      "type": "agent",
      "name": "planner",
      "reason": "도메인 평가 기준 추가"
    },
    {
      "type": "agent",
      "name": "evaluator",
      "reason": "Phoenix UI a11y 체크 강제"
    }
  ],
  "created_at": "2026-05-01",
  "last_verified_base_version": "0.4.0"
}
```

### 3.2 필드 정의

| 필드 | 타입 | 필수 | 설명 |
|:--|:--|:--|:--|
| `schema_version` | string | ✅ | override-manifest 스키마 버전. v0.4.0 기준 `"1.0"` |
| `compatible_base_version` | string | ✅ | 호환 가능한 plugin 버전 범위 (semver 연산자) |
| `overrides` | array | ⬜ (optional) | 현재 override 중인 항목 목록 (문서화 목적) |
| `overrides[].type` | string | ✅ (overrides 있을 때) | `"agent"` (v0.4 는 이 값만 지원) |
| `overrides[].name` | string | ✅ | 대상 파일 basename (확장자 제외) |
| `overrides[].reason` | string | ⬜ | 선택적 메모 |
| `created_at` | string (YYYY-MM-DD) | ⬜ | override 생성 일자 |
| `last_verified_base_version` | string | ⬜ | 마지막으로 테스트한 plugin 버전 |

### 3.3 JSON Schema

`docs/schemas/override-manifest.schema.json` 에 draft-07 JSON Schema 별도 저장. 향후 validator skill 이 로드.

## 4. 구현 체크리스트 (P3, v0.4.0)

- [ ] `hooks/session-start.sh` 신규 작성
  - [ ] shebang `#!/usr/bin/env bash`, `set -u` (fail-open 위해 `-e` 는 사용 안 함)
  - [ ] Step 1 환경 검사 + OVERRIDES_DIR 설정
  - [ ] Step 2 semver 검사 (간이 파서 `~`, `^`, `=`)
  - [ ] Step 3 link-farm (`ln -sf` + `cp` fallback)
  - [ ] Step 4 카운트 로그 + exit 0
  - [ ] `chmod +x` 권한 부여
- [ ] `.claude-plugin/plugin.json` 에 `"hooks": { "SessionStart": "hooks/session-start.sh" }` 추가
- [ ] `plugin.json` `version` 을 `0.3.0` → `0.4.0` 으로 bump
- [ ] `.claude-plugin/marketplace.json` 의 `metadata.version` + `plugins[0].version` 동기화
- [ ] `docs/schemas/override-manifest.schema.json` 작성 (draft-07)
- [ ] `CHANGELOG.md` 에 `[0.4.0] — YYYY-MM-DD` 블록 생성
- [ ] `docs/PLAN-v1.0.md` P3 체크박스 완료 마킹 + Revision Log 추가
- [ ] `README.md` 로드맵 테이블 v0.4.0 ✅ 처리

## 5. 수용 기준 (AC)

| # | 기준 | 검증 방법 |
|:-:|:--|:--|
| AC-1 | override 파일 없는 프로젝트에서 세션 시작 시 hook 무오작동 | `.harness/overrides/` 없는 프로젝트 open → stdout 에 오류/경고 없음 |
| AC-2 | override-manifest 만 존재 + agents/ 없음 → semver 만 검사 | 수동 verify |
| AC-3 | override 파일 3개 있을 때 `.claude/agents/` 에 심볼릭 링크 3개 생성 | `ls -la ${PROJECT}/.claude/agents/` 로 확인 |
| AC-4 | 재실행 멱등 — 같은 세션을 다시 열면 에러 없이 통과 | 연속 2회 세션 시작 → stdout 동일 |
| AC-5 | plugin v0.4.0 + `compatible_base_version: "~0.3"` → 경고 stdout | 수동 verify |
| AC-6 | plugin v0.4.0 + `compatible_base_version: "~0.4"` → 경고 없음 | 수동 verify |
| AC-7 | Hook 실행 시간 < 300ms (일반 프로젝트) | `time hooks/session-start.sh` 측정 |

## 6. 리스크 & 완화

| 리스크 | 영향 | 완화 |
|:--|:--|:--|
| **R-P3-01** Claude Code `SessionStart` hook event 가 실제 존재하지 않거나 다른 이름일 경우 | hook 자체가 실행되지 않음 | 릴리즈 전 Claude Code 공식 문서 hook events 리스트 재확인. 대안 hook (`UserPromptSubmit` 최초 1회) 로 폴백 설계 준비 |
| **R-P3-02** `CLAUDE_PLUGIN_ROOT` 환경변수 미제공 | plugin.json version 읽기 실패 → semver 검사 skip | fail-open 으로 처리. 경고 stdout 출력 후 link-farm 만 수행 |
| **R-P3-03** bash 4 미만 환경 (macOS 기본 bash 3.2) | 연관 배열 등 신택스 불가 | bash 3.2 호환 스크립트로 작성. 배열 대신 루프 + 변수 사용 |
| **R-P3-04** 간이 semver 파서가 사용자의 복잡한 range 표기 오해석 | false 경고 / 경고 누락 | 지원 연산자를 `~`, `^`, `=` 로 **제한** 하고 README 에 명시. 미지원 연산자는 "semver 파싱 불가" 경고로 표시 |
| **R-P3-05** `.claude/agents/` 가 프로젝트 .gitignore 에 있는 경우 | link 가 untracked 로 남음 | 문서에서 `.claude/agents/` 는 항상 git 추적 대상임을 명시 (or symlink 자체는 커밋 가능) |
| **R-P3-06** 프로젝트가 이미 `.claude/agents/planner.md` 를 non-symlink 로 가진 경우 | 덮어쓰기 충돌 | §2.5 정책대로 skip + 경고. 사용자가 의식적 정리할 때까지 유지 |

## 7. 롤백 전략

- **hook 이 오작동해서 세션 시작 실패 유발 시**: `plugin.json` 의 `hooks.SessionStart` 필드만 제거 + patch bump → override 기능 일시 비활성. link-farm 은 사용자가 수동 `ln -sf` 로 우회 가능
- **semver 검사가 잘못된 경고 유발 시**: `hooks/session-start.sh` 의 Step 2 만 주석 처리 후 patch 재출시
- **L2 전체 철회**: 이 단계는 v0.4.0 minor — breaking 이 아니므로 v0.5.0 에서 deprecation 후 제거 가능

## 8. 테스트 프로시저 (수동)

1. `mkdir -p /tmp/test-harness-proj/.harness/overrides/agents`
2. `echo '# test planner override' > /tmp/test-harness-proj/.harness/overrides/agents/planner.md`
3. `cat > /tmp/test-harness-proj/.harness/overrides/override-manifest.json <<EOF
   { "schema_version": "1.0", "compatible_base_version": "~0.4" }
   EOF`
4. `cd /tmp/test-harness-proj && claude` 세션 시작
5. 예상 stdout:
   ```
   [harness plugin v0.4.0] ✅ link-farm configured ... planner.md linked
   ```
6. `ls -la .claude/agents/planner.md` → symlink 확인
7. `compatible_base_version: "~0.3"` 으로 변경 후 재세션 → 경고 stdout

## 9. Revision Log

| 일자 | 변경 |
|:--|:--|
| 2026-04-20 | v1.0 최초 작성 — SessionStart hook 설계 + override-manifest 스키마 + AC 7 + 리스크 6 |

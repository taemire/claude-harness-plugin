# claude-harness-plugin

**범용 혼합 벤더 하네스 플러그인** for Claude Code.

`run` + `uiux` + `resume` 3개의 스킬을 `harness:` 플러그인 네임스페이스로 통합 제공한다. Claude Code 의 `plugin:skill` 콜론 문법으로 호출한다.

```
/harness:run      Planner → Codex Plan Review → Generator → Build Gate → Codex Quick Review → Evaluator ∥ Codex Adversarial → R2 Refinement → Post-Refactor Verification
/harness:uiux     UI primitive inventory → matrix → probe-gen → execute → gap → catalog feedback (6단계 PDCA, 100% 커버리지 게이트)
/harness:resume   체크포인트 기반 자동 재개 (구현 예정)
```

## 요구사항

- Claude Code v2.x (plugin subsystem 지원)
- macOS / Linux bash
- `jq` (`checkpoint_writer.sh` 사용 시)
- Codex CLI (`--codex-level=pro` 경로 사용 시, 선택)

## 설치 (로컬)

### A. 세션 단위 (개발용)

```bash
claude --plugin-dir /path/to/claude-harness-plugin
```

### B. 영구 등록 (프로젝트 또는 사용자 settings)

`.claude/settings.json` (또는 `~/.claude/settings.json`) 에 추가:

```json
{
  "extraKnownMarketplaces": {
    "harness-local": {
      "source": {
        "source": "git",
        "url": "file:///path/to/claude-harness-plugin"
      }
    }
  }
}
```

설치:

```bash
/plugin install harness@harness-local
```

## 구조

```
claude-harness-plugin/
├── .claude-plugin/
│   ├── plugin.json                ← **플러그인 매니페스트 (버전 SSOT)**
│   └── marketplace.json           ← 로컬 마켓플레이스 매니페스트
├── README.md                       ← 이 문서
├── LICENSE                         ← MIT
├── CHANGELOG.md                    ← 버전 이력
├── .gitignore
└── skills/
    ├── run/SKILL.md               ← /harness:run
    ├── uiux/SKILL.md              ← /harness:uiux
    └── resume/SKILL.md            ← /harness:resume
```

## 상태

- **v0.7.0 (2026-04-20)**: Starter templates — `templates/overrides-starter/` 5분 onboarding kit + README §커스터마이징 가이드 (P8)
- **v0.6.0 (2026-04-20)**: Multi-Session Hardening (HARNESS-MSC-001) — BL-ID 네임스페이스 격리, session registry, atomic-write, seed/restore 가드, per-session config (P7)
- **v0.5.0 (2026-04-20)**: `.harness/config.yaml` 프로젝트 SSOT 도입 — L0 config loader + 3단 cascade + SKILL env 치환 (P1 v2)
- **v0.4.4 (2026-04-20)**: commands/ flatten + 슬래시 커맨드 중복 해소
- **v0.4.3 (2026-04-20)**: `/harness:*` 슬래시 커맨드 노출 복구 (BL-307)
- **v0.4.1 (2026-04-20)**: hook 등록 공식 스펙 재배선 (hotfix)
- **v0.4.0 (2026-04-20)**: L2 Agent Replace + L3 호환성 게이트 — SessionStart hook, link-farm, semver check
- **v0.3.0 (2026-04-20)**: L1 변수 주입 레이어 — userConfig 4키 + SKILL.md 치환점
- **v0.2.0 (2026-04-20)**: `.harness/` 경로 통일 (BL-305) + plugin.json SSOT 확정 + marketplace.json 번들링
- **v0.1.0 (2026-04-19)**: 초기 스켈레톤 + 기존 2개 스킬 이전 + `resume` stub

## 버전 SSOT 규칙

- `.claude-plugin/plugin.json` 의 `version` 필드가 **유일한 SSOT** 이다 (Claude Code plugin spec 가 이 값을 읽는다)
- `.claude-plugin/marketplace.json` 의 `metadata.version` 과 `plugins[0].version` 은 `plugin.json` 값을 따라 수동 동기화한다
- 버전 bump 시 세 필드를 반드시 함께 갱신한다

## 로드맵

> **상세 플랜**: [docs/PLAN-v1.0.md](./docs/PLAN-v1.0.md) — 3-레이어 아키텍처 (userConfig 주입 · Agent Replace · 호환성 게이트) + v0.3~v1.0 릴리즈 로드맵 + 7 리스크 + 6 품질 게이트

| 버전 | 내용 |
|:--|:--|
| **v0.1.x** (완료) | 스켈레톤, run/uiux 이전, resume stub |
| **v0.2.x** (완료) | `.harness/` 경로 통일, plugin.json SSOT 확정, marketplace 번들링 |
| **v0.3.x** (완료) | L1 변수 주입 레이어 — userConfig 4키 + SKILL.md 치환점 |
| **v0.4.x** (완료) | L2 Agent Replace + L3 호환성 게이트 — SessionStart hook + link-farm + semver check + commands/ 슬래시 커맨드 |
| **v0.5.x** (완료) | P1 v2 — `.harness/config.yaml` 프로젝트 SSOT + L0 config loader + 3단 cascade |
| **v0.6.x** (완료) | P7 Multi-Session Hardening — BL-ID namespace + session registry + atomic-write + seed guard + per-session config |
| **v0.7.x** (완료) | P8 Starter templates + §커스터마이징 가이드 |
| **v0.8.x** | Evaluation criteria override 전용 파이프라인 + `/harness:resume` 본체 구현 |
| **v0.9.x** | Cross-project migration tool + Telemetry opt-in (선택) |
| **v1.0.x** | API stable lock-in, Anthropic 공식 마켓플레이스 등록 검토 |

---

## 커스터마이징 가이드 (5분 onboarding)

### 빠른 시작

```bash
# 1. 플러그인 설치
/plugin marketplace add taemire/claude-harness-plugin
/plugin install harness

# 2. 프로젝트 루트에서 starter 복사
cp -r ${CLAUDE_PLUGIN_ROOT}/templates/overrides-starter .harness/overrides
cp ${CLAUDE_PLUGIN_ROOT}/templates/config.yaml.example .harness/config.yaml

# 3. .example 제거
cd .harness/overrides
mv override-manifest.json.example override-manifest.json
mv eval_criteria.md.example eval_criteria.md
mv agents/planner.md.example agents/planner.md
cd ../..

# 4. 프로젝트 값 입력 (config.yaml 의 project_name, bl_prefix 수정)
$EDITOR .harness/config.yaml

# 5. 첫 실행
/harness:run "BL-001 첫 기능"
```

### 3-레이어 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│ L0. Config Loader   (.harness/config.yaml → HARNESS_* env)  │
│     project_name · bl_prefix · eval_criteria_path · mode    │
└─────────────────────────────────────────────────────────────┘
                 ↓ SessionStart hook 이 export
┌─────────────────────────────────────────────────────────────┐
│ L2. Agent Replace   (.harness/overrides/agents/ → link-farm)│
│     planner.md · evaluator.md 등 프로젝트 도메인 override   │
└─────────────────────────────────────────────────────────────┘
                 ↓ Claude Code subagent priority (project > plugin)
┌─────────────────────────────────────────────────────────────┐
│ L3. Semver Gate     (override-manifest.json 호환성 검사)    │
│     compatible_base_version ~0.6 → 불일치 시 경고           │
└─────────────────────────────────────────────────────────────┘
```

### FAQ

**Q. `.harness/overrides/` 를 git 에 커밋해야 하나요?**
→ 예. 팀 공유 자산입니다. `.claude/agents/` (symlink) 만 gitignore 합니다.

**Q. 플러그인 버전이 bump 되면 내 override 가 깨지나요?**
→ 아니요. L3 호환성 게이트가 경고만 출력하고 파이프라인은 계속 실행됩니다 (fail-open). 마이그레이션 가이드가 있으면 경고에 경로가 표시됩니다.

**Q. 멀티 프로파일 / 멀티세션 환경에서 안전한가요?**
→ v0.6+ 부터 `.harness/active-sessions.json` + SessionStart preflight + archive-restore drift 감지를 내장합니다 (PHASE-P7 참조).

**Q. UI 커버리지/SPA 상태 보존 같은 프로젝트별 규약을 에이전트에 주입하려면?**
→ `templates/overrides-starter/agents/planner.md.example` 의 `[여기에 프로젝트 제약을 작성]` 섹션을 프로젝트 규약으로 채웁니다. Portal Hub 의 실사례는 `docs/PHASE-P7-multi-session-hardening.md` §1.1 참조.

### 상세 문서

- [templates/overrides-starter/README.md](./templates/overrides-starter/README.md) — 단계별 세부 가이드
- [docs/PLAN-v1.0.md](./docs/PLAN-v1.0.md) — 장기 아키텍처 로드맵
- [docs/PHASE-P7-multi-session-hardening.md](./docs/PHASE-P7-multi-session-hardening.md) — 멀티세션 방어 설계

## 사용 컨텍스트

- 호출 시 작업 디렉토리 (`${CLAUDE_PROJECT_DIR}`) 를 프로젝트 루트로 간주한다. 하네스 산출물은 `.harness/` (체크포인트) 및 `.harness/<type>/` (SPEC/SELF_CHECK/QA_REPORT/output) 아래에 기록된다.
- 체크포인트 엔진 의존 스크립트는 `.harness/common/` 에 위치해야 하며, 프로젝트 측에서 자체 준비한다 (`checkpoint_reader.sh`, `checkpoint_writer.sh`, `error_detector.sh`, `extract_bl_id.sh`).

## 라이선스

MIT — 자세한 내용은 [LICENSE](./LICENSE) 참조.

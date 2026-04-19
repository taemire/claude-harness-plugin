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

- **v0.2.0 (2026-04-20)**: `.harness/` 경로 통일 (BL-305) + VERSION SSOT 도입 + marketplace.json 번들링
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
| **v0.3.x** | L1 변수 주입 레이어 (`userConfig`) + L3 호환성 게이트 |
| **v0.4.x** | L2 Agent Replace 레이어 (SessionStart hook + link-farm) |
| **v0.5.x** | `/harness:resume` 본체 구현 (체크포인트 엔진) |
| **v0.6.x** | Starter templates + 커스터마이징 가이드 강화 |
| **v1.0.x** | API stable lock-in, Anthropic 공식 마켓플레이스 등록 검토 |

## 사용 컨텍스트

- 호출 시 작업 디렉토리 (`${CLAUDE_PROJECT_DIR}`) 를 프로젝트 루트로 간주한다. 하네스 산출물은 `.harness/` (체크포인트) 및 `.harness/<type>/` (SPEC/SELF_CHECK/QA_REPORT/output) 아래에 기록된다.
- 체크포인트 엔진 의존 스크립트는 `.harness/common/` 에 위치해야 하며, 프로젝트 측에서 자체 준비한다 (`checkpoint_reader.sh`, `checkpoint_writer.sh`, `error_detector.sh`, `extract_bl_id.sh`).

## 라이선스

MIT — 자세한 내용은 [LICENSE](./LICENSE) 참조.

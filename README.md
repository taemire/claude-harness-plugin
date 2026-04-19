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
├── .claude-plugin/plugin.json     ← 매니페스트 (name/description/version)
├── README.md                       ← 이 문서
├── LICENSE                         ← MIT
├── CHANGELOG.md                    ← 버전 이력
├── .gitignore
└── skills/
    ├── run/SKILL.md               ← /harness:run
    ├── uiux/SKILL.md              ← /harness:uiux
    └── resume/SKILL.md            ← /harness:resume (stub)
```

## 상태

- **v0.1.0 (2026-04-19)**: 초기 스켈레톤 + 기존 2개 스킬 이전 + `resume` stub

## 로드맵

| 버전 | 내용 |
|:--|:--|
| **v0.1.x** | 스켈레톤, run/uiux 이전, resume stub |
| **v0.2.x** | 체크포인트 엔진 (writer/reader/error_detector) + `/harness:resume` 본체 |
| **v0.3.x** | SKILL.md v3.6 (체크포인트 주입 7개, 병렬 Evaluator∥Adversarial) |
| **v1.0.x** | GitHub 공개 + marketplace 등록 (Anthropic 공식 마켓플레이스 또는 커스텀) |

## 사용 컨텍스트

- 호출 시 작업 디렉토리 (`${CLAUDE_PROJECT_DIR}`) 를 프로젝트 루트로 간주한다. 하네스 산출물은 `.harness/` (체크포인트) 및 `harness/<type>/` (SPEC/SELF_CHECK/QA_REPORT/output) 아래에 기록된다.
- 체크포인트 엔진 의존 스크립트는 `harness/common/` 에 위치해야 하며, 프로젝트 측에서 자체 준비한다 (`checkpoint_reader.sh`, `checkpoint_writer.sh`, `error_detector.sh`, `extract_bl_id.sh`).

## 라이선스

MIT — 자세한 내용은 [LICENSE](./LICENSE) 참조.

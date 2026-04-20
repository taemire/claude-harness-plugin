# Harness Overrides Starter

> **목적**: 새 프로젝트에서 claude-harness-plugin 을 **5분 안에** 프로젝트 도메인에 맞게 커스터마이징하기 위한 seed kit.
> **대상 버전**: v0.6.0+ (L0 config.yaml + L2 Agent Replace + L3 semver 게이트 전제)

---

## 0. 전제 조건

- [claude-harness-plugin](https://github.com/taemire/claude-harness-plugin) 이 이미 설치되어 있어야 함
  ```
  /plugin marketplace add taemire/claude-harness-plugin
  /plugin install harness
  ```
- 프로젝트 루트에서 작업 (git 저장소 루트 기준 `.harness/` 하위 구조를 만듭니다)

---

## 1. 설치 (1분)

```bash
# 플러그인 clone 경로 (또는 cache 경로) 에서 이 디렉토리를 프로젝트의 .harness/overrides/ 로 복사
cp -r ${CLAUDE_PLUGIN_ROOT}/templates/overrides-starter .harness/overrides

# 또는 git clone 한 상태라면
cp -r /path/to/claude-harness-plugin/templates/overrides-starter .harness/overrides
```

`.example` 접미사를 제거해 정식 파일로 만듭니다:

```bash
cd .harness/overrides
mv override-manifest.json.example override-manifest.json
mv eval_criteria.md.example eval_criteria.md
cd agents
mv planner.md.example planner.md
mv evaluator.md.example evaluator.md   # 선택
cd ../..

# 프로젝트 레벨 config (루트)
cp ${CLAUDE_PLUGIN_ROOT}/templates/config.yaml.example .harness/config.yaml
```

---

## 2. 프로젝트 값 채우기 (2분)

### `.harness/config.yaml`

```yaml
schema_version: "1.0"
harness:
  project_name: my-project           # ← 프로젝트 이름
  bl_prefix: BL                       # ← 백로그 ID 접두사 (BL/TASK/TICKET 등)
  eval_criteria_path: .harness/overrides/eval_criteria.md
  harness_mode_default: standard      # lite | standard | pro | ultra
```

### `.harness/overrides/override-manifest.json`

```json
{
  "schema_version": "1.0",
  "compatible_base_version": "~0.6",
  "overrides": [
    { "type": "agent", "name": "planner", "reason": "프로젝트 도메인 제약 주입" }
  ],
  "created_at": "YYYY-MM-DD",
  "last_verified_base_version": "0.6.0"
}
```

### `.harness/overrides/agents/planner.md`

`.example` 파일의 `[여기에 프로젝트 제약을 작성]` 섹션을 프로젝트 규약에 맞게 수정.
Portal Hub 의 실사례를 참조하려면 `docs/PHASE-P7-multi-session-hardening.md` §1.1 "실측 근거".

---

## 3. 검증 (1분)

```bash
# 세션 재시작 후 SessionStart hook 출력 확인
# ┌ 예시:
# │ [harness plugin v0.6.0] ⚙️  config loaded from .harness/config.yaml
# │   exported: HARNESS_PROJECT_NAME HARNESS_BL_PREFIX ...
# │ [harness plugin v0.6.0] ✅ link-farm configured
# │   linked: 1 file(s) planner.md
# └

# overrides/agents/planner.md 가 .claude/agents/planner.md 로 symlink 된 것 확인
ls -la .claude/agents/planner.md
```

---

## 4. 첫 실행 (1분)

```
/harness:run "BL-001 첫 기능 — 사용자 등록 폼"
```

Planner 가 `planner.md` override 의 "프로젝트 제약" 을 반영한 SPEC 을 `.harness/feature/BL-001/SPEC.md` 에 생성합니다.

---

## 포함 파일

| 파일 | 역할 |
|:--|:--|
| `config.yaml.example` | `.harness/config.yaml` 시작 값 (L0 config loader 가 읽음) |
| `override-manifest.json.example` | `.harness/overrides/override-manifest.json` 최소 스키마 |
| `agents/planner.md.example` | Planner override — 프로젝트 도메인 제약 주입 지점 |
| `agents/evaluator.md.example` | Evaluator override — 선택, 채점 기준 커스터마이징 |
| `eval_criteria.md.example` | 합격 기준 9 카테고리 골격 (Portal Hub 사례 기반 일반화) |

---

## FAQ

### Q. `.harness/overrides/` 를 git 에 커밋해야 하나요?

**예**. overrides 는 프로젝트 규약을 담는 자산이라 팀 공유 대상입니다. `.claude/agents/` (symlink 생성물) 만 gitignore 합니다:

```gitignore
# .gitignore
.claude/agents/planner.md    # link-farm 생성물
.harness/active-sessions.json  # 세션별 local state
```

### Q. 플러그인 버전이 bump 되면 어떻게 되나요?

`override-manifest.json` 의 `compatible_base_version` 과 plugin.json `version` 을 semver 비교합니다. 불일치 시 **경고만** 출력되며 파이프라인은 계속 실행됩니다 (fail-open). 마이그레이션 가이드가 있으면 경고에 경로가 표시됩니다.

### Q. override 파일이 없으면 어떻게 되나요?

플러그인이 제공하는 기본 agents 로 동작합니다. `templates/overrides-starter` 전혀 설치하지 않아도 `/harness:run` 은 정상 작동합니다.

### Q. 여러 프로젝트에서 같은 override 를 공유하고 싶어요

`.harness/overrides/` 디렉토리 자체를 별도 repo 로 만들고 각 프로젝트에서 submodule 또는 symlink 로 참조하세요. 플러그인은 그 위에 semver 게이트만 확인합니다.

---

## 다음 단계

- 도메인 제약이 풍부해지면 **`eval_criteria.md`** 에 프로젝트 전용 게이트 추가 (Portal Hub 는 9 카테고리 운영)
- 멀티세션 사용 환경이면 `docs/PHASE-P7-multi-session-hardening.md` §1.1 운영 체크리스트 참조
- 고급: `/harness:uiux` 를 위한 `web/e2e/harness/catalog/ui-primitives.json` 작성 (UI 하네스 전용)

---

**질문/개선**: [GitHub issues](https://github.com/taemire/claude-harness-plugin/issues) (외부 adopter 대상) 또는 로컬 fork 후 feedback.

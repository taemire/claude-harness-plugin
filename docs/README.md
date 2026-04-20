# docs/ — claude-harness-plugin 개선 프로젝트 문서

> 이 디렉토리는 플러그인의 **장기 개선 로드맵 및 설계 문서** 를 보관한다.

## 목차

### Living Documents (상시 갱신)

| 문서 | 설명 | 상태 |
|---|---|---|
| [PLAN-v1.0.md](./PLAN-v1.0.md) | **하네스 개선 프로젝트 SSOT** — 3-레이어 아키텍처, v0.3~v1.0 릴리즈 로드맵, 품질 게이트, 리스크 | 🟢 Active |
| [PHASE-P1-userConfig.md](./PHASE-P1-userConfig.md) | v0.3.0 P1 상세 스펙 (v1) — userConfig 4키 스키마 + 7개 치환점 규약 + 수용 기준 | ✅ 완료 (2026-04-20) · v0.5.0 에서 P1 v2 로 격상 |
| [PHASE-P1-v2-config-yaml.md](./PHASE-P1-v2-config-yaml.md) | v0.5.0 P1 v2 상세 스펙 — `.harness/config.yaml` 프로젝트 SSOT + 3단 cascade + SKILL env 치환 | ✅ 완료 (2026-04-20) |
| [PHASE-P3-session-start-hook.md](./PHASE-P3-session-start-hook.md) | v0.4.0 P3 상세 스펙 — SessionStart hook (L2 link-farm + L3 semver 게이트) + AC 7 + 리스크 6 | ✅ 완료 (2026-04-20, v0.5.0 에서 L0 config loader 추가) |
| [schemas/override-manifest.schema.json](./schemas/override-manifest.schema.json) | override-manifest.json JSON Schema (draft-07) | ✅ 활성 (v0.4.0~) |

### Phase 세부 스펙 (필요 시 생성)

아래 문서들은 본 플랜의 phase 가 진행됨에 따라 추가된다.

- `MIGRATION-v0.2-to-v0.3.md` — v0.2 → v0.3 마이그레이션 가이드 (P5)
- `MIGRATION-v0.3-to-v0.4.md` — 호환성 게이트 발동 시 참조 (v0.4.0)
- `PHASE-P4-starter-templates.md` — P4 starter template 스펙 (v0.6.0 예정)

### 문서 작성 규칙

1. **SSOT 우선** — `PLAN-v1.0.md` 가 항상 최상위 index. 다른 문서는 이 플랜의 phase/섹션을 참조
2. **Living Document** — 구조 변경 시 이 문서를 먼저 갱신 후 구현 커밋
3. **Revision Log** — 모든 문서 맨 아래 revision log 필수
4. **버전 표기** — 문서명에 버전 포함 (`PLAN-v1.0.md`) 하여 major 개정 시 새 파일로 분기

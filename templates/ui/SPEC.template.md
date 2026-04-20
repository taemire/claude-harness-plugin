# [컴포넌트 이름] — <BL-ID>

> **harness type**: ui
> **BL-ID**: <BL-ID>
> **created**: <YYYY-MM-DD>
> **template version**: 1.0 (v0.6.0+)

## 개요
[무엇이고, 어느 레이어에 위치하는지, 누가 사용하는지 2~3문장]

## 레이어 위치
- 파일 경로: `src/components/[layer]/[ComponentName].tsx`
- 레이어: [ui | composite | layout | portal | widgets]
- 의존 컴포넌트: [사용할 shadcn/ui 컴포넌트 목록]

## GraphQL 요구사항
```graphql
query GetXxx { ... }
```

## 역할별 동작 차이
| 역할 | 표시 여부 | 특이사항 |
|---|---|---|

## 기능 목록

### 기능 1: [이름]
- 설명
- 사용자 스토리
- UI 요소
- 상태: [로딩/에러/빈 상태 처리 방법]

## i18n 키 목록
- `[namespace].[key]`: [표시 텍스트]

## 파일 구조
output/
├── [ComponentName].tsx
├── [ComponentName].types.ts
└── [ComponentName].test.tsx

## 성공 지표 (측정 가능)
- [ ] `npx tsc --noEmit` PASS
- [ ] 핵심 인터랙션 요소에 `data-testid` 존재
- [ ] [역할]로 접근 시 [기대 UI 동작]
- [ ] 로딩/에러/빈 상태 각각 정상 렌더링
- [ ] a11y critical = 0

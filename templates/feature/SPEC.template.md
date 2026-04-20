# [기능 이름] — <BL-ID>

> **harness type**: feature
> **BL-ID**: <BL-ID> (resolved at skill entry)
> **created**: <YYYY-MM-DD>
> **template version**: 1.0 (v0.6.0+)

## 개요
[무엇이고, 왜 필요한지, 어떤 모듈에 속하는지 2~3문장]

## 도메인 모델
```go
// internal/domain/<entity>.go
type Entity struct {
    ID string
    // ...
}

type EntityRepository interface {
    FindByID(ctx context.Context, id string) (*Entity, error)
}

type EntityUsecase interface {
    Get(ctx context.Context, id string) (*Entity, error)
}
```

## GraphQL 스키마 변경
```graphql
# internal/api/graphql/schema/<feature>.graphql
extend type Query { ... }
extend type Mutation { ... }
```

## 기능 목록

### 기능 1: [이름]
- 설명
- 사용자 스토리
- 구현 레이어: [domain / usecase / repository / api / ui]
- 보안 고려: [인가, 검증 사항]

## spec_for_backend
- 도메인 모델
- UseCase 정의
- DB 변경
- 역할 인가 매트릭스
- 참조 경로

## spec_for_frontend
- 페이지/컴포넌트 구조
- GraphQL 쿼리/뮤테이션
- UI 상태 관리
- 역할별 UI 분기
- i18n 키 목록

## 공통 인터페이스
- GraphQL 스키마 (타입, 쿼리, 뮤테이션)

## 성공 지표 (측정 가능)
- [ ] `go test ./... -race -count=1` PASS
- [ ] `go build ./...` 에러 없음
- [ ] GraphQL Playground 에서 [쿼리명] 정상 응답
- [ ] `npx tsc --noEmit` PASS

---
name: ddd-cola
description: "COLA DDD Architecture: multi-module project structure, common/client/adapter/app/domain/infrastructure/start modules, Gateway pattern, CQRS, Feign API contracts. Use when a Java Spring Cloud service already uses COLA/DDD or when the task explicitly mentions COLA, DDD, domain/app/infrastructure/client layers, CmdExe, QryExe, Gateway, or ServiceI."
version: "2.3.0"
parameters:
  - name: service_name
    description: "Service name used as module prefix, for example demo-client and demo-adapter"
    type: string
    required: false
  - name: base_package
    description: "Base Java package, for example com.example"
    type: string
    required: false
  - name: use_feign
    description: "Whether the service exposes Feign client APIs for inter-service calls"
    type: boolean
    required: false
    default: true
  - name: use_event_driven
    description: "Whether to include domain events; if true, also load ddd-event-driven"
    type: boolean
    required: false
    default: false
---

# COLA DDD Architecture

## Load Policy

This is a resident core skill for Java feature work, so keep it as a quick decision layer. Load `references/full-guide.md` only when generating or restructuring multiple COLA modules, writing a complete architecture example, or resolving detailed module dependency questions.

Load additional references only when needed:

- `references/code-examples.md`: concrete class templates for ServiceI, FeignClient, Controller, CmdExe, QryExe, DtoVoConvertor, DOConverter, Gateway, GatewayImpl.
- `references/pom-templates.md`: parent/module POMs, Java 21, Spring Boot 3.5, Lombok/mvnd compiler settings.

## When To Apply

Use COLA/DDD when the repository already has `client`, `adapter`, `app`, `domain`, `infrastructure`, and `start` modules, or when the user explicitly asks for COLA, DDD, Gateway, CmdExe/QryExe, ServiceI, or domain layering.

Do not force COLA onto simple MVC CRUD modules. For plain controller-service-mapper work, follow `spring-boot-rest-api-standards` and `mybatis-plus-patterns`.

## Team Overrides

- Use project `Result<T>` and `PageResult<T>` instead of COLA `Response` or `MultiResponse`.
- Use project `BusinessException` hierarchy instead of COLA `BizException`.
- Do not add COLA component dependencies unless the project already depends on them.
- Use Spring Boot 3.x `jakarta.validation` APIs.
- Use constructor injection, normally Lombok `@RequiredArgsConstructor`.
- Put shared kernel types (`Result`, `PageResult`, `BusinessException`, `Command`, `Query`, `ErrorCode`) in the `common` module — NOT in `client`.
- Put Cmd, Qry, DTO, ServiceI, and optional FeignClient in the `client` module. DTO fields are flat primitive types and client-side enums. They never reference domain value objects.
- Domain value objects (ConditionGroup, RewardSpec, StepDefinition, etc.) live in `domain`. They carry behavior. App layer Convertor maps DTO ↔ VO.
- Domain entities are plain domain objects. They do not receive Cmd/DTO directly.
- Infrastructure DO classes use `DO` suffix and MyBatis-Plus annotations.

## Module Model

Team standard modules (official COLA distributed web archetype plus local `common`; `common` is the shared kernel that keeps `client` and `domain` as leaves):

```text
service-common          shared kernel: Result, PageResult, BusinessException, Command, Query, ErrorCode
service-client          API contracts: Cmd/Qry/DTO (flat), ServiceI, FeignClient
service-adapter         HTTP controllers and inbound adapters
service-app             application services, CmdExe, QryExe, DtoVoConvertor (DTO ↔ Domain VO), DOConverter (DO → DTO)
service-domain          domain entities, value objects, gateways, domain services
service-infrastructure  GatewayImpl, Mapper, DO, external clients
service-start           Spring Boot bootstrap and runtime config
```

Dependency direction (client and domain are BOTH leaves — neither depends on the other):

```text
common  ← client                             (Cmd/Qry/DTO + ServiceI)
common  ← domain                             (Entity + VO + Gateway)
domain  ← infrastructure                     (GatewayImpl + Mapper + DO; DIP)
client, infrastructure  ← app                (ServiceI impl + Cmd/QryExe + Convertor)
app  ← adapter  ← start
```

Key invariants:

- Official COLA `cola-archetype-web` provides `client`, `adapter`, `app`, `domain`, `infrastructure`, and `start`. Our kit adds `common` because we use project-local `Result`, `PageResult`, `BusinessException`, `Command`, `Query`, and `ErrorCode` instead of COLA component types.
- `client` and `domain` have ZERO dependency between them. This matches the official COLA `cola-samples/craftsman` layout where `craftsman-client` and `craftsman-domain` are both leaf modules.
- Client DTO fields are flat (primitives + client enums). If a complex structure (ConditionGroup, StepDefinition, RewardSpec) is needed on both sides, define a flat DTO in `client` and a behavior-carrying VO in `domain`. App Convertor bridges them.
- Pragmatic read-path exception: QryExe may query infrastructure Mapper directly for read performance. Write paths must go through the domain Gateway.

## Implementation Rules

- ServiceI is the public facade interface in `client`; app `XxxServiceImpl` implements it and delegates only.
- Write use cases go `Controller -> ServiceI -> XxxCmdExe -> (Convertor DTO→VO) -> Domain -> Gateway -> GatewayImpl -> Mapper`.
- Read use cases go `Controller -> ServiceI -> XxxQryExe -> Mapper -> (Convertor DO→DTO) -> DTO`.
- CmdExe owns transaction boundaries for writes with `@Transactional(rollbackFor = Exception.class)`.
- CmdExe is responsible for DTO → Domain VO conversion via a Convertor (MapStruct) in the app module. Never let domain import from `client.dto`.
- Gateway interfaces live in domain; GatewayImpl lives in infrastructure and stays thin.
- Gateway methods must separate `save()` for INSERT and `update()` for UPDATE.
- Never pass domain entities to infrastructure HTTP/Feign/MQ clients. Convert to primitive values or DTOs first.
- Before generating a CmdExe or QryExe, read the actual Gateway, Mapper, client, and DTO signatures. Do not invent parameters.
- All executor methods use `execute(...)`.
- Use MapStruct for boundary conversion. Standard converter roles: app `DtoVoConvertor` (client DTO/Cmd ↔ domain VO when needed), app `DOConverter` (read-path DO → client DTO), and infrastructure `DomainConverter` (Domain ↔ DO).

## Naming

| Layer | Pattern |
| --- | --- |
| common shared kernel | `Result<T>`, `PageResult<T>`, `BusinessException`, `Command`, `Query`, `ErrorCode` |
| client API | `XxxServiceI`, `XxxFeignClient` |
| client command/query | `XxxCreateCmd`, `XxxPageQry` |
| client data | `XxxDTO` (flat; no domain VO references) |
| app service | `XxxServiceImpl` |
| app write executor | `XxxCreateCmdExe` |
| app read executor | `XxxPageQryExe` |
| app DTO↔VO converter | `XxxDtoVoConvertor` (MapStruct, in app) |
| app DO→DTO converter | `XxxDOConverter` (MapStruct, in app, read path) |
| domain entity | `Xxx` |
| domain value object | `XxxVO` or bare name (e.g., `ConditionGroup`, `RewardSpec`) |
| domain port | `XxxGateway` |
| infrastructure adapter | `XxxGatewayImpl` |
| infrastructure Domain↔DO converter | `XxxDomainConverter` (MapStruct, in infrastructure) |
| persistence object | `XxxDO` |
| mapper | `XxxMapper` |

## Related Skills

- `mybatis-plus-patterns`: DO, Mapper, LambdaQueryWrapper, soft delete, pagination.
- `spring-boot-transaction-management`: transaction boundaries and after-commit behavior.
- `spring-cloud-openfeign`: Feign contracts and consumers.
- `spring-boot-rest-api-standards`: REST endpoints and Result/PageResult.
- `spring-boot-exception-handling`: BusinessException and global handling.
- `ddd-event-driven`: domain events, aggregate event publishing, event sourcing, outbox.


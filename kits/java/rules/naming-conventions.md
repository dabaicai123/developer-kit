---
paths:
  - "**/*.java"
---

# Rule: Java Naming Conventions

Basic Java naming (PascalCase/camelCase/SCREAMING_SNAKE_CASE) — see `java-coding-style.md`. This rule covers **COLA/DDD and Spring Boot-specific naming** only.

## Class Naming

| Type | Convention | Example |
|------|-----------|---------|
| Data Object (MVC) | PascalCase + DO suffix | `UserDO`, `OrderDO` |
| Domain Entity (DDD) | PascalCase, no suffix | `Order`, `Customer` |
| Application Service Interface (COLA) | PascalCase + ServiceI suffix | `MetricsServiceI`, `OrderServiceI` |
| Command Executor (COLA) | PascalCase + CmdExe suffix | `CreateOrderCmdExe` |
| Query Executor (COLA) | PascalCase + QryExe suffix | `OrderListQryExe` |
| Command (COLA) | PascalCase + Cmd suffix | `CreateOrderCmd` |
| Query (COLA) | PascalCase + Qry suffix | `ATAMetricQry` |
| Gateway (DDD) | PascalCase + Gateway suffix | `OrderGateway` |
| Gateway Impl (DDD) | PascalCase + GatewayImpl suffix | `OrderGatewayImpl` |
| Mapper | PascalCase + Mapper suffix | `UserMapper`, `OrderMapper` |
| Service Interface (MVC) | PascalCase + Service suffix | `UserService` |
| Service Impl (MVC) | PascalCase + ServiceImpl suffix | `UserServiceImpl` |
| Controller | PascalCase + Controller suffix | `UserController` |
| Client DTO | PascalCase + DTO suffix | `UserDTO`, `ConditionGroupDTO` |
| Request/response DTO | PascalCase + DTO suffix | `UserCreateDTO`, `UserDTO` |
| App DTO/VO Convertor (COLA) | PascalCase + DtoVoConvertor suffix | `OrderDtoVoConvertor` |
| App DO/DTO Converter (COLA read path) | PascalCase + DOConverter suffix | `OrderDOConverter` |
| Infrastructure Domain/DO Converter (COLA) | PascalCase + DomainConverter suffix | `OrderDomainConverter` |
| Config | PascalCase + Config suffix | `RedisConfig` |
| Exception | PascalCase + Exception suffix | `BusinessException` |

**Architecture note**: MVC uses `DO` suffix for persistence. COLA/DDD uses bare names for domain entities and `DO` suffix for infrastructure persistence.

## Method Naming

- Query: `getById`, `listByCondition`, `page`
- Command: `create`, `update`, `remove`, `save` (INSERT only in COLA Gateway)
- Boolean: `isXxx`, `hasXxx`
- Event handlers: `onXxx`

## Package Naming (COLA Architecture)

COLA package naming follows the team 7-module model from `ddd-cola` (official COLA distributed web modules plus local `common`). Avoid old single-module packages such as `domain.model.entity` or `infrastructure.mapper`.

| Module | Package |
|-------|---------|
| common | `common.result`, `common.exception`, `common.dto` |
| client | `api`, `dto`, `dto.data`, `dto.event` |
| adapter | `web` |
| app | `{domain}`, `{domain}.executor`, `{domain}.executor.query`, `{domain}.convertor` |
| domain | `domain.{domain}`, `domain.{domain}.vo`, `domain.{domain}.gateway`, `domain.{domain}.domainservice` |
| infrastructure | `{domain}`, `{domain}.gatewayimpl.database`, `{domain}.gatewayimpl.database.dataobject`, `{domain}.gatewayimpl.rpc`, `config`, `external` |

## Anti-Patterns

- `UserEntity` — use `UserDO` for persistence, bare `Order` for domain
- `UserRequest` / `UserResponse` - use `UserCreateDTO` / `UserDTO` in simple modules; use `XxxCmd` / `XxxQry` / `XxxDTO` in COLA client module
- `XxxDTO` importing domain VO/entity - define a flat client DTO and map it in app `XxxDtoVoConvertor`
- `UserServiceImple` / `UserServiceImpl2` — typo or numbered suffix
- `t_xxx` table prefix — use plain snake_case

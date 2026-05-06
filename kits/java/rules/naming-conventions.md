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
| DTO | PascalCase + DTO suffix | `UserCreateDTO` |
| VO | PascalCase + VO suffix | `UserVO` |
| Config | PascalCase + Config suffix | `RedisConfig` |
| Exception | PascalCase + Exception suffix | `BusinessException` |

**Architecture note**: MVC uses `DO` suffix for persistence. COLA/DDD uses bare names for domain entities and `DO` suffix for infrastructure persistence.

## Method Naming

- Query: `getById`, `listByCondition`, `page`
- Command: `create`, `update`, `remove`, `save` (INSERT only in COLA Gateway)
- Boolean: `isXxx`, `hasXxx`
- Event handlers: `onXxx`

## Package Naming (COLA Architecture)

| Layer | Package |
|-------|---------|
| Adapter | `adapter.web` (not `adapter.controller`) |
| Application | `app.service` (facade), `app.executor` (CmdExe/QryExe) |
| Domain | `domain.model.entity`, `domain.gateway` |
| Infrastructure | `infrastructure.gatewayimpl`, `infrastructure.mapper` |

## Anti-Patterns

- `UserEntity` — use `UserDO` for persistence, bare `Order` for domain
- `UserRequest` / `UserResponse` — use `UserCreateDTO` / `UserVO`
- `UserServiceImple` / `UserServiceImpl2` — typo or numbered suffix
- `t_xxx` table prefix — use plain snake_case
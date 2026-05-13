---
paths:
  - "**/*.java"
---

# Rule: Java Project Structure

Enforce consistent project structure following MVC (simple modules) or COLA/DDD (complex domains) patterns. Ensure layer separation and proper dependency direction.

## MVC Structure (Simple Modules)

```
com.example.module/
├── controller/    → UserController.java
├── service/       → UserService.java (interface) + UserServiceImpl.java
├── mapper/        → UserMapper.java
├── entity/        → UserDO.java
├── dto/           → UserCreateDTO.java, UserUpdateDTO.java
├── vo/            → UserVO.java, UserPageVO.java
└── bo/            → UserQueryBO.java
```

## COLA/DDD Structure (Complex Domains)

```
com.example.user/
├── adapter/         → controller, web (VO)
├── app/
│   ├── service/     → ServiceI (facade — delegates to executors)
│   └── executor/    → CmdExe (write), QryExe (read)
├── domain/          → entity (bare name, no suffix), gateway, event
├── infrastructure/  → {domain}/GatewayImpl at root, gatewayimpl/database/dataobject (DO, Mapper), config, external
```

For full COLA/DDD architecture details, use the `ddd-cola` skill.

## Naming Per Architecture

| Architecture | Persistence Object | Domain Entity | Data Access |
|---|---|---|---|
| MVC | `UserDO` (DO suffix) | N/A | `UserService extends IService<UserDO>` |
| COLA/DDD | `OrderDO` (DO suffix, in infrastructure `{domain}/gatewayimpl/database/dataobject/`) | `Order` (bare name, in domain) | `OrderGateway` interface + `OrderGatewayImpl` |

## Dependency Direction

- **MVC**: Controller → Service → Mapper (only)
- **DDD/COLA**: Adapter → Service (facade) → CmdExe/QryExe → Domain/Gateway (no upward deps)

## Anti-Patterns

- Controller → Mapper (bypasses Service layer)
- Service → Controller (upward dependency)
- Domain Entity → Service (upward dependency in DDD)
- `Entity` suffix for persistence objects — use `DO` suffix
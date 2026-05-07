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
├── entity/        → UserEntity.java
├── dto/           → UserCreateDTO.java, UserUpdateDTO.java
├── vo/            → UserVO.java, UserPageVO.java
└── bo/            → UserQueryBO.java
```

## COLA/DDD Structure (Complex Domains)

```
com.example.user/
├── adapter/         → controller, web (VO)
├── app/             → service, executor
├── domain/          → entity, gateway, event
├── infrastructure/  → persistence (Mapper, GatewayImpl), config, gateway (clients)
```

For full COLA/DDD architecture details, use the `ddd-cola` skill.

## Dependency Direction

- **Controller** → depends on **Service** (only)
- **Service** → depends on **Mapper** and **Domain Entity** (only)
- **Mapper** → depends on **Entity** (only)

## Anti-Patterns

- Controller → Mapper (bypasses Service layer)
- Service → Controller (upward dependency)
- Entity → Service (upward dependency)
- Field injection (`@Autowired` on fields) — use constructor injection
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
├── dto/           → UserDTO.java, UserPageDTO.java
└── bo/            → UserQueryBO.java
```

## COLA/DDD Structure (Complex Domains)

COLA services use the team 7-module layout from `ddd-cola`: official COLA distributed web modules plus local `common`. `common` is the shared kernel, while `client` and `domain` are both leaf modules and never depend on each other.

```
service-common/          -> Result, PageResult, BusinessException, Command, Query, ErrorCode
service-client/          -> Cmd/Qry/DTO (flat), ServiceI, optional FeignClient
service-adapter/         -> HTTP controllers and inbound adapters
service-app/             -> ServiceI implementation, CmdExe, QryExe, DtoVoConvertor, DOConverter
service-domain/          -> domain entities, value objects, gateway interfaces, domain services
service-infrastructure/  -> GatewayImpl, Mapper, DO, external clients
service-start/           -> Spring Boot bootstrap and runtime config
```

Inside each module, organize by domain first:

```
adapter:         com.example.web/CustomerController.java
app:             com.example.customer/CustomerServiceImpl.java, executor/, convertor/
domain:          com.example.domain.customer/Customer.java, vo/, gateway/, domainservice/
infrastructure:  com.example.customer/CustomerGatewayImpl.java,
                 gatewayimpl/database/CustomerMapper.java,
                 gatewayimpl/database/dataobject/CustomerDO.java
```

For full COLA/DDD architecture details, use the `ddd-cola` skill.

## Naming Boundary

This file defines where code lives. Detailed suffix and class naming rules live in `naming-conventions.md`.

## Dependency Direction

- **MVC**: Controller -> Service -> Mapper (only)
- **DDD/COLA write path**: Controller -> ServiceI -> CmdExe -> Domain -> Gateway -> GatewayImpl -> Mapper
- **DDD/COLA read path**: Controller -> ServiceI -> QryExe -> Mapper -> DOConverter -> DTO
- `client` and `domain` have zero dependency between them. Use `common` for shared kernel types and app-layer convertors for DTO/VO mapping.

## Anti-Patterns

- Controller -> Mapper (bypasses Service layer)
- Service -> Controller (upward dependency)
- Domain Entity -> Service (upward dependency in DDD)
- Domain -> client DTO/Cmd/Qry (breaks leaf-module boundary)
- client DTO -> domain VO/entity (breaks API contract independence)
- CmdExe -> Mapper for writes (bypasses domain Gateway)
- `Entity` suffix for persistence objects - use `DO` suffix

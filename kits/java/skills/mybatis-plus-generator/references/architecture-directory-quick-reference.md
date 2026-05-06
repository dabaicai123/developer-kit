# Architecture Directory Quick Reference

This document provides a quick directory mapping reference for various object types under different architecture types.

> **COLA V5 mapping is consistent with the `ddd-cola` skill**, following COLA V5 official naming conventions (`app`, `gateway`, `adapter/web`).

## Quick Lookup Table

### Entity (Data Object Classes)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/entity/` |
| DDD | `{package}/domain/model/aggregate/{entity}/` or `{package}/domain/model/entity/` |
| Hexagonal | `{package}/domain/model/entity/` |
| Clean | `{package}/domain/entity/` |
| COLA | `{package}/domain/{domain}/` (domain module, flat per-domain; bare name, no ORM annotations) |

### Mapper (Data Access Interfaces)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/mapper/` |
| DDD | `{package}/domain/repository/` (repository interfaces)<br>`{package}/infrastructure/persistence/mapper/` (MyBatis Mapper) |
| Hexagonal | `{package}/application/ports/outbound/` (port interfaces)<br>`{package}/infrastructure/adapter/outbound/persistence/mapper/` (MyBatis Mapper) |
| Clean | `{package}/application/ports/output/` or `{package}/domain/repository/` (interfaces)<br>`{package}/infrastructure/persistence/mapper/` (MyBatis Mapper) |
| COLA | `{package}/domain/{domain}/gateway/` (Gateway interface in domain module)<br>`{package}/{domain}/` (MyBatis Mapper in infrastructure module, flat per-domain) |

### Service (Service Interfaces)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/service/` |
| DDD | `{package}/application/service/` |
| Hexagonal | `{package}/application/ports/inbound/` |
| Clean | `{package}/application/usecase/{entity}/` |
| COLA | `{package}/api/` (ServiceI in client module) |

### ServiceImpl (Service Implementation Classes)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/service/impl/` |
| DDD | `{package}/application/service/impl/` |
| Hexagonal | `{package}/application/services/` |
| Clean | `{package}/application/service/` |
| COLA | `{package}/{domain}/` (app module, flat per-domain) |

### Controller (Controllers)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/controller/` |
| DDD | `{package}/interfaces/web/controller/` |
| Hexagonal | `{package}/infrastructure/adapter/inbound/web/controller/` |
| Clean | `{package}/infrastructure/web/controller/` |
| COLA | `{package}/web/` (adapter module, flat) |

### DTO (Data Transfer Objects)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/dto/` |
| DDD | Request: `{package}/interfaces/web/dto/request/`<br>Response: `{package}/interfaces/web/dto/response/` |
| Hexagonal | `{package}/infrastructure/adapter/inbound/web/dto/` |
| Clean | `{package}/infrastructure/web/dto/` or `{package}/application/dto/` |
| COLA | `{package}/dto/data/` (client module) |

### VO (View Objects)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/vo/` |
| DDD | `{package}/interfaces/web/dto/response/` |
| Hexagonal | `{package}/infrastructure/adapter/inbound/web/dto/` |
| Clean | `{package}/infrastructure/web/dto/` |
| COLA | `{package}/dto/data/` (client module; COLA uses DTO only, no separate VO) |

### Cmd/Qry (Request Objects, COLA only)

| Architecture Type | Directory Path |
|:--------|:---------|
| COLA | `{package}/dto/` (client module; Cmd extends Command, Qry extends Query) |

### BO (Business Objects)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/bo/` |
| DDD | `{package}/application/dto/` |
| Hexagonal | `{package}/application/dto/` |
| Clean | `{package}/application/dto/` |
| COLA | Not used — COLA passes Cmd/Qry/DTO through the full stack without a separate BO layer |

### Persistence Data Object (DO)

**Note**: Only in DDD, Hexagonal, Clean, and COLA architectures is it necessary to distinguish between domain entities and persistence data objects.

| Architecture Type | Directory Path |
|:--------|:---------|
| DDD | `{package}/infrastructure/persistence/entity/` |
| Hexagonal | `{package}/infrastructure/adapter/outbound/persistence/entity/` |
| Clean | `{package}/infrastructure/persistence/entity/` |
| COLA | `{package}/{domain}/` (infrastructure module, flat per-domain; `DO` suffix) |

### Repository/Gateway Implementation

| Architecture Type | Directory Path |
|:--------|:---------|
| DDD | `{package}/infrastructure/persistence/repository/` |
| Hexagonal | `{package}/infrastructure/adapter/outbound/persistence/repositoryimpl/` |
| Clean | `{package}/infrastructure/persistence/repository/` |
| COLA | `{package}/{domain}/` (infrastructure module, flat per-domain; `GatewayImpl` suffix) |

### Converter (COLA only, MapStruct)

| Architecture Type | Directory Path |
|:--------|:---------|
| COLA (DO ↔ Domain) | `{package}/{domain}/` (infrastructure module; `DomainConverter` suffix) |
| COLA (DO → DTO) | `{package}/{domain}/` (app module; `DOConverter` suffix) |

## Complete Path Examples

Assuming base package path is `com.example.order` and table name is `user`:

### MVC Architecture

```
src/main/java/com/example/order/
├── entity/User.java
├── mapper/UserMapper.java
├── service/UserService.java
├── service/impl/UserServiceImpl.java
├── controller/UserController.java
└── dto/UserCreateDTO.java
```

### DDD Architecture

```
src/main/java/com/example/order/
├── domain/
│   ├── model/aggregate/user/User.java
│   └── repository/UserRepository.java
├── application/
│   ├── service/UserApplicationService.java
│   └── service/impl/UserApplicationServiceImpl.java
├── interfaces/web/
│   ├── controller/UserController.java
│   └── dto/
│       ├── request/UserCreateRequest.java
│       └── response/UserResponse.java
└── infrastructure/persistence/
    ├── entity/UserDO.java
    └── mapper/UserMapper.java
```

### Hexagonal Architecture

```
src/main/java/com/example/order/
├── domain/model/entity/User.java
├── application/
│   ├── ports/
│   │   ├── inbound/IUserService.java
│   │   └── outbound/IUserRepository.java
│   └── services/UserServiceImpl.java
└── infrastructure/adapter/
    ├── inbound/web/
    │   ├── controller/UserController.java
    │   └── dto/UserRequest.java
    └── outbound/persistence/
        ├── repositoryimpl/UserRepositoryImpl.java
        ├── mapper/UserMapper.java
        └── entity/UserDO.java
```

### Clean Architecture

```
src/main/java/com/example/order/
├── domain/entity/User.java
├── application/
│   ├── usecase/user/CreateUserUseCase.java
│   ├── ports/output/UserOutputPort.java
│   └── service/UserApplicationService.java
└── infrastructure/
    ├── persistence/
    │   ├── repository/UserRepositoryImpl.java
    │   ├── mapper/UserMapper.java
    │   └── entity/UserDO.java
    └── web/
        ├── controller/UserController.java
        └── dto/UserWebRequest.java
```

### COLA V5 Architecture (aligned with `ddd-cola` skill — 6 Maven modules)

> `ddd-cola` is the authoritative reference. The tree below reflects its **flat per-domain** convention in the `app` and `infrastructure` modules and the `client/dto` + `client/dto/data` split for Cmd/Qry and DTO.

```
demo-parent/
├── demo-client/                         # API contract + common types
│   └── src/main/java/com/example/
│       ├── common/
│       │   ├── result/                  # Result.java, PageResult.java
│       │   ├── exception/               # BusinessException, NotFoundException, ...
│       │   └── dto/                     # Command.java, Query.java (marker base classes)
│       ├── api/
│       │   ├── UserServiceI.java        # Service interface (returns Result<T>)
│       │   └── UserFeignClient.java     # @FeignClient
│       └── dto/
│           ├── UserAddCmd.java          # extends Command
│           ├── UserListQry.java         # extends Query
│           └── data/
│               └── UserDTO.java         # Response DTO
├── demo-adapter/
│   └── src/main/java/com/example/web/
│       └── UserController.java          # @RestController
├── demo-app/
│   └── src/main/java/com/example/user/  # flat per-domain
│       ├── UserServiceImpl.java         # implements UserServiceI
│       ├── UserDOConverter.java         # MapStruct DO → DTO
│       └── executor/
│           ├── UserAddCmdExe.java       # write handler
│           └── query/
│               └── UserListQryExe.java  # read handler
├── demo-domain/
│   └── src/main/java/com/example/domain/user/
│       ├── User.java                    # Entity (@Data, bare name)
│       ├── UserStatus.java
│       ├── gateway/
│       │   └── UserGateway.java         # Persistence port
│       └── domainservice/
│           └── CreditChecker.java       # cross-entity logic (optional)
├── demo-infrastructure/
│   └── src/main/java/com/example/user/  # flat per-domain
│       ├── UserGatewayImpl.java
│       ├── UserDO.java                  # @TableName, @Data
│       ├── UserMapper.java
│       └── UserDomainConverter.java     # MapStruct DO ↔ Domain
└── demo-start/
    └── src/main/java/com/example/
        └── Application.java             # @SpringBootApplication
```

## COLA V5 Naming Convention Comparison

> Consistent with the `ddd-cola` skill

| Concept | COLA V5 Naming | Common Naming in Other Architectures | Description |
|:-----|:------------|:---------------|:-----|
| Application layer | `app` module | `application` | COLA V5 uses short naming |
| Repository interface | `gateway` | `repository` | COLA uses Gateway terminology |
| Controller directory | `adapter/web/` (flat) | nested `interfaces/web/controller/` | COLA uses flat organization |
| Command objects | `Cmd` suffix | `Command` / `Request` | e.g., `CreateUserCmd` |
| Query objects | `Qry` suffix | `Query` / `Request` | e.g., `GetUserQry` |
| Executors | `Exe` suffix | `Handler` / `UseCase` | e.g., `UserCreateCmdExe` |
| Persistence objects | `DO` suffix | `Entity` / `PO` | e.g., `UserDO` |
| Infra/app package | flat per-domain (`{package}/{domain}/`) | `persistence` / `service/impl` | GatewayImpl, Mapper, DO, and converters stay together under one domain package |
| Gateway impl | `GatewayImpl` suffix | `RepositoryImpl` | e.g., `UserGatewayImpl` |
| Cmd/Qry/DTO location | `client` module | `application` / `web` | Kept in client so consumers can use them via Feign |

## Usage Steps

1. **Confirm architecture type** (from Step 2)
2. **Confirm base package path** (from Step 1)
3. **Find object type** (Entity, Mapper, Service, etc.)
4. **Use the table above to find the corresponding directory path**
5. **Build complete path**: `src/main/java/{package}/{directory path}/{ClassName}.java`
6. **Verify directory exists**, create if it does not exist
7. **Generate files**

## Important Notes

1. **Domain Entity vs Persistence Data Object**:
   - DDD, Hexagonal, Clean, and COLA architectures require distinguishing these
   - Domain entities contain business logic and are placed in the domain layer
   - Persistence data objects (DO suffix) are database mappings and are placed in the infrastructure layer

2. **Mapper Interface Location**:
   - In DDD, Hexagonal, and Clean architectures, there are typically two locations:
     - Repository interface (defined in domain layer)
     - MyBatis Mapper (implemented in infrastructure layer)
   - In COLA, Gateway is defined in domain layer, Mapper is implemented in infrastructure layer

3. **DTO Classification**:
   - In DDD architecture, Request and Response are stored separately
   - In COLA, Cmd/Qry live in `client/dto/`, and DTO/VO live in `client/dto/data/` — per `ddd-cola`

4. **Package Path Conversion**:
   - Package paths use dot separators: `com.example.order`
   - File paths use slash separators: `com/example/order/`
   - Base path: `src/main/java/`

5. **COLA V5 Special Conventions**:
   - Application layer package name uses `app` (not `application`)
   - Repository interface uses `gateway` (not `repository`)
   - Controllers are placed directly in `adapter/web/`.

## Reference Documents

- COLA V5 authoritative reference: `../../ddd-cola/SKILL.md`
- COLA code examples: `../../ddd-cola/references/code-examples.md`
- MyBatis-Plus patterns: `../mybatis-plus-patterns/SKILL.md`
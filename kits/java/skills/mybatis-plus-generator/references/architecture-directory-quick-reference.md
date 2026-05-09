# Architecture Directory Quick Reference

This document provides a quick directory mapping reference for various object types under different architecture types.

> **COLA V5 mapping is consistent with the `ddd-cola` skill**, following COLA V5 official naming conventions (`app`, `gateway`, `adapter/controller`).

## Quick Lookup Table

### Entity (Data Object Classes)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/entity/` |
| DDD | `{package}/domain/model/aggregate/{entity}/` or `{package}/domain/model/entity/` |
| Hexagonal | `{package}/domain/model/entity/` |
| Clean | `{package}/domain/entity/` |
| COLA | `{package}/domain/model/entity/` |

### Mapper (Data Access Interfaces)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/mapper/` |
| DDD | `{package}/domain/repository/` (repository interfaces)<br>`{package}/infrastructure/persistence/mapper/` (MyBatis Mapper) |
| Hexagonal | `{package}/application/ports/outbound/` (port interfaces)<br>`{package}/infrastructure/adapter/outbound/persistence/mapper/` (MyBatis Mapper) |
| Clean | `{package}/application/ports/output/` or `{package}/domain/repository/` (interfaces)<br>`{package}/infrastructure/persistence/mapper/` (MyBatis Mapper) |
| COLA | `{package}/domain/gateway/` (gateway interfaces, COLA uses gateway not repository)<br>`{package}/infrastructure/mapper/` (MyBatis Mapper implementations) |

### Service (Service Interfaces)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/service/` |
| DDD | `{package}/application/service/` |
| Hexagonal | `{package}/application/ports/inbound/` |
| Clean | `{package}/application/usecase/{entity}/` |
| COLA | `{package}/app/service/` (COLA V5 uses app, not application) |

### ServiceImpl (Service Implementation Classes)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/service/impl/` |
| DDD | `{package}/application/service/impl/` |
| Hexagonal | `{package}/application/services/` |
| Clean | `{package}/application/service/` |
| COLA | `{package}/app/service/impl/` (COLA V5 uses app, not application) |

### Controller (Controllers)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/controller/` |
| DDD | `{package}/interfaces/web/controller/` |
| Hexagonal | `{package}/infrastructure/adapter/inbound/web/controller/` |
| Clean | `{package}/infrastructure/web/controller/` |
| COLA | `{package}/adapter/controller/` (COLA V5 places directly under adapter, not adapter/web/) |

### DTO (Data Transfer Objects)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/dto/` |
| DDD | Request: `{package}/interfaces/web/dto/request/`<br>Response: `{package}/interfaces/web/dto/response/` |
| Hexagonal | `{package}/infrastructure/adapter/inbound/web/dto/` |
| Clean | `{package}/infrastructure/web/dto/` or `{package}/application/dto/` |
| COLA | `{package}/adapter/dto/` or `{package}/app/model/dto/` |

### VO (View Objects)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/vo/` |
| DDD | `{package}/interfaces/web/dto/response/` |
| Hexagonal | `{package}/infrastructure/adapter/inbound/web/dto/` |
| Clean | `{package}/infrastructure/web/dto/` |
| COLA | `{package}/adapter/dto/` |

### BO (Business Objects)

| Architecture Type | Directory Path |
|:--------|:---------|
| MVC | `{package}/bo/` |
| DDD | `{package}/application/dto/` |
| Hexagonal | `{package}/application/dto/` |
| Clean | `{package}/application/dto/` |
| COLA | `{package}/app/model/` or `{package}/app/executor/` (COLA V5 uses app, not application) |

### Persistence Data Object (DO)

**Note**: Only in DDD, Hexagonal, Clean, and COLA architectures is it necessary to distinguish between domain entities and persistence data objects.

| Architecture Type | Directory Path |
|:--------|:---------|
| DDD | `{package}/infrastructure/persistence/entity/` |
| Hexagonal | `{package}/infrastructure/adapter/outbound/persistence/entity/` |
| Clean | `{package}/infrastructure/persistence/entity/` |
| COLA | `{package}/infrastructure/mapper/dataobject/` |

### Repository/Gateway Implementation

| Architecture Type | Directory Path |
|:--------|:---------|
| DDD | `{package}/infrastructure/persistence/repository/` |
| Hexagonal | `{package}/infrastructure/adapter/outbound/persistence/repositoryimpl/` |
| Clean | `{package}/infrastructure/persistence/repository/` |
| COLA | `{package}/infrastructure/gatewayimpl/` (Gateway implementation) |

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

### COLA V5 Architecture (aligned with ddd-cola skill)

```
src/main/java/com/example/order/
├── adapter/
│   ├── controller/UserController.java
│   ├── scheduler/
│   └── dto/
│       ├── UserCreateRequest.java
│       └── UserResponse.java
├── app/
│   ├── executor/
│   │   ├── command/user/UserCreateCmdExe.java
│   │   └── query/user/UserGetQryExe.java
│   ├── service/UserAppService.java
│   └── service/impl/UserAppServiceImpl.java
├── domain/
│   ├── model/entity/User.java
│   ├── gateway/UserGateway.java
│   └── service/
└── infrastructure/
    ├── gatewayimpl/
    │   └── UserGatewayImpl.java
    ├── mapper/
    │   ├── UserMapper.java
    │   └── dataobject/
    │   │   └── UserDO.java
    ├── external/
    └── config/
```

## COLA V5 Naming Convention Comparison

> Consistent with the `ddd-cola` skill

| Concept | COLA V5 Naming | Common Naming in Other Architectures | Description |
|:-----|:------------|:---------------|:-----|
| Application layer | `app` | `application` | COLA V5 uses short naming |
| Repository interface | `gateway` | `repository` | COLA uses Gateway terminology |
| Controller directory | `adapter/controller/` | `adapter/web/controller/` | COLA uses flat organization |
| Command objects | `Cmd` suffix | `Command` / `Request` | e.g., `CreateUserCmd` |
| Query objects | `Qry` suffix | `Query` / `Request` | e.g., `GetUserQry` |
| Executors | `Exe` suffix | `Handler` / `UseCase` | e.g., `UserCreateCmdExe` |
| Persistence objects | `DO` suffix | `Entity` / `PO` | e.g., `UserDO` |
| Infra package | `gatewayimpl` + `mapper` | `persistence` | COLA uses gatewayimpl for impl, mapper for DO+Mapper |
| Gateway impl | `GatewayImpl` suffix | `RepositoryImpl` | e.g., `UserGatewayImpl` |

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
   - In COLA, DTOs are placed in `adapter/dto/` or `app/model/`

4. **Package Path Conversion**:
   - Package paths use dot separators: `com.example.order`
   - File paths use slash separators: `com/example/order/`
   - Base path: `src/main/java/`

5. **COLA V5 Special Conventions**:
   - Application layer package name uses `app` (not `application`)
   - Repository interface uses `gateway` (not `repository`)
   - Controllers are placed directly in `adapter/controller/` (not `adapter/web/controller/`)

## Reference Documents

- Detailed mapping guide: `architecture-directory-mapping-guide.md`
- Detailed examples: `examples/architecture-directory-mapping.md`
- COLA V5 authoritative reference: `ddd-cola`
- DDD architecture reference: `../ddd4j-project-creator/docs/1、DDD Classic Layered Architecture Directory Structure.md`
- Hexagonal architecture reference: `../ddd4j-project-creator/docs/2、Hexagonal Architecture Detailed Directory Structure Reference.md`
- Clean architecture reference: `../ddd4j-project-creator/docs/3、Clean Architecture Detailed Directory Structure Reference.md`
- COLA V5 architecture reference: `../ddd4j-project-creator/docs/4、COLA V5 Architecture Detailed Directory Structure Reference.md`
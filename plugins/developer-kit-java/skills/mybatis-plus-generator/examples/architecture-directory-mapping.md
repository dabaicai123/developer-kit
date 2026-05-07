# Architecture Directory Mapping Example

This document provides directory mapping examples for MyBatis-Plus Generator generated code under different architecture types.

## Example Scenario

Assume we have a `user` table and need to generate related code, with a base package path of `com.example.order`.

## 1. Traditional MVC Architecture

### Directory Structure

```
src/main/java/com/example/order/
├── entity/
│   └── User.java                    # Entity class
├── mapper/
│   └── UserMapper.java             # Mapper interface
├── service/
│   ├── UserService.java            # Service interface
│   └── impl/
│       └── UserServiceImpl.java    # ServiceImpl implementation class
├── controller/
│   └── UserController.java         # Controller
└── dto/
    ├── UserCreateDTO.java          # Create user DTO
    ├── UserUpdateDTO.java          # Update user DTO
    └── UserQueryDTO.java           # Query user DTO
```

### File Path Examples

- Entity: `src/main/java/com/example/order/entity/User.java`
- Mapper: `src/main/java/com/example/order/mapper/UserMapper.java`
- Service: `src/main/java/com/example/order/service/UserService.java`
- ServiceImpl: `src/main/java/com/example/order/service/impl/UserServiceImpl.java`
- Controller: `src/main/java/com/example/order/controller/UserController.java`
- DTO: `src/main/java/com/example/order/dto/UserCreateDTO.java`

## 2. DDD (Domain-Driven Design) Architecture

### Directory Structure

```
src/main/java/com/example/order/
├── domain/                          # Domain layer
│   ├── model/
│   │   ├── aggregate/
│   │   │   └── user/
│   │   │       └── User.java       # Aggregate root (domain entity)
│   │   └── valueobject/
│   │       ├── UserId.java
│   │       └── Email.java
│   └── repository/
│       └── UserRepository.java     # Repository interface (Mapper interface)
├── application/                     # Application layer
│   ├── service/
│   │   ├── UserApplicationService.java      # Application service interface
│   │   └── impl/
│   │       └── UserApplicationServiceImpl.java  # Application service implementation
│   └── dto/
│       └── UserDTO.java            # Application layer DTO
├── interfaces/                      # Interface layer
│   └── web/
│       ├── controller/
│       │   └── UserController.java # Controller
│       └── dto/
│           ├── request/
│           │   ├── UserCreateRequest.java
│           │   └── UserUpdateRequest.java
│           └── response/
│               └── UserResponse.java  # VO (View Object)
│       └── assembler/
│           └── UserAssembler.java  # DTO assembler
└── infrastructure/                  # Infrastructure layer
    └── persistence/
        ├── repository/
        │   └── JpaUserRepository.java  # Repository implementation
        ├── mapper/
        │   └── UserMapper.java      # MyBatis Mapper
        └── entity/
            └── UserEntity.java      # Persistence entity
```

### File Path Examples

- Domain Entity: `src/main/java/com/example/order/domain/model/aggregate/user/User.java`
- Repository Interface: `src/main/java/com/example/order/domain/repository/UserRepository.java`
- Application Service: `src/main/java/com/example/order/application/service/UserApplicationService.java`
- Application Service Impl: `src/main/java/com/example/order/application/service/impl/UserApplicationServiceImpl.java`
- Controller: `src/main/java/com/example/order/interfaces/web/controller/UserController.java`
- Request DTO: `src/main/java/com/example/order/interfaces/web/dto/request/UserCreateRequest.java`
- Response VO: `src/main/java/com/example/order/interfaces/web/dto/response/UserResponse.java`
- Persistence Entity: `src/main/java/com/example/order/infrastructure/persistence/entity/UserEntity.java`
- Mapper: `src/main/java/com/example/order/infrastructure/persistence/mapper/UserMapper.java`

### Notes

In DDD architecture:
- **Domain entity (User)** is a business model, placed in `domain/model/aggregate/` or `domain/model/entity/`
- **Persistence entity (UserEntity)** is a technical implementation, placed in `infrastructure/persistence/entity/`
- **Mapper interface** is defined in the domain layer (`domain/repository/`) and implemented in the infrastructure layer (`infrastructure/persistence/mapper/`)

## 3. Hexagonal Architecture

### Directory Structure

```
src/main/java/com/example/order/
├── application/                     # Application layer
│   ├── ports/
│   │   ├── inbound/
│   │   │   └── IUserService.java   # Inbound port (Service interface)
│   │   └── outbound/
│   │       └── IUserRepository.java # Outbound port (Repository interface)
│   ├── services/
│   │   └── UserServiceImpl.java    # Application service implementation
│   └── usecases/
│       └── user/
│           └── CreateUserUseCase.java
├── domain/                          # Domain layer
│   ├── model/
│   │   ├── entity/
│   │   │   └── User.java          # Domain entity
│   │   └── valueobject/
│   │       └── Email.java
│   └── service/
│       └── UserDomainService.java
└── infrastructure/                  # Infrastructure layer
    └── adapter/
        ├── inbound/                 # Inbound adapter
        │   └── web/
        │       ├── controller/
        │       │   └── UserController.java  # Controller
        │       └── dto/
        │           ├── CreateUserRequest.java
        │           └── UserResponse.java
        └── outbound/                # Outbound adapter
            └── persistence/
                ├── repositoryimpl/
                │   └── UserRepositoryImpl.java  # Repository implementation
                ├── mapper/
                │   └── UserMapper.java         # MyBatis Mapper
                └── entity/
                    └── UserEntity.java         # Persistence entity
```

### File Path Examples

- Domain Entity: `src/main/java/com/example/order/domain/model/entity/User.java`
- Inbound Port: `src/main/java/com/example/order/application/ports/inbound/IUserService.java`
- Outbound Port: `src/main/java/com/example/order/application/ports/outbound/IUserRepository.java`
- Service Impl: `src/main/java/com/example/order/application/services/UserServiceImpl.java`
- Controller: `src/main/java/com/example/order/infrastructure/adapter/inbound/web/controller/UserController.java`
- Repository Impl: `src/main/java/com/example/order/infrastructure/adapter/outbound/persistence/repositoryimpl/UserRepositoryImpl.java`
- Mapper: `src/main/java/com/example/order/infrastructure/adapter/outbound/persistence/mapper/UserMapper.java`
- Persistence Entity: `src/main/java/com/example/order/infrastructure/adapter/outbound/persistence/entity/UserEntity.java`

## 4. Clean Architecture

### Directory Structure

```
src/main/java/com/example/order/
├── domain/                          # Domain layer (innermost layer)
│   ├── entity/
│   │   └── User.java               # Business entity
│   ├── valueobject/
│   │   └── Email.java
│   ├── repository/
│   │   └── UserRepository.java     # Repository interface
│   └── service/
│       └── UserDomainService.java
├── application/                     # Application layer
│   ├── usecase/
│   │   └── user/
│   │       ├── CreateUserUseCase.java
│   │       └── GetUserUseCase.java
│   ├── ports/
│   │   ├── input/
│   │   │   └── UserInputPort.java
│   │   └── output/
│   │       └── UserOutputPort.java  # Output port (Repository interface)
│   ├── service/
│   │   └── UserApplicationService.java  # Application service (ServiceImpl)
│   └── dto/
│       └── UserDTO.java
└── infrastructure/                  # Infrastructure layer (outermost layer)
    ├── persistence/
    │   ├── repository/
    │   │   └── UserRepositoryImpl.java  # Repository implementation
    │   ├── mapper/
    │   │   └── UserMapper.java         # MyBatis Mapper
    │   └── entity/
    │       └── UserEntity.java         # Persistence entity
    └── web/
        ├── controller/
        │   └── UserController.java     # Controller
        └── dto/
            ├── CreateUserWebRequest.java
            └── UserWebResponse.java
```

### File Path Examples

- Domain Entity: `src/main/java/com/example/order/domain/entity/User.java`
- Repository Interface: `src/main/java/com/example/order/application/ports/output/UserOutputPort.java`
- Use Case: `src/main/java/com/example/order/application/usecase/user/CreateUserUseCase.java`
- Application Service: `src/main/java/com/example/order/application/service/UserApplicationService.java`
- Controller: `src/main/java/com/example/order/infrastructure/web/controller/UserController.java`
- Repository Impl: `src/main/java/com/example/order/infrastructure/persistence/repository/UserRepositoryImpl.java`
- Mapper: `src/main/java/com/example/order/infrastructure/persistence/mapper/UserMapper.java`
- Persistence Entity: `src/main/java/com/example/order/infrastructure/persistence/entity/UserEntity.java`

## 5. COLA V5 Architecture

### Directory Structure

```
src/main/java/com/example/order/
├── domain/                          # Domain layer
│   ├── model/
│   │   ├── entity/
│   │   │   └── User.java           # Entity
│   │   └── valueobject/
│   │       └── Email.java
│   ├── repository/
│   │   └── UserRepository.java     # Repository interface (Mapper interface)
│   ├── gateway/
│   │   └── UserGateway.java
│   ├── service/
│   │   └── UserDomainService.java
│   └── ability/
│       └── UserAbility.java
├── application/                     # Application layer
│   ├── executor/                   # Executor (CQRS)
│   │   ├── command/
│   │   │   └── user/
│   │   │       └── UserCreateCmdExe.java
│   │   └── query/
│   │       └── user/
│   │           └── UserGetQryExe.java
│   ├── service/
│   │   ├── UserAppService.java     # Application service interface
│   │   └── impl/
│   │       └── UserAppServiceImpl.java  # Application service implementation
│   └── model/
│       ├── command/
│       │   └── UserCreateCmd.java
│       ├── query/
│       │   └── UserGetQry.java
│       └── dto/
│           └── UserDTO.java
└── adapter/                        # Adapter layer
    └── web/
        ├── controller/
        │   └── UserController.java  # Controller
        └── dto/
            ├── UserCreateRequest.java
            └── UserResponse.java
```

### File Path Examples

- Domain Entity: `src/main/java/com/example/order/domain/model/entity/User.java`
- Repository Interface: `src/main/java/com/example/order/domain/repository/UserRepository.java`
- Application Service: `src/main/java/com/example/order/application/service/UserAppService.java`
- Application Service Impl: `src/main/java/com/example/order/application/service/impl/UserAppServiceImpl.java`
- Command Executor: `src/main/java/com/example/order/application/executor/command/user/UserCreateCmdExe.java`
- Query Executor: `src/main/java/com/example/order/application/executor/query/user/UserGetQryExe.java`
- Controller: `src/main/java/com/example/order/adapter/web/controller/UserController.java`
- DTO: `src/main/java/com/example/order/adapter/web/dto/UserCreateRequest.java`

## How to Determine Output Directory

### Step 1: Confirm Architecture Type

In Step 2, the user has already selected the architecture type. Based on the selection, use the corresponding directory mapping.

### Step 2: Confirm Base Package Path

Ask the user:
```
Please provide the project's base package path (e.g.: com.example.order)
```

### Step 3: Confirm Project Structure

If the project structure is non-standard, ask the user:
```
Please confirm the project's directory structure so that generated code is placed in the correct location.

Examples:
- Which directory should entity classes be placed in?
- Which directory should Controllers be placed in?
- Which directory should Services be placed in?
```

### Step 4: Build Complete Path

Based on the architecture type and base package path, build the complete file path:

**Example:**
- Architecture: DDD
- Base package: `com.example.order`
- Table name: `user`
- Entity path: `src/main/java/com/example/order/domain/model/aggregate/user/User.java`

### Step 5: Verify Directory Exists

Before generating code, check whether the directory exists:
- If the directory does not exist, create it
- If the directory already exists, confirm whether to overwrite existing files

## Common Questions

### Q1: How to distinguish domain entities from persistence entities?

**A**: 
- **Domain entity**: Business model, contains business logic, placed in the domain layer (`domain/`)
- **Persistence entity**: Database mapping, placed in the infrastructure layer (`infrastructure/persistence/entity/`)

In DDD, Hexagonal, and Clean architectures, both types of entities are typically generated.

### Q2: Where should the Mapper interface be placed?

**A**: 
- **MVC**: `{package}/mapper/`
- **DDD**: Repository interface in `{package}/domain/repository/`, MyBatis Mapper in `{package}/infrastructure/persistence/mapper/`
- **Hexagonal**: Port interface in `{package}/application/ports/outbound/`, MyBatis Mapper in `{package}/infrastructure/adapter/outbound/persistence/mapper/`
- **Clean**: Output port in `{package}/application/ports/output/`, MyBatis Mapper in `{package}/infrastructure/persistence/mapper/`
- **COLA**: `{package}/domain/repository/`

### Q3: How to determine the location of DTOs?

**A**: 
- **MVC**: `{package}/dto/`
- **DDD**: Request DTO in `{package}/interfaces/web/dto/request/`, Response VO in `{package}/interfaces/web/dto/response/`
- **Hexagonal**: `{package}/infrastructure/adapter/inbound/web/dto/`
- **Clean**: `{package}/infrastructure/web/dto/` or `{package}/application/dto/`
- **COLA**: `{package}/adapter/web/dto/` or `{package}/application/model/dto/`

### Q4: What if the project structure is non-standard?

**A**: Ask the user for their specific directory structure, or have the user provide a project directory structure example, then adjust accordingly.

## Reference Documentation

Detailed architecture directory structure references:
- DDD classic layered architecture: `reference/ddd-architecture-directory-structure.md`
- Hexagonal architecture: `reference/hexagonal-architecture-directory-structure.md`
- Clean architecture: `reference/clean-architecture-directory-structure.md`
- COLA V5 architecture: `reference/cola-v5-architecture-directory-structure.md`
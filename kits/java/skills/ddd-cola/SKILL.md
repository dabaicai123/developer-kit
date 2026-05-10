---
name: ddd-cola
description: "COLA DDD Architecture (Web/Distributed): multi-module project structure (client/adapter/app/domain/infrastructure/start), Feign integration, Gateway pattern, CQRS. Uses project's own Result/BusinessException conventions. Use when creating a Spring Cloud microservice with COLA/DDD architecture."
version: "2.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# COLA DDD Architecture (Web/Distributed)

## When to use this skill

Use when creating or structuring a Spring Cloud microservice with COLA/DDD multi-module architecture, implementing domain-driven design with a client module for Feign API sharing.

## Quick Guide

| Your scenario | What to do |
|---------------|-----------|
| Starting a new service? | Follow **Project Setup** → scaffold 6 modules per **Module Structure** |
| Adding a new use case? | Pick CQRS path: Write → CmdExe → Domain → Gateway; Read → QryExe → Mapper |
| Unsure about a module? | Client → Feign + ServiceI; Adapter → `spring-boot-rest-api-standards`; Domain → this skill's Gateway + Entity; Infrastructure → `mybatis-plus-patterns` |
| Confused about naming? | See **Naming Per Module** |
| Confused about data flow? | Cmd/Qry (client) → Entity (domain, plain params) → DO (infrastructure) → DB → Result<T> |
| Other service calling yours? | They depend on your `client` jar, inject FeignClient |

## Official COLA vs Team Override

| Aspect | Official COLA (archetype-web) | Team Override | Reason |
|--------|-------------------------------|-------------|--------|
| Response types | `Response<T>` / `MultiResponse<T>` (cola-component-dto) | `Result<T>` / `PageResult<T>` | Project already uses Result across all services; avoid dual type systems |
| Exception types | `BizException` / `SysException` (cola-component-exception) | `BusinessException` + sub-classes | Project already uses BusinessException with int error codes |
| COLA component deps | Required (BOM, dto, exception, domain-starter) | None | COLA components target Alibaba internal ecosystem (HSF/Mtop); unnecessary for Spring Cloud |
| Domain entity annotation | `@Entity` (cola-component-domain-starter, prototype scope) | `@Data` (Lombok) | Lombok is lighter, already used in project; prototype scope rarely needed |
| Infrastructure package | `gatewayimpl.database.dataobject` (some samples) | Flat per-domain (`customer/CustomerGatewayImpl.java`) | Simpler, fewer sub-packages; official archetype-web sample also uses flat layout |
| ServiceI return type | `Response` / `MultiResponse` | `Result<T>` / `PageResult<T>` | Same as non-DDD services; no type split |
| Cmd/Qry base | Extends COLA `Command` / `Query` | Extends self-defined `Command` / `Query` (in client `common.dto`) | No cola-component-dto dependency; marker classes serve the same CQRS identification purpose |

## Project Setup

### 1. Multi-Module Maven Project

COLA archetype-web pattern — 6 Maven modules under a parent POM:

```
demo-parent/
├── demo-client/           # API interfaces, DTOs, Feign clients, common types
├── demo-adapter/          # HTTP inbound (Controllers)
├── demo-app/              # Application services, executors
├── demo-domain/           # Domain entities, Gateways, domain services
├── demo-infrastructure/   # Gateway implementations, Mappers, external clients
└── demo-start/            # Bootstrap (Application.java + config)
```

### 2. Module Dependencies

```
start → adapter → app → {client, infrastructure → domain → client}
```

| Module | Depends On | Reason |
|--------|-----------|--------|
| **client** | jakarta.validation-api, lombok, openfeign(provided) | Pure API contract + common types. OpenFeign `provided` scope — consumers bring their own runtime |
| **domain** | client | Uses Result/BusinessException base types from client common; **does NOT import Cmd/DTO into Entity constructors** |
| **infrastructure** | domain | Implements domain Gateway interfaces; contains DO/Mapper |
| **app** | client, infrastructure | ServiceI from client; infrastructure for **read path** (see CQRS exception below) |
| **adapter** | app | Calls Application Service |
| **start** | adapter | Brings all modules together for bootstrap |

> **Read path pragmatic exception**: app depends on infrastructure so QryExe can access Mapper directly. This bypasses Domain for performance. The write path still follows strict dependency inversion (CmdExe → Domain Gateway → GatewayImpl). ArchUnit should enforce write-path compliance while allowing this read-path shortcut.

### 3. Client Jar Publishing

Other services consume your API via the client jar. Key practices:
- **Artifact name**: `${service-name}-client` (e.g., `demo-client`)
- **Version**: Follow the service version (e.g., `1.0.0-SNAPSHOT` during dev, `1.0.0` for release)
- **Deploy**: `mvn deploy` to shared Maven repository (Nexus/Artifactory)
- **Compatibility**: Minor version additions (new methods on ServiceI) are backward-compatible; breaking changes require major version bump or new interface
- **Consumer**: Other services add `<dependency><groupId>...</groupId><artifactId>demo-client</artifactId></dependency>` and inject FeignClient

> For multi-service version alignment, use a shared BOM or parent POM that declares all client jar versions.

### 4. Other Setup

- **Configuration**: PostgreSQL + Redis + MyBatis-Plus YAML in start module → see `mybatis-plus-patterns`
- **Nacos/Sentinel/OpenFeign**: See `spring-cloud-alibaba`
- **Docker Compose**: PostgreSQL + Redis → see `docker-expert`
- **mvnd + JDK 21 + Lombok**: Add `<forceLegacyJavacApi>true</forceLegacyJavacApi>` to maven-compiler-plugin → see `references/pom-templates.md`
- **External HTTP Client**: RestClient (Spring 6.1+) for `infrastructure/external/` → see `spring-boot-rest-client`
- **pom.xml templates**: Full pom for each module → see `references/pom-templates.md`

## Module Structure & Package Conventions

### client Module — API Contract + Common Types

The client module is published as a Maven dependency for other services to consume via Feign.

```
com.example.common.result/
├── Result.java                      # (existing — see spring-boot-rest-api-standards)
├── PageResult.java                  # (existing — see spring-boot-rest-api-standards)
com.example.common.exception/
├── BusinessException.java           # (existing — see spring-boot-exception-handling)
├── NotFoundException.java
├── ConflictException.java
com.example.common.dto/
├── Command.java                     # Write command marker (new — for CQRS identification)
├── Query.java                       # Read query marker (new — for CQRS identification)
com.example.api/
├── CustomerServiceI.java            # Service interface (returns Result<T>)
├── CustomerFeignClient.java         # @FeignClient — recommended pattern
com.example.dto/
├── CustomerAddCmd.java              # extends Command
├── CustomerListByNameQry.java       # extends Query
com.example.dto.data/
├── CustomerDTO.java                 # Data Transfer Object
com.example.dto.event/
├── CustomerCreatedEvent.java        # Domain event DTO
└── DomainEventConstant.java         # Event topic constants
```

> `Result`, `PageResult`, and `BusinessException` are project-wide conventions defined in `spring-boot-rest-api-standards` and `spring-boot-exception-handling`. They are placed in client `common/` packages so all modules (domain, app, adapter, infrastructure) can access them without pulling in Spring Boot starters. `Command` and `Query` are new marker base classes for CQRS identification.

**Feign Integration Pattern (recommended):**

```java
// api/CustomerServiceI.java
public interface CustomerServiceI {
    Result<Void> addCustomer(CustomerAddCmd cmd);
    Result<List<CustomerDTO>> listByName(CustomerListByNameQry qry);
}

// api/CustomerFeignClient.java
@FeignClient(name = "customer-service", path = "/customer")
public interface CustomerFeignClient extends CustomerServiceI {
}
```

> **When FeignClient extends ServiceI**: Only suitable when ALL ServiceI methods are external-facing. If ServiceI includes internal-only methods (e.g., batch processing triggered by scheduler), split into separate interfaces — keep `CustomerServiceI` for internal use, create `CustomerExternalApi` for Feign.

> **client stays lightweight**: No Spring Boot starter, no MyBatis-Plus, no COLA component deps. OpenFeign is `provided` scope. PageResult has an `of(Page<T>)` factory method that references MyBatis-Plus's `Page` class, but this is only used at runtime in infrastructure/app; client jar consumers who don't use MyBatis-Plus can still use PageResult's other constructors.

### adapter Module — HTTP Inbound

```
com.example.web/
├── CustomerController.java
```

Adapter is a routing layer — no business logic, no DTO conversion. Controller delegates to ServiceI directly. For detailed example → see `references/code-examples.md`.

### app Module — Application Layer

Organize by domain first, then by function.

```
com.example.customer/
├── CustomerServiceImpl.java           # Implements ServiceI, delegates to executors
└── executor/
    ├── CustomerAddCmdExe.java         # Write handler
    └── query/
        └── CustomerListByNameQryExe.java  # Read handler
```

**Service vs Executor:**

| Component | Package | Responsibility | Contains Logic? |
|-----------|---------|---------------|----------------|
| **Service** | `com.example.customer/` | Implements ServiceI; pure delegation to Executors | No |
| **CmdExe** | `executor/` | Write operations: converts Cmd → plain params, calls Domain | Yes (simple) / Delegates (complex) |
| **QryExe** | `executor/query/` | Read operations: queries Mapper directly, bypasses Domain | Yes |

> **CmdExe converts Cmd to Domain params**: Domain Entity receives plain parameters (not Cmd object). This keeps Domain decoupled from client DTOs. E.g., `Customer.create(cmd.getCompanyName(), cmd.getCustomerType())`, NOT `Customer.create(cmd)`.

> **All Executors use `execute()` as method name**: `CmdExe.execute(cmd)` and `QryExe.execute(qry)`. Service delegates by calling executor's `execute` method.

### domain Module — Domain Core

Organize by domain first, then by function. Gateway interfaces and domain services are sub-packages within each domain.

```
com.example.domain.customer/
├── Customer.java                      # Entity (@Data, bare name)
├── CustomerType.java                  # Enum
├── gateway/
    ├── CustomerGateway.java           # Persistence port
    └── CreditGateway.java             # External service port
├── domainservice/
    └── CreditChecker.java             # Cross-entity logic within domain
```

> **Domain Entity uses plain params in factory methods** — never receives client Cmd/DTO directly. This keeps Domain independent of the API contract.

> **Gateway is broader than Repository** — covers persistence AND external service access contracts. Define in Domain, implement in Infrastructure.

> **Domain entities do NOT inject Spring beans** — pure Java. Cross-entity logic goes in DomainService (`domainservice/`).

> Domain depends on client only for Result/BusinessException base types, NOT for Cmd/DTO input.

### infrastructure Module — Implementation

Flat per-domain package. No `gatewayimpl/` sub-package — everything related to a domain grouped together.

```
com.example.customer/
├── CustomerGatewayImpl.java
├── CreditGatewayImpl.java
├── CustomerDO.java                    # @TableName, @Data
├── CustomerMapper.java                # MyBatis-Plus Mapper
com.example.config/
└── AppConfig.java
com.example.external/
└── ExternalClientConfig.java          # RestClient/Feign config
```

> DO and Mapper conventions → see `mybatis-plus-patterns`. MapStruct converters → see `mapstruct-patterns`.

### start Module — Bootstrap

```
com.example/
├── Application.java                   # @SpringBootApplication @EnableDiscoveryClient @EnableFeignClients
resources/
├── application.yml                    # DB, Redis, MyBatis-Plus → see mybatis-plus-patterns
├── bootstrap.yml                      # Nacos config → see spring-cloud-alibaba
```

## CQRS Paths

| Type | Path | Notes |
|------|------|-------|
| **Command (Write)** | Controller → Service → CmdExe → Domain Entity → Gateway → GatewayImpl → Mapper → DB | CmdExe converts Cmd → plain params for Domain |
| **Query (Read)** | Controller → Service → QryExe → Mapper → DB | Pragmatic shortcut: bypasses Domain for performance |
| **Feign (Write)** | Other Service → FeignClient(ServiceI) → Controller → Service → CmdExe → Domain → Gateway → DB | Same internal path as HTTP |
| **Feign (Read)** | Other Service → FeignClient(ServiceI) → Controller → Service → QryExe → Mapper → DB | Read bypasses Domain |

> **Write path must follow dependency inversion**: CmdExe → Domain Gateway → Infrastructure GatewayImpl. Never CmdExe → Mapper directly for writes.
> **Read path pragmatic shortcut**: QryExe → Mapper directly. This is why app depends on infrastructure. For complex read logic that needs domain validation, QryExe can still go through Domain — it's a choice, not a rule.

## Dependency Direction & Enforcement

```
client (no internal deps)
    ↑
domain (depends on client — for Result/BusinessException only, NOT Cmd/DTO)
    ↑
infrastructure (depends on domain — implements Gateway interfaces)
    ↑
app (depends on client + infrastructure — read path pragmatic shortcut)
    ↑
adapter (depends on app)
    ↑
start (depends on adapter)
```

### ArchUnit Rules

Enforce dependency direction with ArchUnit tests in the start module:

```java
@AnalyzeClasses(packages = "com.example")
public class ColaArchitectureTest {

    @ArchTest
    static final ArchRule domain_no_app =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..app..")
            .because("domain must not depend on app — upward dependency breaks inversion");

    @ArchTest
    static final ArchRule domain_no_infrastructure =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..infrastructure..");

    @ArchTest
    static final ArchRule domain_no_client_dto =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..client.dto..")
            .because("domain must not depend on client Cmd/Qry/DTO — only Result/BusinessException allowed");

    @ArchTest
    static final ArchRule adapter_no_mapper =
        noClasses()
            .that().resideInAPackage("..adapter..")
            .should().dependOnClassesThat()
            .resideInAPackage("..infrastructure..");

    @ArchTest
    static final ArchRule write_path_uses_gateway =
        classes()
            .that().resideInAPackage("..executor..")
            .and().areNotAssignableTo(Query.class)
            .should().notDependOnClassesThat()
            .areAssignableTo(BaseMapper.class)
            .because("Write executors must go through Domain Gateway, not Mapper directly");
}
```

## Naming Per Module

| Module | Class Type | Suffix | Example |
|--------|-----------|--------|---------|
| client | Response Wrapper | none | `Result<T>`, `PageResult<T>` → see spring-boot-rest-api-standards |
| client | Business Exception | none | `BusinessException` + sub-classes → see spring-boot-exception-handling |
| client | Command Base | none | `Command` (abstract, marker) |
| client | Query Base | none | `Query` (abstract, marker) |
| client | Service Interface | I | `CustomerServiceI` |
| client | Feign Client | FeignClient | `CustomerFeignClient` |
| client | Command DTO | Cmd | `CustomerAddCmd` |
| client | Query DTO | Qry | `CustomerListByNameQry` |
| client | Data Transfer Object | DTO | `CustomerDTO` |
| client | Domain Event DTO | Event | `CustomerCreatedEvent` |
| adapter | Controller | Controller | `CustomerController` |
| app | Service Implementation | Impl | `CustomerServiceImpl` |
| app | Command Executor | CmdExe | `CustomerAddCmdExe` |
| app | Query Executor | QryExe | `CustomerListByNameQryExe` |
| domain | Entity | none | `Customer` (bare name, @Data) |
| domain | Value Object | none | `Credit` |
| domain | Enum | none | `CustomerType` |
| domain | Gateway | Gateway | `CustomerGateway` |
| domain | Domain Service | none or DomainService | `CreditChecker` or `OrderDomainService` |
| infrastructure | Gateway Implementation | GatewayImpl | `CustomerGatewayImpl` |
| infrastructure | Data Object | DO | `CustomerDO` |
| infrastructure | Mapper | Mapper | `CustomerMapper` |

> All Executor methods use `execute()` as the standard name: `CmdExe.execute(cmd)`, `QryExe.execute(qry)`.

## Data Flow

```
Write: Cmd (client) → CmdExe converts to plain params → Entity (domain) → Gateway → GatewayImpl → DO (infrastructure) → DB → Result<T>
Read:  Qry (client) → QryExe → Mapper (infrastructure) → DO → DTO (client) → Result<List<DTO>> or PageResult<DTO>
```

Conversion: MapStruct at each boundary → see `mapstruct-patterns`

## Best Practices

- Domain model is optional — COLA is application architecture, not strict DDD. For simple cases, logic in Executor + Gateway is sufficient; for complex domains, invest in rich entities. "无有必要勿增实体，不要为了DDD而DDD"
- Package structure: organize by domain first, then by function — `domain/customer/gateway/CustomerGateway.java`, not `domain/gateway/CustomerGateway.java`
- Domain entities are plain Java classes with **bare names** (no suffix); use `@Data` for convenience; Infrastructure DOs use **DO suffix**
- Domain Entity factory methods receive **plain parameters**, not Cmd objects — CmdExe converts Cmd → plain params for Domain
- Gateway `save()` = INSERT, `update()` = UPDATE — no ambiguity
- client module stays lightweight — no COLA component deps, no Spring Boot starter, no MyBatis runtime. OpenFeign `provided` scope
- ServiceI returns `Result<T>` and `PageResult<T>` — same as non-DDD services, no type system split
- FeignClient extends ServiceI only when all methods are external-facing. Split interfaces for internal-only methods
- Adapter is a routing layer — no business logic, Controller delegates to ServiceI
- Write path follows strict dependency inversion (CmdExe → Domain Gateway). Read path pragmatic shortcut (QryExe → Mapper directly)
- All Executor methods use `execute()` as standard name
- Use ArchUnit to enforce dependency direction — see `Dependency Direction & Enforcement`
- Use `@TableLogic(value = "", delval = "now()")` with `deleted_at TIMESTAMPTZ` → see `mybatis-plus-patterns`
- Use `@TableId(type = IdType.ASSIGN_ID)` for distributed ID → see `mybatis-plus-patterns`
- Use `LambdaQueryWrapper`, never raw `QueryWrapper` → see `mybatis-plus-patterns`
- Use MapStruct at layer boundaries → see `mapstruct-patterns`
- Do not add `@Transactional(readOnly = true)` on pure query methods → see `spring-boot-transaction-management`

## Related Skills

- `spring-cloud-alibaba` — Nacos, Sentinel, RocketMQ, OpenFeign — distributed infrastructure
- `spring-boot-rest-api-standards` — `Result<T>`, `PageResult<T>`, unified response pattern
- `spring-boot-exception-handling` — `BusinessException`, `ErrorCodes`, `GlobalExceptionHandler`
- `ddd-event-driven` — domain event design, event stores, aggregate boundaries
- `spring-boot-transaction-management` — @Transactional patterns for executor and service layer
- `spring-boot-rest-client` — RestClient for `infrastructure/external/`
- `mybatis-plus-patterns` — DO conventions, Mapper, soft delete, ID generation, pagination
- `mapstruct-patterns` — MapStruct converters for Domain ↔ DO and Domain ↔ DTO
- `spring-boot-dependency-injection` — constructor injection, Bean lifecycle

## References

- `references/pom-templates.md` — Full pom.xml for each module
- `references/code-examples.md` — Detailed code examples for each layer

## Keywords

cola, COLA architecture, COLA V5, DDD, microservice, spring cloud, multi-module, client, adapter, app, domain, infrastructure, feign, gateway, GatewayImpl, mapper, executor, Result, PageResult, BusinessException, dependency inversion, ArchUnit
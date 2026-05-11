---
name: ddd-cola
description: "COLA DDD Architecture: multi-module project structure (client/adapter/app/domain/infrastructure/start), Feign integration, Gateway pattern, CQRS. Use when creating or structuring a Spring Cloud microservice with COLA/DDD multi-module architecture. Do NOT use for simple MVC, non-microservice, or non-Java projects."
version: "2.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
parameters:
  - name: service_name
    description: "Service name (used as module prefix, e.g. 'demo' → demo-client, demo-adapter)"
    type: string
    required: true
  - name: base_package
    description: "Base Java package (e.g. 'com.example')"
    type: string
    required: true
  - name: use_feign
    description: "Whether the service exposes Feign client for inter-service calls"
    type: boolean
    required: false
    default: true
  - name: use_event_driven
    description: "Whether to include domain events (if true, also load ddd-event-driven skill)"
    type: boolean
    required: false
    default: false
  - name: architecture_type
    description: "Deployment architecture type (fixed: Spring Cloud)"
    type: string
    required: false
    default: "spring_cloud"
    constant: true
---

# COLA DDD Architecture

## When to use this skill

Use when creating or structuring a Spring Cloud microservice with COLA/DDD multi-module architecture, implementing domain-driven design with a client module for Feign API sharing.

**Do NOT use when:**
- Building a simple MVC/layered application without domain complexity → use `spring-boot-rest-api-standards`
- The project is not a Java/Spring Boot/Spring Cloud microservice
- Only adding a new endpoint to an existing non-COLA service → use the relevant module-specific skill

## Quick Guide

| Your scenario | What to do |
|---------------|-----------|
| Starting a new service? | Follow **Project Setup** → scaffold 6 modules per **Module Structure** |
| Adding a new use case? | Pick CQRS path: Write → CmdExe → Domain → Gateway; Read → QryExe → Mapper |
| Unsure about a module? | Client → Feign + ServiceI; Adapter → `spring-boot-rest-api-standards`; Domain → this skill's Gateway + Entity; Infrastructure → `mybatis-plus-patterns` |
| Confused about naming? | See **Naming Per Module** |
| Confused about data flow? | Cmd/Qry (client) → Entity (domain, plain params) → DO (infrastructure) → DB → Result<T> |
| Other service calling yours? | They depend on your `client` jar, inject FeignClient |
| Need domain events? | Use `ddd-event-driven` skill — see **Event Integration** below |
| Adding to existing COLA project? | See **Partial Module Addition** below |

## Official COLA vs Team Override

| Aspect | Official COLA (archetype-web) | Team Override | Reason |
|--------|-------------------------------|-------------|--------|
| Response types | `Response<T>` / `MultiResponse<T>` (cola-component-dto) | `Result<T>` / `PageResult<T>` | Project already uses Result across all services; avoid dual type systems |
| Exception types | `BizException` / `SysException` (cola-component-exception) | `BusinessException` + sub-classes | Project already uses BusinessException with int error codes |
| COLA component deps | Required (BOM, dto, exception, domain-starter) | None | Project uses self-defined types across all services; importing COLA components creates a dual type system and adds dependency on the COLA release cycle. COLA components are OSS but designed around HSF/Mtop patterns that don't apply to Spring Cloud |
| Domain entity annotation | `@Entity` (cola-component-domain-starter, prototype scope) | `@Data` (Lombok) | Lombok is lighter, already used in project; prototype scope rarely needed |
| Infrastructure package | `gatewayimpl/database/dataobject` at project root (`cola-samples/craftsman` style) | Domain-first + `craftsman`-style nesting: `customer/CustomerGatewayImpl.java` at domain root, with `customer/gatewayimpl/database/` and `customer/gatewayimpl/rpc/` sub-packages | Keeps all Customer infra co-located (domain-first); nested `database/dataobject` + `rpc/dataobject` cleanly separates heterogeneous data sources from day one; same internal nesting as `craftsman` sample but scoped per-domain instead of per-project |
| ServiceI return type | `Response` / `MultiResponse` | `Result<T>` / `PageResult<T>` | Same as non-DDD services; no type split |
| Cmd/Qry base | Extends COLA `Command` / `Query` | Extends self-defined `Command` / `Query` (in client `common.dto`) | No cola-component-dto dependency; marker classes serve the same CQRS identification purpose |
| Cmd field structure | `CustomerAddCmd` wraps nested `CustomerDTO` | `CustomerAddCmd` uses flat fields (`companyName`, `customerType`) | Flat fields are simpler for API consumers; nested DTO adds unnecessary wrapping for single-entity operations. For multi-entity or complex Cmd, nested DTO is still recommended |
| Query hierarchy | `Query extends Command` (cola-component-dto) | `Query` and `Command` are independent abstract classes | Decoupling Query from Command avoids semantic confusion — a read operation is not a write operation. Both remain Serializable marker classes |
| Validation API | `javax.validation-api` (Spring Boot 2.x) | `jakarta.validation-api` (Spring Boot 3.x) | Project uses Spring Boot 3.x / Jakarta EE 9+; javax is legacy |
| DI style | `@Autowired` / `@Resource` (official archetype) | Constructor injection via `@RequiredArgsConstructor` | Constructor injection is the Spring-recommended best practice; explicit, testable, immutable |
| Exception handling | `@CatchAndLog` (cola-component-catchlog-starter) on ServiceImpl | `GlobalExceptionHandler` (spring-boot-exception-handling skill) | Dropping COLA components means dropping catchlog; GlobalExceptionHandler provides equivalent centralized error handling |
| Gateway methods | `getByById(String customerId)` only (archetype sample) | `save()`, `update()`, `findById()` | Official sample is minimal; real services need CRUD operations. `save()` = INSERT, `update()` = UPDATE — no ambiguity |
| `scanBasePackages` | `{"${package}", "com.alibaba.cola"}` | Standard `@SpringBootApplication` (no cola scan) | No COLA component beans to scan; Spring Boot auto-detection suffices |

## COLA v5.x Scope

This skill targets **cola-archetype-web** (6-module distributed web archetype). `cola-archetype-light`, `cola-component-unittest`, and `cola-component-test-container` are excluded per Team Override. JDK 21 / Spring Boot 3.5.x is adopted — see pom-templates.md for version configuration.

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

The client module is published as a Maven dependency for other services to consume via Feign. **Cmd, Qry, and DTO all live in client** so that the API contract is self-contained — consumers can construct Cmd/Qry objects and deserialize DTO responses without depending on app/domain/infrastructure.

```
com.example.common.result/
├── Result.java                      # (existing — see spring-boot-rest-api-standards)
├── PageResult.java                  # (existing — see spring-boot-rest-api-standards)
com.example.common.exception/
├── BusinessException.java           # (existing — see spring-boot-exception-handling)
├── NotFoundException.java
├── ConflictException.java
com.example.common.dto/
├── Command.java                     # Write command marker (self-defined, not from cola-component-dto)
├── Query.java                       # Read query marker (self-defined; unlike COLA official, Query does NOT extend Command)
com.example.api/
├── CustomerServiceI.java            # Service interface (returns Result<T>)
├── CustomerFeignClient.java         # @FeignClient — recommended pattern
com.example.dto/
├── CustomerAddCmd.java              # extends Command
├── CustomerListByNameQry.java       # extends Query
com.example.dto.data/
├── CustomerDTO.java                 # Data Transfer Object
com.example.dto.event/
├── CustomerCreatedEvent.java        # Domain event DTO (for inter-service events)
└── DomainEventConstant.java         # Event topic constants
```

> `Result`, `PageResult`, and `BusinessException` are project-wide conventions defined in `spring-boot-rest-api-standards` and `spring-boot-exception-handling`. They are placed in client `common/` packages so all modules (domain, app, adapter, infrastructure) can access them without pulling in Spring Boot starters. `Command` and `Query` are self-defined marker base classes for CQRS identification. They are NOT from `cola-component-dto` — see Team Override table for details.

> **Cmd/Qry location**: Always in `client/dto/` — this is the canonical location. If a Cmd/Qry is purely internal (never sent by external callers), it may live in `app/`, but this should be the exception, not the default.

> **FeignClient extends ServiceI**: Only when ALL ServiceI methods are external-facing. If some are internal-only, split into separate interfaces. Code examples → see `references/code-examples.md`.

> **client stays lightweight**: No Spring Boot starter, no MyBatis-Plus, no COLA component deps. OpenFeign is `provided` scope. If strict client isolation is required, replace `PageResult.of(Page<T>)` with `PageResult.of(List<T>, long total)` that doesn't reference MyBatis types.

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

> CmdExe converts Cmd to **plain params** for Domain — Domain never receives client Cmd/DTO. All Executors use `execute()` as method name.

### domain Module — Domain Core

Organize by domain first, then by function. Gateway interfaces and domain services are sub-packages within each domain.

```
com.example.domain.customer/
├── Customer.java                      # Entity (@Data, bare name)
├── CustomerType.java                  # Enum
├── gateway/
│   ├── CustomerGateway.java           # Persistence port
│   └── CreditGateway.java             # External service port
├── domainservice/
│   └── CreditChecker.java             # Cross-entity logic within domain
```

> Domain depends on client only for Result/BusinessException base types, NOT for Cmd/DTO. Domain entities do NOT inject Spring beans — cross-entity logic goes in DomainService. Gateway covers persistence AND external service access — define in Domain, implement in Infrastructure.

### infrastructure Module — Implementation

**Domain-first with `craftsman`-style nested sub-packages**. Each domain is a top-level package; within each domain, use `gatewayimpl/database/dataobject` and `gatewayimpl/rpc/dataobject` to separate data sources by technology. `GatewayImpl` stays at the domain root as the facade.

```
com.example.customer/                    # domain-first: all Customer infra here
├── CustomerGatewayImpl.java             # domain-level facade — implements CustomerGateway
├── CreditGatewayImpl.java               # another Gateway impl for the same domain
└── gatewayimpl/
    ├── database/                        # persistence source
    │   ├── CustomerMapper.java          # MyBatis-Plus Mapper
    │   └── dataobject/
    │       └── CustomerDO.java          # @TableName, @Data
    └── rpc/                             # external RPC/HTTP source (optional)
        ├── CreditRpcClient.java         # RestClient / Feign wrapper
        └── dataobject/
            └── CreditRpcDO.java         # RPC response object
com.example.config/                      # cross-domain infra config (root-level)
└── AppConfig.java
com.example.external/                    # cross-domain external client config (root-level)
└── ExternalClientConfig.java            # shared RestClient/Feign bean config
```

**Rules**

- **GatewayImpl always at domain root** — it's the port-facing facade; technology details belong in `gatewayimpl/` sub-packages.
- **`gatewayimpl/database/dataobject`** holds all persistence artifacts (DO + Mapper) for the domain.
- **`gatewayimpl/rpc/dataobject`** holds all RPC artifacts (client + response DO) when the domain calls external services.
- **Add more sub-packages as needed** — e.g., `gatewayimpl/mq/` for message queue publishers/consumers.
- **Cross-domain config** stays at root (`com.example.config/`, `com.example.external/`) for shared beans used by multiple domains.

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

### Cross-Layer Contract Verification

**Before generating CmdExe that calls infrastructure Gateway/Client**:
1. Read the Gateway interface definition in domain layer
2. Read the GatewayImpl method signatures in infrastructure layer (or external client interface)
3. Ensure CmdExe calls match the actual method signatures — never assume parameters

**Contract verification rule**: CmdExe must read Gateway interface before calling. Never assume method signatures — always verify actual parameter types and order. Domain entities are NOT valid parameters for infrastructure clients (RestClient, Feign) — convert to primitive types or DTOs first.

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
    static final ArchRule adapter_no_infrastructure =
        noClasses()
            .that().resideInAPackage("..adapter..")
            .should().dependOnClassesThat()
            .resideInAPackage("..infrastructure..");

    @ArchTest
    static final ArchRule write_executors_no_infrastructure =
        noClasses()
            .that().haveSimpleNameNotContaining("QryExe")
            .and().haveSimpleNameContaining("CmdExe")
            .should().dependOnClassesThat()
            .resideInAPackage("..infrastructure..")
            .because("Write executors (CmdExe) must go through Domain Gateway, not infrastructure directly; QryExe bypasses Domain for read performance");
}
```

> **Package pattern**: This skill uses domain-first packages (`com.example.domain.customer`). The `..domain..`, `..adapter..` patterns match naturally. For app/infrastructure classes without layer-name in path, the `CmdExe`/`QryExe` simple-name pattern provides enforcement. For stricter enforcement, use ArchUnit's `layeredArchitecture()` API based on module classpath.

> **Rule correctness**: `write_executors_no_infrastructure` uses `.haveSimpleNameContaining("CmdExe").and().haveSimpleNameNotContaining("QryExe")` to target write executors precisely.

## Event Integration

When `use_event_driven` is true, load `ddd-event-driven` skill alongside this skill. Key integration points:

- **Simple events**: CmdExe publishes event after domain operation, event DTO in `client/dto/event/`. No `AggregateRoot` base class needed.
- **Rich domain events**: Domain entity extends `AggregateRoot` (from ddd-event-driven) instead of plain `@Data`. All other COLA conventions remain the same.
- **Event sourcing + projections**: Use `ddd-event-driven` full model with outbox table in infrastructure.

See `ddd-event-driven` skill for complete event design patterns.

## Partial Module Addition

When adding a new domain to an existing COLA project:

1. **client**: Add new `XxxServiceI`, `XxxCmd`, `XxxQry`, `XxxDTO`, (optional) `XxxFeignClient`
2. **adapter**: Add new `XxxController`
3. **app**: Add new `XxxServiceImpl`, `XxxCmdExe`, `XxxQryExe`
4. **domain**: Add new `Xxx` entity, `XxxGateway` interface, (optional) `XxxDomainService`
5. **infrastructure**: Create new domain package `xxx/` with:
   - `XxxGatewayImpl.java` at domain root (facade)
   - `gatewayimpl/database/`: `XxxMapper.java`
   - `gatewayimpl/database/dataobject/`: `XxxDO.java`
   - (optional) `gatewayimpl/rpc/` + `gatewayimpl/rpc/dataobject/` when calling external services
   - (optional) `XxxDOConverter` for read path (in app module)

No need to modify existing domains' files. Module pom.xml dependencies are already correct.

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
Read:  Qry (client) → QryExe → Mapper (infrastructure) → DO → DOConverter.toDTO() → DTO (client) → Result<List<DTO>> or PageResult<DTO>
```

Conversion: MapStruct at each boundary → see `mapstruct-patterns`

## Best Practices

- Domain model is optional — COLA is application architecture, not strict DDD. "Do not multiply entities beyond necessity; do not force DDD where it is not needed"
- Package structure: organize by domain first, then by function
- Domain entities: bare names with `@Data`; Infrastructure DOs: **DO suffix**
- Gateway `save()` = INSERT, `update()` = UPDATE
- FeignClient extends ServiceI only when all methods are external-facing
- Use ArchUnit to enforce dependency direction
- Use `@TableLogic(value = "", delval = "now()")` with `deleted_at TIMESTAMPTZ` → see `mybatis-plus-patterns`
- Use `@TableId(type = IdType.ASSIGN_ID)` for distributed ID → see `mybatis-plus-patterns`
- Use `LambdaQueryWrapper`, never raw `QueryWrapper` → see `mybatis-plus-patterns`
- Use MapStruct at layer boundaries → see `mapstruct-patterns`
- Do not add `@Transactional(readOnly = true)` on pure query methods → see `spring-boot-transaction-management`

## Related Skills

- `spring-cloud-alibaba` — Nacos, Sentinel, RocketMQ, OpenFeign — distributed infrastructure
- `spring-boot-rest-api-standards` — `Result<T>`, `PageResult<T>`, unified response pattern
- `spring-boot-exception-handling` — `BusinessException`, `ErrorCodes`, `GlobalExceptionHandler`
- `ddd-event-driven` — domain event design, event sourcing, CQRS with projections, AggregateRoot pattern
- `spring-boot-transaction-management` — @Transactional patterns for executor and service layer
- `spring-boot-rest-client` — RestClient for `infrastructure/external/`
- `mybatis-plus-patterns` — DO conventions, Mapper, soft delete, ID generation, pagination
- `mapstruct-patterns` — MapStruct converters for Domain ↔ DO and Domain ↔ DTO
- `spring-boot-dependency-injection` — constructor injection, Bean lifecycle

## References

- `references/pom-templates.md` — Full pom.xml for each module
- `references/code-examples.md` — Detailed code examples for each layer

## Keywords

cola, COLA architecture, COLA 4.x, COLA 5.x, cola-archetype-web, DDD, domain-driven design, microservice, spring cloud, multi-module, client, adapter, app, domain, infrastructure, feign, gateway, GatewayImpl, mapper, executor, Result, PageResult, BusinessException, dependency inversion, ArchUnit, CQRS, CmdExe, QryExe

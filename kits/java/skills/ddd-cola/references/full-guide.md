---
name: ddd-cola
description: "COLA DDD Architecture: multi-module project structure (common/client/adapter/app/domain/infrastructure/start), Feign integration, Gateway pattern, CQRS. Use when creating or structuring a Spring Cloud microservice with COLA/DDD multi-module architecture. Do NOT use for simple MVC, non-microservice, or non-Java projects."
version: "2.2.0"
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
| Starting a new service? | Follow **Project Setup** → scaffold 7 modules per **Module Structure** (common/client/adapter/app/domain/infrastructure/start) |
| Adding a new use case? | Pick CQRS path: Write → CmdExe → DtoVoConvertor → Domain → Gateway; Read → QryExe → Mapper |
| Unsure about a module? | Common → shared kernel types; Client → Feign + ServiceI + flat DTOs; Adapter → `spring-boot-rest-api-standards`; Domain → this skill's Gateway + Entity + VO; Infrastructure → `mybatis-plus-patterns` |
| Confused about naming? | See **Naming Per Module** |
| Confused about data flow? | Cmd/Qry (client) → VO (domain via DtoVoConvertor) → DO (infrastructure via DomainConverter) → DB → Result<T> |
| DTO vs VO for the same concept? | Flat `XxxDTO` in client (serializable, no behavior) + rich `Xxx` VO in domain (behavior); app `DtoVoConvertor` bridges them |
| Other service calling yours? | They depend on your `client` jar (which transitively pulls `common`), inject FeignClient |
| Need domain events? | Use `ddd-event-driven` skill — see **Event Integration** below |
| Adding to existing COLA project? | See **Partial Module Addition** below |

## Official COLA vs Team Override

| Aspect | Official COLA (archetype-web) | Team Override | Reason |
|--------|-------------------------------|-------------|--------|
| Module count | 6 modules (client/adapter/app/domain/infrastructure/start) | 7 modules — add `common` as shared kernel | Official COLA uses `cola-component-dto` + `cola-component-exception` as shared kernel. We don't import those, so we carve out a local `common` module. Keeps `client` and `domain` as leaf modules with zero edge between them (matches `cola-samples/craftsman` where `craftsman-client` and `craftsman-domain` are both leaves) |
| Response types | `Response<T>` / `MultiResponse<T>` (cola-component-dto) | `Result<T>` / `PageResult<T>` (in `common`) | Project already uses Result across all services; avoid dual type systems |
| Exception types | `BizException` / `SysException` (cola-component-exception) | `BusinessException` + sub-classes (in `common`) | Project already uses BusinessException with int error codes |
| COLA component deps | Required (BOM, dto, exception, domain-starter) | None — replaced by local `common` module | Project uses self-defined types across all services; importing COLA components creates a dual type system and adds dependency on the COLA release cycle. COLA components are OSS but designed around HSF/Mtop patterns that don't apply to Spring Cloud |
| Domain entity annotation | `@Entity` (cola-component-domain-starter, prototype scope) | `@Data` (Lombok) | Lombok is lighter, already used in project; prototype scope rarely needed |
| Infrastructure package | `gatewayimpl/database/dataobject` at project root (`cola-samples/craftsman` style) | Domain-first + `craftsman`-style nesting: `customer/CustomerGatewayImpl.java` at domain root, with `customer/gatewayimpl/database/` and `customer/gatewayimpl/rpc/` sub-packages | Keeps all Customer infra co-located (domain-first); nested `database/dataobject` + `rpc/dataobject` cleanly separates heterogeneous data sources from day one; same internal nesting as `craftsman` sample but scoped per-domain instead of per-project |
| ServiceI return type | `Response` / `MultiResponse` | `Result<T>` / `PageResult<T>` | Same as non-DDD services; no type split |
| Cmd/Qry base | Extends COLA `Command` / `Query` | Extends self-defined `Command` / `Query` (in `common`) | No cola-component-dto dependency; marker classes serve the same CQRS identification purpose |
| Cmd field structure | `CustomerAddCmd` wraps nested `CustomerDTO` | `CustomerAddCmd` uses flat fields (`companyName`, `customerType`) | Flat fields are simpler for API consumers; nested DTO adds unnecessary wrapping for single-entity operations. For multi-entity or complex Cmd, nested DTO is still recommended |
| Value objects | Live in domain; client has no VO knowledge | DTO in `client` (flat, serializable), VO in `domain` (behavior-carrying); app `DtoVoConvertor` bridges them | When a complex structure (ConditionGroup, RewardSpec, StepDefinition) must cross the API boundary, defining two types keeps `client` and `domain` independent — which is the only way to keep them as leaf modules |
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

COLA archetype-web pattern adapted with a local `common` shared-kernel module — 7 Maven modules under a parent POM:

```
demo-parent/
├── demo-common/           # Shared kernel: Result, PageResult, BusinessException, Command, Query, ErrorCode
├── demo-client/           # API interfaces, Cmd/Qry/DTO (flat), Feign clients
├── demo-adapter/          # HTTP inbound (Controllers)
├── demo-app/              # Application services, executors, DTO↔VO Convertor
├── demo-domain/           # Domain entities, value objects (with behavior), Gateways, domain services
├── demo-infrastructure/   # Gateway implementations, Mappers, external clients
└── demo-start/            # Bootstrap (Application.java + config)
```

### 2. Module Dependencies

```
start → adapter → app → {client → common, infrastructure → domain → common}
```

| Module | Depends On | Reason |
|--------|-----------|--------|
| **common** | lombok(provided) | Pure Java shared kernel. No framework deps. Both client and domain depend on it |
| **client** | common, jakarta.validation-api, lombok, openfeign(provided) | Pure API contract — Cmd/Qry/DTO with flat fields. Never references domain types. OpenFeign `provided` scope — consumers bring their own runtime |
| **domain** | common, lombok(provided) | Pure domain core. Value objects carry behavior. Leaf module; does NOT depend on client |
| **infrastructure** | domain | Implements domain Gateway interfaces; contains DO/Mapper. Transitively gets common |
| **app** | client, infrastructure | ServiceI from client; infrastructure for **read path** (see CQRS exception below). Transitively gets common and domain. Hosts `DtoVoConvertor` (DTO ↔ domain VO) |
| **adapter** | app | Calls Application Service |
| **start** | adapter | Brings all modules together for bootstrap |

> **Read path pragmatic exception**: app depends on infrastructure so QryExe can access Mapper directly. This bypasses Domain for performance. The write path still follows strict dependency inversion (CmdExe → Domain Gateway → GatewayImpl). ArchUnit should enforce write-path compliance while allowing this read-path shortcut.

> **Why `common` exists**: The official COLA samples use `cola-component-dto` and `cola-component-exception` as a shared kernel so that `craftsman-client` and `craftsman-domain` can both be leaf modules. We don't import those COLA components, so we carve out an equivalent local module. Without it, either `domain` has to depend on `client` (breaks DDD) or `client` has to depend on `domain` (breaks API contract independence).

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

### common Module — Shared Kernel

The `common` module holds framework-neutral types that both `client` and `domain` need. It has no Spring, no MyBatis, no Jackson — pure Java + Lombok. This is the only way to keep `client` and `domain` as independent leaf modules.

```
com.example.common.result/
├── Result.java                      # (existing — see spring-boot-rest-api-standards)
└── PageResult.java                  # (existing — see spring-boot-rest-api-standards)
com.example.common.exception/
├── BusinessException.java           # (existing — see spring-boot-exception-handling)
├── NotFoundException.java
├── ConflictException.java
└── ErrorCode.java                   # int-based error code enum
com.example.common.dto/
├── Command.java                     # Write command marker (self-defined, not from cola-component-dto)
└── Query.java                       # Read query marker (self-defined; unlike COLA official, Query does NOT extend Command)
```

> These types are placed in `common` so all modules (client, domain, app, adapter, infrastructure) can access them without pulling in Spring Boot starters. `Command` and `Query` are self-defined marker base classes for CQRS identification — NOT from `cola-component-dto`.

### client Module — API Contract

The client module is published as a Maven dependency for other services to consume via Feign. **Cmd, Qry, and DTO all live in client with flat fields** so that the API contract is self-contained — consumers can construct Cmd/Qry objects and deserialize DTO responses without depending on app/domain/infrastructure.

```
com.example.api/
├── CustomerServiceI.java            # Service interface (returns Result<T>)
├── CustomerFeignClient.java         # @FeignClient — recommended pattern
com.example.dto/
├── CustomerAddCmd.java              # extends Command (from common)
├── CustomerListByNameQry.java       # extends Query (from common)
com.example.dto.data/
├── CustomerDTO.java                 # Data Transfer Object (flat fields, client-side enums only)
├── ConditionGroupDTO.java           # Complex structure DTO — flat, serializable, NO behavior
├── RewardSpecDTO.java
com.example.dto.event/
├── CustomerCreatedEvent.java        # Domain event DTO (for inter-service events)
└── DomainEventConstant.java         # Event topic constants
```

> **Client DTO discipline**: DTO fields use primitives, Strings, collections, and client-side enums only. They NEVER reference domain value objects. When a complex structure like `ConditionGroup` must cross the API boundary, define `ConditionGroupDTO` here (flat, @Data, no methods) and a behavior-carrying `ConditionGroup` VO in `domain`. App `DtoVoConvertor` bridges the two.

> **Cmd/Qry location**: Always in `client/dto/` — this is the canonical location. If a Cmd/Qry is purely internal (never sent by external callers), it may live in `app/`, but this should be the exception, not the default.

> **FeignClient extends ServiceI**: Only when ALL ServiceI methods are external-facing. If some are internal-only, split into separate interfaces. Code examples → see `references/code-examples.md`.

> **client stays lightweight**: Depends on `common` + jakarta.validation + lombok(provided) + openfeign(provided) + swagger(provided). No Spring Boot starter, no MyBatis-Plus, no COLA component deps. `PageResult` only exposes `PageResult.of(List<T> records, long total, long page, long pageSize)` — it does not depend on MyBatis-Plus `Page<T>`. App/infrastructure callers destructure MP's `Page` at the call site (`records / total / current / size`) and pass them into `PageResult.of(...)`.

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
├── convertor/
│   └── CustomerDtoVoConvertor.java    # MapStruct — DTO ↔ Domain VO (e.g., ConditionGroupDTO ↔ ConditionGroup)
└── executor/
    ├── CustomerAddCmdExe.java         # Write handler — uses Convertor before calling Domain
    └── query/
        └── CustomerListByNameQryExe.java  # Read handler
```

**Service vs Executor:**

| Component | Package | Responsibility | Contains Logic? |
|-----------|---------|---------------|----------------|
| **Service** | `com.example.customer/` | Implements ServiceI; pure delegation to Executors | No |
| **CmdExe** | `executor/` | Write operations: converts Cmd → Domain VO via Convertor, calls Domain | Yes (simple) / Delegates (complex) |
| **QryExe** | `executor/query/` | Read operations: queries Mapper directly, bypasses Domain | Yes |
| **Convertor** | `convertor/` | MapStruct bridge between client DTO and domain VO; decouples API contract from domain model | No (pure mapping) |

> CmdExe converts Cmd to **plain params or Domain VOs** for Domain — Domain never receives client Cmd/DTO directly. All Executors use `execute()` as method name.

### domain Module — Domain Core

Organize by domain first, then by function. Gateway interfaces, value objects, and domain services are sub-packages within each domain.

```
com.example.domain.customer/
├── Customer.java                      # Entity (@Data, bare name)
├── CustomerType.java                  # Enum
├── vo/
│   ├── ConditionGroup.java            # Value object with behavior (matches, evaluate, etc.)
│   ├── RewardSpec.java
│   └── StepDefinition.java
├── gateway/
│   ├── CustomerGateway.java           # Persistence port
│   └── CreditGateway.java             # External service port
├── domainservice/
│   └── CreditChecker.java             # Cross-entity logic within domain
```

> **Domain is a leaf module**. It depends only on `common` (for Result/BusinessException/ErrorCode) and Lombok. It does NOT depend on `client`. Domain entities do NOT inject Spring beans — cross-entity logic goes in DomainService. Gateway covers persistence AND external service access — define in Domain, implement in Infrastructure.

> **Domain VOs vs client DTOs**: When the same conceptual structure (e.g., `ConditionGroup`) must appear on both API contract and inside the domain model, define both — `ConditionGroupDTO` in client (flat, no behavior) and `ConditionGroup` in domain (rich, with behavior like `matches()`, `evaluate()`). App `DtoVoConvertor` maps between them. This is how we keep client and domain as independent leaves.

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
| **Command (Write)** | Controller → Service → CmdExe → DtoVoConvertor (DTO→VO) → Domain Entity → Gateway → GatewayImpl → DomainConverter (Domain→DO) → Mapper → DB | CmdExe converts Cmd fields/nested DTOs into Domain VOs via the app-module Convertor |
| **Query (Read)** | Controller → Service → QryExe → Mapper → DOConverter (DO→DTO) → DB | Pragmatic shortcut: bypasses Domain for performance |
| **Feign (Write)** | Other Service → FeignClient(ServiceI) → Controller → Service → CmdExe → DtoVoConvertor → Domain → Gateway → DB | Same internal path as HTTP |
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
common (no internal deps; pure Java + Lombok)
   ↑                  ↑
client (depends on common only — leaf)        domain (depends on common only — leaf)
                      ↑
              infrastructure (depends on domain — implements Gateway interfaces)
                      ↑
                     app (depends on client + infrastructure — read path pragmatic shortcut; hosts DtoVoConvertor)
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
    static final ArchRule domain_no_client =
        noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat()
            .resideInAPackage("..client..")
            .orShould().dependOnClassesThat().resideInAPackage("..dto..")
            .because("domain is a leaf module; it must never reference client API contracts. Use common module for shared types.");

    @ArchTest
    static final ArchRule client_no_domain =
        noClasses()
            .that().resideInAPackage("..client..")
            .or().resideInAPackage("..api..")
            .should().dependOnClassesThat()
            .resideInAPackage("..domain..")
            .because("client is a leaf module; API contract must not leak domain types. Define flat DTOs in client and use DtoVoConvertor in app.");

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

1. **common**: Add new `ErrorCode` entries if needed. Usually no changes — shared kernel is stable
2. **client**: Add new `XxxServiceI`, `XxxCmd`, `XxxQry`, `XxxDTO` (flat), (optional) `XxxFeignClient`. If the new domain needs a complex structure in its API, also add `XxxConfigDTO` (flat, serializable)
3. **adapter**: Add new `XxxController`
4. **app**: Add new `XxxServiceImpl`, `XxxCmdExe`, `XxxQryExe`, (optional) `XxxDtoVoConvertor` if the domain has VO-bearing DTOs
5. **domain**: Add new `Xxx` entity, `XxxGateway` interface, (optional) `vo/XxxConfig` value object with behavior, (optional) `XxxDomainService`
6. **infrastructure**: Create new domain package `xxx/` with:
   - `XxxGatewayImpl.java` at domain root (facade)
   - `gatewayimpl/database/`: `XxxMapper.java`, `XxxDomainConverter.java`
   - `gatewayimpl/database/dataobject/`: `XxxDO.java`
   - (optional) `gatewayimpl/rpc/` + `gatewayimpl/rpc/dataobject/` when calling external services

No need to modify existing domains' files. Module pom.xml dependencies are already correct.

## Naming Per Module

| Module | Class Type | Suffix | Example |
|--------|-----------|--------|---------|
| common | Response Wrapper | none | `Result<T>`, `PageResult<T>` → see spring-boot-rest-api-standards |
| common | Business Exception | none | `BusinessException` + sub-classes → see spring-boot-exception-handling |
| common | Error Code | none | `ErrorCode` (enum or int constants) |
| common | Command Base | none | `Command` (abstract, marker) |
| common | Query Base | none | `Query` (abstract, marker) |
| client | Service Interface | I | `CustomerServiceI` |
| client | Feign Client | FeignClient | `CustomerFeignClient` |
| client | Command DTO | Cmd | `CustomerAddCmd` |
| client | Query DTO | Qry | `CustomerListByNameQry` |
| client | Data Transfer Object | DTO | `CustomerDTO`, `ConditionGroupDTO` (flat, no domain refs) |
| client | Domain Event DTO | Event | `CustomerCreatedEvent` |
| adapter | Controller | Controller | `CustomerController` |
| app | Service Implementation | Impl | `CustomerServiceImpl` |
| app | Command Executor | CmdExe | `CustomerAddCmdExe` |
| app | Query Executor | QryExe | `CustomerListByNameQryExe` |
| app | DTO↔VO Converter | DtoVoConvertor | `CustomerDtoVoConvertor` (MapStruct) |
| domain | Entity | none | `Customer` (bare name, @Data) |
| domain | Value Object | none | `ConditionGroup`, `RewardSpec`, `Credit` |
| domain | Enum | none | `CustomerType` |
| domain | Gateway | Gateway | `CustomerGateway` |
| domain | Domain Service | none or DomainService | `CreditChecker` or `OrderDomainService` |
| infrastructure | Gateway Implementation | GatewayImpl | `CustomerGatewayImpl` |
| infrastructure | Domain↔DO Converter | DomainConverter | `CustomerDomainConverter` (MapStruct) |
| infrastructure | Data Object | DO | `CustomerDO` |
| infrastructure | Mapper | Mapper | `CustomerMapper` |

> All Executor methods use `execute()` as the standard name: `CmdExe.execute(cmd)`, `QryExe.execute(qry)`.

## Data Flow

```
Write: Cmd (client) → CmdExe → DtoVoConvertor (app, DTO→VO) → Entity/VO (domain) → Gateway → GatewayImpl → DomainConverter (infra, Domain→DO) → DO (infrastructure) → DB → Result<T>
Read:  Qry (client) → QryExe → Mapper (infrastructure) → DO → DOConverter.toDTO() → DTO (client) → Result<List<DTO>> or PageResult<DTO>
```

Conversion has two boundaries:
- App `DtoVoConvertor` (MapStruct) — flat client DTO ↔ behavior-carrying domain VO. Lives in app because app is the only module that knows both client and domain.
- Infrastructure `DomainConverter` (MapStruct) — domain Entity/VO ↔ DO. Lives in infrastructure.

→ see `mapstruct-patterns`

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

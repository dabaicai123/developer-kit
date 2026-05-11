---
name: mybatis-plus-generator
description: "MyBatis-Plus code generation from database tables: DO, Mapper, Service, Controller, DTO, VO with MVC and DDD/COLA architectures. Use when scaffolding MyBatis-Plus CRUD code from existing database tables."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# MyBatis-Plus Generator

## When to use this skill

Use when scaffolding MyBatis-Plus CRUD code from existing database tables. For manually writing or editing individual modules, use `mybatis-plus-patterns` instead. Do NOT trigger for generic code generation, JPA/Hibernate, or other ORM frameworks.

Supported: MVC / DDD/COLA / Layered / Clean architectures; Java and Kotlin.

## Spring Boot 3.x Dependency

Runtime dependencies: see `mybatis-plus-patterns` for `mybatis-plus-spring-boot3-starter` and `mybatis-plus-jsqlparser`. Generator dependency (separate from runtime):

```xml
<dependency>
    <groupId>com.baomidou</groupId>
    <artifactId>mybatis-plus-generator</artifactId>
    <version>3.5.9</version>
</dependency>
<dependency>
    <groupId>org.freemarker</groupId>
    <artifactId>freemarker</artifactId>
    <version>2.3.32</version>
</dependency>
```

> **MySQL driver**: Use `com.mysql.cj.jdbc.Driver` (not `com.mysql.jdbc.Driver`, removed in Connector/J 8.x).

## FastAutoGenerator Builder API (Recommended)

The official API uses `FastAutoGenerator` with builder pattern (preferred over legacy `AutoGenerator` setter pattern):

```java
FastAutoGenerator.create("jdbc:postgresql://localhost:5432/mydb", "user", "password")
    .globalConfig(builder -> {
        builder.author("Your Name")
            .outputDir(projectPath + "/src/main/java")
            .disableOpenDir();
    })
    .packageConfig(builder -> {
        builder.parent("com.example")
            .moduleName("app")
            .entity("domain.model.entity")
            .mapper("infrastructure.mapper")
            .service("service")
            .serviceImpl("service.impl")
            .controller("adapter.web")
            .pathInfo(Collections.singletonMap(OutputFile.xml,
                projectPath + "/src/main/resources/mapper"));
    })
    .strategyConfig(builder -> {
        builder.addInclude("user", "order")
            .addTablePrefix("tbl_")
            .entityBuilder()
            .enableLombok()
            .enableTableFieldAnnotation()
            .idType(IdType.ASSIGN_ID)
            .logicDeleteColumnName("deleted_at")
            .versionColumnName("version")
            .addTableFills(new Column("created_at", FieldFill.INSERT))
            .addTableFills(new Property("updatedAt", FieldFill.INSERT_UPDATE))
            .controllerBuilder()
            .enableRestStyle()
            .enableHyphenStyle()
            .serviceBuilder()
            .formatServiceFileName("%sService")
            .formatServiceImplFileName("%sServiceImpl");
    })
    .injectionConfig(builder -> {
        // Generate DTO/VO/BO via CustomFile.Builder (see Custom Artifact Generation below)
        builder.customFile(new CustomFile.Builder()
            .fileName("entityDTO.java")
            .templatePath("templates/entityDTO.java.ftl")
            .packageName("dto")
            .build());
    })
    .templateEngine(new FreemarkerTemplateEngine())
    .execute();
```

### Custom Artifact Generation (DTO/VO/BO/Cmd)

Since 3.5.3, the `CustomFile.Builder` API generates additional artifact types:

```java
FastAutoGenerator.create(url, username, password)
    .injectionConfig(injectConfig -> {
        // Inject custom template variables (accessible via ${cfg.xxx} in templates)
        Map<String, Object> customMap = new HashMap<>();
        customMap.put("enableSwagger", true);
        injectConfig.customMap(customMap);

        // Generate DTO
        injectConfig.customFile(new CustomFile.Builder()
            .fileName("entityDTO.java")
            .templatePath("templates/entityDTO.java.ftl")
            .packageName("dto")
            .build());

        // Generate VO
        injectConfig.customFile(new CustomFile.Builder()
            .fileName("entityVO.java")
            .templatePath("templates/entityVO.java.ftl")
            .packageName("vo")
            .build());
    })
    .templateEngine(new FreemarkerTemplateEngine())
    .execute();
```

> **OpenAPI 3 annotations**: The generator's `enableSwagger()` adds Swagger annotations. For Spring Boot 3.x, use custom FreeMarker templates that generate OpenAPI 3 annotations (`@Schema`, `@Tag`, `@Operation`) instead. Use `springdoc-openapi-starter-webmvc-ui` dependency. See `spring-boot-openapi-documentation` for complete configuration.

### IFileCreate — Protecting Existing Custom Code

When re-running the generator, use `IFileCreate` to prevent overwriting manually customized files:

```java
InjectionConfig injectionConfig = new InjectionConfig() {
    @Override
    public IFileCreate getFileCreate() {
        return new IFileCreate() {
            @Override
            public boolean isCreate(File file) {
                return !file.exists() || file.length() == 0;  // skip if file already has content
            }
        };
    }
};
```

Run the generator once for initial scaffolding, then manually customize. Never re-run on modified files without `IFileCreate`.

## Architecture-Specific Generation

### MVC Architecture

Standard MVC mapping — generates Entity, Mapper, Service/ServiceImpl, Controller, DTO/VO/BO in flat packages.

**Package mapping (MVC)**:

| Artifact | Package | Suffix |
|---|---|---|
| Entity | `entity` | none |
| Mapper | `mapper` | Mapper |
| Service | `service` | Service |
| ServiceImpl | `service.impl` | ServiceImpl |
| Controller | `controller` | Controller |
| DTO | `dto` | DTO |
| VO | `vo` | VO |
| BO | `bo` | BO |

### DDD/COLA Architecture

The generator **cannot natively produce** COLA's 4-layer structure. Generate COLA code by:

1. Use `CustomFile.Builder` to generate files into each COLA layer
2. Create custom FreeMarker templates for each COLA artifact type
3. Use `pathInfo` to route files to the correct package directories

**COLA artifact mapping** (aligned with `ddd-cola` — `{domain}` is the domain name, e.g. `user`, `customer`):

| COLA Artifact | Package | Suffix | Notes |
|---|---|---|---|
| Domain Entity | `domain.{domain}` (domain module) | none (bare name) | `@Data`, no ORM annotations |
| DO | `{domain}.gatewayimpl.database.dataobject` (infrastructure module) | DO | Full MyBatis-Plus annotations (@TableName, @TableId, @TableLogic, @Version) |
| Mapper | `{domain}.gatewayimpl.database` (infrastructure module) | Mapper | extends `BaseMapper<XxxDO>` |
| Gateway (port) | `domain.{domain}.gateway` | Gateway | Interface — `save()`, `update()`, `findById()` |
| GatewayImpl | `{domain}` (infrastructure module, domain root) | GatewayImpl | Implements Gateway, uses Mapper + DomainConverter |
| ServiceI | `api` (client module) | ServiceI | Application service interface, returns `Result<T>` |
| ServiceImpl | `{domain}` (app module) | ServiceImpl | implements ServiceI, delegates to executors |
| CmdExe | `{domain}.executor` (app module) | CmdExe | Write handler — Domain → Gateway |
| QryExe | `{domain}.executor.query` (app module) | QryExe | Read handler — Mapper directly |
| Controller | `web` (adapter module, flat) | Controller | REST API |
| Cmd / Qry | `dto` (client module) | Cmd (extends Command) / Qry (extends Query) | Marker base classes are self-defined in `common.dto` |
| DTO | `dto.data` (client module) | DTO | Response objects |

**Type Mapping Rule**: When generating Cmd/Qry DTOs, field types MUST match the corresponding DO field types derived from schema:
- Schema `BIGINT` → DO `Long` → Cmd/Qry `Long` (NOT `String`)
- Schema `INTEGER` → DO `Integer` → Cmd/Qry `Integer`
- Schema `TEXT` → DO `String` → Cmd/Qry `String`
- Schema `NUMERIC(p,s)` → DO `BigDecimal` → Cmd/Qry `BigDecimal`
- Schema `BOOLEAN` → DO `Boolean` → Cmd/Qry `Boolean`
- Schema `TIMESTAMPTZ` → DO `LocalDateTime` → Cmd/Qry `LocalDateTime`

Never guess field types — always reference the schema column type or the generated DO field type.
| Converter (DO ↔ Domain) | `{domain}` (infrastructure module) | DomainConverter | MapStruct interface — see `mapstruct-patterns` |
| Converter (DO → DTO) | `{domain}` (app module) | DOConverter | MapStruct interface |

**Key distinction**: Domain entities use **bare names** (no suffix, no ORM annotations), while infrastructure DOs use the **DO suffix** with full MyBatis-Plus annotations. The generator's default entity template produces DO-style classes; you need a custom template for bare-name domain entities.

**CQRS paths**: Write → Controller → ServiceI → CmdExe → Domain → Gateway → DB. Read → Controller → ServiceI → QryExe → Mapper → DB. See `ddd-cola` for detailed explanation.

### Kotlin Support Note

MyBatis-Plus generator has **no official Kotlin template engine**. Kotlin generation requires custom FreeMarker templates with Kotlin syntax (data classes, companion objects, val/var) and `.kt` file extension via `CustomFile.Builder`. The `.kt.ftl` templates in this skill are community-driven.

## How to use this skill

### Step 1: Collect Input

Collect: (1) Database connection URL or table structure, (2) architecture type (MVC, DDD/COLA, Layered, Clean, Custom), (3) language (Java or Kotlin), (4) functional requirements per table. Enable OpenAPI 3 annotations when API documentation is requested.

**CRITICAL — Schema Verification**: For each table, read the EXACT column list from the provided schema (SQL DDL or database introspection). Do NOT assume common columns exist across all tables. Generate DO fields ONLY for columns that actually exist in the schema. Never use a "common template" that assumes all tables have the same columns (e.g., assuming all config tables have `status` when the schema doesn't define it).

### Step 2: Map Directories

After determining architecture, map output directories. For COLA, see `ddd-cola` skill for the complete layer structure. Confirm directory structure with user before generating code.

### Step 3: Configure FastAutoGenerator

Configure builder with: global settings (author, output dir, Lombok), package paths (per architecture), strategy (table names, naming, ID type, soft delete, optimistic lock), and injection config for custom artifacts via `CustomFile.Builder`.

### Step 4: Protect Existing Code

When re-running, use `IFileCreate` to prevent overwriting manually customized files. Run once for initial scaffolding, then manually customize.

## Templates

Templates use **FreeMarker** syntax (`.ftl` files). See `references/template-variables.md` for variable list.

### Standard Templates (MVC)

Java: `entity.java.ftl`, `mapper.java.ftl`, `service.java.ftl`, `serviceImpl.java.ftl`, `controller.java.ftl`, `dto.java.ftl`, `vo.java.ftl`, `bo.java.ftl`

Kotlin: Corresponding `.kt.ftl` variants.

### DDD/COLA Templates

These templates generate COLA-layer artifacts. All are in `templates/` root, supporting both Java and Kotlin:

**Domain Layer**: `aggregate-root.*.ftl`, `repository.*.ftl` (→ Gateway), `domain-service.*.ftl`, `value-object.*.ftl`, `domain-event.*.ftl`

**Application Layer**: `application-service.*.ftl` (→ CmdExe/QryExe)

**Adapter Layer**: `assembler.*.ftl` (→ Converter/DTOConverter)

> **Naming alignment**: The template file names use generic DDD terms (repository, assembler) but should map to COLA naming conventions (Gateway, Converter) when generating COLA architecture code. See the COLA artifact mapping table above.

## Related Skills

- `ddd-cola` — COLA architecture layer structure, naming conventions, Gateway pattern for generated code
- `mybatis-plus-patterns` — coding patterns for manually writing/editing MyBatis-Plus modules
- `mapstruct-patterns` — MapStruct converters for Domain ↔ DO and Domain ↔ DTO at layer boundaries
- `postgresql-table-design` — PostgreSQL schema design for code generation source tables
- `spring-boot-openapi-documentation` — OpenAPI 3 annotations for generated controllers and DTOs

## Keywords

mybatis-plus, mybatis-plus-generator, mybatis-plus code generation, generate mybatis-plus code, mybatis-plus crud generation, mybatis-plus from table, mybatis-plus code from database, COLA code generation, DDD code generation
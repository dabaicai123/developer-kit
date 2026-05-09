---
name: mybatis-plus-generator
description: "MyBatis-Plus code generation from database tables: Entity, Mapper, Service, Controller, DTO, VO, BO with MVC and DDD architectures in Java and Kotlin. Use when scaffolding MyBatis-Plus CRUD code from existing database tables."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

## When to use this skill

Use when scaffolding MyBatis-Plus CRUD code from existing database tables. For manually writing or editing individual modules, use `mybatis-plus-patterns` instead. Do NOT trigger for generic code generation, JPA/Hibernate, or other ORM frameworks.

Supported: MVC / DDD / COLA / Layered / Clean architectures; Java and Kotlin.

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

### FastAutoGenerator Builder API (Recommended)

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
            .controller("adapter.controller")
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

### Custom Artifact Generation (DTO/VO/BO)

Since 3.5.3, the `CustomFile.Builder` API generates additional artifact types (DTO, VO, BO, Cmd, etc.):

```java
FastAutoGenerator.create(url, username, password)
    .injectionConfig(injectConfig -> {
        // Inject custom template variables (accessible via ${cfg.xxx} in templates)
        // FastAutoGenerator uses customMap(); legacy AutoGenerator uses InjectionConfig.initMap()
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

> **OpenAPI 3 vs Swagger 2**: The generator's `enableSwagger()` produces **Swagger 2 annotations** (`@ApiModel`, `@ApiModelProperty`) by default. For Spring Boot 3.x with springdoc-openapi, create custom templates that generate **OpenAPI 3 annotations** (`@Schema`, `@Tag`, `@Operation`) instead. Use `springdoc-openapi-starter-webmvc-ui` dependency.

### IFileCreate — Protecting Existing Custom Code

When re-running the generator, use `IFileCreate` to prevent overwriting files that have been manually customized:

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

**Best practice**: Run the generator once for initial scaffolding, then manually customize. Never re-run the generator on files that have been modified unless you use `IFileCreate` to protect existing content.

### DDD/COLA Architecture Generation Limitation

The generator **cannot natively produce** COLA's 4-layer structure. To generate DDD/COLA code:

1. Use `CustomFile.Builder` to generate files into each COLA layer (Gateway, GatewayImpl, Cmd, Executor)
2. Create custom FreeMarker templates for each COLA artifact type
3. Use `pathInfo` to route files to the correct package directories

**Key distinction**: Domain entities use **bare names** (no suffix, no ORM annotations), while infrastructure DOs use the **DO suffix** with full MyBatis-Plus annotations. The generator's default entity template produces the latter; you need a custom template for the domain entity.

### Kotlin Support Note

MyBatis-Plus generator has **no official Kotlin template engine**. Kotlin generation requires:
- Custom FreeMarker templates with Kotlin syntax (data classes, companion objects, val/var)
- `.kt` file extension via `CustomFile.Builder`
- Manual handling of Kotlin-specific features

The `.kt.ftl` templates referenced in this skill are community-driven, not officially provided by baomidou.

## How to use this skill

### Step 1: Collect Input (Required)

Collect: (1) Database connection URL or table structure, (2) architecture type (MVC, DDD/COLA, Layered, Clean, Custom), (3) language (Java or Kotlin), (4) functional requirements per table. Enable OpenAPI 3 annotations (`@Schema`, `@Tag`, `@Operation`) when API documentation is requested.

### Step 2: Map Directories

After determining architecture, map output directories. See `references/architecture-directory-quick-reference.md` for lookup table. Confirm directory structure with user before generating code.

### Step 3: Configure FastAutoGenerator

Configure builder with: global settings (author, output dir, Lombok), package paths (per architecture), strategy (table names, naming, ID type, soft delete, optimistic lock), and injection config for custom artifacts (DTO/VO/BO via `CustomFile.Builder`). See `references/code-generation-standards.md` for detailed requirements.

### Step 4: Protect Existing Code with IFileCreate

When re-running the generator, use `IFileCreate` to prevent overwriting manually customized files. Run once for initial scaffolding, then manually customize. Never re-run on modified files without `IFileCreate`.

### Code Generation Standards

Analyze foreign keys and table relationships to generate accurate relationship comments. Include `@Schema`/OpenAPI annotations; add `@NotNull`/`@NotBlank` where columns have NOT NULL constraints. See `references/code-generation-standards.md` for detailed requirements.

### Reference Documentation

#### Architecture & Directory Mapping
- `references/architecture-directory-mapping-guide.md` — Complete directory mapping guide for all architectures
- `references/architecture-directory-quick-reference.md` — Quick lookup table for directory mappings

#### Code Generation Standards
- `references/code-generation-standards.md` — Detailed comment standards, template usage, and code quality requirements
- `references/template-variables.md` — Complete list of template variables
- `references/swagger-annotations-guide.md` — OpenAPI 3 annotation reference

#### MyBatis-Plus Reference
- `references/mybatis-plus-generator-guide.md` — MyBatis-Plus Generator usage guide

### Examples

See the `examples/` directory for complete examples:
- `examples/mvc-architecture-example.md` — MVC architecture generation example
- `examples/ddd-architecture-example.md` — DDD architecture generation example
- `examples/full-workflow-example.md` — Complete workflow example
- `examples/architecture-directory-mapping.md` — Directory mapping examples for different architectures
- `examples/swagger-annotations-example.md` — OpenAPI 3 annotation examples

### Templates

Templates are located in `templates/` directory, using **FreeMarker** syntax (`.ftl` files), strictly following [MyBatis-Plus official templates](https://github.com/baomidou/mybatis-plus/tree/3.0/mybatis-plus-generator/src/main/resources/templates).

#### Standard Templates (MVC Architecture)

**Java Templates:**
- `entity.java.ftl` - Entity class template
- `mapper.java.ftl` - Mapper interface template
- `service.java.ftl` - Service interface template
- `serviceImpl.java.ftl` - Service implementation template
- `controller.java.ftl` - Controller template
- `dto.java.ftl` - DTO template
- `vo.java.ftl` - VO template
- `bo.java.ftl` - BO template

**Kotlin Templates:**
- `entity.kt.ftl` - Entity data class template
- `mapper.kt.ftl` - Mapper interface template
- `service.kt.ftl` - Service interface template
- `serviceImpl.kt.ftl` - Service implementation template
- `controller.kt.ftl` - Controller template
- `dto.kt.ftl` - DTO template
- `vo.kt.ftl` - VO template
- `bo.kt.ftl` - BO template

#### DDD Architecture Templates

All DDD templates are located in `templates/` root directory, supporting both Java and Kotlin:

**Domain Layer:**
- `aggregate-root.java.ftl` / `aggregate-root.kt.ftl` - Aggregate root template
- `repository.java.ftl` / `repository.kt.ftl` - Repository interface template (domain layer)
- `domain-service.java.ftl` / `domain-service.kt.ftl` - Domain service template
- `value-object.java.ftl` / `value-object.kt.ftl` - Value object template
- `domain-event.java.ftl` / `domain-event.kt.ftl` - Domain event template

**Application Layer:**
- `application-service.java.ftl` / `application-service.kt.ftl` - Application service template

**Interface Layer:**
- `assembler.java.ftl` / `assembler.kt.ftl` - DTO assembler template

**Template Features:**
- Support for OpenAPI 3 annotations
- Intelligent comments based on table structure
- Custom method generation support
- Kotlin-specific features (data classes, null safety, etc.)
- DDD-specific patterns (aggregate root, value objects, domain events)
- FreeMarker syntax for template engine

**Reference**: See MyBatis-Plus official templates at:
- https://github.com/baomidou/mybatis-plus/tree/3.0/mybatis-plus-generator/src/main/resources/templates

## Related Skills

- `ddd-cola` — COLA architecture layer structure for generated code
- `mybatis-plus-patterns` — coding patterns for manually writing/editing MyBatis-Plus modules
- `postgresql-table-design` — PostgreSQL schema design for code generation source tables

## Keywords

mybatis-plus, mybatis-plus-generator, mybatis-plus code generator, mybatis-plus code generation, generate mybatis-plus code, mybatis-plus entity generator, mybatis-plus mapper generator, mybatis-plus service generator, mybatis-plus controller generator, mybatis-plus crud generation, mybatis-plus from table, mybatis-plus code from database

**IMPORTANT**: All keywords must include "MyBatis-Plus" or "mybatis-plus" to avoid false triggers. Generic terms like "code generator" or "generate code from table" without "MyBatis-Plus" should NOT trigger this skill.
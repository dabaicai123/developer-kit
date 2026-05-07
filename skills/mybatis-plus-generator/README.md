# MyBatis-Plus Generator Skill

## Overview

This is a MyBatis-Plus code generation skill based on the Agent Skills specification, capable of automatically generating complete CRUD code from database table structures, including Entity, Mapper, Service, ServiceImpl, Controller, DTO, VO, BO and other objects.

**Important**: This skill is triggered only when the user explicitly mentions **MyBatis-Plus** or **mybatis-plus-generator**, to avoid conflicts with other code generation tools.

## Features

1. **Intelligent Code Generation**: Generates code based on table structures and business requirements, with intelligent comments rather than simple template filling
2. **Multi-Architecture Support**: Supports MVC, DDD (Domain-Driven Design), layered architecture, Clean architecture, Hexagonal architecture, COLA V5, etc.
3. **Multi-Language Support**: Supports Java and Kotlin, using corresponding template files
4. **Intelligent Comments**: Generates comments compliant with Java programming standards, based on business context understanding
5. **Custom Methods**: Automatically analyzes and generates custom methods based on business requirements
6. **API Documentation Support**: Supports OpenAPI 3 annotations
7. **DDD Pattern Support**: Supports Aggregate Root, Repository, Domain Service, Value Object, Domain Event and other DDD patterns
8. **Progress Tracking**: Real-time generation progress output
9. **Statistics Report**: Outputs detailed statistics after generation completes

## File Structure

```
mybatis-plus-generator/
├── SKILL.md                              # Main skill document (Agent Skills specification)
├── LICENSE.txt                           # Apache 2.0 license
├── README.md                             # This file
├── examples/                             # Examples directory
│   ├── full-workflow-example.md         # Full workflow example
│   ├── mvc-architecture-example.md      # MVC architecture example
│   ├── ddd-architecture-example.md      # DDD architecture example
│   ├── architecture-directory-mapping.md # Architecture directory mapping example
│   └── swagger-annotations-example.md   # OpenAPI 3 annotation example
├── reference/                            # Reference documentation directory
│   ├── mybatis-plus-generator-guide.md  # MyBatis-Plus Generator guide
│   ├── template-variables.md            # Template variables reference
│   ├── architecture-directory-mapping-guide.md # Architecture directory mapping detailed guide
│   ├── architecture-directory-quick-reference.md # Architecture directory mapping quick reference
│   ├── code-generation-standards.md     # Code generation standards
│   ├── progress-and-statistics-formats.md # Progress and statistics formats
│   └── swagger-annotations-guide.md     # OpenAPI 3 annotation reference
└── templates/                            # Code template directory (FreeMarker syntax)
    ├── entity.java.ftl / entity.kt.ftl  # Entity class template
    ├── mapper.java.ftl / mapper.kt.ftl  # Mapper interface template
    ├── service.java.ftl / service.kt.ftl # Service interface template
    ├── serviceImpl.java.ftl / serviceImpl.kt.ftl # ServiceImpl implementation class template
    ├── controller.java.ftl / controller.kt.ftl # Controller template
    ├── dto.java.ftl / dto.kt.ftl         # DTO data transfer object template
    ├── vo.java.ftl / vo.kt.ftl          # VO view object template
    ├── bo.java.ftl / bo.kt.ftl          # BO business object template
    ├── repository.java.ftl / repository.kt.ftl # DDD Repository interface template
    ├── aggregate-root.java.ftl / aggregate-root.kt.ftl # DDD Aggregate Root template
    ├── domain-service.java.ftl / domain-service.kt.ftl # DDD Domain Service template
    ├── value-object.java.ftl / value-object.kt.ftl # DDD Value Object template
    ├── domain-event.java.ftl / domain-event.kt.ftl # DDD Domain Event template
    ├── application-service.java.ftl / application-service.kt.ftl # DDD Application Service template
    └── assembler.java.ftl / assembler.kt.ftl # DDD Assembler template
```

## Workflow

The skill follows an 8-step systematic workflow:

1. **Collect Configuration**: Database information, global configuration, package configuration, strategy configuration, API documentation (OpenAPI 3)
2. **Determine Architecture**: MVC, DDD, layered architecture, Clean architecture, Hexagonal architecture, COLA V5, etc., and determine directory mapping
3. **Collect Requirements**: Functional requirements analysis, automatic identification of standard methods and custom methods
4. **Determine Language**: Java or Kotlin, using corresponding template files
5. **Create Todo**: Detailed generation plan, including table names, object types, method names
6. **Generate Code**: Use FreeMarker templates to generate code, with intelligent comments
7. **Progress Update**: Real-time generation progress output, update Todo list
8. **Statistics**: Detailed statistics report after generation completes

## Usage

**Important**: This skill is triggered only when the user explicitly mentions **MyBatis-Plus** or **mybatis-plus-generator**.

### Trigger Phrase Examples

- ✅ "Generate MyBatis-Plus code"
- ✅ "Use MyBatis-Plus to generate code from table structure"
- ✅ "MyBatis-Plus code generator"
- ✅ "mybatis-plus-generator"
- ❌ "Generate code from table structure" (MyBatis-Plus not explicitly mentioned, will not trigger)
- ❌ "Generate CRUD code" (MyBatis-Plus not explicitly mentioned, will not trigger)

### Usage Flow

When the user explicitly mentions MyBatis-Plus, the skill automatically:

1. **Collects configuration**: Database connection, table names, package names, author, etc.
2. **Determines architecture type**: MVC, DDD, etc., and determines the correct directory structure
3. **Analyzes business requirements**: Identifies standard CRUD methods and custom business methods
4. **Selects programming language**: Java or Kotlin
5. **Generates code**: Uses corresponding template files to generate code
6. **Provides progress updates**: Real-time display of generation progress
7. **Outputs statistics**: Detailed report after generation completes

## Template Description

### Template Engine

All template files use **FreeMarker** template syntax (`.ftl` files), strictly following the [MyBatis-Plus official templates](https://github.com/baomidou/mybatis-plus/tree/3.0/mybatis-plus-generator/src/main/resources/templates).

### Template Syntax

FreeMarker templates support:
- Variable substitution (`${variable}`)
- Conditional logic (`<#if>`)
- Loop iteration (`<#list>`)
- String operations (`?substring`, `?lower_case`, etc.)

### Template Categories

#### Standard Templates (MVC Architecture)

- **Java templates**: `entity.java.ftl`, `mapper.java.ftl`, `service.java.ftl`, `serviceImpl.java.ftl`, `controller.java.ftl`, `dto.java.ftl`, `vo.java.ftl`, `bo.java.ftl`
- **Kotlin templates**: `entity.kt.ftl`, `mapper.kt.ftl`, `service.kt.ftl`, `serviceImpl.kt.ftl`, `controller.kt.ftl`, `dto.kt.ftl`, `vo.kt.ftl`, `bo.kt.ftl`

#### DDD Architecture Templates

- **Domain layer**: `aggregate-root.*.ftl`, `repository.*.ftl`, `domain-service.*.ftl`, `value-object.*.ftl`, `domain-event.*.ftl`
- **Application layer**: `application-service.*.ftl`
- **Interface layer**: `assembler.*.ftl`

### Template Features

- ✅ Supports OpenAPI 3 annotations
- ✅ Intelligent comment generation (based on table structure and business context)
- ✅ Custom method support
- ✅ Kotlin feature support (data class, null safety, companion object, etc.)
- ✅ DDD pattern support (Aggregate Root, Value Object, Domain Event, etc.)

For detailed template variable descriptions, refer to `reference/template-variables.md`.

## Comment Standards

Generated code comments follow strict standards:

### JavaDoc Standards

- **Class comments**: Include `<p>` tag descriptions, explaining the business purpose of the class, listing main fields
- **Method comments**: Include `<p>` tag descriptions, explaining business logic, specifying parameter types and return value types
- **Field comments**: Explain business meaning, including data type and constraint information

### Comment Features

- ✅ **Intelligent Understanding**: Generates comments based on table structure and business context, not simply copying field names
- ✅ **Standards Compliance**: Follows Java programming standards, uses `<p>` tags
- ✅ **Explicit Types**: `@param`, `@return`, `@exception` declare types explicitly
- ✅ **Business-Oriented**: Comments explain business meaning, not technical implementation details

For detailed comment standards, refer to:
- `reference/code-generation-standards.md` - Code generation standards
- `java-code-comments` skill - Java code comments skill

## Architecture Support

### MVC Architecture

Generates standard MVC layered code:
- Entity (entity class)
- Mapper (data access layer)
- Service / ServiceImpl (business logic layer)
- Controller (controller layer)
- DTO / VO / BO (data transfer objects)

### DDD Architecture

Supports complete DDD patterns:
- **Aggregate Root**: Core domain object
- **Repository**: Domain layer persistence interface
- **Domain Service**: Cross-aggregate business logic
- **Value Object**: Immutable value object
- **Domain Event**: Domain event definition
- **Application Service**: Application layer orchestration
- **Assembler**: DTO and domain object conversion

### Directory Mapping

Different architecture patterns have different directory structures. The skill automatically determines the correct directory location based on the architecture type. For details, refer to:
- `reference/architecture-directory-mapping-guide.md` - Complete directory mapping guide
- `reference/architecture-directory-quick-reference.md` - Quick reference table
- `examples/architecture-directory-mapping.md` - Directory mapping example

## API Documentation Support

### OpenAPI 3

- Annotations used: `@Schema`, `@Tag`, `@Operation`, `@Parameter`
- Dependency: `springdoc-openapi-ui`
- Applicable to: Spring Boot 2.2+ and Spring Boot 3.x projects

For detailed usage, refer to `reference/swagger-annotations-guide.md`.

## Example Documentation

- `examples/full-workflow-example.md` - Full workflow example
- `examples/mvc-architecture-example.md` - MVC architecture generation example
- `examples/ddd-architecture-example.md` - DDD architecture generation example
- `examples/architecture-directory-mapping.md` - Architecture directory mapping example
- `examples/swagger-annotations-example.md` - OpenAPI 3 annotation usage example

## Reference Documentation

### Core References

- `reference/mybatis-plus-generator-guide.md` - MyBatis-Plus Generator usage guide
- `reference/template-variables.md` - Template variables complete reference
- `reference/code-generation-standards.md` - Code generation standards and comment specifications

### Architecture References

- `reference/architecture-directory-mapping-guide.md` - Architecture directory mapping detailed guide
- `reference/architecture-directory-quick-reference.md` - Architecture directory mapping quick reference

### Other References

- `reference/swagger-annotations-guide.md` - OpenAPI 3 annotation reference
- `reference/progress-and-statistics-formats.md` - Progress update and statistics report formats

## External Links

- [MyBatis-Plus Official Documentation](https://baomidou.com/)
- [MyBatis-Plus Generator Documentation](https://baomidou.com/pages/d357af/)
- [MyBatis-Plus GitHub](https://github.com/baomidou/mybatis-plus)
- [MyBatis-Plus Official Templates](https://github.com/baomidou/mybatis-plus/tree/3.0/mybatis-plus-generator/src/main/resources/templates)
- [Agent Skills Specification](https://agentskills.io/)
- [Agent Skills Getting Started Guide](https://support.claude.com/zh-CN/articles/12512198-%E5%A6%82%E4%BBD%E5%88%9B%E5%BB%BA%E8%87%AE%E5%AE%9A%E4%B9%89-skills)

## License

Apache 2.0 License - See `LICENSE.txt` for details
---
name: mybatis-plus-generator
description: "MyBatis-Plus code generation from database tables: Entity, Mapper, Service, Controller, DTO, VO, BO with MVC and DDD architectures in Java and Kotlin. Use when scaffolding MyBatis-Plus CRUD code from existing database tables."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

## When to use this skill

**CRITICAL: This skill should ONLY be triggered when the user explicitly mentions MyBatis-Plus or mybatis-plus-generator.**

This skill is for **batch code generation** from database tables. For manually writing or editing individual Mapper/Entity/Service modules, use `mybatis-plus-patterns` instead.

**ALWAYS use this skill when the user mentions:**
- MyBatis-Plus code generation
- Generating MyBatis-Plus code from database tables
- MyBatis-Plus generator or mybatis-plus-generator
- Creating MyBatis-Plus Entity, Mapper, Service, Controller code

**Trigger phrases include:**
- "MyBatis-Plus code generation"
- "mybatis-plus-generator"
- "Generate code from database tables with MyBatis-Plus"

**DO NOT trigger this skill for:**
- Generic code generation without mentioning MyBatis-Plus
- JPA/Hibernate code generation
- Other ORM frameworks (TypeORM, Sequelize, etc.)
- Generic CRUD operations without MyBatis-Plus context

**Supported architectures:**
- Traditional MVC (Model-View-Controller)
- DDD (Domain-Driven Design)
- Layered Architecture
- Clean Architecture

**Supported languages:**
- Java
- Kotlin

**Supported component types:**
- Entity
- Mapper (data access interface)
- Service (service interface)
- ServiceImpl (service implementation)
- Controller
- DTO (Data Transfer Object)
- VO (Value Object / View Object)
- BO (Business Object)
- Model (data model)

## How to use this skill

**CRITICAL: This skill should ONLY be triggered when the user explicitly mentions MyBatis-Plus or mybatis-plus-generator. Do NOT trigger for generic code generation requests without MyBatis-Plus context.**

### Workflow Overview

This skill follows a systematic 8-step workflow:

1. **Collect Configuration** - Collect database information, global configuration, package configuration, strategy configuration
2. **Determine Architecture** - Ask user about architecture type (MVC, DDD, etc.) to determine which objects to generate
3. **Collect Requirements** - Ask user for functional requirements to analyze and determine methods to generate
4. **Determine Language** - Ask user about programming language (Java or Kotlin)
5. **Create Todo List** - Generate a detailed todo list with table names, object types, and method names
6. **Generate Code** - Generate code files with intelligent comments based on table structure and requirements
7. **Progress Updates** - Provide real-time progress updates during code generation
8. **Statistics** - Output statistics after generation completes

### Step-by-Step Process

#### Step 1: Collect Configuration

**CRITICAL: Before generating any code, you MUST collect the following configuration:**

1. **Database Information:**
   - Database type (MySQL, PostgreSQL, Oracle, etc.)
   - Database connection URL (or ask user to provide table structure)
   - Database name
   - Table names (one or multiple tables)
   - If user cannot provide database connection, ask for table structure (CREATE TABLE statement or table schema)

2. **Global Configuration:**
   - Author name
   - Output directory (default: `src/main/java`)
   - File override strategy (overwrite, skip, ask)
   - Enable Lombok (yes/no)
   - Enable API documentation (yes/no) — uses OpenAPI 3 annotations
   - Enable validation annotations (yes/no)

3. **Package Configuration:**
   - Parent package name (e.g., `com.example.app`)
   - Entity package (default: `entity`)
   - Mapper package (default: `mapper`)
   - Service package (default: `service`)
   - ServiceImpl package (default: `service.impl`)
   - Controller package (default: `controller`)
   - DTO package (default: `dto`)
   - VO package (default: `vo`)
   - BO package (default: `bo`)

4. **Strategy Configuration:**
   - Naming strategy (camelCase, PascalCase, etc.)
   - Table prefix removal (yes/no, prefix name)
   - Field naming strategy
   - Primary key strategy (AUTO, UUID, etc.)

**IMPORTANT: When user enables API documentation, OpenAPI 3 annotations are used by default:**

```
API documentation uses OpenAPI 3 (springdoc-openapi):
- Annotations: @Schema, @Tag, @Operation, @Parameter
- Dependencies: springdoc-openapi-ui
- For: Spring Boot 2.2+ and Spring Boot 3.x projects
```

**Output**: A configuration summary showing all collected information.

#### Step 2: Determine Architecture

**CRITICAL: You MUST ask the user about the architecture type to determine which objects to generate.**

Present architecture options:

```
Select project architecture type:
- [ ] Traditional MVC (Model-View-Controller)
  - Generates: Entity, Mapper, Service, ServiceImpl, Controller
- [ ] COLA V5 (Domain-Driven Design) ← Recommended, aligned with ddd-cola skill
  - Generates: Entity, Gateway, AppService, ServiceImpl, Controller, DTO, VO
- [ ] Layered Architecture
  - Generates: Entity, Mapper, Service, ServiceImpl, Controller
- [ ] Clean Architecture
  - Generates: Entity, Repository, UseCase, Controller, DTO
- [ ] Custom Architecture
  - Specify which object types to generate
```

**Wait for user confirmation** before proceeding.

**IMPORTANT: Directory Mapping Based on Architecture**

After determining the architecture type, you MUST identify the correct output directories for each generated object.

**CRITICAL Steps:**

1. **Ask user for base package path** (e.g., `com.example.order`)
2. **Use architecture directory mapping** to determine correct paths:
   - **Quick Reference**: See `references/architecture-directory-quick-reference.md` for lookup table
   - **Detailed Guide**: See `references/architecture-directory-mapping-guide.md` for complete mapping rules
3. **Verify directory exists** or create it if needed
4. **Generate files** in the correct location

**Common Path Examples:**

For `user` table with base package `com.example.order`:
- **MVC**: Entity → `com/example/order/entity/User.java`, Controller → `com/example/order/controller/UserController.java`
- **DDD**: Entity → `com/example/order/domain/model/aggregate/user/User.java`, Controller → `com/example/order/interfaces/web/controller/UserController.java`
- **Hexagonal**: Entity → `com/example/order/domain/model/entity/User.java`, Controller → `com/example/order/infrastructure/adapter/inbound/web/controller/UserController.java`
- **Clean**: Entity → `com/example/order/domain/entity/User.java`, Controller → `com/example/order/infrastructure/web/controller/UserController.java`
- **COLA** (aligned with ddd-cola skill): Entity → `com/example/order/domain/model/entity/User.java`, Gateway → `com/example/order/domain/gateway/UserGateway.java`, AppService → `com/example/order/app/service/UserAppService.java`, Controller → `com/example/order/adapter/controller/UserController.java`

**CRITICAL**: Always confirm the exact directory structure with the user if the project structure is unclear. Ask: "Please confirm the project directory structure so I can place generated code in the correct locations."

#### Step 3: Collect Requirements

**CRITICAL: Ask user for functional requirements to understand what methods need to be generated.**

Ask the user:

```
Describe the functional requirements for this code generation:

For example:
- User management: need to query users by email, query by username, user login verification
- Order management: need order statistics, paginated order query, order status update
- Product management: need product search, category query, inventory management

Describe in detail what features each table needs, and I will automatically analyze the required methods.
```

**After user provides requirements:**

1. **Analyze requirements** to identify:
   - Standard CRUD methods (create, read, update, delete)
   - Custom query methods (findByEmail, findByUsername, etc.)
   - Custom business methods (statistics, aggregation, etc.)
   - Custom update methods (updateStatus, updatePassword, etc.)

2. **For each table, identify:**
   - Standard methods needed
   - Custom methods needed based on requirements
   - Method parameters and return types
   - Business logic hints (for method skeletons)

**Output**: A requirements analysis showing:
- Standard methods for each table
- Custom methods for each table
- Method signatures (parameters and return types)

#### Step 4: Determine Language

**CRITICAL: Ask user about programming language.**

```
Select programming language:
- [ ] Java
- [ ] Kotlin
```

**Wait for user confirmation** before proceeding.

**Note**: Templates in `templates/` directory support both Java and Kotlin. Use appropriate templates based on user's choice.

#### Step 5: Create Todo List

**CRITICAL: After collecting all information, create a detailed todo list.**

For each table, generate a structured todo list:

```markdown
## Todo List: MyBatis-Plus Code Generation

### Table: user

#### Entity Layer
- [ ] User.java - Entity class
  - [ ] Class comments
  - [ ] Field definitions (id, username, email, password, status, createTime, updateTime)
  - [ ] Field comments

#### Mapper Layer
- [ ] UserMapper.java - Data access interface
  - [ ] Class comments
  - [ ] Basic CRUD methods (extends BaseMapper)

#### Service Layer
- [ ] UserService.java - Service interface
  - [ ] Class comments
  - [ ] saveUser() - Save user
  - [ ] findById() - Query by ID
  - [ ] updateUser() - Update user
  - [ ] deleteById() - Delete user
  - [ ] findByEmail() - Query by email (custom method)
  - [ ] findByUsername() - Query by username (custom method)

#### ServiceImpl Layer
- [ ] UserServiceImpl.java - Service implementation
  - [ ] Class comments
  - [ ] Implement all Service interface methods
  - [ ] Method comments and implementation skeletons

#### Controller Layer
- [ ] UserController.java - Controller
  - [ ] Class comments
  - [ ] createUser() - Create user
  - [ ] getUserById() - Query user
  - [ ] updateUser() - Update user
  - [ ] deleteUser() - Delete user
  - [ ] getUserByEmail() - Query by email (custom endpoint)

#### DTO Layer (if architecture requires)
- [ ] UserCreateDTO.java - Create user DTO
- [ ] UserUpdateDTO.java - Update user DTO
- [ ] UserQueryDTO.java - Query user DTO

#### VO Layer (if architecture requires)
- [ ] UserVO.java - User view object

### Table: order
...
```

**Important**: 
- Organize by table
- List all objects that need to be generated
- Include all methods (standard + custom)
- Use checkboxes for tracking progress

#### Step 6: Generate Code

**CRITICAL: Generate code files with intelligent comments based on table structure and requirements.**

**Order of generation:**
1. **Entity** - First (base for all other objects)
2. **Mapper** - Second (data access layer)
3. **Service** - Third (business interface)
4. **ServiceImpl** - Fourth (business implementation)
5. **Controller** - Fifth (API layer)
6. **DTO/VO/BO** - Sixth (if needed by architecture)

**For each object:**

1. **Load appropriate template** from `templates/` directory based on object type and language
2. **Analyze table structure**: Read columns, types, constraints, primary keys, foreign keys, relationships
3. **Generate intelligent comments**: Based on business context, not just technical names
   - Class comments: Explain purpose, list main fields
   - Method comments: Explain business logic, include all parameters and return types
   - Field comments: Explain business meaning, not just column names
4. **Generate code**: Replace template variables, add annotations, generate method skeletons
5. **For custom methods**: Generate signatures, add business logic comments, add TODO hints
6. **Determine output directory**: Use architecture directory mapping (see Step 2)
7. **Save files** to correct location based on architecture and package configuration

**After generating each object:**
- Update the todo list: mark completed items with `[x]`
- Show progress to the user
- Continue to the next object

**Code Generation Standards**: See `references/code-generation-standards.md` for detailed requirements on comments, templates, and code quality.

#### Step 7: Progress Updates

**CRITICAL: Provide real-time progress updates during code generation.**

**Update progress after:**
- Each table starts processing
- Each object is generated
- Each method is added
- Each table completes

**Progress Format**: See `references/progress-and-statistics-formats.md` for detailed progress update format and examples.

#### Step 8: Statistics

**CRITICAL: After all code generation completes, output comprehensive statistics.**

**Statistics Format**: See `references/progress-and-statistics-formats.md` for detailed statistics format including:
- Overall statistics (tables, objects, methods, files, lines)
- Per-table statistics
- Per-type statistics
- File locations
- Code quality checklist

### Code Generation Standards

**IMPORTANT: Generated code must include intelligent, context-aware comments, not just template placeholders.**

**Key Requirements:**
1. **Class Comments**: Explain purpose based on business context, include table mapping, list main fields
2. **Method Comments**: Explain business logic, include all parameters with types, return value with type, exceptions
3. **Field Comments**: Explain business meaning, include data type and constraints, not just column names

**Detailed Standards**: See `references/code-generation-standards.md` for:
- Complete comment format requirements
- Template usage guidelines
- Template variables reference
- Swagger annotation selection
- Custom method generation standards
- Code quality requirements

### Best Practices

1. **Intelligent Comments**: Generate comments based on table structure analysis and business requirements, not just template placeholders
2. **Context Awareness**: Understand table relationships and business context to generate meaningful comments
3. **Method Analysis**: Analyze user requirements to determine what methods are needed
4. **Progress Tracking**: Always update todo list and show progress
5. **Code Quality**: Generate production-ready code with proper annotations and validation
6. **Template Enhancement**: Use templates as base, but enhance with intelligent additions
7. **Language Support**: Support both Java and Kotlin with appropriate templates

### Reference Documentation

**CRITICAL: Use these reference documents for detailed guidance:**

#### Architecture & Directory Mapping
- `references/architecture-directory-mapping-guide.md` - **Complete directory mapping guide for all architectures** (CRITICAL)
- `references/architecture-directory-quick-reference.md` - Quick lookup table for directory mappings

#### Code Generation Standards
- `references/code-generation-standards.md` - Detailed comment standards, template usage, and code quality requirements
- `references/template-variables.md` - Complete list of template variables
- `references/swagger-annotations-guide.md` - OpenAPI 3 annotation reference

#### Progress & Statistics
- `references/progress-and-statistics-formats.md` - Progress update and statistics output formats

#### MyBatis-Plus Reference
- `references/mybatis-plus-generator-guide.md` - MyBatis-Plus Generator usage guide

### Examples

See the `examples/` directory for complete examples:
- `examples/mvc-architecture-example.md` - MVC architecture generation example
- `examples/ddd-architecture-example.md` - DDD architecture generation example
- `examples/full-workflow-example.md` - Complete workflow example
- `examples/architecture-directory-mapping.md` - Directory mapping examples for different architectures
- `examples/swagger-annotations-example.md` - OpenAPI 3 annotation examples

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

**English keywords:**
mybatis-plus, mybatis-plus-generator, mybatis-plus code generator, mybatis-plus code generation, generate mybatis-plus code, mybatis-plus entity generator, mybatis-plus mapper generator, mybatis-plus service generator, mybatis-plus controller generator, mybatis-plus crud generation, mybatis-plus from table, mybatis-plus code from database

**IMPORTANT**: All keywords must include "MyBatis-Plus" or "mybatis-plus" to avoid false triggers. Generic terms like "code generator" or "generate code from table" without "MyBatis-Plus" should NOT trigger this skill.

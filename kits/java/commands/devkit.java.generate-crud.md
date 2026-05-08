---
description: Generates complete CRUD implementation for a domain class using MyBatis-Plus patterns. Creates Entity, Mapper, Service, ServiceImpl, Controller, and DTO/VO with pagination and soft delete support.
argument-hint: "[domain-class-name]"
allowed-tools: Read, Write, Bash, Glob, Grep
model: inherit
---

## Generate CRUD Command

Generates a complete MyBatis-Plus CRUD stack for a domain class.

### Usage

`/devkit.java.generate-crud [domain-class-name]`

**domain-class-name**: The name of the domain entity (e.g., `User`, `Order`, `Product`)

### Execution

1. Invoke the `spring-boot-backend-development-expert` agent
2. Use the `mybatis-plus-generator` skill for code generation
3. Generate the following files:
   - **DO**: `XxxDO.java` with `@TableName`, `@TableId(type = IdType.ASSIGN_ID)`, `@TableLogic(value = "", delval = "now()")`, `@Version`
   - **Mapper**: `XxxMapper.java` extending `BaseMapper<XxxDO>`
   - **Service** (MVC): `XxxService.java` extending `IService<XxxDO>`, `XxxServiceImpl.java` extending `ServiceImpl<XxxMapper, XxxDO>`
   - **Gateway** (DDD): `XxxGateway.java` interface, `XxxGatewayImpl.java` (see `ddd-cola` skill)
   - **Controller**: `XxxController.java` with REST endpoints
   - **DTO**: `XxxCreateDTO.java`, `XxxUpdateDTO.java`
   - **VO**: `XxxVO.java`, `XxxPageVO.java`
   - **BO**: `XxxQueryBO.java` for query conditions
4. Follow `spring-boot-rest-api-standards` for API design
5. Add `spring-boot-validation` annotations on DTOs
6. Include pagination (`Page<>`) and soft delete (`@TableLogic(value = "", delval = "now()")` with `deleted_at TIMESTAMPTZ`) support
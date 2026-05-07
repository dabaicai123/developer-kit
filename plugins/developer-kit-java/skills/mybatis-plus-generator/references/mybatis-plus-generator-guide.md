# MyBatis-Plus Generator Reference Guide

## Overview

This document provides a usage guide and best practices for MyBatis-Plus Generator, helping to understand the principles and configuration of code generation.

## MyBatis-Plus Generator Principles

### Core Components

1. **CodeGenerator**
   - Responsible for reading database table structures
   - Generates code based on configuration
   - Uses template engines to render code

2. **Template Engine**
   - Supports Velocity, Freemarker, Beetl
   - Uses placeholder replacement to generate code
   - Official templates located at: `mybatis-plus-generator/src/main/resources/templates`

3. **StrategyConfig**
   - Controls which files to generate
   - Controls naming rules
   - Controls field mapping rules

### Generation Flow

```
Database table structure
    ↓
Read table metadata (columns, types, constraints)
    ↓
Apply configuration strategies (naming, package paths, etc.)
    ↓
Load template files
    ↓
Replace template variables
    ↓
Generate code files
```

## Official Template Reference

### Template Location

MyBatis-Plus official templates are located at:
- GitHub: https://github.com/baomidou/mybatis-plus/tree/3.0/mybatis-plus-generator/src/main/resources/templates
- Local path: `mybatis-plus-generator/src/main/resources/templates`

### Template Files

1. **entity.java.vm** - Entity class template
2. **mapper.java.vm** - Mapper interface template
3. **mapper.xml.vm** - Mapper XML template
4. **service.java.vm** - Service interface template
5. **serviceImpl.java.vm** - ServiceImpl implementation class template
6. **controller.java.vm** - Controller template

### Template Variables

Common template variables:

- `${package.Entity}` - Entity package path
- `${package.Mapper}` - Mapper package path
- `${package.Service}` - Service package path
- `${package.Controller}` - Controller package path
- `${author}` - Author
- `${date}` - Date
- `${table.name}` - Table name
- `${entity}` - Entity class name
- `${table.comment}` - Table comment
- `${field.name}` - Field name
- `${field.propertyName}` - Property name
- `${field.comment}` - Field comment
- `${field.type}` - Field type

## Configuration Details

### GlobalConfig

```java
GlobalConfig globalConfig = new GlobalConfig();
globalConfig.setAuthor("System");              // Author
globalConfig.setOutputDir("src/main/java");    // Output directory
globalConfig.setFileOverride(true);            // Whether to override files
globalConfig.setOpen(false);                   // Whether to open output directory
globalConfig.setSwagger2(true);                // Whether to enable Swagger
```

### PackageConfig

```java
PackageConfig packageConfig = new PackageConfig();
packageConfig.setParent("com.example.app");    // Parent package name
packageConfig.setEntity("entity");              // Entity package name
packageConfig.setMapper("mapper");             // Mapper package name
packageConfig.setService("service");           // Service package name
packageConfig.setServiceImpl("service.impl");  // ServiceImpl package name
packageConfig.setController("controller");     // Controller package name
```

### StrategyConfig

```java
StrategyConfig strategyConfig = new StrategyConfig();
strategyConfig.setNaming(NamingStrategy.underline_to_camel);  // Naming strategy
strategyConfig.setColumnNaming(NamingStrategy.underline_to_camel);
strategyConfig.setEntityLombokModel(true);      // Use Lombok
strategyConfig.setRestControllerStyle(true);    // REST style
strategyConfig.setControllerMappingHyphenStyle(true);
strategyConfig.setTablePrefix("t_");            // Table prefix
```

### TemplateConfig

```java
TemplateConfig templateConfig = new TemplateConfig();
templateConfig.setEntity("/templates/entity.java.vm");
templateConfig.setMapper("/templates/mapper.java.vm");
templateConfig.setService("/templates/service.java.vm");
templateConfig.setServiceImpl("/templates/serviceImpl.java.vm");
templateConfig.setController("/templates/controller.java.vm");
```

## Best Practices

### 1. Comment Generation

- Use table comments as class comments
- Use field comments as property comments
- Generate method comments based on business logic
- Follow Java programming conventions

### 2. Code Quality

- Generate production-ready code
- Include appropriate annotations (Lombok, Swagger, Validation)
- Include complete JavaDoc comments
- Follow naming conventions

### 3. Custom Methods

- Generate custom methods based on business requirements
- Provide method skeletons and TODO comments
- Include parameter validation hints
- Include exception handling hints

### 4. Architecture Adaptation

- Generate different objects based on architecture type
- MVC: Entity, Mapper, Service, ServiceImpl, Controller
- DDD: Entity, Mapper, Service, ServiceImpl, Controller, DTO, VO, BO
- Clean Architecture: Entity, Repository, UseCase, Controller, DTO

## Reference Materials

- [MyBatis-Plus Official Documentation](https://baomidou.com/)
- [MyBatis-Plus Generator Documentation](https://baomidou.com/pages/d357af/)
- [MyBatis-Plus GitHub](https://github.com/baomidou/mybatis-plus)
- [MyBatis-Plus Generator UI](https://github.com/Coffee-Tang/mybatis-plus-generator-ui)
# Template Variables Reference

## Overview

This document describes the variables available in MyBatis-Plus Generator templates, used to replace template placeholders during code generation.

## Basic Variables

### Package-Related Variables

- `${package.Entity}` - Entity package path (e.g., `com.example.app.entity`)
- `${package.Mapper}` - Mapper package path (e.g., `com.example.app.mapper`)
- `${package.Service}` - Service package path (e.g., `com.example.app.service`)
- `${package.ServiceImpl}` - ServiceImpl package path (e.g., `com.example.app.service.impl`)
- `${package.Controller}` - Controller package path (e.g., `com.example.app.controller`)
- `${package.DTO}` - DTO package path (e.g., `com.example.app.dto`)
- `${package.VO}` - VO package path (e.g., `com.example.app.vo`)
- `${package.BO}` - BO package path (e.g., `com.example.app.bo`)
- `${package.ModuleName}` - Module name (optional)

### Class Name-Related Variables

- `${entity}` - Entity class name (e.g., `User`)
- `${table.entityName}` - Entity class name (same as `${entity}`)
- `${table.mapperName}` - Mapper interface name (e.g., `UserMapper`)
- `${table.serviceName}` - Service interface name (e.g., `UserService`)
- `${table.serviceImplName}` - ServiceImpl class name (e.g., `UserServiceImpl`)
- `${table.controllerName}` - Controller class name (e.g., `UserController`)
- `${table.entityPath}` - Entity path (for URL, e.g., `user`)

### Table-Related Variables

- `${table.name}` - Table name (e.g., `user`)
- `${table.comment}` - Table comment (e.g., `User table`)
- `${schemaName}` - Database schema name (optional)

### Author and Date

- `${author}` - Author name
- `${date}` - Current date (format: `yyyy-MM-dd`)

## Field-Related Variables

### Field Loop

Use `#foreach($field in ${table.fields})` to iterate over all fields in templates.

### Field Attributes

- `${field.name}` - Database field name (e.g., `user_name`)
- `${field.propertyName}` - Java property name (e.g., `userName`)
- `${field.type}` - Database field type (e.g., `varchar`)
- `${field.propertyType}` - Java property type (e.g., `String`)
- `${field.comment}` - Field comment (e.g., `Username`)
- `${field.length}` - Field length (e.g., `50`)
- `${field.keyFlag}` - Whether it is a primary key (boolean)
- `${field.fill}` - Field fill strategy (e.g., `INSERT`, `UPDATE`, `INSERT_UPDATE`)
- `${field.convert}` - Whether field conversion is needed (boolean)
- `${field.versionField}` - Whether it is a version field (boolean)
- `${field.logicDeleteField}` - Whether it is a logical delete field (boolean)

## Configuration-Related Variables

### Global Configuration

- `${swagger}` - Whether to enable API documentation (boolean)
- `${entityLombokModel}` - Whether to use Lombok (boolean)
- `${restControllerStyle}` - Whether to use REST style (boolean)
- `${controllerMappingHyphenStyle}` - Whether Controller mapping uses hyphens (boolean)
- `${superEntityClass}` - Parent entity class (optional)
- `${superEntityClassPackage}` - Parent entity class package path (optional)
- `${superMapperClass}` - Parent Mapper class (default: `BaseMapper`)
- `${superMapperClassPackage}` - Parent Mapper class package path (default: `com.baomidou.mybatisplus.core.mapper.BaseMapper`)
- `${superServiceClass}` - Parent Service class (default: `IService`)
- `${superServiceClassPackage}` - Parent Service class package path (default: `com.baomidou.mybatisplus.extension.service.IService`)
- `${superServiceImplClass}` - Parent ServiceImpl class (default: `ServiceImpl`)
- `${superServiceImplClassPackage}` - Parent ServiceImpl class package path (default: `com.baomidou.mybatisplus.extension.service.impl.ServiceImpl`)
- `${superControllerClass}` - Parent Controller class (optional)
- `${superControllerClassPackage}` - Parent Controller class package path (optional)

### Primary Key Strategy

- `${keyStrategy}` - Primary key strategy (e.g., `AUTO`, `UUID`, `ID_WORKER`)
- `${keyPropertyName}` - Primary key property name (e.g., `id`)

### Serialization

- `${serialVersionUID}` - Whether to generate serialVersionUID (boolean)

## Custom Method Variables

### Custom Method Loop

Use `#foreach($method in ${customMethods})` to iterate over custom methods in templates.

### Method Attributes

- `${method.name}` - Method name (e.g., `findByEmail`)
- `${method.description}` - Method description (e.g., `Find user by email`)
- `${method.detailDescription}` - Method detailed description
- `${method.returnType}` - Return type (e.g., `User`)
- `${method.returnDescription}` - Return value description
- `${method.mappingPath}` - Controller mapping path (e.g., `email/{email}`)

### Method Parameter Loop

Use `#foreach($param in ${method.parameters})` to iterate over method parameters within a method.

### Parameter Attributes

- `${param.name}` - Parameter name (e.g., `email`)
- `${param.type}` - Parameter type (e.g., `String`)
- `${param.description}` - Parameter description (e.g., `User email address`)

### Method Exception Loop

Use `#foreach($exception in ${method.exceptions})` to iterate over method exceptions within a method.

### Exception Attributes

- `${exception.type}` - Exception type (e.g., `java.lang.IllegalArgumentException`)
- `${exception.description}` - Exception description (e.g., `Thrown when email address is empty`)

## DTO-Related Variables

### DTO Types

- `${dtoType}` - DTO type (e.g., `Create`, `Update`, `Query`)
- `${dtoPurpose}` - DTO purpose (e.g., `Create user`, `Update user`)
- `${dtoUsage}` - DTO usage scenario (e.g., `User registration`, `User information update`)

### DTO Field Loop

Use `#foreach($field in ${dtoFields})` to iterate over DTO fields in DTO templates.

### DTO Field Attributes

- `${field.required}` - Whether the field is required (boolean)
- Other field attributes are the same as regular fields

## Conditional Checks

### Conditional Syntax

```velocity
#if(${condition})
    // Code when condition is true
#else
    // Code when condition is false
#end
```

### Common Conditions

- `${swagger}` - Whether Swagger is enabled
- `${entityLombokModel}` - Whether Lombok is used
- `${customMethods}` - Whether there are custom methods
- `${superEntityClass}` - Whether there is a parent entity class
- `${field.keyFlag}` - Whether it is a primary key field
- `${field.fill}` - Whether there is a field fill strategy

## Loop Syntax

### foreach Loop

```velocity
#foreach($item in ${items})
    // Loop body
    ${item.property}
#end
```

### Loop Variables

- `${foreach.index}` - Current index (starting from 0)
- `${foreach.count}` - Current count (starting from 1)
- `${foreach.hasNext}` - Whether there is a next element (boolean)
- `${foreach.first}` - Whether it is the first element (boolean)
- `${foreach.last}` - Whether it is the last element (boolean)

## String Operations

### Case Conversion

- `${string.substring(0,1).toLowerCase()}` - Lowercase first letter
- `${string.substring(0,1).toUpperCase()}` - Uppercase first letter

### String Checks

- `"$!field.comment" != ""` - Check if string is not empty

## Usage Examples

### Example 1: Generate Fields

```velocity
#foreach($field in ${table.fields})
    /**
     * ${field.comment}
     */
    private ${field.propertyType} ${field.propertyName};
#end
```

### Example 2: Conditional Generation

```velocity
#if(${swagger})
    @Schema(description = "${field.comment}")
#end
```

### Example 3: Custom Methods

```velocity
#foreach($method in ${customMethods})
    /**
     * ${method.description}
     */
    ${method.returnType} ${method.name}(#foreach($param in ${method.parameters})${param.type} ${param.name}#if($foreach.hasNext), #end#end);
#end
```

### Example 4: OpenAPI 3 Annotations

```velocity
#if(${swagger})
    @Schema(description = "${table.comment}")
    @Schema(description = "${field.comment}")
    @Tag(name = "${table.comment} Management", description = "${table.comment} Management API")
    @Operation(summary = "Create ${table.comment}", description = "Create a new ${table.comment} record")
#end
```

## Reference Materials

- [Velocity Template Syntax](https://velocity.apache.org/engine/2.3/user-guide.html)
- [MyBatis-Plus Generator Documentation](https://baomidou.com/pages/d357af/)
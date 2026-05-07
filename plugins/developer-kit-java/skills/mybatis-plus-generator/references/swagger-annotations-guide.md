# OpenAPI 3 Annotations Reference Guide

## Overview

This skill uses only OpenAPI 3 annotations (`io.swagger.v3.oas.annotations.*`), Swagger 2 is no longer supported.

## OpenAPI 3 Annotations

### Dependency Configuration

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-ui</artifactId>
    <version>1.7.0</version>
</dependency>
```

For Spring Boot 3.x projects:

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

### Applicable Scenarios

- Spring Boot 2.2+ and Spring Boot 3.x projects
- Conforms to OpenAPI 3.0 specification
- Officially recommended API documentation standard

## Annotations Overview

### Class-Level Annotations

| Purpose | Annotation |
|:---|:---|
| Entity class/model | `@Schema(description = "...")` |
| Controller | `@Tag(name = "...", description = "...")` |
| Service interface | `@Tag(name = "...", description = "...")` |

### Method-Level Annotations

| Purpose | Annotation |
|:---|:---|
| API operation | `@Operation(summary = "...", description = "...")` |
| Parameter description | `@Parameter(name = "...", description = "...", required = true)` |

### Field-Level Annotations

| Purpose | Annotation |
|:---|:---|
| Field description | `@Schema(description = "...", required = true)` |

## Code Examples

### Entity Class

```java
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "User entity class")
public class User {

    @Schema(description = "User ID")
    private Long id;

    @Schema(description = "Username", required = true)
    private String username;
}
```

### Controller

```java
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;

@Tag(name = "User Management", description = "User management API")
@RestController
@RequestMapping("/user")
public class UserController {

    @Operation(summary = "Create user", description = "Create a new user record")
    @PostMapping
    public User create(@RequestBody User user) {
        return userService.save(user);
    }

    @Operation(summary = "Find user by ID", description = "Query user details by ID")
    @Parameter(name = "id", description = "User ID", required = true)
    @GetMapping("/{id}")
    public User getById(@PathVariable Long id) {
        return userService.getById(id);
    }
}
```

### DTO (Data Transfer Object)

```java
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "User creation data transfer object")
public class UserCreateDTO {

    @Schema(description = "Username", required = true)
    @NotBlank(message = "Username cannot be empty")
    @Size(max = 50, message = "Username length cannot exceed 50 characters")
    private String username;

    @Schema(description = "Email address", required = true)
    @NotBlank(message = "Email address cannot be empty")
    @Email(message = "Invalid email format")
    private String email;
}
```

## Template Variables

In code generation templates, use the following variable to control API documentation:

- `${swagger}` - Whether to enable API documentation (boolean)

### Template Conditional Check

```ftl
<#if swagger>
@Schema(description = "${table.comment}")
</#if>
```

## References

- [OpenAPI 3 Official Documentation](https://swagger.io/specification/)
- [SpringDoc OpenAPI](https://springdoc.org/)
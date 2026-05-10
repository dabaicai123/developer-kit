# OpenAPI 3 Annotations Reference

## Spring Boot 3.x Dependency

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.8.0</version>
</dependency>
```

> For Spring Boot 2.x projects (not recommended in this kit): use `springdoc-openapi-ui` 1.x. See `spring-boot-openapi-documentation` for complete configuration.

## Annotations

### Class-Level

| Target | Annotation |
|---|---|
| Entity / DTO | `@Schema(description = "...")` |
| Controller | `@Tag(name = "...", description = "...")` |

### Method-Level

| Target | Annotation |
|---|---|
| API operation | `@Operation(summary = "...", description = "...")` |
| Parameter | `@Parameter(name = "...", description = "...", required = true)` |

### Field-Level

| Target | Annotation |
|---|---|
| Field description | `@Schema(description = "...", required = true)` |

## Code Examples

### Controller

```java
@Tag(name = "User Management", description = "User management API")
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Validated
public class UserController {

    @Operation(summary = "Create user")
    @PostMapping
    public Result<UserDTO> create(@Valid @RequestBody UserAddCmd cmd) {
        return Result.success(userAddCmdExe.execute(cmd));
    }

    @Operation(summary = "Get user by ID")
    @GetMapping("/{userId}")
    public Result<UserDTO> get(@PathVariable @NotBlank String userId) {
        return Result.success(userQryExe.findById(userId));
    }
}
```

### DTO

```java
@Schema(description = "User creation request")
public record UserAddCmd(
    @Schema(description = "Username", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotBlank String username,

    @Schema(description = "Email address", requiredMode = Schema.RequiredMode.REQUIRED)
    @NotBlank @Email String email
) {}
```

## Template Conditional

In FreeMarker templates, use `${cfg.enableSwagger}` from `customMap`:

```ftl
<#if cfg.enableSwagger>
@Schema(description = "${field.comment}")
</#if>
```

## References

- `spring-boot-openapi-documentation` — Complete OpenAPI configuration, security, pagination
- [SpringDoc OpenAPI](https://springdoc.org/)
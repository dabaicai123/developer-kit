---
name: spring-boot-openapi-documentation
description: "SpringDoc OpenAPI 3.0 and Swagger UI for Spring Boot 3.x: API documentation generation, OpenAPI annotations, security documentation, and schema examples. Use when setting up API documentation, configuring Swagger UI, or adding OpenAPI annotations to REST endpoints."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot OpenAPI Documentation with SpringDoc

## When to use this skill

- Set up SpringDoc OpenAPI and generate OpenAPI 3.0 specs for Spring Boot 3.x REST APIs
- Configure and customize Swagger UI
- Document controllers, request/response models, and validation with OpenAPI annotations
- Implement API security documentation (JWT, OAuth2, Basic Auth)
- Document pageable/sortable endpoints and add examples/schemas
- Customize OpenAPI definitions programmatically, support multiple API groups/versions
- Document error responses, exception handlers, and Kotlin-based Spring Boot APIs

## Instructions

### 1. Add Dependencies

Add SpringDoc starter for your application type (WebMvc or WebFlux). See [dependency-setup.md](references/dependency-setup.md) for Maven/Gradle configuration.

### 2. Configure SpringDoc

Set basic configuration in `application.yml`:

```yaml
springdoc:
  api-docs:
    path: /api-docs
  swagger-ui:
    path: /swagger-ui.html
    operationsSorter: method
```

See [configuration.md](references/configuration.md) for advanced options.

### 3. Document Controllers

Use OpenAPI annotations to add descriptive information:

```java
@RestController
@Tag(name = "Book", description = "Book management APIs")
public class BookController {

    @Operation(summary = "Get book by ID")
    @ApiResponse(responseCode = "200", description = "Book found")
    @GetMapping("/{id}")
    public Book findById(@PathVariable Long id) { }
}
```

See [controller-documentation.md](references/controller-documentation.md) for patterns.

### 4. Document Models

Apply `@Schema` annotations to DTOs:

```java
@Schema(description = "Book data object")
public class Book {
    @Schema(example = "1", accessMode = Schema.AccessMode.READ_ONLY)
    private Long id;

    @Schema(example = "Clean Code", required = true)
    private String title;
}
```

See [model-documentation.md](references/model-documentation.md) for validation patterns.

### 5. Configure Security

Set up security schemes in OpenAPI bean:

```java
@Bean
public OpenAPI customOpenAPI() {
    return new OpenAPI()
        .components(new Components()
            .addSecuritySchemes("bearer-jwt", new SecurityScheme()
                .type(SecurityScheme.Type.HTTP)
                .scheme("bearer")
                .bearerFormat("JWT")
            )
        );
}
```

Apply with `@SecurityRequirement(name = "bearer-jwt")` on controllers. See [security-configuration.md](references/security-configuration.md).

### 6. Document Pagination

Use `@ParameterObject` for Spring Data `Pageable`:

```java
@GetMapping("/paginated")
public Page<Book> findAll(@ParameterObject Pageable pageable) {
    return repository.findAll(pageable);
}
```

See [pagination-support.md](references/pagination-support.md).

### 7. Test Documentation

Access Swagger UI at `/swagger-ui/index.html` to verify documentation completeness.

### 8. Customize for Production

Configure API grouping, versioning, and build plugins. See [advanced-configuration.md](references/advanced-configuration.md) and [build-integration.md](references/build-integration.md).

## Best Practices

- **Use descriptive operation summaries**: concise (< 120 chars), action-oriented (e.g., 'Get user by ID', not 'User endpoint')
- **Document all response codes**: Include success (2xx), client errors (4xx), server errors (5xx)
- **Add examples to request/response bodies**: Use `@ExampleObject` for realistic examples
- **Leverage JSR-303 validation annotations**: SpringDoc auto-generates constraints from validation annotations
- **Use `@ParameterObject` for complex parameters**: Especially for Pageable, custom filter objects
- **Group related endpoints with `@Tag`**: Organize API by domain entities or features
- **Document security requirements**: Apply `@SecurityRequirement` where authentication needed
- **Hide internal endpoints**: Use `@Hidden` or separate API groups; never expose admin/internal endpoints in public groups
- **Customize Swagger UI for better UX**: Enable filtering, sorting, try-it-out features
- **Version your API documentation**: Include version in OpenAPI Info

## References

- **[dependency-setup.md](references/dependency-setup.md)** — Maven/Gradle dependencies and version selection
- **[configuration.md](references/configuration.md)** — Basic and advanced configuration options
- **[controller-documentation.md](references/controller-documentation.md)** — Controller and endpoint documentation patterns
- **[model-documentation.md](references/model-documentation.md)** — Data Object, DTO, and validation documentation
- **[security-configuration.md](references/security-configuration.md)** — JWT, OAuth2, Basic Auth, API key configuration
- **[pagination-support.md](references/pagination-support.md)** — Pageable, Slice, and custom pagination patterns
- **[advanced-configuration.md](references/advanced-configuration.md)** — API groups, customizers, OpenAPI bean configuration
- **[exception-handling.md](references/exception-handling.md)** — Exception documentation and error response schemas
- **[build-integration.md](references/build-integration.md)** — Maven/Gradle plugins and CI/CD integration
- **[complete-examples.md](references/complete-examples.md)** — Full controller, data object, and configuration examples
- **[annotations-reference.md](references/annotations-reference.md)** — Complete annotation reference with attributes
- **[springdoc-official.md](references/springdoc-official.md)** — Official SpringDoc documentation
- **[troubleshooting.md](references/troubleshooting.md)** — Common issues and solutions

## Constraints and Warnings

- Do not expose sensitive data in API examples or schema descriptions
- Keep OpenAPI annotations minimal to avoid cluttering controller code; use global configurations when possible
- Large API definitions can impact Swagger UI performance; consider grouping APIs by domain
- Schema generation may not work correctly with complex generic types; use explicit `@Schema` annotations
- Avoid circular references in DTOs as they cause infinite recursion in schema generation
- Security schemes must be properly configured before using `@SecurityRequirement` annotations
- Hidden endpoints (`@Operation(hidden = true)`) are still visible in code and may leak through other documentation tools

## Examples

### Documented Model with Validation

```java
@Schema(description = "Book data object")
public class Book {
    @Schema(description = "Unique identifier", example = "1", accessMode = Schema.AccessMode.READ_ONLY)
    private Long id;

    @Schema(description = "Book title", example = "Clean Code", required = true)
    @NotBlank
    @Size(min = 1, max = 200)
    private String title;

    @Schema(description = "Author name", example = "Robert C. Martin")
    @NotBlank
    private String author;

    @Schema(description = "Price in USD", example = "29.99", minimum = "0")
    @NotNull
    @DecimalMin("0.0")
    private BigDecimal price;
}
```

## Related Skills

- `spring-boot-rest-api-standards` — REST API design standards, URL conventions, Result<T>
- `spring-boot-validation` — @Valid, @NotBlank, MethodArgumentNotValidException
- `spring-boot-security-jwt` — JWT security scheme configuration in OpenAPI docs

## External Resources

- [SpringDoc Official Documentation](https://springdoc.org/)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Swagger UI Configuration](https://swagger.io/docs/open-source-tools/swagger-ui/usage/configuration/)

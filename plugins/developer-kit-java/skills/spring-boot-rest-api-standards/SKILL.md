---
name: spring-boot-rest-api-standards
description: Provides REST API design standards and best practices for Spring Boot projects. Use when creating or reviewing REST endpoints, DTOs, error handling, pagination, security headers, HATEOAS and architecture patterns.
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot REST API Standards

## Overview

REST API design standards for Spring Boot covering URL design, HTTP methods, status codes, DTOs, validation, error handling, pagination, and security headers.

## When to use this skill

- Creating REST endpoints and API routes
- Designing DTOs and API contracts
- Implementing error handling and validation
- Setting up pagination and filtering
- Configuring security headers and CORS
- Reviewing REST API architecture

## Instructions

### To Build RESTful API Endpoints

Follow these steps to create well-designed REST API endpoints:

1. **Design Resource-Based URLs**
   - Use plural nouns for resource names
   - Follow REST conventions: GET /users, POST /users, PUT /users/{id}
   - Avoid action-based URLs like /getUserList

2. **Implement Proper HTTP Methods**
   - GET: Retrieve resources (safe, idempotent)
   - POST: Create resources (not idempotent)
   - PUT: Replace entire resources (idempotent)
   - PATCH: Partial updates (not idempotent)
   - DELETE: Remove resources (idempotent)

3. **Use Appropriate Result Codes** (all responses use HTTP 200, business code in `Result.code`)
   - 200: All successful operations (GET/POST/PUT/DELETE)
   - 400: Validation errors, invalid input
   - 401: Missing or invalid auth
   - 403: No permission
   - 404: Resource not found
   - 409: Duplicate, state conflict
   - 500: Unexpected server errors

4. **Create Request/Response DTOs**
   - Separate API contracts from domain entities
   - Use Java records or Lombok `@Data`/`@Value`
   - Apply Jakarta validation annotations
   - Keep DTOs immutable when possible

5. **Implement Validation**
   - Use `@Valid` annotation on `@RequestBody` parameters
   - Apply validation constraints (`@NotBlank`, `@Email`, `@Size`, etc.)
   - Handle validation errors with `MethodArgumentNotValidException`

6. **Set Up Error Handling**
   - Use `@RestControllerAdvice` for global exception handling
   - Return unified `Result<T>` responses with `code`, `msg`, `data` fields
   - Use `BusinessException` subclasses (`NotFoundException`, `ValidationException`, etc.) with `Result.fail(code, msg)`

7. **Configure Pagination**
   - Use `PageResult<T>` for paginated responses (wrap MyBatis-Plus `Page<T>` with `PageResult.of(mpPage).map()`)
   - Include page, pageSize, total, records fields
   - Return `Result<PageResult<T>>` from controller endpoints

8. **Add Security Headers**
   - Configure CORS policies
   - Set content security policy
   - Include X-Frame-Options, X-Content-Type-Options

**Validation checkpoints:**
- After step 1-2: Verify URL structure follows REST conventions (/users not /getUsers)
- After step 3: Test each endpoint returns correct status codes
- After step 4-5: Validate DTOs with curl or HTTPie before proceeding
- After step 6: Confirm error responses match standardized format

## Examples

### Basic CRUD Controller

```java
@RestController
@RequestMapping("/v1/users")
@RequiredArgsConstructor
@Slf4j
public class UserController {
    private final UserService userService;

    @GetMapping
    public Result<PageResult<UserResponse>> getAllUsers(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "10") long pageSize) {
        log.debug("Fetching users page {} size {}", page, pageSize);
        return Result.success(userService.getAll(page, pageSize));
    }

    @GetMapping("/{id}")
    public Result<UserResponse> getUserById(@PathVariable Long id) {
        return Result.success(userService.getById(id));
    }

    @PostMapping
    public Result<Void> createUser(@Valid @RequestBody CreateUserRequest request) {
        userService.create(request);
        return Result.success();
    }

    @PutMapping("/{id}")
    public Result<UserResponse> updateUser(
            @PathVariable Long id,
            @Valid @RequestBody UpdateUserRequest request) {
        return Result.success(userService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public Result<Void> deleteUser(@PathVariable Long id) {
        userService.delete(id);
        return Result.success();
    }
}
```

### Request/Response DTOs

```java
// Request DTO
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CreateUserRequest {
    @NotBlank(message = "User name cannot be blank")
    private String name;

    @Email(message = "Valid email required")
    private String email;
}

// Response DTO
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {
    private Long id;
    private String name;
    private String email;
    private LocalDateTime createdAt;
}
```

### Global Exception Handler

```java
@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public Result<Void> handleValidationException(MethodArgumentNotValidException ex) {
        String msg = ex.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + ": " + f.getDefaultMessage())
                .collect(Collectors.joining("; "));
        log.warn("Validation error: {}", msg);
        return Result.fail(400, msg);
    }

    @ExceptionHandler(BusinessException.class)
    public Result<Void> handleBusinessException(BusinessException ex) {
        log.warn("Business error: {} - {}", ex.getCode(), ex.getMsg());
        return Result.fail(ex.getCode(), ex.getMsg());
    }
}
```

## Best Practices

### 1. Use Constructor Injection
```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
}
```

### 2. Prefer Immutable DTOs (Java Records or `@Value`)
```java
public record UserResponse(Long id, String name, String email) {}
```

> For transaction management patterns (`@Transactional`, propagation, rollback rules), see `spring-boot-transaction-management`.

## Constraints and Warnings

1. **Never expose entities directly** - Use DTOs to separate API contracts from domain models
2. **Follow REST conventions** - Use nouns for resources (/users), correct HTTP methods, plural names, proper status codes
3. **Handle all exceptions globally** - Use `@RestControllerAdvice`, never let raw exceptions bubble up
4. **Always paginate large result sets** - Prevent performance issues and DDoS vulnerabilities
5. **Validate all input data** - Use Jakarta validation annotations on request DTOs
6. **Never expose sensitive data** - Don't log or expose passwords, tokens, PII

## References

- See `references/` directory for comprehensive reference material including HTTP status codes, Spring annotations, and detailed examples
- Refer to the `spring-boot-code-review-expert` agent for code review guidelines
- Review `spring-boot-dependency-injection` for dependency injection patterns

## Related Skills

- `spring-boot-validation` — @Valid, @NotBlank, MethodArgumentNotValidException
- `spring-boot-exception-handling` — @RestControllerAdvice, BusinessException, Result<T>
- `spring-boot-security-jwt` — JWT authentication for REST endpoints
- `spring-boot-openapi-documentation` — OpenAPI/Swagger documentation for REST APIs
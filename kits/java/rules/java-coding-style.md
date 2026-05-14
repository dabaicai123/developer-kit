---
paths:
  - "**/*.java"
---

# Java Coding Style

## Core Principles

- **KISS**: prefer the simplest solution that works.
- **DRY**: extract repeated logic only when the repetition is real.
- **YAGNI**: do not introduce abstractions before they are needed.
- **Immutability**: prefer `record`, `final` fields, and `List.copyOf()` when they improve clarity and safety.

## Formatting

- Use `google-java-format` or project Checkstyle when configured.
- One public top-level type per file.
- Match the project's existing indentation style.
- Member order: constants, fields, constructors, public methods, protected methods, private methods.
- Files should usually stay between 200 and 400 lines; 800 lines is the practical upper bound.
- Organize by feature/domain, not by technical type, when the project already follows domain-first layout.

## Modern Java (Java 21)

Use modern language features when they improve clarity:

- `record` for immutable DTOs or value types.
- Sealed classes for closed type hierarchies.
- Pattern matching for `instanceof`.
- Pattern matching in `switch` for exhaustive sealed type handling.
- Text blocks for multi-line strings.
- Switch expressions with arrow syntax.
- `var` only when the local type is obvious from the right-hand side.

```java
if (shape instanceof Circle c) {
    return Math.PI * c.radius() * c.radius();
}

public sealed interface PaymentMethod permits CreditCard, BankTransfer, Wallet {
}

String label = switch (status) {
    case ACTIVE -> "Active";
    case CLOSED -> "Closed";
};
```

## Optional

- Return `Optional<T>` from finder methods when absence is expected.
- Never call `Optional.get()` without checking presence.
- Do not use `Optional` as a field type or method parameter.

```java
return repository.findById(id)
    .map(ResponseDto::from)
    .orElseThrow(() -> new OrderNotFoundException(id));
```

## Streams

- Keep pipelines short, usually three or four operations at most.
- Prefer method references when they remain readable.
- Avoid side effects in stream pipelines.
- Use a simple loop when stream logic becomes hard to read.

## Comments & Javadoc (Mandatory)

All Java code in this project must carry Chinese Javadoc and inline comments where required. Missing comments mean the implementation is incomplete.

### 1. Class-level Javadoc

Every class, interface, and enum has a top-level Javadoc with responsibility, `@author`, and `@since`.

```java
/**
 * 用户管理应用服务实现。
 *
 * <p>负责用户账户创建、状态变更、密码重置等用户用例编排。
 * 写操作通过 CmdExe 执行，查询操作通过 QryExe 执行。
 *
 * @author devkit-java-feature
 * @since 1.0.0
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserServiceI {
}
```

### 2. Method-level Javadoc

All `public` and `protected` methods must have Javadoc including `@param`, `@return`, and `@throws` when applicable.

```java
/**
 * 根据用户编号查询用户详情。
 *
 * @param userId 用户编号，不能为空
 * @return 用户详情 DTO
 * @throws NotFoundException 当用户不存在或已删除时抛出
 */
public UserDTO getById(Long userId) {
}
```

`private` methods need Javadoc only when logic is non-trivial, usually more than ten lines or containing non-obvious business rules.

### 3. Field Comments

Every DO / DTO / BO / Cmd / Qry field must have a `/** */` comment describing its business meaning, not a literal translation of the field name.

```java
@TableName("sys_user")
public class UserDO {
    /** 用户主键，使用雪花算法生成的分布式 ID。 */
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    /** 登录账号，全局唯一，仅支持字母、数字和下划线。 */
    private String username;

    /** BCrypt 加密后的密码哈希，禁止存储明文密码。 */
    private String password;

    /** 账户状态：0=正常，1=锁定，2=禁用。 */
    private Integer status;

    /** 软删除时间，null 表示未删除。 */
    @TableLogic(value = "", delval = "now()")
    private LocalDateTime deletedAt;
}
```

DTO / Cmd / Qry fields additionally use `@Schema(description = "...")` for OpenAPI rendering:

```java
public class UserPageQry extends Query {
    /** 用户名模糊查询关键字。 */
    @Schema(description = "用户名模糊查询关键字", example = "zhang")
    private String usernameKeyword;
}
```

### 4. Controller Annotation Docs

Every controller method must carry `@Operation` and appropriate `@ApiResponse` / `@Parameter` annotations, and keep method Javadoc.

```java
/**
 * 分页查询用户列表。
 *
 * @param qry 查询条件，支持用户名和状态过滤
 * @return 用户分页结果
 */
@GetMapping
@Operation(summary = "分页查询用户", description = "按用户名关键字和状态过滤，支持分页")
@ApiResponse(responseCode = "200", description = "查询成功")
public Result<PageResult<UserDTO>> page(@ParameterObject @Valid UserPageQry qry) {
    return userService.page(qry);
}
```

### 5. Inline Comments for Complex Logic

Whenever there is a non-obvious business rule, workaround, algorithm, or external constraint, write an inline comment explaining why.

```java
// 锁定账户前必须先强制下线所有会话，否则已有 JWT 在过期前仍然可用。
sessionService.revokeAll(userId);

// 这里先更新数据库再发布事件，避免消费者读取到旧状态。
userGateway.update(user);
eventPublisher.publish(new UserLockedEvent(userId));
```

Forbidden comments:

```java
// Wrong: repeats the code
user.setUsername(dto.getUsername());

// Wrong: translates the method name
userService.save(user);
```

### 6. DDD/COLA Layer Specifics

- **ServiceI implementation**: class Javadoc states that it delegates to executors and does not own business logic.
- **CmdExe / QryExe**: class Javadoc states the use-case scenario; `execute` method Javadoc describes the business workflow.
- **Gateway interface**: method Javadoc uses domain semantics, such as "激活账户", not database details such as "update status = 1".
- **Domain Entity**: method comments describe business behavior, not field mutation.
- **Client DTO/Cmd/Qry**: comments describe API contract fields and must not mention domain value object internals.

### 7. Self-check Before Delivery

1. Does every class / interface / enum have top-level Javadoc?
2. Does every `public` / `protected` method have `@param`, `@return`, and `@throws` where applicable?
3. Does every DO / DTO / BO / Cmd / Qry field have a `/** */` business comment?
4. Does every complex logic block have a WHY comment?
5. Do all controller methods have `@Operation`, and do request/response DTOs have `@Schema`?

## Import Completeness

- After writing source/test files, verify all symbols have explicit imports.
- Common misses: `java.util.Map`, sealed interfaces, Hamcrest matchers, `ParameterObject`.

## Never Loop Individual IO

- For-loop DB calls, HTTP requests, MQ publishes, and file reads are N+1 anti-patterns.
- Use batch methods (`saveBatch`, `listByIds`, `IN` clause), async composition (`CompletableFuture`), or batch APIs.

## Error Handling

- Prefer unchecked exceptions for domain errors.
- Create domain-specific `BusinessException` subclasses for business failures.
- Avoid broad `catch (Exception e)` except in top-level handlers.
- See `error-handling.md` and `spring-boot-exception-handling` for full patterns.

## Input Validation

- Validate all user input at system boundaries.
- Never trust external data from API responses, user input, or files.
- See `spring-boot-validation` for Jakarta Bean Validation patterns.

## Code Smells

- **Deep nesting**: prefer early returns.
- **Magic numbers**: use named constants.
- **Long functions**: split into focused methods.

## Anti-Patterns

- `SELECT *` - always specify needed columns.
- Catching generic `Exception` in application logic - use specific business exceptions.
- `@Autowired` on fields for required dependencies - use constructor injection.
- Mutable state where immutable values are enough - default to `final`.
- Comments that repeat the code - write WHY, not WHAT.

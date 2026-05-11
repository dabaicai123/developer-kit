---
paths:
  - "**/*.java"
---

# Java Coding Style

## Core Principles

- **KISS**: simplest solution that works; optimize for clarity over cleverness
- **DRY**: extract repeated logic; introduce abstractions when repetition is real, not speculative
- **YAGNI**: don't build features/abstractions before they're needed; start simple, refactor under pressure
- **Immutability**: prefer immutable data — `record`, `final` fields, `List.copyOf()`. Prevents hidden side effects and enables safe concurrency

## Formatting

- **google-java-format** or **Checkstyle** (Google or Sun style) for enforcement
- One public top-level type per file
- Consistent indent: 2 or 4 spaces (match project standard)
- Member order: constants, fields, constructors, public methods, protected, private
- Files: 200-400 lines typical, 800 max. Organize by feature/domain, not by type

## Modern Java (Java 21)

Use modern features where they improve clarity:

- **Records** for immutable DTOs/value types (Java 16+)
- **Sealed classes** for closed type hierarchies (Java 17+)
- **Pattern matching** `instanceof` — no explicit cast (Java 16+)
- **Pattern matching in switch** — exhaustive sealed type handling (Java 21+)
- **Text blocks** for multi-line strings (Java 15+)
- **Switch expressions** with arrow syntax (Java 14+)
- **`var`** for obvious local variable types

```java
if (shape instanceof Circle c) { return Math.PI * c.radius() * c.radius(); }
public sealed interface PaymentMethod permits CreditCard, BankTransfer, Wallet {}
String label = switch (status) { case ACTIVE -> "Active"; case CLOSED -> "Closed"; };
```

## Optional

- Return `Optional<T>` from finder methods; use `map()/flatMap()/orElseThrow()`
- Never call `get()` without `isPresent()`; never use `Optional` as field type or parameter

```java
return repository.findById(id).map(ResponseDto::from).orElseThrow(() -> new OrderNotFoundException(id));
```

## Streams

- Keep pipelines short (3-4 operations max); prefer method references
- Avoid side effects; for complex logic, prefer a loop over a convoluted pipeline

## Comments & Javadoc (Mandatory)

All Java code in this project MUST carry **Chinese** Javadoc / inline comments. Missing comments == incomplete code. Self-check before delivery.

### 1. Class-level Javadoc (required)

Every class / interface / enum has a top-level Javadoc with responsibility + `@author` + `@since`:

```java
/**
 * 用户管理服务实现。
 *
 * <p>负责用户账户的 CRUD、状态流转、密码重置等核心业务逻辑，
 * 缓存由 {@link com.alicp.jetcache.anno.Cached} 管理，过期时间 1 小时。
 *
 * @author devkit-java-feature
 * @since 1.0.0
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {
```

### 2. Method-level Javadoc (required for public / protected)

All `public` and `protected` methods must have Javadoc including `@param`, `@return`, `@throws`:

```java
/**
 * 根据用户 ID 查询用户详情，结果走 JetCache 缓存。
 *
 * @param userId 用户主键，不能为 null
 * @return 用户详情 VO；若用户不存在或已软删除，抛出 {@link NotFoundException}
 * @throws NotFoundException 当 userId 对应用户不存在时
 */
@Cached(name = "user:", key = "#userId", expire = 3600)
public UserVO getById(Long userId) {
```

`private` methods need Javadoc only when logic is non-trivial (>10 lines or contains non-obvious business rules). Trivial getters/setters/utility methods can skip it.

### 3. Field comments (required on DO / DTO / VO / BO / Cmd / Qry)

Every persistence and transport object field must have a `/** */` comment describing its **business meaning**, not a literal translation of the field name:

```java
@TableName("sys_user")
public class UserDO {
    /** 用户主键（雪花算法生成的分布式 ID） */
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    /** 登录账号，全局唯一，仅支持字母数字下划线，3-32 位 */
    private String username;

    /** BCrypt 加密后的密码哈希，不得明文存储 */
    private String password;

    /** 账户状态：0=正常, 1=锁定, 2=禁用；枚举见 {@link UserStatusEnum} */
    private Integer status;

    /** 软删除时间戳，null 表示未删除；由 @TableLogic 自动维护 */
    @TableLogic(value = "", delval = "now()")
    private LocalDateTime deletedAt;
}
```

DTO / VO / Cmd / Qry fields additionally use `@Schema(description = "...")` for OpenAPI rendering:

```java
public class UserPageQry {
    @Schema(description = "用户名模糊查询关键字", example = "zhang")
    private String usernameKeyword;
}
```

### 4. Controller annotation docs

Every Controller method must carry `@Operation` + `@Parameter` + `@ApiResponse`, AND keep its Javadoc:

```java
/**
 * 分页查询用户列表。
 *
 * @param qry 查询条件，支持用户名、状态过滤
 * @return 分页结果
 */
@GetMapping
@Operation(summary = "分页查询用户", description = "按用户名关键字和状态过滤，支持分页")
@ApiResponse(responseCode = "200", description = "查询成功")
public Result<PageResult<UserVO>> page(@Valid UserPageQry qry) {
```

### 5. Inline comments on complex business logic

Whenever there is a **non-obvious** business rule, algorithm, workaround, or external constraint, write an inline comment explaining **WHY** (not what):

```java
// 锁定账户前必须先强制下线所有会话，否则 JWT 仍然有效直到过期
sessionService.revokeAll(userId);

// 这里手动 flush，因为下面要发 MQ 事件，必须保证 DB 已提交
// 否则消费者可能读到旧数据（参考 #BUG-2024-318）
userMapper.updateById(user);
```

**Forbidden** — trivial restating-the-code comments:

```java
// ❌ Wrong: literal restatement of the code
// 设置用户名
user.setUsername(dto.getUsername());

// ❌ Wrong: translates the method name
// 保存用户
userService.save(user);
```

### 6. DDD/COLA layer specifics

- **CmdExe / QryExe**: class Javadoc states the use-case scenario; the `execute` method Javadoc describes the business workflow steps.
- **Gateway interface**: method Javadoc uses **domain semantics** (e.g. "激活账户"), never database/CRUD semantics ("update status = 1").
- **Domain Entity**: method comments describe **business behavior** ("激活账户"), not field mutation ("设置 status=1").

### 7. Self-check before delivery

After generating code, verify:

1. Does every class / interface / enum have a top-level Javadoc?
2. Does every `public` / `protected` method have `@param` / `@return` / `@throws`?
3. Does every DO / DTO / VO / BO / Cmd / Qry field have a `/** */` comment?
4. Does every complex logic block (>10 lines or branching) have a WHY comment?
5. Do all Controller methods have `@Operation` and request/response DTOs have `@Schema`?

**Missing comments == incomplete code. Fix and re-deliver.**

## Import Completeness

- After writing source/test files, verify all symbols have explicit imports
- Common misses: `java.util.Map`, sealed interfaces, Hamcrest matchers

## Never Loop Individual IO

- For-loop DB calls, HTTP requests, MQ publishes, file reads = N+1 anti-pattern
- Use batch methods (`saveBatch`, `listByIds`, `IN` clause), parallel/async (`CompletableFuture`), or batch APIs

## Error Handling

- Prefer unchecked exceptions for domain errors; create domain-specific `RuntimeException` subclasses
- Avoid broad `catch (Exception e)` unless at top-level handlers; include context in messages
- See `error-handling.md` rule and `spring-boot-exception-handling` skill for full patterns

## Input Validation

- Validate all user input at system boundaries; fail fast with clear error messages
- Never trust external data (API responses, user input, file content)
- See `spring-boot-validation` skill for Jakarta Bean Validation patterns

## Code Smells

- **Deep nesting**: prefer early returns over nested conditionals
- **Magic numbers**: use named constants for thresholds, delays, limits
- **Long functions**: split into focused pieces (<50 lines each)

## Anti-Patterns

- `SELECT *` — always specify needed columns
- Catching generic `Exception` — use specific business exceptions
- `@Autowired` on fields for required deps — use constructor injection
- Mutable state where immutable suffices — default to `final`
- Comments that repeat the code (`// set the name`) — write WHY, not WHAT
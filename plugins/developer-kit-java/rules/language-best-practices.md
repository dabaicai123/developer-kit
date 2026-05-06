---
paths:
  - "**/*.java"
---

# Rule: Java Language Best Practices

## Context

Enforce Java best practices for Spring Boot + MyBatis-Plus projects, covering coding standards, modern Java features, and tech-stack-specific patterns.

## Guidelines

### Dependency Injection

Always use **constructor injection** for required dependencies. Use `@Autowired` only for optional dependencies.

```java
// Good: Constructor injection (required deps are explicit and immutable)
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserEntity> implements UserService {
    private final OrderService orderService;

    public UserServiceImpl(OrderService orderService) {
        this.orderService = orderService;
    }
}

// Bad: Field injection (hidden dependencies, mutable)
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserEntity> implements UserService {
    @Autowired
    private OrderService orderService; // WRONG
}
```

### MyBatis-Plus Query Patterns

Always use `LambdaQueryWrapper` for type-safe queries. Never use `QueryWrapper` with string column names.

```java
// Good: LambdaQueryWrapper (type-safe, refactoring-safe)
lambdaQuery()
    .eq(UserEntity::getUsername, username)
    .like(UserEntity::getEmail, keyword)
    .between(UserEntity::getCreatedAt, start, end)
    .list();

// Bad: QueryWrapper with strings (fragile, no compile-time check)
new QueryWrapper<UserEntity>()
    .eq("username", username) // WRONG: string column name
    .like("email", keyword)   // WRONG: typos won't be caught
```

### Transaction Management

- Use `@Transactional(readOnly = true)` for all query methods
- Use `@Transactional` for write operations
- Keep transactions short — never hold locks during external calls

```java
// Good
@Transactional(readOnly = true)
public PageResult<UserVO> page(int pageNum, int pageSize) {
    Page<UserEntity> mpPage = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
    return PageResult.of(mpPage).map(UserConverter::toVO);
}

@Transactional
public void createUser(UserCreateDTO dto) {
    userMapper.insert(convert(dto));
}
```

### Caching with JetCache

Always set expiration on cached data. Never use cache without `expire`.

```java
// Good: Cache with expiration
@Cached(name = "user:", key = "#id", expire = 3600)
public UserVO getById(Long id) { ... }

@CacheInvalidate(name = "user:", key = "#id")
public void updateUser(Long id, UserUpdateDTO dto) { ... }

// Bad: Cache without expiration (memory leak risk)
@Cached(name = "user:", key = "#id") // WRONG: no expire
```

### Soft Delete

Always use `@TableLogic` for soft delete. Never use physical delete for business data.

```java
// Good: Soft delete with @TableLogic
@TableLogic
@TableField(fill = FieldFill.UPDATE)
private LocalDateTime deletedAt;

// Bad: Physical delete
@TableField(value = "is_deleted") // WRONG: use @TableLogic instead
private Integer isDeleted;
```

### Response Format

Use the unified `Result<T>` wrapper for all API responses. Outer structure is always exactly `code/msg/data`. See `spring-boot-rest-api-standards/references/unified-result-pattern.md` for full definition.

```java
Result.success(userVO);                              // single item
Result.success(pageData);                             // page query (Result.PageData<T>)
Result.success(list);                                 // list
Result.success();                                     // no data
Result.fail(404, "User not found");                   // error

// Bad: Inconsistent formats
return userVO;                              // WRONG: no Result wrapper
return ResponseEntity.ok(userVO);           // WRONG: use Result instead
```
return Result.fail("NOT_FOUND", "msg");     // WRONG: String code, use int HTTP status
```

### Java 21 Features

Use modern Java features when appropriate:

| Feature | Use When |
|---------|----------|
| `var` | Type is obvious from context (e.g., `var users = service.list()`) |
| Records | Immutable data carriers (DTOs, VOs, config) |
| Pattern matching | `instanceof` checks with type extraction |
| Switch expressions | Multi-branch logic with return value |
| Sealed classes | Restricted type hierarchies |
| Text blocks | Multi-line strings (SQL, JSON) |

## Anti-Patterns

- `SELECT *` — always specify needed columns
- Catching generic `Exception` — use specific business exceptions
- `@Autowired` on fields — use constructor injection
- `QueryWrapper` with string names — use `LambdaQueryWrapper`
- Cache without `expire` — always set expiration
- Missing `@Transactional(readOnly = true)` on queries
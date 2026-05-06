---
paths:
  - "**/*Mapper.java"
  - "**/*Service.java"
  - "**/*ServiceImpl.java"
  - "**/*Entity.java"
---

# Rule: MyBatis-Plus Conventions

## Context

Enforce MyBatis-Plus best practices for mapper, service, and entity definitions. These conventions ensure type-safe queries, consistent patterns, and proper ORM usage.

## Guidelines

### Entity Conventions

```java
// Good: Complete MyBatis-Plus entity
@Data
@TableName("t_user")
public class UserEntity {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    private String username;
    private String email;

    @TableLogic
    @TableField(fill = FieldFill.UPDATE)
    private LocalDateTime deletedAt;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
```

Required entity annotations:
- `@TableName("t_xxx")` — explicit table name mapping
- `@TableId(type = IdType.ASSIGN_ID)` — use ASSIGN_ID for distributed systems
- `@TableLogic` — soft delete field (never physical delete)
- `@TableField(fill = FieldFill.INSERT/UPDATE)` — auto-fill timestamps

### Mapper Conventions

```java
// Good: Standard mapper interface
public interface UserMapper extends BaseMapper<UserEntity> {
    // Custom queries only when LambdaQueryWrapper cannot express the logic
    @Select("SELECT * FROM t_user WHERE email = #{email} AND deleted_at IS NULL")
    UserEntity selectByEmail(@Param("email") String email);
}
```

Rules:
- Always extend `BaseMapper<XxxEntity>`
- Only add custom methods when `LambdaQueryWrapper` cannot express the query
- Use `@Select` annotation for simple custom queries (prefer over XML mapper files)
- Use `#{param}` (parameterized) — never `${param}` (raw interpolation, SQL injection risk)

### Service Conventions

```java
// Good: Service interface + implementation
public interface UserService extends IService<UserEntity> {
    PageResult<UserVO> page(int pageNum, int pageSize, UserQueryBO query);
    UserVO getById(Long id);
    void create(UserCreateDTO dto);
    void update(Long id, UserUpdateDTO dto);
    void removeById(Long id);
}

@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserEntity> implements UserService {

    @Override
    @Transactional(readOnly = true)
    public PageResult<UserVO> page(int pageNum, int pageSize, UserQueryBO query) {
        LambdaQueryWrapper<UserEntity> wrapper = lambdaQuery()
            .like(StringUtils.isNotBlank(query.getUsername()), UserEntity::getUsername, query.getUsername())
            .eq(query.getEmail() != null, UserEntity::getEmail, query.getEmail())
            .between(query.getStart() != null, UserEntity::getCreatedAt, query.getStart(), query.getEnd());
        Page<UserEntity> mpPage = baseMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return PageResult.of(mpPage).map(UserConverter::toVO);
    }

    @Override
    @Transactional
    public void create(UserCreateDTO dto) {
        UserEntity entity = convert(dto);
        userMapper.insert(entity);
    }
}
```

Rules:
- Interface must extend `IService<XxxEntity>`
- Implementation must extend `ServiceImpl<XxxMapper, XxxEntity>`
- Use `lambdaQuery()` / `lambdaUpdate()` inside ServiceImpl (not `new LambdaQueryWrapper`)
- Use conditional expressions: `.eq(condition, column, value)` for optional filters
- Use `@Transactional(readOnly = true)` for query methods
- Use `@Transactional` for write methods

### Query Conventions

```java
// Good: LambdaQueryWrapper with conditional expressions
lambdaQuery()
    .eq(StringUtils.isNotBlank(name), UserEntity::getUsername, name)
    .like(StringUtils.isNotBlank(keyword), UserEntity::getEmail, keyword)
    .between(start != null, UserEntity::getCreatedAt, start, end)
    .orderByDesc(UserEntity::getCreatedAt)
    .list();

// Bad: QueryWrapper with string column names
new QueryWrapper<UserEntity>()
    .eq("username", name)        // WRONG: fragile, no type safety
    .like("email", keyword)      // WRONG: typos not caught at compile time
    .orderByDesc("created_at");  // WRONG: string column reference
```

### Pagination Conventions

```java
// Good: PageResult.of(mpPage).map() 统一转换
Page<UserEntity> mpPage = new Page<>(pageNum, pageSize);
baseMapper.selectPage(mpPage, wrapper);
return PageResult.of(mpPage).map(UserConverter::toVO);

// Bad: In-memory pagination (memory risk)
List<UserEntity> all = userMapper.selectList(wrapper);
int start = (pageNum - 1) * pageSize;
List<UserEntity> pageData = all.subList(start, start + pageSize); // WRONG
```

## Anti-Patterns

- `QueryWrapper` with string column names — use `LambdaQueryWrapper`
- `${param}` in mapper SQL — use `#{param}` (parameterized)
- Direct `BaseMapper` calls in Controller — go through Service
- In-memory pagination — use `Page<>` object
- Physical delete — use `@TableLogic` soft delete
- `new LambdaQueryWrapper<>` outside ServiceImpl — use `lambdaQuery()`
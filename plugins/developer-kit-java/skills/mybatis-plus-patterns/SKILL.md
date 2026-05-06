---
name: mybatis-plus-patterns
description: MyBatis-Plus patterns for Spring Boot 3.5.x covering mapper, entity, service layer, pagination, soft delete, and field fill. Use for Java Spring Boot backend development with MyBatis-Plus as ORM.
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# MyBatis-Plus Patterns

MyBatis-Plus ORM patterns for Spring Boot 3.5.x with PostgreSQL.

## When to Use

- Manually writing or editing a single Mapper/Entity/Service (not batch generation)
- Configuring MyBatis-Plus pagination, soft delete, field fill
- Understanding entity annotations (@TableName, @TableId, @TableLogic)
- Setting up MyBatis-Plus interceptors
- Writing LambdaQueryWrapper queries

## When NOT to Use

- For batch code generation from database tables → use `mybatis-plus-generator`
- `mybatis-plus-generator` creates full CRUD scaffolding; this skill is for coding patterns when writing/editing individual modules

## Related Skills

- For REST API standards → `spring-boot-rest-api-standards`
- For exception handling → `spring-boot-exception-handling`
- For validation → `spring-boot-validation`
- For caching → `jetcache`
- For logging → `spring-boot-logging`
- For async processing → `spring-boot-event-driven-patterns`
- For code generation → `mybatis-plus-generator`

## Mapper Pattern

```java
/**
 * 用户数据访问接口
 * <p>提供用户表的 CRUD 操作及自定义查询方法</p>
 */
@Mapper
public interface UserMapper extends BaseMapper<UserEntity> {
    /**
     * 查询指定状态的用户列表（分页）
     *
     * @param status 用户状态枚举
     * @param page   分页参数
     * @return 按创建时间倒序排列的用户分页结果
     */
    @Select("SELECT * FROM user WHERE status = #{status} ORDER BY created_at DESC")
    List<UserEntity> findActiveUsers(@Param("status") UserStatus status, Page<UserEntity> page);
}
```

## Entity Definition

```java
/**
 * 用户实体类
 * <p>映射数据库 user 表，包含用户基本信息、状态及时间字段</p>
 *
 * @author author-name
 */
@Data
@EqualsAndHashCode(callSuper = false)
@TableName("user")
public class UserEntity {
    /**
     * 用户ID，自增主键
     */
    @TableId(type = IdType.AUTO)
    private Long id;

    /**
     * 用户名，唯一标识
     */
    private String username;

    /**
     * 用户邮箱
     */
    private String email;

    /**
     * 逻辑删除标识（0=未删除，1=已删除）
     */
    @TableLogic
    private Integer deleted;

    /**
     * 创建时间，插入时自动填充
     */
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    /**
     * 更新时间，插入和更新时自动填充
     */
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
```

## Service Interface & Implementation (IService Pattern)

```java
/**
 * 用户服务接口
 * <p>提供用户 CRUD 及自定义查询业务方法</p>
 */
public interface UserService extends IService<UserEntity> {
    /**
     * 根据邮箱查询用户
     *
     * @param email 用户邮箱
     * @return 对应的用户实体，不存在则返回 null
     */
    UserEntity findByEmail(String email);
}

/**
 * 用户服务实现类
 * <p>继承 ServiceImpl 获得 CRUD 基础方法，通过 baseMapper 访问数据层</p>
 *
 * @author author-name
 */
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, UserEntity> implements UserService {

    /**
     * 根据邮箱查询用户
     *
     * @param email 用户邮箱
     * @return 对应的用户实体，不存在则返回 null
     */
    @Override
    @Transactional(readOnly = true)
    public UserEntity findByEmail(String email) {
        return lambdaQuery().eq(UserEntity::getEmail, email).one();
    }
}
```

## Pagination Configuration

```java
/**
 * MyBatis-Plus 配置类
 * <p>注册分页拦截器，支持 PostgreSQL 分页查询</p>
 */
@Configuration
public class MybatisPlusConfig {
    @Bean
    public MybatisPlusInterceptor mybatisPlusInterceptor() {
        MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
        interceptor.addInnerInterceptor(new PaginationInnerInterceptor(DbType.POSTGRE_SQL));
        return interceptor;
    }
}
```

## Field Fill (Auto-fill timestamps)

```java
/**
 * MyBatis-Plus 元数据自动填充处理器
 * <p>插入时填充 createdAt 和 updatedAt，更新时填充 updatedAt</p>
 */
@Component
public class MybatisPlusMetaObjectHandler implements MetaObjectHandler {
    @Override
    public void insertFill(MetaObject metaObject) {
        this.strictInsertFill(metaObject, "createdAt", LocalDateTime.class, LocalDateTime.now());
        this.strictInsertFill(metaObject, "updatedAt", LocalDateTime.class, LocalDateTime.now());
    }

    @Override
    public void updateFill(MetaObject metaObject) {
        this.strictUpdateFill(metaObject, "updatedAt", LocalDateTime.class, LocalDateTime.now());
    }
}
```

## Soft Delete

- Entity: use `@TableLogic` on `deleted` field
- Config: `mybatis-plus.global-config.db-config.logic-delete-value=1` and `logic-not-delete-value=0`
- All `select*` queries automatically filter deleted records
- `deleteById` executes UPDATE instead of DELETE

## Query Wrapper

```java
/**
 * 构建用户查询条件：状态为活跃、用户名模糊匹配、按创建时间倒序
 */
LambdaQueryWrapper<UserEntity> wrapper = new LambdaQueryWrapper<>();
wrapper.eq(UserEntity::getStatus, UserStatus.ACTIVE)
       .like(UserEntity::getUsername, keyword)
       .orderByDesc(UserEntity::getCreatedAt);
Page<UserEntity> result = userMapper.selectPage(page, wrapper);
```

## Best Practices

- Use **IService/ServiceImpl pattern**: Service 接口继承 `IService<Entity>`，实现类继承 `ServiceImpl<Mapper, Entity>`
- Use `@Transactional(readOnly = true)` for all query methods
- Use `LambdaQueryWrapper` instead of `QueryWrapper` for type safety
- Use `@TableLogic` for soft deletes — never physically delete business data
- Use `Page<>` for pagination, never manually calculate offset
- Use `@Data + @EqualsAndHashCode(callSuper = false)` for Entity classes
- Add detailed JavaDoc comments: class comments explain purpose, method comments include parameters/return/exceptions, field comments explain business meaning
- Keep mappers simple — complex queries go in XML or `@Select`
- Use `lambdaQuery()` / `lambdaUpdate()` inside ServiceImpl for type-safe CRUD inside service methods
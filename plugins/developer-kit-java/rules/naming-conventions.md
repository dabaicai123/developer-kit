---
paths:
  - "**/*.java"
---

# Rule: Java Naming Conventions

## Context

Enforce consistent naming conventions across Java/Spring Boot projects following Java standards and Spring ecosystem patterns.

## Guidelines

### Class Naming

| Type | Convention | Example |
|------|-----------|---------|
| Entity | PascalCase + Entity suffix | `UserEntity`, `OrderEntity` |
| Mapper | PascalCase + Mapper suffix | `UserMapper`, `OrderMapper` |
| Service Interface | PascalCase + Service suffix | `UserService`, `OrderService` |
| Service Impl | PascalCase + ServiceImpl suffix | `UserServiceImpl` |
| Controller | PascalCase + Controller suffix | `UserController` |
| DTO | PascalCase + DTO suffix | `UserCreateDTO`, `UserUpdateDTO` |
| VO | PascalCase + VO suffix | `UserVO`, `UserPageVO` |
| BO | PascalCase + BO suffix | `UserQueryBO` |
| Config | PascalCase + Config suffix | `RedisConfig`, `MybatisPlusConfig` |
| Exception | PascalCase + Exception suffix | `BusinessException` |
| Utility | PascalCase + Utils/Helper suffix | `RedisUtils` |

### Method Naming

- Query methods: `getById`, `listByCondition`, `page`
- Command methods: `create`, `update`, `remove`, `save`
- Boolean methods: `isXxx`, `hasXxx`, `canXxx`
- Event handlers: `onXxx` (e.g., `onOrderCreated`)

### Variable Naming

- Local variables: camelCase (`userId`, `orderList`)
- Constants: UPPER_SNAKE_CASE (`MAX_RETRY_COUNT`)
- Boolean variables: `isXxx`, `hasXxx`
- Collection variables: plural form (`users`, `orders`)

### Package Naming (COLA Architecture)

| Layer | Package | Example |
|-------|---------|---------|
| Adapter | `adapter.controller`, `adapter.web` | `com.example.adapter.controller` |
| Application | `app.service`, `app.executor` | `com.example.app.service` |
| Domain | `domain.entity`, `domain.gateway` | `com.example.domain.entity` |
| Infrastructure | `infrastructure.persistence`, `infrastructure.config` | `com.example.infrastructure.persistence` |

## Examples

### Good

```java
// Entity
@TableName("t_user")
public class UserEntity {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
}

// Mapper
public interface UserMapper extends BaseMapper<UserEntity> {}

// Service
public interface UserService extends IService<UserEntity> {}
public class UserServiceImpl extends ServiceImpl<UserMapper, UserEntity> implements UserService {}

// Controller
@RestController
@RequestMapping("/api/v1/users")
public class UserController {}

// DTO
public class UserCreateDTO {
    @NotBlank
    private String username;
}
```

### Bad

```java
// Wrong: no Entity suffix, no PascalCase
public class user {}

// Wrong: ServiceImpl doesn't follow naming
public class UserServiceImple // typo
public class UserServiceImpl2 // numbered suffix

// Wrong: inconsistent DTO naming
public class UserRequest {} // should be UserCreateDTO
public class UserResponse {} // should be UserVO
```
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
| Data Object (MVC) | PascalCase + DO suffix | `UserDO`, `OrderDO` |
| Domain Entity (DDD) | PascalCase, no suffix | `Order`, `Customer` |
| Mapper | PascalCase + Mapper suffix | `UserMapper`, `OrderMapper` |
| Service Interface | PascalCase + Service suffix | `UserService`, `OrderService` |
| Service Impl | PascalCase + ServiceImpl suffix | `UserServiceImpl` |
| Gateway (DDD) | PascalCase + Gateway suffix | `OrderGateway` |
| Gateway Impl (DDD) | PascalCase + GatewayImpl suffix | `OrderGatewayImpl` |
| Controller | PascalCase + Controller suffix | `UserController` |
| DTO | PascalCase + DTO suffix | `UserCreateDTO`, `UserUpdateDTO` |
| VO | PascalCase + VO suffix | `UserVO`, `UserPageVO` |
| BO | PascalCase + BO suffix | `UserQueryBO` |
| Config | PascalCase + Config suffix | `RedisConfig`, `MybatisPlusConfig` |
| Exception | PascalCase + Exception suffix | `BusinessException` |
| Utility | PascalCase + Utils/Helper suffix | `RedisUtils` |

**Architecture note**: MVC projects use `DO` suffix for persistence objects. COLA/DDD projects use bare names for domain entities and `DO` suffix for infrastructure persistence objects.

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
| Infrastructure | `infrastructure.gatewayimpl`, `infrastructure.mapper`, `infrastructure.config` | `com.example.infrastructure.gatewayimpl` |

## Examples

### Good

```java
// Data Object (MVC)
@TableName("user")
public class UserDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
}

// Domain Entity (DDD/COLA) — no suffix, no ORM annotations
public class Order {
    private String orderId;
    private List<OrderItem> items;
}

// Infrastructure DO (DDD/COLA) — persistence mapping
@TableName("order")
public class OrderDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
}

// Mapper
public interface UserMapper extends BaseMapper<UserDO> {}

// Service (MVC)
public interface UserService extends IService<UserDO> {}
public class UserServiceImpl extends ServiceImpl<UserMapper, UserDO> implements UserService {}

// Gateway (DDD/COLA)
public interface OrderGateway {
    void save(Order order);
    Optional<Order> findById(String id);
}

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
// Wrong: no DO suffix for persistence object
public class user {}
public class User {} // should be UserDO for MVC, or bare Order for DDD domain

// Wrong: ServiceImpl doesn't follow naming
public class UserServiceImple // typo
public class UserServiceImpl2 // numbered suffix

// Wrong: inconsistent DTO naming
public class UserRequest {} // should be UserCreateDTO
public class UserResponse {} // should be UserVO

// Wrong: Entity suffix for persistence objects (use DO suffix)
public class UserEntity {} // should be UserDO
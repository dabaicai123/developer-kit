---
paths:
  - "**/*.java"
---

# Rule: Java Project Structure

## Context

Enforce consistent project structure following either MVC (simple modules) or COLA/DDD (complex domains) patterns. Ensure layer separation and proper dependency direction.

## Guidelines

### MVC Structure (Simple Modules)

```
com.example.module/
├── controller/
│   └── UserController.java
├── service/
│   ├── UserService.java        (interface)
│   └── UserServiceImpl.java    (implementation)
├── mapper/
│   └── UserMapper.java
├── entity/
│   └── UserEntity.java
├── dto/
│   ├── UserCreateDTO.java
│   └── UserUpdateDTO.java
├── vo/
│   ├── UserVO.java
│   └── UserPageVO.java
└── bo/
│   └── UserQueryBO.java
```

### COLA/DDD Structure (Complex Domains)

```
com.example.user/
├── adapter/
│   ├── controller/
│   │   └── UserController.java
│   └── web/
│       └── UserVO.java
├── app/
│   ├── service/
│   │   ├── UserService.java
│   │   └── UserServiceImpl.java
│   └── executor/
│       └── UserCreateExecutor.java
├── domain/
│   ├── entity/
│   │   └── UserEntity.java
│   ├── gateway/
│   │   └── UserGateway.java
│   └── event/
│       └── UserCreatedEvent.java
├── infrastructure/
│   ├── persistence/
│   │   ├── UserMapper.java
│   │   └── UserGatewayImpl.java
│   ├── config/
│   └─ gateway/        (external service clients)
│       └── UserClient.java
```

### Dependency Direction Rules

- **Controller** → depends on **Service** (only)
- **Service** → depends on **Mapper** and **Domain Entity** (only)
- **Mapper** → depends on **Entity** (only)
- **Never**: Controller → Mapper (bypass Service)
- **Never**: Service → Controller (upward dependency)
- **Never**: Entity → Service (upward dependency)

### Shared/Common Structure

```
com.example.common/
├── config/             (Spring configuration classes)
│   ├── MybatisPlusConfig.java
│   ├── RedisConfig.java
│   └── SecurityConfig.java
├── exception/          (Global exception handling)
│   ├── BusinessException.java
│   ├── NotFoundException.java
│   └── GlobalExceptionHandler.java
├── result/             (Response wrapper)
│   ├── Result.java              (unified response: {"code":200,"msg":"success","data":...})
│   └── PageResult.java          (pagination: records + total + page + pageSize, with MyBatis-Plus Page.of())
├── enums/              (Shared enumerations)
└── utils/              (Utility classes)
    ├── RedisUtils.java
    └── DistributedLockUtils.java
```

## Examples

### Good

```java
// Controller only depends on Service
@RestController
public class UserController {
    private final UserService userService; // Service, not Mapper
    public UserController(UserService userService) {
        this.userService = userService;
    }
}
```

### Bad

```java
// Controller directly depends on Mapper (violates layer separation)
@RestController
public class UserController {
    @Autowired
    private UserMapper userMapper; // WRONG: should use Service
}
```
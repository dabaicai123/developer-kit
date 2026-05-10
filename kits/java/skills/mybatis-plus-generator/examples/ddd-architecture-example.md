# DDD/COLA Architecture Code Generation Example

## Scenario

Generate COLA architecture code for the `user` table, including DO, Mapper, Gateway, GatewayImpl, Cmd, CmdExe, QryExe, Controller, DTO, and Converter.

## Configuration

```
Database: PostgreSQL, table: user
Architecture: COLA (DDD)
Language: Java
Package: com.example
Lombok: enabled
OpenAPI 3: enabled
```

## COLA Package Mapping

> This mapping follows the **flat per-domain** layout defined in `ddd-cola` SKILL.md. Each domain's files are grouped together, not split into nested sub-packages.

```
com.example/                              # Across 6 Maven modules
├── client/                               # demo-client module
│   ├── api/
│   │   ├── UserServiceI.java             # Service interface (returns Result<T>)
│   │   └── UserFeignClient.java          # @FeignClient (optional)
│   ├── dto/
│   │   ├── UserAddCmd.java               # extends Command
│   │   ├── UserUpdateCmd.java            # extends Command
│   │   └── UserQry.java                  # extends Query
│   ├── dto/data/
│   │   └── UserDTO.java                  # Data Transfer Object
│   ├── common.result/                    # Result, PageResult (shared)
│   ├── common.exception/                 # BusinessException (shared)
│   └── common.dto/                       # Command, Query marker base classes
├── adapter/                              # demo-adapter module
│   └── web/
│       └── UserController.java           # @RestController
├── app/                                  # demo-app module
│   └── user/
│       ├── UserServiceImpl.java          # Implements UserServiceI
│       └── executor/
│           ├── UserAddCmdExe.java        # Write handler
│           └── query/
│               └── UserQryExe.java       # Read handler
├── domain/                               # demo-domain module
│   └── user/
│       ├── User.java                     # Entity (@Data, bare name)
│       ├── UserStatus.java               # Enum
│       └── gateway/
│           └── UserGateway.java          # Persistence port interface
└── infrastructure/                       # demo-infrastructure module
    └── user/
        ├── UserGatewayImpl.java          # Implements UserGateway
        ├── UserDO.java                   # @TableName, @Data
        ├── UserMapper.java               # MyBatis-Plus Mapper
        └── UserDOConverter.java          # MapStruct Domain ↔ DO
```

## Functional Requirements

```
User management features:
1. Create user (Cmd → CmdExe → Domain → Gateway)
2. Query user by ID (Qry → QryExe → Mapper directly, bypass Domain)
3. Update user information (Cmd → CmdExe → Domain → Gateway)
4. Delete user
5. List users with pagination (Qry → QryExe → Mapper)
```

## Generated Code Examples

### 1. Domain Entity — User (bare name, no ORM annotations)

```java
package com.example.domain.user;

/**
 * User domain entity — represents a registered user.
 */
public class User {
    private String userId;
    private String username;
    private String email;
    private UserStatus status;

    public static User create(String username, String email) {
        User user = new User();
        user.userId = IdUtil.simpleUUID();
        user.username = username;
        user.email = email;
        user.status = UserStatus.ACTIVE;
        return user;
    }

    public void updateEmail(String newEmail) {
        this.email = newEmail;
    }

    public void deactivate() {
        this.status = UserStatus.DISABLED;
    }
}
```

### 2. DO — UserDO (infrastructure, full MyBatis-Plus annotations)

```java
package com.example.user;

@Data
@EqualsAndHashCode(callSuper = false)
@TableName("user")
public class UserDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    private String userId;

    private String username;

    private String email;

    private String status;

    @TableLogic(value = "", delval = "now()")
    private LocalDateTime deletedAt;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @Version
    private Integer version;
}
```

### 3. Gateway (port interface — domain layer)

```java
package com.example.domain.user.gateway;

public interface UserGateway {
    void save(User user);
    void update(User user);
    Optional<User> findById(String userId);
}
```

### 4. Converter — UserDOConverter (MapStruct, infrastructure)

```java
package com.example.user;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface UserDOConverter {
    UserDO toDO(User user);
    User toDomain(UserDO userDO);

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateDOFromDomain(User user, @MappingTarget UserDO userDO);
}
```

### 5. GatewayImpl (infrastructure, implements Gateway)

```java
package com.example.user;

@Repository
@RequiredArgsConstructor
public class UserGatewayImpl implements UserGateway {
    private final UserMapper userMapper;
    private final UserDOConverter userDOConverter;

    @Override
    public void save(User user) {
        userMapper.insert(userDOConverter.toDO(user));
    }

    @Override
    public void update(User user) {
        UserDO existing = userMapper.selectOne(
            new LambdaQueryWrapper<UserDO>().eq(UserDO::getUserId, user.getUserId()));
        userDOConverter.updateDOFromDomain(user, existing);
        userMapper.updateById(existing);
    }

    @Override
    public Optional<User> findById(String userId) {
        return Optional.ofNullable(userMapper.selectOne(
            new LambdaQueryWrapper<UserDO>().eq(UserDO::getUserId, userId)))
            .map(userDOConverter::toDomain);
    }
}
```

### 6. Cmd (request object — in client module)

```java
package com.example.dto;

public class UserAddCmd extends Command {
    @NotBlank
    private String username;

    @NotBlank @Email
    private String email;
}

public class UserUpdateCmd extends Command {
    @NotBlank
    private String userId;

    @NotBlank @Email
    private String newEmail;
}
```

### 7. CmdExe (write handler — goes through Domain)

```java
package com.example.user.executor;

@Component
@RequiredArgsConstructor
public class UserAddCmdExe {
    private final UserGateway userGateway;

    @Transactional(rollbackFor = Exception.class)
    public Result<Void> execute(UserAddCmd cmd) {
        User user = User.create(cmd.getUsername(), cmd.getEmail());
        userGateway.save(user);
        return Result.success();
    }
}
```

### 8. QryExe (read handler — bypasses Domain, queries Mapper directly)

```java
package com.example.user.executor.query;

@Component
@RequiredArgsConstructor
public class UserQryExe {
    private final UserMapper userMapper;
    private final UserDOConverter userDOConverter;

    public Result<UserDTO> findById(String userId) {
        return Optional.ofNullable(userMapper.selectOne(
            new LambdaQueryWrapper<UserDO>().eq(UserDO::getUserId, userId)))
            .map(userDOConverter::toDomain)
            .map(UserDTO::from)
            .map(Result::success)
            .orElseThrow(() -> new NotFoundException("User", userId));
    }

    public PageResult<UserDTO> page(int pageNum, int pageSize, UserQry qry) {
        LambdaQueryWrapper<UserDO> wrapper = new LambdaQueryWrapper<UserDO>()
            .like(StringUtils.isNotBlank(qry.getUsername()), UserDO::getUsername, qry.getUsername())
            .eq(StringUtils.isNotBlank(qry.getStatus()), UserDO::getStatus, qry.getStatus())
            .orderByDesc(UserDO::getCreatedAt);
        Page<UserDO> mpPage = userMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return PageResult.of(mpPage).map(userDOConverter::toDomain).map(UserDTO::from);
    }
}
```

### 9. Controller (adapter layer)

```java
package com.example.web;

@RestController
@RequestMapping("/api/v1/users")
@Tag(name = "User Management")
@RequiredArgsConstructor
@Validated
public class UserController {
    private final UserServiceI userService;

    @Operation(summary = "Create user")
    @PostMapping
    public Result<Void> create(@Valid @RequestBody UserAddCmd cmd) {
        return userService.addUser(cmd);
    }

    @Operation(summary = "Get user by ID")
    @GetMapping("/{userId}")
    public Result<UserDTO> get(@PathVariable @NotBlank String userId) {
        return userService.getUser(userId);
    }
}
```

## COLA Architecture Characteristics

### Dependency Direction

```
start → adapter → app → {client, infrastructure → domain → client}
```

Domain depends on client (Result/BusinessException only); Infrastructure implements Domain Gateway; App depends on client + infrastructure (read path shortcut).

### CQRS Paths

| Type | Path |
|---|---|
| Write | Controller → ServiceI → CmdExe → Domain → Gateway → GatewayImpl → DB |
| Read | Controller → ServiceI → QryExe → Mapper → DB |

### Key Distinctions from Generic DDD

- Domain entities: **bare names** (no suffix, no ORM annotations)
- Infrastructure DOs: **DO suffix** with MyBatis-Plus annotations
- Persistence port: **Gateway** (not Repository)
- Persistence impl: **GatewayImpl** (not RepositoryImpl)
- Request objects: **Cmd** (create) / **Qry** (query) — in **client module**, not app
- Write handler: **CmdExe**, not Application Service directly
- Read handler: **QryExe**, bypasses Domain for performance
- Object mapping: **Converter** (MapStruct), not Assembler
- Service interface: **ServiceI** (COLA naming convention) — in **client module**

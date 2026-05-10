# DDD/COLA Architecture Code Generation Example

## Scenario

Generate COLA architecture code for the `user` table, including DO, Mapper, Gateway, GatewayImpl, Cmd, CmdExe, QryExe, Controller, DTO, and Converter.

## Configuration

```
Database: PostgreSQL, table: user
Architecture: COLA V5 (DDD)
Language: Java
Package: com.example.app
Lombok: enabled
OpenAPI 3: enabled
```

## COLA Package Mapping

```
com.example.app/
├── adapter/
│   ├── controller/           # UserController
│   └── converter/            # UserDTOConverter (MapStruct)
├── app/
│   ├── executor/             # UserAddCmdExe, UserQryExe
│   └── service/              # UserServiceI (interface)
├── domain/
│   ├── model/
│   │   └── entity/           # User (bare name, no suffix)
│   └── gateway/              # UserGateway (port interface)
└── infrastructure/
    ├── gatewayimpl/
│   │   ├── converter/        # UserDOConverter (MapStruct)
│   │   └── UserGatewayImpl
│   └── mapper/
│       ├── dataobject/       # UserDO (with MyBatis-Plus annotations)
│       └── UserMapper
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
package com.example.app.domain.model.entity;

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
package com.example.app.infrastructure.mapper.dataobject;

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
package com.example.app.domain.gateway;

public interface UserGateway {
    void save(User user);
    void update(User user);
    Optional<User> findById(String userId);
}
```

### 4. Converter — UserDOConverter (MapStruct, infrastructure)

```java
package com.example.app.infrastructure.gatewayimpl.converter;

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
package com.example.app.infrastructure.gatewayimpl;

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

### 6. Cmd (request object)

```java
package com.example.app.app.executor.command;

public record UserAddCmd(
    @NotBlank String username,
    @NotBlank @Email String email
) {}

public record UserUpdateCmd(
    @NotBlank String userId,
    @NotBlank @Email String newEmail
) {}
```

### 7. CmdExe (write handler — goes through Domain)

```java
package com.example.app.app.executor;

@Component
@RequiredArgsConstructor
public class UserAddCmdExe {
    private final UserGateway userGateway;

    @Transactional(rollbackFor = Exception.class)
    public UserDTO execute(UserAddCmd cmd) {
        User user = User.create(cmd.username(), cmd.email());
        userGateway.save(user);
        return UserDTO.from(user);
    }
}
```

### 8. QryExe (read handler — bypasses Domain, queries Mapper directly)

```java
package com.example.app.app.executor;

@Component
@RequiredArgsConstructor
public class UserQryExe {
    private final UserMapper userMapper;
    private final UserDOConverter userDOConverter;

    public UserDTO findById(String userId) {
        return Optional.ofNullable(userMapper.selectOne(
            new LambdaQueryWrapper<UserDO>().eq(UserDO::getUserId, userId)))
            .map(userDOConverter::toDomain)
            .map(UserDTO::from)
            .orElseThrow(() -> new NotFoundException("User", userId));
    }

    public PageResult<UserDTO> page(int pageNum, int pageSize, UserQueryBO query) {
        LambdaQueryWrapper<UserDO> wrapper = new LambdaQueryWrapper<UserDO>()
            .like(StringUtils.isNotBlank(query.getUsername()), UserDO::getUsername, query.getUsername())
            .eq(StringUtils.isNotBlank(query.getStatus()), UserDO::getStatus, query.getStatus())
            .orderByDesc(UserDO::getCreatedAt);
        Page<UserDO> mpPage = userMapper.selectPage(new Page<>(pageNum, pageSize), wrapper);
        return PageResult.of(mpPage).map(userDOConverter::toDomain).map(UserDTO::from);
    }
}
```

### 9. Controller (adapter layer)

```java
package com.example.app.adapter.controller;

@RestController
@RequestMapping("/api/v1/users")
@Tag(name = "User Management")
@RequiredArgsConstructor
@Validated
public class UserController {
    private final UserAddCmdExe userAddCmdExe;
    private final UserQryExe userQryExe;

    @Operation(summary = "Create user")
    @PostMapping
    public Result<UserDTO> create(@Valid @RequestBody UserAddCmd cmd) {
        return Result.success(userAddCmdExe.execute(cmd));
    }

    @Operation(summary = "Get user by ID")
    @GetMapping("/{userId}")
    public Result<UserDTO> get(@PathVariable @NotBlank String userId) {
        return Result.success(userQryExe.findById(userId));
    }
}
```

## COLA Architecture Characteristics

### Dependency Direction

```
Adapter → Application → Domain ← Infrastructure
```

Domain depends on nothing; Application depends on Domain; Adapter/Infrastructure depend on Application and Domain.

### CQRS Paths

| Type | Path |
|---|---|
| Write | Controller → ServiceI → CmdExe → Domain → Gateway → DB |
| Read | Controller → ServiceI → QryExe → Mapper → DB |

### Key Distinctions from Generic DDD

- Domain entities: **bare names** (no suffix, no ORM annotations)
- Infrastructure DOs: **DO suffix** with MyBatis-Plus annotations
- Persistence port: **Gateway** (not Repository)
- Persistence impl: **GatewayImpl** (not RepositoryImpl)
- Request objects: **Cmd** (create) / **Qry** (query), not generic DTO
- Write handler: **CmdExe**, not Application Service directly
- Read handler: **QryExe**, bypasses Domain for performance
- Object mapping: **Converter** (MapStruct), not Assembler
- Service interface: **ServiceI** (COLA naming convention)
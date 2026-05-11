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

> This mapping follows the conventions defined in `ddd-cola` SKILL.md. Each domain's files are grouped together, not split into nested sub-packages. For module structure, dependency direction, and CQRS paths, refer to `ddd-cola` SKILL.md.

```
com.example/                              # Across 6 Maven modules
├── client/                               # demo-client module
│   ├── api/
│   │   ├── UserServiceI.java             # Service interface (returns Result<T>)
│   │   └── UserFeignClient.java          # @FeignClient
│   ├── dto/
│   │   ├── UserAddCmd.java               # extends Command
│   │   ├── UserUpdateCmd.java            # extends Command
│   │   └── UserQry.java                  # extends Query
│   ├── dto/data/
│   │   └── UserDTO.java                  # Data Transfer Object
│   ├── common.result/                    # Result, PageResult (shared)
│   ├── common.exception/                 # BusinessException (shared)
│   └── common.dto/                       # Command, Query marker base classes (self-defined)
├── adapter/                              # demo-adapter module
│   └── web/
│       └── UserController.java           # @RestController
├── app/                                  # demo-app module
│   └── user/
│       ├── UserServiceImpl.java          # Implements UserServiceI
│       └── executor/
│           ├── UserAddCmdExe.java        # Write handler
│           ├── UserUpdateCmdExe.java     # Write handler
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
        ├── UserGatewayImpl.java          # domain-level facade — implements UserGateway
        └── gatewayimpl/
            └── database/
                ├── UserMapper.java       # MyBatis-Plus Mapper
                ├── UserDomainConverter.java  # MapStruct Domain ↔ DO
                └── dataobject/
                    └── UserDO.java       # @TableName, @Data
    # UserDOConverter (DO → DTO) lives in app module: app/user/converter/UserDOConverter.java
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

### 1. Domain Entity — User (bare name, @Data, no ORM annotations)

```java
package com.example.domain.user;

@Data
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

### 2. DO — UserDO (infrastructure, `gatewayimpl/database/dataobject/`, full MyBatis-Plus annotations)

```java
package com.example.user.gatewayimpl.database.dataobject;

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

### 4. Converter — UserDomainConverter (MapStruct, infrastructure — DO ↔ Domain, in `gatewayimpl/database/`)

```java
package com.example.user.gatewayimpl.database;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface UserDomainConverter {
    UserDO toDO(User user);
    User toDomain(UserDO userDO);

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateDOFromDomain(User user, @MappingTarget UserDO userDO);
}
```

### 5. Converter — UserDOConverter (MapStruct, app — DO → DTO, in `converter/` sub-package)

```java
package com.example.user.converter;

@Mapper(componentModel = "spring")
public interface UserDOConverter {
    UserDTO toDTO(UserDO userDO);
}
```

### 6. GatewayImpl (infrastructure, at domain root — implements Gateway, composes `gatewayimpl/database`)

```java
package com.example.user;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.example.user.gatewayimpl.database.UserDomainConverter;
import com.example.user.gatewayimpl.database.UserMapper;
import com.example.user.gatewayimpl.database.dataobject.UserDO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class UserGatewayImpl implements UserGateway {
    private final UserMapper userMapper;
    private final UserDomainConverter userDomainConverter;

    @Override
    public void save(User user) {
        userMapper.insert(userDomainConverter.toDO(user));
    }

    @Override
    public void update(User user) {
        userMapper.updateById(userDomainConverter.toDO(user));
    }

    @Override
    public Optional<User> findById(String userId) {
        return Optional.ofNullable(userMapper.selectOne(
            new LambdaQueryWrapper<UserDO>().eq(UserDO::getUserId, userId)))
            .map(userDomainConverter::toDomain);
    }
}
```

### 7. Cmd (request object — in client module)

```java
package com.example.dto;

// client/dto/UserAddCmd.java
@Data
public class UserAddCmd extends Command {
    @NotBlank
    private String username;

    @NotBlank @Email
    private String email;
}

// client/dto/UserUpdateCmd.java
@Data
public class UserUpdateCmd extends Command {
    @NotBlank
    private String userId;

    @NotBlank @Email
    private String newEmail;
}
```

### 8. CmdExe (write handler — goes through Domain)

```java
package com.example.user.executor;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

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

### 9. QryExe (read handler — bypasses Domain, queries Mapper directly)

```java
package com.example.user.executor.query;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class UserQryExe {
    private final UserMapper userMapper;
    private final UserDOConverter userDOConverter;

    public Result<UserDTO> findById(String userId) {
        return Optional.ofNullable(userMapper.selectOne(
            new LambdaQueryWrapper<UserDO>().eq(UserDO::getUserId, userId)))
            .map(userDOConverter::toDTO)
            .map(Result::success)
            .orElseThrow(() -> new NotFoundException("User", userId));
    }

    public Result<PageResult<UserDTO>> page(long page, long pageSize, UserQry qry) {
        LambdaQueryWrapper<UserDO> wrapper = new LambdaQueryWrapper<UserDO>()
            .like(StringUtils.hasText(qry.getUsername()), UserDO::getUsername, qry.getUsername())
            .eq(StringUtils.hasText(qry.getStatus()), UserDO::getStatus, qry.getStatus())
            .orderByDesc(UserDO::getCreatedAt);
        Page<UserDO> mpPage = userMapper.selectPage(new Page<>(page, pageSize), wrapper);
        return Result.success(PageResult.of(mpPage).map(userDOConverter::toDTO));
    }
}
```

### 10. Controller (adapter layer)

```java
package com.example.web;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/users")
@Tag(name = "用户管理", description = "用户管理接口")
@RequiredArgsConstructor
public class UserController {
    private final UserServiceI userService;

    @Operation(summary = "创建用户")
    @PostMapping
    public Result<Void> create(@Valid @RequestBody UserAddCmd cmd) {
        return userService.addUser(cmd);
    }

    @Operation(summary = "查询用户")
    @GetMapping("/{userId}")
    public Result<UserDTO> get(@PathVariable String userId) {
        return userService.getUser(userId);
    }

    @Operation(summary = "用户列表")
    @GetMapping
    public Result<PageResult<UserDTO>> list(
            @RequestParam(defaultValue = "1") long page,
            @RequestParam(defaultValue = "10") long pageSize,
            @RequestParam(required = false) String status) {
        return userService.listUsers(page, pageSize, status);
    }
}
```

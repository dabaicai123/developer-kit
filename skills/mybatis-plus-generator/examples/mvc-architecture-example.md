# MVC Architecture Code Generation Example

## Scenario

Generate complete MVC architecture code for the `user` table, including Entity, Mapper, Service, ServiceImpl, Controller.

## Configuration

```
Database information:
- Database type: MySQL
- Table name: user

Global configuration:
- Author: System
- Enable Lombok: Yes
- Enable Swagger: Yes

Package configuration:
- Parent package: com.example.app
- Entity package: entity
- Mapper package: mapper
- Service package: service
- ServiceImpl package: service.impl
- Controller package: controller

Architecture type: MVC
Programming language: Java
```

## Table Structure

```sql
CREATE TABLE `user` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT 'User primary key ID',
  `username` varchar(50) NOT NULL COMMENT 'Username',
  `email` varchar(100) NOT NULL COMMENT 'Email address',
  `password` varchar(255) NOT NULL COMMENT 'Password',
  `status` int(11) NOT NULL DEFAULT '1' COMMENT 'User status: 0-disabled, 1-enabled',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Creation time',
  `update_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Update time',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`),
  UNIQUE KEY `uk_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='User table';
```

## Functional Requirements

```
User management features:
1. User registration (create user)
2. Query user by ID
3. Query user by email
4. Query user by username
5. Update user information
6. Delete user
```

## Generated Code

### 1. User.java (Entity)

```java
package com.example.app.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * <p>User entity class</p>
 * 
 * <p>Corresponds to the user table in the database, used to store basic user information.
 * This entity class uses MyBatis-Plus annotations for ORM mapping, supporting automatic table creation and field mapping.</p>
 * 
 * <p>Main fields:
 * <ul>
 *   <li>id: User primary key ID</li>
 *   <li>username: Username</li>
 *   <li>email: Email address</li>
 *   <li>password: Password</li>
 *   <li>status: User status: 0-disabled, 1-enabled</li>
 * </ul>
 * </p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Data
@TableName("user")
public class User {
    
    @TableId(type = IdType.AUTO)
    private Long id;
    
    @TableField("username")
    private String username;
    
    @TableField("email")
    private String email;
    
    @TableField("password")
    private String password;
    
    @TableField("status")
    private Integer status;
    
    @TableField(value = "create_time", fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    
    @TableField(value = "update_time", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
```

### 2. UserMapper.java (Mapper)

```java
package com.example.app.mapper;

import com.example.app.entity.User;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

/**
 * <p>User data access interface</p>
 * 
 * <p>Corresponds to the user table in the database, provides user-related data access operations.
 * This interface uses the MyBatis-Plus framework, extending BaseMapper to provide basic CRUD operations.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Mapper
public interface UserMapper extends BaseMapper<User> {
    
    /**
     * <p>Query user by email</p>
     * 
     * @param email java.lang.String User email address
     * @return com.example.app.entity.User User entity object
     */
    User findByEmail(String email);
    
    /**
     * <p>Query user by username</p>
     * 
     * @param username java.lang.String Username
     * @return com.example.app.entity.User User entity object
     */
    User findByUsername(String username);
}
```

### 3. UserService.java (Service)

```java
package com.example.app.service;

import com.example.app.entity.User;
import com.baomidou.mybatisplus.extension.service.IService;

/**
 * <p>User service interface</p>
 * 
 * <p>Defines user-related business logic interfaces, including user CRUD operations.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
public interface UserService extends IService<User> {
    
    /**
     * <p>Query user by email</p>
     * 
     * @param email java.lang.String User email address
     * @return com.example.app.entity.User User entity object
     */
    User findByEmail(String email);
    
    /**
     * <p>Query user by username</p>
     * 
     * @param username java.lang.String Username
     * @return com.example.app.entity.User User entity object
     */
    User findByUsername(String username);
}
```

### 4. UserServiceImpl.java (ServiceImpl)

```java
package com.example.app.service.impl;

import com.example.app.entity.User;
import com.example.app.mapper.UserMapper;
import com.example.app.service.UserService;
import com.baomidou.mybatisplus.extension.service.impl.ServiceImpl;
import org.springframework.stereotype.Service;

/**
 * <p>User service implementation class</p>
 * 
 * <p>Implements the UserService interface, provides user-related business logic implementation.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Service
public class UserServiceImpl extends ServiceImpl<UserMapper, User> implements UserService {
    
    @Override
    public User findByEmail(String email) {
        // TODO: Implement the business logic for querying user by email
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email address cannot be empty");
        }
        return baseMapper.findByEmail(email);
    }
    
    @Override
    public User findByUsername(String username) {
        // TODO: Implement the business logic for querying user by username
        if (username == null || username.isEmpty()) {
            throw new IllegalArgumentException("Username cannot be empty");
        }
        return baseMapper.findByUsername(username);
    }
}
```

### 5. UserController.java (Controller)

```java
package com.example.app.controller;

import com.example.app.entity.User;
import com.example.app.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * <p>User controller</p>
 * 
 * <p>Provides user-related REST API interfaces.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Tag(name = "User Management", description = "User management API")
@RestController
@RequestMapping("/user")
public class UserController {
    
    @Autowired
    private UserService userService;
    
    @Operation(summary = "Create user", description = "Create a new user record")
    @PostMapping
    public User create(@RequestBody User user) {
        return userService.save(user) ? user : null;
    }
    
    @Operation(summary = "Query user by ID", description = "Query user details by ID")
    @Parameter(name = "id", description = "User ID", required = true)
    @GetMapping("/{id}")
    public User getById(@PathVariable Long id) {
        return userService.getById(id);
    }
    
    @Operation(summary = "Query user by email", description = "Query user information by email")
    @GetMapping("/email/{email}")
    public User getByEmail(@PathVariable String email) {
        return userService.findByEmail(email);
    }
    
    @Operation(summary = "Query user by username", description = "Query user information by username")
    @GetMapping("/username/{username}")
    public User getByUsername(@PathVariable String username) {
        return userService.findByUsername(username);
    }
    
    @Operation(summary = "Update user", description = "Update user information")
    @PutMapping("/{id}")
    public User update(@PathVariable Long id, @RequestBody User user) {
        user.setId(id);
        return userService.updateById(user) ? user : null;
    }
    
    @Operation(summary = "Delete user", description = "Delete user by ID")
    @DeleteMapping("/{id}")
    public boolean delete(@PathVariable Long id) {
        return userService.removeById(id);
    }
}
```

## Generation Statistics

```
Total objects generated: 5
Total methods generated: 12
Total files generated: 5
Total lines of code: approximately 350
```
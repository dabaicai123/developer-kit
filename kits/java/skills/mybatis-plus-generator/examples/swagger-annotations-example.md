# OpenAPI 3 Annotation Examples

## Scenario

Demonstrates complete examples of using OpenAPI 3 annotations in Entity, Controller, and DTO.

## DO Example

```java
package com.example.app.entity;

import com.baomidou.mybatisplus.annotation.*;
import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * <p>User entity class</p>
 * 
 * <p>Corresponds to the user table in the database, used to store basic user information.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Data
@TableName("user")
@Schema(description = "User entity class")
public class User {
    
    /**
     * <p>User primary key ID</p>
     */
    @TableId(type = IdType.ASSIGN_ID)
    @Schema(description = "User primary key ID")
    private Long id;
    
    /**
     * <p>Username</p>
     */
    @TableField("username")
    @Schema(description = "Username", required = true)
    private String username;
    
    /**
     * <p>Email address</p>
     */
    @TableField("email")
    @Schema(description = "Email address", required = true)
    private String email;
}
```

## Controller Example

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
    
    /**
     * <p>Create user</p>
     * 
     * @param user User entity object
     * @return User entity object
     */
    @Operation(summary = "Create user", description = "Create a new user record")
    @PostMapping
    public User create(@RequestBody User user) {
        return userService.save(user);
    }
    
    /**
     * <p>Query user by ID</p>
     * 
     * @param id User unique identifier
     * @return User entity object
     */
    @Operation(summary = "Query user by ID", description = "Query user details by ID")
    @Parameter(name = "id", description = "User ID", required = true)
    @GetMapping("/{id}")
    public User getById(@PathVariable Long id) {
        return userService.getById(id);
    }
}
```

## DTO Example

```java
package com.example.app.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import javax.validation.constraints.*;

/**
 * <p>User creation DTO</p>
 * 
 * <p>Data transfer object for user registration.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Data
@Schema(description = "User creation data transfer object")
public class UserCreateDTO {
    
    @Schema(description = "Username", required = true)
    @NotBlank(message = "Username cannot be empty")
    @Size(max = 50, message = "Username length cannot exceed 50 characters")
    private String username;
    
    @Schema(description = "Email address", required = true)
    @NotBlank(message = "Email address cannot be empty")
    @Email(message = "Invalid email format")
    private String email;
}
```

## Annotation Quick Reference

| Import | Annotation |
|:---|:---|
| `io.swagger.v3.oas.annotations.media.Schema` | `@Schema` — Entity/field description |
| `io.swagger.v3.oas.annotations.tags.Tag` | `@Tag` — Controller grouping |
| `io.swagger.v3.oas.annotations.Operation` | `@Operation` — API operation description |
| `io.swagger.v3.oas.annotations.Parameter` | `@Parameter` — Parameter description |
# DDD Architecture Code Generation Example

## Scenario

Generate complete DDD (Domain-Driven Design) architecture code for the `user` table, including Entity, Mapper, Service, ServiceImpl, Controller, DTO, VO, BO.

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
- Entity package: domain.entity
- Mapper package: infrastructure.mapper
- Service package: domain.service
- ServiceImpl package: application.service.impl
- Controller package: interfaces.controller
- DTO package: interfaces.dto
- VO package: interfaces.vo
- BO package: domain.bo

Architecture type: DDD
Programming language: Java
```

## Functional Requirements

```
User management features:
1. User registration (create user, requires DTO)
2. Query user by ID (returns VO)
3. Query user by email
4. Update user information (requires DTO)
5. Delete user
6. User list query (paginated, returns VO list)
```

## Generated Code Structure

### DDD Layered Structure

```
com.example.app/
├── domain/                    # Domain layer
│   ├── entity/               # Entity
│   │   └── User.java
│   ├── bo/                   # Business object
│   │   └── UserBO.java
│   └── service/              # Domain service interface
│       └── UserService.java
├── application/              # Application layer
│   └── service/
│       └── impl/
│           └── UserServiceImpl.java
├── infrastructure/           # Infrastructure layer
│   └── mapper/
│       └── UserMapper.java
└── interfaces/               # Interface layer
    ├── controller/
    │   └── UserController.java
    ├── dto/
    │   ├── UserCreateDTO.java
    │   └── UserUpdateDTO.java
    └── vo/
        └── UserVO.java
```

## Generated Code Examples

### 1. UserCreateDTO.java

```java
package com.example.app.interfaces.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import javax.validation.constraints.*;

/**
 * <p>User creation DTO</p>
 * 
 * <p>Data transfer object for user registration.
 * This DTO contains the fields required for user registration, used in the user registration scenario.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Schema(description = "User registration data transfer object")
@Data
public class UserCreateDTO implements Serializable {
    
    @Schema(description = "Username", required = true)
    @NotBlank(message = "Username cannot be empty")
    @Size(max = 50, message = "Username length cannot exceed 50 characters")
    private String username;
    
    @Schema(description = "Email address", required = true)
    @NotBlank(message = "Email address cannot be empty")
    @Email(message = "Invalid email format")
    @Size(max = 100, message = "Email length cannot exceed 100 characters")
    private String email;
    
    @Schema(description = "Password", required = true)
    @NotBlank(message = "Password cannot be empty")
    @Size(min = 8, max = 255, message = "Password length must be between 8-255 characters")
    private String password;
}
```

### 2. UserVO.java

```java
package com.example.app.interfaces.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * <p>User view object</p>
 * 
 * <p>Used for user view display, containing user display fields.
 * This VO is used for API responses and does not contain sensitive information (such as password).</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Schema(description = "User view object")
@Data
public class UserVO implements Serializable {
    
    @Schema(description = "User ID")
    private Long id;
    
    @Schema(description = "Username")
    private String username;
    
    @Schema(description = "Email address")
    private String email;
    
    @Schema(description = "User status: 0-disabled, 1-enabled")
    private Integer status;
    
    @Schema(description = "Creation time")
    private LocalDateTime createTime;
    
    @Schema(description = "Update time")
    private LocalDateTime updateTime;
}
```

### 3. UserBO.java

```java
package com.example.app.domain.bo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

/**
 * <p>User business object</p>
 * 
 * <p>Encapsulates the user's business logic object, containing business rules and business methods.
 * This BO is used for business layer processing, containing business logic and business rule validation.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Schema(description = "User business object")
@Data
public class UserBO implements Serializable {
    
    @Schema(description = "User ID")
    private Long id;
    
    @Schema(description = "Username")
    private String username;
    
    @Schema(description = "Email address")
    private String email;
    
    @Schema(description = "User status")
    private Integer status;
    
    /**
     * <p>Verify whether user status is active</p>
     * 
     * @return boolean Whether the user is active
     */
    public boolean isActive() {
        return status != null && status == 1;
    }
}
```

### 4. UserController.java (DDD Version)

```java
package com.example.app.interfaces.controller;

import com.example.app.interfaces.dto.UserCreateDTO;
import com.example.app.interfaces.dto.UserUpdateDTO;
import com.example.app.interfaces.vo.UserVO;
import com.example.app.application.service.impl.UserServiceImpl;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * <p>User controller</p>
 * 
 * <p>Provides user-related REST API interfaces, following DDD architecture design.
 * This controller is located in the interface layer, responsible for receiving requests and returning responses.</p>
 * 
 * @author System
 * @since 2024-12-19
 */
@Tag(name = "User Management", description = "User management API")
@RestController
@RequestMapping("/user")
public class UserController {
    
    @Autowired
    private UserServiceImpl userService;
    
    @Operation(summary = "Create user", description = "User registration")
    @PostMapping
    public UserVO create(@RequestBody UserCreateDTO dto) {
        // TODO: Call application layer service, convert DTO to entity, return VO
        return null;
    }
    
    @Operation(summary = "Query user by ID", description = "Query user details")
    @GetMapping("/{id}")
    public UserVO getById(@PathVariable Long id) {
        // TODO: Call application layer service, return VO
        return null;
    }
    
    @Operation(summary = "Update user", description = "Update user information")
    @PutMapping("/{id}")
    public UserVO update(@PathVariable Long id, @RequestBody UserUpdateDTO dto) {
        // TODO: Call application layer service, update user information, return VO
        return null;
    }
    
    @Operation(summary = "Delete user", description = "Delete user by ID")
    @DeleteMapping("/{id}")
    public boolean delete(@PathVariable Long id) {
        // TODO: Call application layer service, delete user
        return false;
    }
}
```

## DDD Architecture Characteristics

### 1. Clear Layering

- **Domain Layer**: Contains entities, business objects, domain service interfaces
- **Application Layer**: Contains service implementations, coordinating domain layer and infrastructure layer
- **Infrastructure Layer**: Contains data access (Mapper)
- **Interface Layer**: Contains controllers, DTOs, VOs

### 2. Clear Object Responsibilities

- **Entity**: Domain entity, containing business attributes and business methods
- **BO**: Business object, encapsulating business logic
- **DTO**: Data transfer object, used for interface input
- **VO**: View object, used for interface output

### 3. Dependency Direction

- Interface layer -> Application layer -> Domain layer
- Infrastructure layer -> Domain layer
- Follows the dependency inversion principle

## Generation Statistics

```
Total objects generated: 8
Total methods generated: 15
Total files generated: 8
Total lines of code: approximately 600
```
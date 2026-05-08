# Full Workflow Example

## Scenario

Generate complete MyBatis-Plus code for a user management system, including the `user` and `order` tables, using MVC architecture, Java language.

## Workflow

### Step 1: Collect Configuration

**User input:**

```
Database information:
- Database type: MySQL
- Database name: teaching_ai
- Table names: user, order

Global configuration:
- Author: System
- Output directory: src/main/java
- File overwrite strategy: Ask
- Enable Lombok: Yes
- Enable Swagger: Yes
- Enable validation annotations: Yes

Package configuration:
- Parent package: com.example.app
- Entity package: entity
- Mapper package: mapper
- Service package: service
- ServiceImpl package: service.impl
- Controller package: controller

Strategy configuration:
- Naming strategy: CamelCase
- Table prefix: None
- Primary key strategy: AUTO
```

**Output:**

```
## Configuration Confirmation

✅ Database information:
- Database type: MySQL
- Database name: teaching_ai
- Table names: user, order

✅ Global configuration:
- Author: System
- Output directory: src/main/java
- File overwrite strategy: Ask
- Enable Lombok: Yes
- Enable Swagger: Yes
- Enable validation annotations: Yes

✅ Package configuration:
- Parent package: com.example.app
- Entity package: com.example.app.entity
- Mapper package: com.example.app.mapper
- Service package: com.example.app.service
- ServiceImpl package: com.example.app.service.impl
- Controller package: com.example.app.controller

✅ Strategy configuration:
- Naming strategy: CamelCase
- Table prefix: None
- Primary key strategy: AUTO
```

### Step 2: Determine Architecture Type

**Ask the user:**

```
Please select the project architecture type:
- [x] Traditional MVC (Model-View-Controller)
  - Generates: Entity, Mapper, Service, ServiceImpl, Controller
```

**User confirms: MVC architecture**

### Step 3: Collect Functional Requirements

**Ask the user:**

```
Please describe the functional requirements for this code generation:

Examples:
- User management: need to query users by email, query users by username, user login verification
- Order management: need order statistics, paginated order query, order status update
```

**User input:**

```
User management functional requirements:
1. User registration (create user)
2. User login (query by username and password)
3. Query user by email
4. Query user by username
5. Update user information
6. Delete user
7. User list query (paginated)

Order management functional requirements:
1. Create order
2. Query order by order ID
3. Query order list by user ID
4. Order statistics (count orders and total amount per user)
5. Update order status
6. Delete order
7. Paginated order query
```

**Requirements analysis output:**

```
## Requirements Analysis Results

### user table

Standard methods:
- saveUser() - Save user
- findById() - Query by ID
- updateUser() - Update user
- deleteById() - Delete by ID
- findAll() - Query all (paginated)

Custom methods:
- findByEmail(String email) - Query user by email
- findByUsername(String username) - Query user by username
- login(String username, String password) - User login verification

### order table

Standard methods:
- saveOrder() - Save order
- findById() - Query by ID
- updateOrder() - Update order
- deleteById() - Delete by ID
- findAll() - Query all (paginated)

Custom methods:
- findByUserId(Long userId) - Query order list by user ID
- getOrderStatistics(Long userId) - Order statistics (order count, total amount)
- updateOrderStatus(Long orderId, Integer status) - Update order status
```

### Step 4: Determine Programming Language

**Ask the user:**

```
Please select the programming language:
- [x] Java
- [ ] Kotlin
```

**User confirms: Java**

### Step 5: Create Todo List

**Generated Todo list:**

```markdown
## Todo List: MyBatis-Plus Code Generation

### Table: user

#### Entity layer
- [ ] User.java - Entity class
  - [ ] Class comment
  - [ ] Field definitions (id, username, email, password, status, createTime, updateTime)
  - [ ] Field comments

#### Mapper layer
- [ ] UserMapper.java - Data access interface
  - [ ] Class comment
  - [ ] Basic CRUD methods (extending BaseMapper)
  - [ ] Custom query methods (findByEmail, findByUsername)

#### Service layer
- [ ] UserService.java - Service interface
  - [ ] Class comment
  - [ ] saveUser() - Save user
  - [ ] findById() - Query by ID
  - [ ] updateUser() - Update user
  - [ ] deleteById() - Delete by ID
  - [ ] findByEmail() - Query by email
  - [ ] findByUsername() - Query by username
  - [ ] login() - User login verification

#### ServiceImpl layer
- [ ] UserServiceImpl.java - Service implementation class
  - [ ] Class comment
  - [ ] Implement all Service interface methods
  - [ ] Method comments and implementation skeleton

#### Controller layer
- [ ] UserController.java - Controller
  - [ ] Class comment
  - [ ] createUser() - Create user
  - [ ] getUserById() - Query user
  - [ ] updateUser() - Update user
  - [ ] deleteUser() - Delete user
  - [ ] getUserByEmail() - Query by email
  - [ ] getUserByUsername() - Query by username
  - [ ] login() - User login

### Table: order
- [ ] Order.java - Entity class
- [ ] OrderMapper.java - Data access interface
- [ ] OrderService.java - Service interface
- [ ] OrderServiceImpl.java - Service implementation class
- [ ] OrderController.java - Controller
```

### Step 6: Generate Code

**Generation progress update:**

```markdown
## Code Generation Progress

### Table: user

✅ Completed:
- [x] User.java - Entity class (7 fields, complete comments)
- [x] UserMapper.java - Data access interface (extending BaseMapper, 2 custom methods)

🔄 In progress:
- [ ] UserService.java - Service interface
  - [x] Class comment
  - [x] saveUser() method
  - [x] findById() method
  - [x] updateUser() method
  - [x] deleteById() method
  - [ ] findByEmail() method
  - [ ] findByUsername() method
  - [ ] login() method

⏳ Pending:
- [ ] UserServiceImpl.java - Service implementation class
- [ ] UserController.java - Controller

### Table: order
...
```

**Generated code example:**

#### User.java (Entity)

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
 *   <li>id: User primary key, auto-increment</li>
 *   <li>username: Username, unique, used for login</li>
 *   <li>email: Email address, unique, used for login and password recovery</li>
 *   <li>password: Encrypted password</li>
 *   <li>status: User status (0-disabled, 1-enabled)</li>
 * </ul>
 * </p>
 * 
 * @author System
 * @since 1.0.0
 */
@Data
@TableName("user")
public class User {
    
    /**
     * <p>User primary key ID</p>
     * 
     * <p>Auto-increment database primary key, uniquely identifies a user</p>
     */
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
    
    /**
     * <p>Username</p>
     * 
     * <p>Username used for user login, must be unique, length limit 50 characters</p>
     */
    @TableField("username")
    private String username;
    
    /**
     * <p>Email address</p>
     * 
     * <p>User email address, used for login and password recovery, must be unique, length limit 100 characters</p>
     */
    @TableField("email")
    private String email;
    
    /**
     * <p>Password</p>
     * 
     * <p>User password, encrypted when stored (BCrypt), length limit 255 characters</p>
     */
    @TableField("password")
    private String password;
    
    /**
     * <p>User status</p>
     * 
     * <p>User status indicator:
     * <ul>
     *   <li>0: Disabled</li>
     *   <li>1: Enabled</li>
     * </ul>
     * </p>
     */
    @TableField("status")
    private Integer status;
    
    /**
     * <p>Creation time</p>
     * 
     * <p>User record creation time, automatically set by the database</p>
     */
    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createTime;
    
    /**
     * <p>Update time</p>
     * 
     * <p>Last update time of the user record, automatically maintained by the database</p>
     */
    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
```

#### UserService.java (Service Interface)

```java
package com.example.app.service;

import com.example.app.entity.User;
import com.baomidou.mybatisplus.extension.service.IService;

/**
 * <p>User service interface</p>
 * 
 * <p>Defines user-related business logic interfaces, including user CRUD operations.
 * This interface follows Domain-Driven Design (DDD) principles, encapsulating core business logic of the user domain.</p>
 * 
 * <p>Main responsibilities:
 * <ul>
 *   <li>User creation and registration</li>
 *   <li>User information query (including query by email, username)</li>
 *   <li>User login verification</li>
 *   <li>User information update</li>
 *   <li>User deletion</li>
 * </ul>
 * </p>
 * 
 * @author System
 * @since 1.0.0
 */
public interface UserService extends IService<User> {
    
    /**
     * <p>Query user by email</p>
     * 
     * <p>Query user information by email address, used for user login and email verification scenarios.
     * Returns null if the user does not exist.</p>
     * 
     * @param email java.lang.String User email address, cannot be empty
     * @return com.example.app.entity.User User entity object, returns null if not found
     * @exception java.lang.IllegalArgumentException Thrown when email address is empty
     */
    User findByEmail(String email);
    
    /**
     * <p>Query user by username</p>
     * 
     * <p>Query user information by username, used for user login scenarios.
     * Returns null if the user does not exist.</p>
     * 
     * @param username java.lang.String Username, cannot be empty
     * @return com.example.app.entity.User User entity object, returns null if not found
     * @exception java.lang.IllegalArgumentException Thrown when username is empty
     */
    User findByUsername(String username);
    
    /**
     * <p>User login verification</p>
     * 
     * <p>Verify user identity by username and password, used for user login scenarios.
     * The verification process includes: querying user, verifying password, checking user status.</p>
     * 
     * @param username java.lang.String Username, cannot be empty
     * @param password java.lang.String Password (plain text), cannot be empty
     * @return com.example.app.entity.User User entity object, returns null if verification fails
     * @exception java.lang.IllegalArgumentException Thrown when username or password is empty
     */
    User login(String username, String password);
}
```

### Step 7: Progress Update

**Real-time progress output:**

```
✅ Completed Entity generation for user table
✅ Completed Mapper generation for user table
🔄 Generating Service interface for user table...
✅ Completed Service interface generation for user table
🔄 Generating ServiceImpl implementation class for user table...
✅ Completed ServiceImpl implementation class generation for user table
🔄 Generating Controller for user table...
✅ Completed Controller generation for user table

✅ Completed Entity generation for order table
...
```

### Step 8: Statistics

**Final statistics output:**

```markdown
## Code Generation Statistics

### Overall Statistics
- **Tables generated**: 2 tables (user, order)
- **Total objects generated**: 10 objects
- **Total methods generated**: 35 methods
- **Total files generated**: 10 files
- **Total lines of code**: approximately 1,800 lines

### Per-table Statistics

#### user table
- Entity: 1 (7 fields)
- Mapper: 1 (extends BaseMapper, 2 custom methods)
- Service: 1 (7 methods: 4 standard methods + 3 custom methods)
- ServiceImpl: 1 (7 method implementations)
- Controller: 1 (7 endpoints)
- **Subtotal**: 5 objects, 16 methods

#### order table
- Entity: 1 (10 fields)
- Mapper: 1 (extends BaseMapper, 2 custom methods)
- Service: 1 (8 methods: 4 standard methods + 4 custom methods)
- ServiceImpl: 1 (8 method implementations)
- Controller: 1 (8 endpoints)
- **Subtotal**: 5 objects, 19 methods

### File Locations
All files have been generated in the following directories:
- Entity: `src/main/java/com/example/app/entity/`
- Mapper: `src/main/java/com/example/app/mapper/`
- Service: `src/main/java/com/example/app/service/`
- ServiceImpl: `src/main/java/com/example/app/service/impl/`
- Controller: `src/main/java/com/example/app/controller/`

### Code Quality
- ✅ All classes have complete JavaDoc comments
- ✅ All methods have parameter and return value descriptions
- ✅ All fields have business meaning comments
- ✅ Custom methods have business logic descriptions
- ✅ Compliant with Java programming standards
- ✅ Includes Lombok annotations
- ✅ Includes Swagger annotations
```
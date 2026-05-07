# Progress Updates and Statistics Formats

This document provides format standards for progress updates and final statistics during code generation.

## Progress Update Format

### Basic Format

```markdown
## Code Generation Progress

### Table: {tableName}

Completed:
- [x] {ClassName}.java - {description} ({details})

In Progress:
- [ ] {ClassName}.java - {description}
  - [x] {completed item}
  - [ ] {pending item}

Pending:
- [ ] {ClassName}.java - {description}
```

### Detailed Example

```markdown
## Code Generation Progress

### Table: user

Completed:
- [x] User.java - Entity class (8 fields, complete comments)
- [x] UserMapper.java - Data access interface (extends BaseMapper)
- [x] UserService.java - Service interface (6 methods)

In Progress:
- [ ] UserServiceImpl.java - Service implementation class
  - [x] Class comment
  - [x] saveUser() method
  - [ ] findById() method
  - [ ] updateUser() method
  - [ ] deleteById() method
  - [ ] findByEmail() method
  - [ ] findByUsername() method

Pending:
- [ ] UserController.java - Controller
- [ ] UserCreateDTO.java - Create user DTO
- [ ] UserUpdateDTO.java - Update user DTO
- [ ] UserVO.java - User view object

### Table: order

Completed:
- [x] Order.java - Entity class (12 fields)
- [x] OrderMapper.java - Data access interface

In Progress:
- [ ] OrderService.java - Service interface

Pending:
- [ ] OrderServiceImpl.java - Service implementation class
- [ ] OrderController.java - Controller
- [ ] OrderCreateDTO.java - Create order DTO
- [ ] OrderVO.java - Order view object
```

### When to Update Progress

Update progress at the following times:
- When starting to process each table
- When each object generation is completed
- When each method is added
- When each table processing is completed

## Statistics Format

### Basic Format

```markdown
## Code Generation Statistics

### Overall Statistics
- **Tables generated**: {count} tables ({table names})
- **Total objects generated**: {count} objects
- **Total methods generated**: {count} methods
- **Total files generated**: {count} files
- **Total lines of code**: approximately {count} lines

### Statistics by Table

#### {tableName} table
- Entity: {count} ({fieldCount} fields)
- Mapper: {count} (extends BaseMapper, {methodCount} base methods)
- Service: {count} ({methodCount} methods: {standardCount} standard methods + {customCount} custom methods)
- ServiceImpl: {count} ({methodCount} method implementations)
- Controller: {count} ({endpointCount} endpoints)
- DTO: {count} ({dtoNames})
- VO: {count} ({voNames})
- **Subtotal**: {totalObjects} objects, {totalMethods} methods

### Statistics by Type
- Entity: {count}
- Mapper: {count}
- Service: {count}
- ServiceImpl: {count}
- Controller: {count}
- DTO: {count}
- VO: {count}

### File Locations
All files have been generated to the following directories:
- Entity: `{path}`
- Mapper: `{path}`
- Service: `{path}`
- ServiceImpl: `{path}`
- Controller: `{path}`
- DTO: `{path}`
- VO: `{path}`

### Code Quality
- All classes have complete JavaDoc comments
- All methods have parameter and return value descriptions
- All fields have business meaning comments
- Custom methods have business logic descriptions
- Complies with Java programming conventions
```

### Detailed Example

```markdown
## Code Generation Statistics

### Overall Statistics
- **Tables generated**: 2 tables (user, order)
- **Total objects generated**: 14 objects
- **Total methods generated**: 48 methods
- **Total files generated**: 14 files
- **Total lines of code**: approximately 2,500 lines

### Statistics by Table

#### user table
- Entity: 1 (8 fields)
- Mapper: 1 (extends BaseMapper, 5 base methods)
- Service: 1 (6 methods: 4 standard methods + 2 custom methods)
- ServiceImpl: 1 (6 method implementations)
- Controller: 1 (5 endpoints)
- DTO: 2 (UserCreateDTO, UserUpdateDTO)
- VO: 1 (UserVO)
- **Subtotal**: 8 objects, 17 methods

#### order table
- Entity: 1 (12 fields)
- Mapper: 1 (extends BaseMapper, 5 base methods)
- Service: 1 (8 methods: 4 standard methods + 4 custom methods)
- ServiceImpl: 1 (8 method implementations)
- Controller: 1 (7 endpoints)
- DTO: 3 (OrderCreateDTO, OrderUpdateDTO, OrderQueryDTO)
- VO: 1 (OrderVO)
- **Subtotal**: 8 objects, 31 methods

### Statistics by Type
- Entity: 2
- Mapper: 2
- Service: 2
- ServiceImpl: 2
- Controller: 2
- DTO: 5
- VO: 2

### File Locations
All files have been generated to the following directories:
- Entity: `src/main/java/com/example/app/entity/`
- Mapper: `src/main/java/com/example/app/mapper/`
- Service: `src/main/java/com/example/app/service/`
- ServiceImpl: `src/main/java/com/example/app/service/impl/`
- Controller: `src/main/java/com/example/app/controller/`
- DTO: `src/main/java/com/example/app/dto/`
- VO: `src/main/java/com/example/app/vo/`

### Code Quality
- All classes have complete JavaDoc comments
- All methods have parameter and return value descriptions
- All fields have business meaning comments
- Custom methods have business logic descriptions
- Complies with Java programming conventions
```

## Usage Instructions

### Progress Updates

During code generation, update progress in real time:
1. When each object is completed, update the corresponding checkbox
2. When each method is completed, update method-level progress
3. When each table is completed, mark the table as completed

### Statistics

After code generation is complete, output full statistics:
1. Summarize the generation status of all tables
2. Classify statistics by object type
3. List the paths of all generated files
4. Describe code quality status

## References

- Full workflow example: `../examples/full-workflow-example.md`
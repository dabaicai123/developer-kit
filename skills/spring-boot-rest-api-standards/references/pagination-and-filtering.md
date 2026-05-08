# Pagination and Filtering Reference

## Pagination with MyBatis-Plus

### Basic Pagination
```java
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;

    @GetMapping
    public Result<PageResult<UserResponse>> getAllUsers(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "10") int size) {
        PageResult<UserResponse> users = userService.findAll(page, size);
        return Result.success(users);
    }
}
```

### Pagination with Sorting
```java
@GetMapping
public Result<PageResult<UserResponse>> getAllUsers(
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size,
        @RequestParam(defaultValue = "created_at") String sortBy,
        @RequestParam(defaultValue = "DESC") String sortDirection) {

    PageResult<UserResponse> users = userService.findAll(page, size, sortBy, sortDirection);
    return Result.success(users);
}
```

### Multi-field Sorting
```java
@GetMapping
public Result<PageResult<UserResponse>> getAllUsers(
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size,
        @RequestParam(defaultValue = "name,created_at") String sortFields) {

    // sortFields format: "name,created_at" (ASC by default) or "name,-created_at" (prefix - for DESC)
    PageResult<UserResponse> users = userService.findAll(page, size, sortFields);
    return Result.success(users);
}
```

## Service Layer with MyBatis-Plus

### Basic Pagination Service
```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserMapper userMapper; // MyBatis-Plus mapper

    public PageResult<UserResponse> findAll(int page, int size) {
        Page<User> mpPage = new Page<>(page, size);
        Page<User> result = userMapper.selectPage(mpPage, null);
        return PageResult.of(result).map(this::toResponse);
    }

    public PageResult<UserResponse> findAll(int page, int size, String sortBy, String sortDirection) {
        Page<User> mpPage = new Page<>(page, size);
        // Build order item for MyBatis-Plus
        if ("ASC".equalsIgnoreCase(sortDirection)) {
            mpPage.addOrder(OrderItem.asc(sortBy));
        } else {
            mpPage.addOrder(OrderItem.desc(sortBy));
        }
        Page<User> result = userMapper.selectPage(mpPage, null);
        return PageResult.of(result).map(this::toResponse);
    }
}
```

### Multi-field Sorting Service
```java
public PageResult<UserResponse> findAll(int page, int size, String sortFields) {
    Page<User> mpPage = new Page<>(page, size);

    // Parse sort fields: "name,-created_at" -> ASC name, DESC created_at
    Arrays.stream(sortFields.split(","))
        .map(field -> {
            if (field.startsWith("-")) {
                return OrderItem.desc(field.substring(1));
            }
            return OrderItem.asc(field);
        })
        .forEach(mpPage::addOrder);

    Page<User> result = userMapper.selectPage(mpPage, null);
    return PageResult.of(result).map(this::toResponse);
}
```

## Response Format

### Standard PageResult Response (wrapped in Result)
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "records": [
      {
        "id": 1,
        "name": "John Doe",
        "email": "john@example.com",
        "createdAt": "2024-01-15T10:30:00Z"
      }
    ],
    "total": 45,
    "size": 10,
    "current": 1,
    "pages": 5
  }
}
```

### PageResult Wrapper
```java
// PageResult is our standard pagination wrapper, converting MyBatis-Plus Page to a clean response format
// Usage: PageResult.of(mpPage).map(entity -> toResponse(entity))
@Data
public class PageResult<T> {
    private List<T> records;
    private long total;
    private long size;
    private long current;
    private long pages;

    public static <E> PageResult<E> of(Page<E> mpPage) {
        PageResult<E> result = new PageResult<>();
        result.setRecords(mpPage.getRecords());
        result.setTotal(mpPage.getTotal());
        result.setSize(mpPage.getSize());
        result.setCurrent(mpPage.getCurrent());
        result.setPages(mpPage.getPages());
        return result;
    }

    /**
     * Map data object records to DTOs while preserving pagination metadata
     */
    public <R> PageResult<R> map(Function<E, R> mapper) {
        PageResult<R> result = new PageResult<>();
        result.setRecords(this.records.stream().map(mapper).collect(Collectors.toList()));
        result.setTotal(this.total);
        result.setSize(this.size);
        result.setCurrent(this.current);
        result.setPages(this.pages);
        return result;
    }
}
```

## Filtering

### Query Parameter Filtering with LambdaQueryWrapper
```java
@GetMapping
public Result<PageResult<UserResponse>> getUsers(
        @RequestParam(required = false) String name,
        @RequestParam(required = false) String email,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size) {

    PageResult<UserResponse> result = userService.findFiltered(name, email, page, size);
    return Result.success(result);
}

// Service implementation
public PageResult<UserResponse> findFiltered(String name, String email, int page, int size) {
    LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();

    if (name != null && !name.isEmpty()) {
        wrapper.like(User::getName, name);
    }

    if (email != null && !email.isEmpty()) {
        wrapper.like(User::getEmail, email);
    }

    Page<User> mpPage = new Page<>(page, size);
    mpPage.addOrder(OrderItem.desc("created_at"));
    Page<User> result = userMapper.selectPage(mpPage, wrapper);
    return PageResult.of(result).map(this::toResponse);
}
```

### Dynamic LambdaQueryWrapper Builder
```java
public class UserQueryBuilders {

    public static LambdaQueryWrapper<User> buildFilterWrapper(
            String name, String email, Boolean active, LocalDate createdAfter) {

        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();

        if (name != null && !name.isEmpty()) {
            wrapper.like(User::getName, name);
        }

        if (email != null && !email.isEmpty()) {
            wrapper.like(User::getEmail, email);
        }

        if (active != null) {
            wrapper.eq(User::getActive, active);
        }

        if (createdAfter != null) {
            wrapper.ge(User::getCreatedAt, createdAfter.atStartOfDay());
        }

        return wrapper;
    }
}

// Usage in controller
@GetMapping("/users")
public Result<PageResult<UserResponse>> getUsers(
        @RequestParam(required = false) String name,
        @RequestParam(required = false) String email,
        @RequestParam(required = false) Boolean active,
        @RequestParam(required = false) LocalDate createdAfter,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size) {

    LambdaQueryWrapper<User> wrapper = UserQueryBuilders.buildFilterWrapper(name, email, active, createdAfter);
    Page<User> mpPage = new Page<>(page, size);
    mpPage.addOrder(OrderItem.desc("created_at"));
    Page<User> result = userMapper.selectPage(mpPage, wrapper);
    return Result.success(PageResult.of(result).map(this::toResponse));
}
```

### Date Range Filtering
```java
@GetMapping("/orders")
public Result<PageResult<OrderResponse>> getOrders(
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size) {

    LambdaQueryWrapper<Order> wrapper = new LambdaQueryWrapper<>();

    if (startDate != null) {
        wrapper.ge(Order::getCreatedAt, startDate.atStartOfDay());
    }

    if (endDate != null) {
        wrapper.le(Order::getCreatedAt, endDate.atEndOfDay());
    }

    Page<Order> mpPage = new Page<>(page, size);
    mpPage.addOrder(OrderItem.desc("created_at"));
    Page<Order> result = orderMapper.selectPage(mpPage, wrapper);
    return Result.success(PageResult.of(result).map(this::toResponse));
}
```

## Advanced Filtering

### Filter DTO Pattern
```java
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserFilter {
    private String name;
    private String email;
    private Boolean active;
    private LocalDate createdAfter;
    private LocalDate createdBefore;
    private List<Long> roleIds;

    public LambdaQueryWrapper<User> toQueryWrapper() {
        LambdaQueryWrapper<User> wrapper = new LambdaQueryWrapper<>();

        if (name != null && !name.isEmpty()) {
            wrapper.like(User::getName, name);
        }

        if (email != null && !email.isEmpty()) {
            wrapper.like(User::getEmail, email);
        }

        if (active != null) {
            wrapper.eq(User::getActive, active);
        }

        if (createdAfter != null) {
            wrapper.ge(User::getCreatedAt, createdAfter.atStartOfDay());
        }

        if (createdBefore != null) {
            wrapper.le(User::getCreatedAt, createdBefore.atEndOfDay());
        }

        if (roleIds != null && !roleIds.isEmpty()) {
            wrapper.in(User::getRoleId, roleIds);
        }

        return wrapper;
    }
}

// Controller
@GetMapping("/users")
public Result<PageResult<UserResponse>> getUsers(
        UserFilter filter,
        @RequestParam(defaultValue = "1") int page,
        @RequestParam(defaultValue = "10") int size) {

    LambdaQueryWrapper<User> wrapper = filter.toQueryWrapper();
    Page<User> mpPage = new Page<>(page, size);
    mpPage.addOrder(OrderItem.desc("created_at"));
    Page<User> result = userMapper.selectPage(mpPage, wrapper);
    return Result.success(PageResult.of(result).map(this::toResponse));
}
```

## Performance Considerations

### Database Optimization
```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserMapper userMapper;

    public PageResult<UserResponse> findAll(int page, int size, String sortBy, String sortDirection) {
        Page<User> mpPage = new Page<>(page, size);
        mpPage.addOrder("ASC".equalsIgnoreCase(sortDirection)
            ? OrderItem.asc(sortBy) : OrderItem.desc(sortBy));

        Page<User> result = userMapper.selectPage(mpPage, null);
        return PageResult.of(result).map(this::toResponse);
    }
}
```

### Cache Pagination Results
```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserMapper userMapper;
    private final CacheManager cacheManager;

    public PageResult<UserResponse> findAll(LambdaQueryWrapper<User> wrapper, int page, int size) {
        String cacheKey = "users:" + wrapper.hashCode() + ":" + page + ":" + size;

        return cacheManager.getCache("users").get(cacheKey, () -> {
            Page<User> mpPage = new Page<>(page, size);
            mpPage.addOrder(OrderItem.desc("created_at"));
            Page<User> result = userMapper.selectPage(mpPage, wrapper);
            return PageResult.of(result).map(this::toResponse);
        });
    }
}
```
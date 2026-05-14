# Controller Layer and Exception Handler Unit Testing Reference

Unit testing for `@RestController` (adapter module `web/` package) and `@ControllerAdvice` using MockMvc without full Spring context.

## COLA Naming Conventions

- **Package**: `adapter.web` (NOT `controller`), e.g., `com.example.adapter.web.UserController`
- **URL prefix**: `/v1/` for all REST APIs, e.g., `/v1/users`
- **Return**: `Result<T>` unified wrapper (NOT `ResponseEntity`)
- **Dependency**: Service interfaces named `UserServiceI` (ending with `I`)

## Dependency Configuration

`spring-boot-starter-test` (Spring Boot 3.5.x) provides MockMvc, JUnit 5, Mockito 5, and AssertJ.

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-test</artifactId>
  <scope>test</scope>
</dependency>
```

For Spring Security testing, add:

```xml
<dependency>
  <groupId>org.springframework.security</groupId>
  <artifactId>spring-security-test</artifactId>
  <scope>test</scope>
</dependency>
```

## Basic Testing Patterns

### Setup: Standalone MockMvc

```java
@ExtendWith(MockitoExtension.class)
class UserControllerTest {
  @Mock private UserServiceI userServiceI;
  @InjectMocks private UserController userController;
  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    mockMvc = MockMvcBuilders.standaloneSetup(userController).build();
  }
}
```

### GET: List and Single Resource

```java
@Test
void shouldReturnAllUsers() throws Exception {
  when(userServiceI.getAllUsers()).thenReturn(Result.success(List.of(new UserDTO(1L, "Alice"))));
  mockMvc.perform(get("/v1/users"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.data[0].name").value("Alice"));
  verify(userServiceI).getAllUsers();
}

@Test
void shouldReturn404WhenUserNotFound() throws Exception {
  when(userServiceI.getUserById(999L)).thenThrow(new UserNotFoundException("User not found"));
  mockMvc.perform(get("/v1/users/999")).andExpect(status().isNotFound());
}
```

### POST: Create Resource

```java
@Test
void shouldCreateUserAndReturn200() throws Exception {
  when(userServiceI.createUser(any())).thenReturn(Result.success(new UserDTO(1L, "Alice")));
  mockMvc.perform(post("/v1/users")
      .contentType("application/json")
      .content("{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.data.id").value(1));
  verify(userServiceI).createUser(any(CreateUserCmd.class));
}
```

### PUT / DELETE

```java
@Test
void shouldUpdateUser() throws Exception {
  when(userServiceI.updateUser(eq(1L), any())).thenReturn(Result.success(new UserDTO(1L, "Updated")));
  mockMvc.perform(put("/v1/users/1").contentType("application/json").content("{\"name\":\"Updated\"}"))
    .andExpect(status().isOk());
}

@Test
void shouldDeleteUser() throws Exception {
  doNothing().when(userServiceI).deleteUser(1L);
  mockMvc.perform(delete("/v1/users/1")).andExpect(status().isOk());
  verify(userServiceI).deleteUser(1L);
}
```

### Query Parameters and Path Variables

```java
// Query parameters
mockMvc.perform(get("/v1/users/search").param("name", "Alice"))
  .andExpect(status().isOk());

// Path variables
mockMvc.perform(get("/v1/users/{id}", 123L))
  .andExpect(status().isOk())
  .andExpect(jsonPath("$.data.id").value(123));
```

### Validation Errors (400), Headers, Content Negotiation

```java
// Validation errors
mockMvc.perform(post("/v1/users").contentType("application/json").content("{\"name\":\"\"}"))
  .andExpect(status().isBadRequest())
  .andExpect(jsonPath("$.errors").isArray());

// Response headers
mockMvc.perform(get("/v1/users"))
  .andExpect(header().exists("X-Total-Count"));

// Content negotiation
mockMvc.perform(get("/v1/users/1").accept("application/json"))
  .andExpect(content().contentType("application/json"));
```

## Spring Security 6.x Testing

Spring Security 6.x (Spring Boot 3.5) requires `@WithMockUser` or `@WithAnonymousUser` for authenticated endpoint testing.

```java
// Authenticated user with specific role
@Test
@WithMockUser(roles = "ADMIN")
void shouldAllowAdminToDeleteUser() throws Exception {
  mockMvc.perform(delete("/v1/admin/users/1")).andExpect(status().isOk());
}

// Anonymous user — expects 401/403
@Test
@WithAnonymousUser
void shouldDenyAnonymousAccess() throws Exception {
  mockMvc.perform(delete("/v1/admin/users/1")).andExpect(status().isUnauthorized());
}

// Custom username and authorities
@Test
@WithMockUser(username = "alice", authorities = "ROLE_USER")
void shouldAllowUserAccess() throws Exception {
  mockMvc.perform(get("/v1/users")).andExpect(status().isOk());
}
```

NOT test security by calling endpoints without `@WithMockUser` in `@WebMvcTest` — default security config blocks all requests.

## Advanced Patterns

### Paginated Response

```java
@Test
void shouldReturnPaginatedUsers() throws Exception {
  Page<UserDTO> page = new PageImpl<>(List.of(new UserDTO(1L, "Alice")), PageRequest.of(0, 10), 2);
  when(userServiceI.getUsers(any(Pageable.class))).thenReturn(page);
  mockMvc.perform(get("/v1/users").param("page", "0").param("size", "10"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.totalElements").value(2));
}
```

### File Upload

```java
@Test
void shouldUploadFile() throws Exception {
  MockMultipartFile file = new MockMultipartFile("file", "test.txt", "text/plain", "content".getBytes());
  when(fileServiceI.store(any())).thenReturn("file-id");
  mockMvc.perform(multipart("/v1/files/upload").file(file))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.data.fileId").value("file-id"));
}
```

## Exception Handler Testing

Test `@ControllerAdvice` and `@ExceptionHandler` — verify error response format and HTTP status codes.

### Handler Implementation

```java
@ControllerAdvice
public class GlobalExceptionHandler {
  @ExceptionHandler(ResourceNotFoundException.class)
  @ResponseStatus(HttpStatus.NOT_FOUND)
  public Result<Void> handleNotFound(ResourceNotFoundException ex) {
    return Result.fail(404, ex.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  @ResponseStatus(HttpStatus.BAD_REQUEST)
  public Result<Void> handleMethodArgumentNotValid(MethodArgumentNotValidException ex) {
    Map<String, String> errors = new HashMap<>();
    ex.getBindingResult().getFieldErrors().forEach(e -> errors.put(e.getField(), e.getDefaultMessage()));
    return Result.fail(400, "Parameter validation failed", errors);
  }
}
```

### Unit Testing

Register handler via `setControllerAdvice()`, create test Controller throwing specific exceptions:

```java
@ExtendWith(MockitoExtension.class)
class GlobalExceptionHandlerTest {
  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    mockMvc = MockMvcBuilders.standaloneSetup(new TestController())
        .setControllerAdvice(new GlobalExceptionHandler())
        .build();
  }

  @Test
  void shouldReturn404WhenResourceNotFound() throws Exception {
    mockMvc.perform(get("/v1/users/999"))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.code").value(404))
        .andExpect(jsonPath("$.message").value("User not found"));
  }

  @Test
  void shouldReturn400WithFieldErrors() throws Exception {
    mockMvc.perform(post("/v1/users")
        .contentType("application/json")
        .content("{\"name\":\"\",\"email\":\"invalid\"}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.message").value("Parameter validation failed"));
  }
}

@RestController
@RequestMapping("/v1")
class TestController {
  @GetMapping("/users/{id}")
  public User getUser(@PathVariable Long id) { throw new ResourceNotFoundException("User not found"); }
}
```

### Handler with Dependency Injection

```java
private MessageServiceI messageServiceI = mock(MessageServiceI.class);

mockMvc = MockMvcBuilders.standaloneSetup(new TestController())
    .setControllerAdvice(new GlobalExceptionHandler(messageServiceI))
    .build();

when(messageServiceI.getMessage("USER_NOT_FOUND")).thenReturn("User not found");
mockMvc.perform(get("/v1/users/999"))
    .andExpect(jsonPath("$.message").value("User not found"));
verify(messageServiceI).getMessage("USER_NOT_FOUND");
```

### Handler Key Rules

- NOT skip `setControllerAdvice()` — handler does NOT take effect without registration
- NOT assert only HTTP status code — verify all fields in error response body
- NOT omit `@ResponseStatus` — missing annotation results in HTTP 200 by default
- `@ExceptionHandler` matches by exception type — more specific types take precedence

## Anti-patterns

| Pitfall | Wrong | Correct |
|------|----------|----------|
| Business logic in Controller tests | Verifying business results | Only verify HTTP responses; business logic in Service tests |
| Null Service dependencies | `@InjectMocks` with missing mocks | `@Mock` all ServiceI dependencies |
| No interaction verification | Only asserting status | Add `verify(serviceI).method()` |
| Hardcoded URLs | `get("/users/1")` | `BASE_URL = "/v1/users"` |
| Exact JSON comparison | `content().string(containsString("{...}"))` | `jsonPath("$.data.id").value(1)` |
| Handler not triggered | Missing `setControllerAdvice()` | Register handler and match exception type |

## Troubleshooting Guide

| Issue | Solution |
|------|----------|
| 415 Unsupported Media Type | Add `.contentType("application/json")` |
| JsonPath assertion fails | Add `.andDo(print())` to view actual response |
| Expected 200, got 404/500 | Check URL matches `@RequestMapping` |
| `verify()` fails | Set mock before `perform()`; use `any()` for matching |
| Empty response body | Confirm `@RestController` annotation and ObjectMapper config |
| Validation returns 500 | Add `.setValidator(validator)` to standaloneSetup |
| Handler not triggered | Register handler via `setControllerAdvice()` and match exception type |

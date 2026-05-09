---
name: unit-test-controller-layer
description: "Unit testing REST controllers with MockMvc and @WebMvcTest: request/response mapping, validation, exception handling, and HTTP status codes. Use when testing web layer endpoints in isolation or API endpoint testing."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Unit Testing REST Controllers with MockMvc

## Overview

Provides patterns for unit testing `@RestController` and `@Controller` classes using MockMvc. Covers request/response handling, HTTP status codes, request parameter binding, validation, content negotiation, response headers, and exception handling with mocked service dependencies.

## When to use this skill

Use for: controller tests, API endpoint testing, Spring MVC tests, mock HTTP requests, unit testing web layer endpoints, verifying REST controllers in isolation.

## Instructions

1. **Setup standalone MockMvc**: `MockMvcBuilders.standaloneSetup(controller)` for isolated testing
2. **Mock service dependencies**: Use `@Mock` for all services, `@InjectMocks` for the controller
3. **Test HTTP methods**: GET, POST, PUT, PATCH, DELETE with correct status codes
4. **Validate responses**: JsonPath assertions for JSON, content matchers for body
5. **Test validation**: Send invalid input, verify 400 status with error details
6. **Test errors**: Verify 404, 400, 401, 403, 500 for appropriate conditions
7. **Validate headers**: Both request (Authorization) and response headers
8. **Test content negotiation**: Different Accept and Content-Type headers

### Validation Workflow

```
Run test → If fails: add .andDo(print()) → Check actual vs expected → Fix assertion
```

## Examples

### Maven / Gradle Dependencies

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-test</artifactId>
  <scope>test</scope>
</dependency>
```

### Basic Pattern: GET Endpoint

```java
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class UserControllerTest {

  @Mock
  private UserService userService;

  @InjectMocks
  private UserController userController;

  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    mockMvc = MockMvcBuilders.standaloneSetup(userController).build();
  }

  @Test
  void shouldReturnAllUsers() throws Exception {
    List<UserDto> users = List.of(new UserDto(1L, "Alice"), new UserDto(2L, "Bob"));
    when(userService.getAllUsers()).thenReturn(users);

    mockMvc.perform(get("/api/users"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$[0].id").value(1))
      .andExpect(jsonPath("$[0].name").value("Alice"));

    verify(userService, times(1)).getAllUsers();
  }

  @Test
  void shouldReturn404WhenUserNotFound() throws Exception {
    when(userService.getUserById(999L))
      .thenThrow(new UserNotFoundException("User not found"));

    mockMvc.perform(get("/api/users/999"))
      .andExpect(status().isNotFound());

    verify(userService).getUserById(999L);
  }
}
```

### POST: Create Resource

```java
@Test
void shouldCreateUserAndReturn200() throws Exception {
  UserDto createdUser = new UserDto(1L, "Alice", "alice@example.com");
  when(userService.createUser(any())).thenReturn(createdUser);

  mockMvc.perform(post("/api/users")
      .contentType("application/json")
      .content("{\"name\":\"Alice\",\"email\":\"alice@example.com\"}"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.id").value(1))
    .andExpect(jsonPath("$.name").value("Alice"));

  verify(userService).createUser(any(UserCreateRequest.class));
}
```

### PUT: Update Resource

```java
@Test
void shouldUpdateUserAndReturn200() throws Exception {
  UserDto updatedUser = new UserDto(1L, "Updated");
  when(userService.updateUser(eq(1L), any())).thenReturn(updatedUser);

  mockMvc.perform(put("/api/users/1")
      .contentType("application/json")
      .content("{\"name\":\"Updated\"}"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.name").value("Updated"));

  verify(userService).updateUser(eq(1L), any());
}
```

### DELETE: Remove Resource

```java
@Test
void shouldDeleteUserAndReturn200() throws Exception {
  doNothing().when(userService).deleteUser(1L);

  mockMvc.perform(delete("/api/users/1"))
    .andExpect(status().isOk());

  verify(userService).deleteUser(1L);
}
```

### Query Parameters

```java
@Test
void shouldFilterUsersByName() throws Exception {
  when(userService.searchUsers("Alice")).thenReturn(List.of(new UserDto(1L, "Alice")));

  mockMvc.perform(get("/api/users/search").param("name", "Alice"))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$[0].name").value("Alice"));

  verify(userService).searchUsers("Alice");
}
```

### Path Variables

```java
@Test
void shouldGetUserByIdFromPath() throws Exception {
  when(userService.getUserById(123L)).thenReturn(new UserDto(123L, "Alice"));

  mockMvc.perform(get("/api/users/{id}", 123L))
    .andExpect(status().isOk())
    .andExpect(jsonPath("$.id").value(123));
}
```

### Validation Errors (400)

```java
@Test
void shouldReturn400WhenRequestBodyInvalid() throws Exception {
  mockMvc.perform(post("/api/users")
      .contentType("application/json")
      .content("{\"name\":\"\"}"))
    .andExpect(status().isBadRequest())
    .andExpect(jsonPath("$.errors").isArray());
}
```

### Response Headers

```java
@Test
void shouldReturnCustomHeaders() throws Exception {
  when(userService.getAllUsers()).thenReturn(List.of());

  mockMvc.perform(get("/api/users"))
    .andExpect(status().isOk())
    .andExpect(header().exists("X-Total-Count"))
    .andExpect(header().string("X-Total-Count", "0"));
}
```

### Authorization Header

```java
@Test
void shouldRequireAuthorizationHeader() throws Exception {
  mockMvc.perform(get("/api/users"))
    .andExpect(status().isUnauthorized());

  mockMvc.perform(get("/api/users").header("Authorization", "Bearer token"))
    .andExpect(status().isOk());
}
```

### Content Negotiation

```java
@Test
void shouldReturnJsonWhenAcceptHeaderIsJson() throws Exception {
  when(userService.getUserById(1L)).thenReturn(new UserDto(1L, "Alice"));

  mockMvc.perform(get("/api/users/1").accept("application/json"))
    .andExpect(status().isOk())
    .andExpect(content().contentType("application/json"));
}
```

## Best Practices

- Test happy path AND error scenarios (404, 400, 500)
- Use `jsonPath()` for fluent JSON assertions
- Assert one behavior per test method — multiple `jsonPath()` checks on the same response are acceptable

## Constraints and Warnings

- Controller tests verify HTTP handling only — not full request flow
- `standaloneSetup()` may not support `@Validated` without full context
- JsonPath requires valid JSON in response body
- `@PreAuthorize`/`@Secured` need additional setup — consider separate security tests
- File uploads require `MockMultipartFile`

## References

- [Spring MockMvc Documentation](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/test/web/servlet/MockMvc.html)
- [Spring Testing Best Practices](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.testing)

## Related Skills

- `unit-test-exception-handler` — testing @ExceptionHandler and @ControllerAdvice
- `unit-test-bean-validation` — testing @Valid request DTO validation

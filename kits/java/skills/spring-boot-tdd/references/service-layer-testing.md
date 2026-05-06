# Service Layer Unit Testing Reference

Unit testing for `@Service` / `ServiceI` / `CmdExe` using Mockito 5 without Spring container or database.

## Dependency Configuration

`spring-boot-starter-test` (Spring Boot 3.5.x) provides JUnit 5, Mockito 5, AssertJ, and Hamcrest — no additional test dependencies needed for pure unit tests.

For projects NOT using the starter, declare individually:

```xml
<dependency>
  <groupId>org.junit.jupiter</groupId>
  <artifactId>junit-jupiter</artifactId>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.mockito</groupId>
  <artifactId>mockito-core</artifactId>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.mockito</groupId>
  <artifactId>mockito-junit-jupiter</artifactId>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.assertj</groupId>
  <artifactId>assertj-core</artifactId>
  <scope>test</scope>
</dependency>
```

Gradle (without starter):
```kotlin
dependencies {
  testImplementation("org.junit.jupiter:junit-jupiter")
  testImplementation("org.mockito:mockito-core")
  testImplementation("org.mockito:mockito-junit-jupiter")
  testImplementation("org.assertj:assertj-core")
}
```

## COLA Naming Conventions

- **Interface**: `UserServiceI` (ending with `I`), implementation `UserServiceImpl`
- **Command Executor**: `CreateUserCmdExe`, `UpdateUserCmdExe` (ending with `CmdExe`)
- **Injection**: `@Mock` for ServiceI, `@InjectMocks` for CmdExe
- **Return**: `Result<T>` unified wrapper, NOT raw objects or `ResponseEntity`

```java
@ExtendWith(MockitoExtension.class)
class CreateUserCmdExeTest {
  @Mock private UserRepository userRepository;
  @InjectMocks private CreateUserCmdExe createUserCmdExe;

  @Test
  void shouldCreateUserSuccessfully() {
    when(userRepository.save(any())).thenReturn(new User(1L, "Alice"));
    Result<User> result = createUserCmdExe.execute(new CreateUserCmd("Alice"));

    assertThat(result.isSuccess()).isTrue();
    assertThat(result.getData().getName()).isEqualTo("Alice");
  }
}
```

## Basic Testing Patterns

### Single-Dependency ServiceI

```java
@ExtendWith(MockitoExtension.class)
class UserServiceITest {
  @Mock private UserRepository userRepository;
  @InjectMocks private UserServiceI userServiceI;

  @Test
  void shouldReturnUserWhenFound() {
    User expected = new User(1L, "Alice");
    when(userRepository.findById(1L)).thenReturn(Optional.of(expected));

    Result<User> result = userServiceI.getUser(1L);

    assertThat(result.isSuccess()).isTrue();
    assertThat(result.getData().getName()).isEqualTo("Alice");
    verify(userRepository).findById(1L);
  }

  @Test
  void shouldThrowWhenUserNotFound() {
    when(userRepository.findById(999L)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> userServiceI.getUser(999L))
      .isInstanceOf(UserNotFoundException.class);
  }
}
```

### Multi-Dependency ServiceI

```java
@ExtendWith(MockitoExtension.class)
class UserEnrichmentServiceITest {
  @Mock private UserRepository userRepository;
  @Mock private EmailServiceI emailServiceI;
  @Mock private AnalyticsClient analyticsClient;
  @InjectMocks private UserEnrichmentServiceI enrichmentServiceI;

  @Test
  void shouldCreateUserAndSendWelcomeEmail() {
    User newUser = new User(1L, "Alice", "alice@example.com");
    when(userRepository.save(any(User.class))).thenReturn(newUser);
    doNothing().when(emailServiceI).sendWelcomeEmail(newUser.getEmail());

    Result<User> result = enrichmentServiceI.registerNewUser("Alice", "alice@example.com");

    assertThat(result.getData().getId()).isEqualTo(1L);
    verify(userRepository).save(any(User.class));
    verify(emailServiceI).sendWelcomeEmail("alice@example.com");
    verify(analyticsClient, never()).trackUserRegistration(any());
  }
}
```

## Exception Scenario Testing

```java
@Test
void shouldThrowExceptionWhenUserNotFound() {
  when(userRepository.findById(999L))
    .thenThrow(new UserNotFoundException("User not found"));

  assertThatThrownBy(() -> userServiceI.getUserDetails(999L))
    .isInstanceOf(UserNotFoundException.class)
    .hasMessageContaining("User not found");
}

@Test
void shouldRethrowRepositoryException() {
  when(userRepository.findAll())
    .thenThrow(new DataAccessException("Database connection failed"));

  assertThatThrownBy(() -> userServiceI.getAllUsers())
    .isInstanceOf(DataAccessException.class)
    .hasMessageContaining("Database connection failed");
}
```

## ArgumentCaptor Parameter Capture

```java
@Test
void shouldCaptureUserDataWhenSaving() {
  ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);
  when(userRepository.save(any(User.class)))
    .thenAnswer(invocation -> invocation.getArgument(0));

  userServiceI.createUser("Alice", "alice@example.com");

  verify(userRepository).save(captor.capture());
  assertThat(captor.getValue().getName()).isEqualTo("Alice");
  assertThat(captor.getValue().getEmail()).isEqualTo("alice@example.com");
}

@Test
void shouldCaptureMultipleArgumentsAcrossCalls() {
  ArgumentCaptor<User> captor = ArgumentCaptor.forClass(User.class);

  userServiceI.createUser("Alice", "alice@example.com");
  userServiceI.createUser("Bob", "bob@example.com");

  verify(userRepository, times(2)).save(captor.capture());
  assertThat(captor.getAllValues()).hasSize(2);
  assertThat(captor.getAllValues().get(0).getName()).isEqualTo("Alice");
}
```

## Call Order and Frequency Verification

```java
@Test
void shouldCallMethodsInCorrectOrder() {
  InOrder inOrder = inOrder(userRepository, emailServiceI);

  userServiceI.registerNewUser("Alice", "alice@example.com");

  inOrder.verify(userRepository).save(any(User.class));
  inOrder.verify(emailServiceI).sendWelcomeEmail(any());
}

@Test
void shouldCallMethodExactlyOnce() {
  userServiceI.getUserDetails(1L);

  verify(userRepository, times(1)).findById(1L);
  verify(userRepository, never()).findAll();
}
```

## Async Service Testing

```java
@Test
void shouldReturnCompletableFutureWhenFetchingAsyncData() {
  List<User> users = List.of(new User(1L, "Alice"));
  when(userRepository.findAllAsync())
    .thenReturn(CompletableFuture.completedFuture(users));

  CompletableFuture<List<User>> result = userServiceI.getAllUsersAsync();

  assertThat(result).isCompletedWithValue(users);
}
```

## Anti-patterns

- NOT mock value objects or DTOs — create real instances instead
- NOT test private methods — cover through public method behavior
- NOT mix `any()` / `eq()` matchers with actual values in the same stub — all parameters must use matchers or all must use actual values
- NOT over-verify — only verify interactions relevant to the test scenario
- NOT stub mocks globally in `@BeforeEach setUp()` — unused stubs trigger `UnnecessaryStubbingException`. Move stubs into each test method.
- NOT assume `mock.method2Param()` delegates to `mock.method3Param()` — Mockito mocks do NOT delegate internally. Stub every called signature:
  ```java
  // Real code: httpClient.postJson(url, body) internally calls httpClient.postJson(url, body, Map.of())
  when(httpClient.postJson(anyString(), anyString())).thenReturn(response);
  when(httpClient.postJson(anyString(), anyString(), anyMap())).thenReturn(response);
  ```
- NOT use `anyString()` for nullable parameters — `anyString()` rejects `null`. Use `any()` or explicit stub.
- Mockito default returns: `String` → `null` (NOT empty string), `int/long` → `0`, `boolean` → `false`

## Troubleshooting Guide

| Issue | Cause | Solution |
|------|------|----------|
| `UnfinishedStubbingException` | `when()` missing `thenReturn/thenThrow/thenAnswer` | Ensure each stub is complete |
| `UnnecessaryStubbingException` | stub not used by all test paths | Move stubs to individual tests or use `@MockitoSettings(strictness = Strictness.LENIENT)` |
| `NullPointerException` in test | `@InjectMocks` missing dependency | Ensure all constructor parameters have `@Mock` |
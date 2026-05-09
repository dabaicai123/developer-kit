---
name: unit-test-service-layer
description: "Unit testing service layer with Mockito: mocking repository calls, verifying method invocations, exception scenarios, and stubbing external API responses. Use when testing service behaviors and business logic without database or external services."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Unit Testing Service Layer with Mockito

## Overview

Provides patterns for unit testing `@Service` classes using Mockito. Mocks repository calls, verifies method invocations, tests exception scenarios, and stubs external API responses. Enables fast, isolated tests without Spring container or database.

## When to use this skill

- Testing business logic in `@Service` classes
- Mocking repository and external client dependencies
- Verifying service interactions with mocked collaborators
- Testing error handling and edge cases in services
- Writing fast, isolated unit tests (no database, no API calls)

## Instructions

1. **Use `@ExtendWith(MockitoExtension.class)` with `@Mock`/`@InjectMocks`**: Declare `@Mock` for dependencies (repositories, clients) and `@InjectMocks` for the service under test
2. **Arrange-Act-Assert pattern**: Create test data, configure mocks with `when().thenReturn()`, execute the service method, and assert results with AssertJ
3. **Test exception scenarios**: Configure mocks with `when().thenThrow()` and assert with `assertThatThrownBy()`

## Examples

### Basic Service Test Pattern

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

  @Mock
  private UserRepository userRepository;

  @InjectMocks
  private UserService userService;

  @Test
  void shouldReturnUserWhenFound() {
    // Arrange
    User expected = new User(1L, "Alice");
    when(userRepository.findById(1L)).thenReturn(Optional.of(expected));

    // Act
    User result = userService.getUser(1L);

    // Assert
    assertThat(result.getName()).isEqualTo("Alice");
    verify(userRepository).findById(1L);
  }

  @Test
  void shouldThrowWhenUserNotFound() {
    // Arrange
    when(userRepository.findById(999L)).thenReturn(Optional.empty());

    // Act & Assert
    assertThatThrownBy(() -> userService.getUser(999L))
      .isInstanceOf(UserNotFoundException.class);
  }
}
```

### Verify Method Invocations

```java
@Test
void shouldSendEmailOnUserCreation() {
  User newUser = new User(1L, "Alice", "alice@example.com");
  when(userRepository.save(any(User.class))).thenReturn(newUser);

  enrichmentService.registerNewUser("Alice", "alice@example.com");

  verify(userRepository).save(any(User.class));
  verify(emailService).sendWelcomeEmail("alice@example.com");
}
```

For additional patterns (multiple dependencies, argument captors, async services, InOrder verification), see `references/examples.md`.

## Best Practices

- **Mock only direct dependencies** (repositories, clients -- not value objects); create real instances for value objects and DTOs
- **Test one behavior per test method** — keep tests focused

## Constraints and Warnings

- Do not mock value objects or DTOs; create real instances with test data.
- Avoid mocking too many dependencies; consider refactoring if a service has too many collaborators.
- Tests must be independent; do not rely on execution order.
- Be cautious with `@Spy`; partial mocking is harder to understand and maintain.
- Do not test private methods directly; test them through public method behavior.
- Argument matchers (`any()`, `eq()`) cannot be mixed with actual values in the same stub.
- Use `verify()` only for interactions that matter to the test scenario; avoid over-verifying.
- **Strict stubbing conflict**: `@BeforeEach setUp()` stubs that aren't used in all test paths cause `UnnecessaryStubbingException`. Use `@MockitoSettings(strictness = Strictness.LENIENT)` or move stubs into individual test methods.
- **Mock delegation**: Mockito mocks do NOT internally delegate — `mock.method2Param()` will NOT invoke `mock.method3Param()` even if real code delegates. Stub each called signature separately.
- **Mock default returns**: `String` returns `null` (not ""), so `anyString()` won't match null. Use `any()` for nullable parameters, or stub explicitly.

## References

- [Mockito Documentation](https://javadoc.io/doc/org.mockito/mockito-core/latest/org/mockito/Mockito.html)
- [JUnit 5 User Guide](https://junit.org/junit5/docs/current/user-guide/)
- [AssertJ Assertions](https://assertj.github.io/assertj-core-features-highlight.html)

## Related Skills

- `spring-boot-tdd` — TDD workflow, coverage thresholds, test-first development
- `unit-test-mapper-converter` — testing MapStruct mappers and DO/DTO converters

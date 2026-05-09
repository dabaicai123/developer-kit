---
name: unit-test-security-authorization
description: "Unit testing Spring Security authorization with @PreAuthorize, @Secured, and @RolesAllowed: role-based access control and authorization policies. Use when testing security configurations and access control logic."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Unit Testing Security and Authorization

## When to use this skill

Use this skill when:
- Testing `@PreAuthorize` and `@Secured` method-level security
- Testing role-based access control (RBAC)
- Testing custom permission evaluators
- Verifying access denied scenarios
- Testing authorization with authenticated principals
- Want fast authorization tests without full Spring Security context

## Instructions

Follow these steps to test Spring Security authorization:

### 1. Set Up Security Testing Dependencies
Add spring-security-test to your test dependencies.

### 2. Enable Method Security in Test Configuration
Use `@EnableMethodSecurity` on a test `@Configuration` class.

### 3. Test with `@WithMockUser`
Use `@WithMockUser(roles = "...")` to simulate authenticated users. Assert `doesNotThrowAnyException()` for allowed access and `isInstanceOf(AccessDeniedException.class)` for denied access.

### 4. Test Custom Permission Evaluators
Construct `Authentication` manually with `UsernamePasswordAuthenticationToken` and `SimpleGrantedAuthority`. Invoke the evaluator directly and assert boolean results.

### 5. Validate Security is Active
If tests pass unexpectedly, add an unauthenticated assertion (`assertThatThrownBy(...).isInstanceOf(AccessDeniedException.class)`) to confirm `@EnableMethodSecurity` is enforced — missing annotation causes all checks to be bypassed silently.

## Examples

### Basic `@PreAuthorize` Test

> **Important**: `@PreAuthorize` works via Spring AOP proxying. To test method-level security, you must use `@SpringBootTest` + `@EnableMethodSecurity` so the proxy intercepts calls. Mockito's `@InjectMocks` bypasses the proxy, making `@PreAuthorize` silently ignored.

```java
@Service
public class UserService {
  @PreAuthorize("hasRole('ADMIN')")
  public void deleteUser(Long userId) {
    // delete logic
  }
}

// Test — requires Spring context for proxy-based security
@SpringBootTest
@EnableMethodSecurity
class UserServiceAuthorizationTest {

  @MockBean private UserRepository userRepository;
  @Autowired private UserService userService;

  @Test
  @WithMockUser(roles = "ADMIN")
  void shouldAllowAdminToDeleteUser() {
    assertThatCode(() -> userService.deleteUser(1L))
      .doesNotThrowAnyException();
  }

  @Test
  @WithMockUser(roles = "USER")
  void shouldDenyUserFromDeletingUser() {
    assertThatThrownBy(() -> userService.deleteUser(1L))
      .isInstanceOf(AccessDeniedException.class);
  }
}
```

### Expression-Based Security Test

```java
@PreAuthorize("#userId == authentication.principal.id")
public UserProfile getUserProfile(Long userId) {
  // get profile
}

// For custom principal properties, use @WithUserDetails with a custom UserDetailsService
@Test
@WithUserDetails("alice")
void shouldAllowUserToAccessOwnProfile() {
  assertThatCode(() -> service.getUserProfile(1L))
    .doesNotThrowAnyException();
}
```

> **Validation tip**: If a security test passes unexpectedly, verify that `@EnableMethodSecurity` is active on the test configuration — a missing annotation causes all `@PreAuthorize` checks to be bypassed silently.

See [references/basic-testing.md](references/basic-testing.md) for more basic patterns and [references/advanced-authorization.md](references/advanced-authorization.md) for complex expressions and custom evaluators.

## Best Practices

1. **Test both allow and deny cases** for each security rule
2. **Test anonymous access separately** from authenticated access

## Common Pitfalls

- Forgetting to enable method security in test configuration
- Not testing both allow and deny scenarios
- Testing framework code instead of authorization logic
- Not handling null authentication in tests
- Mixing authentication and authorization tests unnecessarily

## Constraints and Warnings

- **Method security requires proxy**: `@PreAuthorize` works via proxies; direct method calls bypass security
- **`@EnableMethodSecurity`**: Must be enabled for `@PreAuthorize`, `@Secured` to work
- **Role prefix**: Spring adds "ROLE_" prefix automatically; use `hasRole('ADMIN')` not `hasRole('ROLE_ADMIN')`
- **Authentication context**: Security context is thread-local; be careful with async tests
- **`@WithMockUser` limitations**: Creates a simple Authentication; complex auth scenarios need custom setup
- **SpEL expressions**: Complex SpEL in `@PreAuthorize` can be difficult to debug; test thoroughly
- **Performance impact**: Method security adds overhead; consider security at layer boundaries

## References

### Setup and Configuration
- **[references/setup.md](references/setup.md)** - Maven/Gradle dependencies and security configuration

### Testing Patterns
- **[references/basic-testing.md](references/basic-testing.md)** - Basic patterns for `@PreAuthorize`, `@Secured`, MockMvc testing, and parameterized tests

### Advanced Topics
- **[references/advanced-authorization.md](references/advanced-authorization.md)** - Expression-based authorization, custom permission evaluators, SpEL expressions

### Complete Examples
- **[references/complete-examples.md](references/complete-examples.md)** - Before/after examples showing transition from manual to declarative security

## Related Skills

- `spring-boot-security` — Spring Security configuration, CORS, CSRF, method security
- `spring-boot-security-jwt` — JWT authentication, SecurityFilterChain, token management

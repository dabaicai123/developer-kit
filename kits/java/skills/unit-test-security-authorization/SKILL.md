---
name: unit-test-security-authorization
description: "Unit testing Spring Security authorization: @PreAuthorize, @Secured, role-based access control. Use when testing security configurations and access control logic."
version: "1.1.0"
type: skill
---

# Unit Testing Security and Authorization

## When to use this skill

Use this skill when:
- Testing `@PreAuthorize`, `@Secured`, `@RolesAllowed` method-level security
- Testing role-based access control (RBAC)
- Testing custom permission evaluators
- Verifying access denied scenarios
- Want fast authorization tests without full Spring Security context

## Anti-Patterns

- **NOT** test `@PreAuthorize` with `new Service()` or `@InjectMocks` — Spring AOP proxy is required; use `@SpringBootTest` + `@EnableMethodSecurity`
- **NOT** use `@MockBean` — deprecated since Spring Boot 3.4; use `@MockitoBean` from `org.springframework.test.context.bean.override.mockito`
- **NOT** use `@EnableGlobalMethodSecurity` — removed in Spring Security 6.x; use `@EnableMethodSecurity`
- **NOT** use `hasRole('ROLE_ADMIN')` — Spring adds `ROLE_` prefix automatically; write `hasRole('ADMIN')`
- **NOT** use `@WithMockUser` for custom principal properties like `id` — `@WithMockUser` creates a simple `User` without custom fields; use `@WithUserDetails` with a custom `UserDetailsService`

## Instructions

1. Add `spring-security-test` to test dependencies
2. Use `@EnableMethodSecurity` on test `@Configuration`
3. Use `@WithMockUser(roles = "...")` to simulate authenticated users; assert `doesNotThrowAnyException()` for allowed, `isInstanceOf(AccessDeniedException.class)` for denied
4. Test custom evaluators by constructing `Authentication` with `UsernamePasswordAuthenticationToken` + `SimpleGrantedAuthority`; invoke directly and assert boolean
5. Validate security is active: add unauthenticated assertion to confirm `@EnableMethodSecurity` is enforced — missing annotation causes all checks to be bypassed silently

## Examples

### Basic `@PreAuthorize` Test

> `@PreAuthorize` works via Spring AOP proxying. Must use `@SpringBootTest` + `@EnableMethodSecurity` so the proxy intercepts calls. `@InjectMocks` bypasses the proxy, making `@PreAuthorize` silently ignored.

```java
@Service
public class UserService {
  @PreAuthorize("hasRole('ADMIN')")
  public void deleteUser(Long userId) {
    // delete logic
  }
}

@SpringBootTest
@EnableMethodSecurity
class UserServiceAuthorizationTest {

  @MockitoBean private UserRepository userRepository;
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

// Custom principal properties require @WithUserDetails
@Test
@WithUserDetails("alice")
void shouldAllowUserToAccessOwnProfile() {
  assertThatCode(() -> service.getUserProfile(1L))
    .doesNotThrowAnyException();
}
```

See [references/basic-testing.md](references/basic-testing.md) for more patterns and [references/advanced-authorization.md](references/advanced-authorization.md) for complex expressions and custom evaluators.

## Constraints

- **Proxy required**: `@PreAuthorize` works via AOP proxies; direct/internal calls bypass security
- **`@EnableMethodSecurity`**: Must be enabled for `@PreAuthorize`, `@Secured` to work
- **Role prefix**: Spring adds `ROLE_` automatically; use `hasRole('ADMIN')` not `hasRole('ROLE_ADMIN')`
- **`@WithMockUser`**: Creates simple `User` principal; custom properties require `@WithUserDetails`
- **Thread-local context**: Security context is thread-local; async tests need `DelegatingSecurityContextExecutorService`

## References

- [references/setup.md](references/setup.md) — Dependencies and configuration
- [references/basic-testing.md](references/basic-testing.md) — `@PreAuthorize`, `@Secured`, MockMvc, parameterized tests
- [references/advanced-authorization.md](references/advanced-authorization.md) — Expression-based auth, custom evaluators, SpEL
- [references/complete-examples.md](references/complete-examples.md) — Before/after transition examples

## Related Skills

- `spring-boot-security`
- `spring-boot-security-jwt`
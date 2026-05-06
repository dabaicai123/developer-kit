# Basic Testing Patterns

> `@PreAuthorize` on service methods requires `@SpringBootTest` + `@EnableMethodSecurity` for proxy interception. Direct instantiation (`new Service()`) bypasses the proxy.

## Testing `@PreAuthorize` with Role-Based Access Control

### Service with Security Annotations

```java
@Service
public class UserService {

  @PreAuthorize("hasRole('ADMIN')")
  public void deleteUser(Long userId) {
    // delete logic
  }

  @PreAuthorize("hasRole('USER')")
  public User getCurrentUser() {
    // get user logic
  }

  @PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")
  public List<User> listAllUsers() {
    // list logic
  }
}
```

### Authorization Tests (Spring Context Required)

```java
@SpringBootTest
@EnableMethodSecurity
class UserServiceSecurityTest {

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

  @Test
  @WithMockUser(roles = "ADMIN")
  void shouldAllowAdminAndManagerToListUsers() {
    assertThatCode(() -> userService.listAllUsers())
      .doesNotThrowAnyException();
  }

  @Test
  void shouldDenyAnonymousUserAccess() {
    assertThatThrownBy(() -> userService.deleteUser(1L))
      .isInstanceOf(AccessDeniedException.class);
  }
}
```

## Testing `@Secured` Annotation

> `@Secured` requires `@EnableMethodSecurity(securedEnabled = true)`. `@Secured` matches exact authority strings — use `@Secured("ROLE_ADMIN")` to match the `ROLE_ADMIN` authority created by `@WithMockUser(roles = "ADMIN")`.

```java
@Service
public class OrderService {

  @Secured("ROLE_ADMIN")
  public Order approveOrder(Long orderId) {
    // approval logic
  }

  @Secured({"ROLE_ADMIN", "ROLE_MANAGER"})
  public List<Order> getOrders() {
    // get orders
  }
}
```

```java
@SpringBootTest
@EnableMethodSecurity(securedEnabled = true)
class OrderSecurityTest {

  @MockitoBean private OrderRepository orderRepository;
  @Autowired private OrderService orderService;

  @Test
  @WithMockUser(roles = "ADMIN")
  void shouldAllowAdminToApproveOrder() {
    assertThatCode(() -> orderService.approveOrder(1L))
      .doesNotThrowAnyException();
  }

  @Test
  @WithMockUser(roles = "USER")
  void shouldDenyUserFromApprovingOrder() {
    assertThatThrownBy(() -> orderService.approveOrder(1L))
      .isInstanceOf(AccessDeniedException.class);
  }
}
```

## Testing Controller Security with MockMvc

> Controller `@PreAuthorize` also requires proxy. Use `@WebMvcTest` to load the controller with Spring proxy.

```java
@RestController
@RequestMapping("/v1/admin")
public class AdminController {

  @GetMapping("/users")
  @PreAuthorize("hasRole('ADMIN')")
  public Result<List<UserDTO>> listAllUsers() {
    // logic
  }

  @DeleteMapping("/users/{id}")
  @PreAuthorize("hasRole('ADMIN')")
  public void deleteUser(@PathVariable Long id) {
    // delete logic
  }
}
```

```java
@WebMvcTest(AdminController.class)
class AdminControllerSecurityTest {

  @MockitoBean private UserService userService;
  @Autowired private MockMvc mockMvc;

  @Test
  @WithMockUser(roles = "ADMIN")
  void shouldAllowAdminToListUsers() throws Exception {
    mockMvc.perform(get("/v1/admin/users"))
      .andExpect(status().isOk());
  }

  @Test
  @WithMockUser(roles = "USER")
  void shouldDenyUserFromListingUsers() throws Exception {
    mockMvc.perform(get("/v1/admin/users"))
      .andExpect(status().isForbidden());
  }

  @Test
  void shouldDenyAnonymousAccessToAdminEndpoint() throws Exception {
    mockMvc.perform(get("/v1/admin/users"))
      .andExpect(status().isUnauthorized());
  }

  @Test
  @WithMockUser(roles = "ADMIN")
  void shouldAllowAdminToDeleteUser() throws Exception {
    mockMvc.perform(delete("/v1/admin/users/1"))
      .andExpect(status().isOk());
  }
}
```

## Testing Multiple Roles with Parameterized Tests

> `@WithMockUser` provides a fixed role per test — NOT combine it with `@ValueSource` expecting per-parameter roles. Use `SecurityContext` manipulation for dynamic role testing.

```java
@SpringBootTest
@EnableMethodSecurity
class RoleBasedAccessTest {

  @MockitoBean private UserRepository userRepository;
  @Autowired private AdminService adminService;

  @ParameterizedTest
  @ValueSource(strings = {"ADMIN", "SUPER_ADMIN", "SYSTEM"})
  void shouldAllowPrivilegedRolesToDeleteUser(String role) {
    SecurityContext context = SecurityContextHolder.createEmptyContext();
    context.setAuthentication(new UsernamePasswordAuthenticationToken(
      "user", null, List.of(new SimpleGrantedAuthority("ROLE_" + role))));
    SecurityContextHolder.setContext(context);

    assertThatCode(() -> adminService.deleteUser(1L))
      .doesNotThrowAnyException();
  }

  @ParameterizedTest
  @ValueSource(strings = {"USER", "GUEST", "READONLY"})
  void shouldDenyUnprivilegedRolesToDeleteUser(String role) {
    SecurityContext context = SecurityContextHolder.createEmptyContext();
    context.setAuthentication(new UsernamePasswordAuthenticationToken(
      "user", null, List.of(new SimpleGrantedAuthority("ROLE_" + role))));
    SecurityContextHolder.setContext(context);

    assertThatThrownBy(() -> adminService.deleteUser(1L))
      .isInstanceOf(AccessDeniedException.class);
  }
}
```

## `@WithMockUser` Options

```java
@WithMockUser                                          // default user with role "USER"
@WithMockUser(username = "alice")                      // custom username
@WithMockUser(roles = "ADMIN")                         // single role
@WithMockUser(roles = {"ADMIN", "USER"})               // multiple roles
@WithMockUser(authorities = "READ_PERMISSION")          // single authority (no ROLE_ prefix)
@WithMockUser(authorities = {"READ", "WRITE"})          // multiple authorities
```
# Complete Examples — Before and After

## Example 1: Adding Security Tests

### Before: Service Without Security Testing

```java
@Service
public class AdminService {
    public void deleteUser(Long userId) {
        repository.deleteById(userId);
    }
}
```

### After: Service With Security Test Coverage

```java
@Service
public class AdminService {
    @PreAuthorize("hasRole('ADMIN')")
    public void deleteUser(Long userId) {
        repository.deleteById(userId);
    }
}

@SpringBootTest
@EnableMethodSecurity
class AdminServiceSecurityTest {

    @MockitoBean private UserRepository userRepository;
    @Autowired private AdminService adminService;

    @Test
    @WithMockUser(roles = "ADMIN")
    void shouldAllowAdminToDeleteUser() {
        assertThatCode(() -> adminService.deleteUser(1L))
            .doesNotThrowAnyException();
    }

    @Test
    @WithMockUser(roles = "USER")
    void shouldDenyUserFromDeletingUser() {
        assertThatThrownBy(() -> adminService.deleteUser(1L))
            .isInstanceOf(AccessDeniedException.class);
    }
}
```

## Example 2: Declarative Security Replaces Manual Checks

### Before: Manual Security Check (Anti-Pattern)

```java
// NOT: manual security checks in business logic
@Service
public class AdminService {
    public void deleteUser(Long userId, User currentUser) {
        if (currentUser.hasRole("ADMIN")) {
            repository.deleteById(userId);
        } else {
            throw new AccessDeniedException("Not authorized");
        }
    }
}
```

### After: Declarative Security with Testing

```java
@Service
public class AdminService {
    @PreAuthorize("hasRole('ADMIN')")
    public void deleteUser(Long userId) {
        repository.deleteById(userId);
    }
}

@SpringBootTest
@EnableMethodSecurity
class AdminServiceSecurityTest {

    @MockitoBean private UserRepository userRepository;
    @Autowired private AdminService adminService;

    @Test
    @WithMockUser(roles = "ADMIN")
    void shouldExecuteDelete() {
        adminService.deleteUser(1L);
        verify(userRepository).deleteById(1L);
    }

    @Test
    @WithMockUser(roles = "USER")
    void shouldNotExecuteDeleteDueToSecurity() {
        assertThatThrownBy(() -> adminService.deleteUser(1L))
            .isInstanceOf(AccessDeniedException.class);
        verify(userRepository, never()).deleteById(anyLong());
    }
}
```

## Example 3: Controller Security Testing

### Before: Insecure Controller

```java
@RestController
@RequestMapping("/api")
public class UserController {

    @GetMapping("/users/{id}")
    public Result<User> getUser(@PathVariable Long id) {
        return Result.success(service.findById(id));
    }

    @DeleteMapping("/users/{id}")
    public Result<Void> deleteUser(@PathVariable Long id) {
        service.deleteUser(id);
        return Result.success();
    }
}
```

### After: Secure Controller with Tests

```java
@RestController
@RequestMapping("/v1/admin")
public class AdminController {

    @GetMapping("/users/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<User> getUser(@PathVariable Long id) {
        return Result.success(service.findById(id));
    }

    @DeleteMapping("/users/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public Result<Void> deleteUser(@PathVariable Long id) {
        service.deleteUser(id);
        return Result.success();
    }
}

@WebMvcTest(AdminController.class)
class AdminControllerSecurityTest {

    @MockitoBean private UserService userService;
    @Autowired private MockMvc mockMvc;

    @Test
    @WithMockUser(roles = "ADMIN")
    void shouldAllowAdminToGetUser() throws Exception {
        mockMvc.perform(get("/v1/admin/users/1"))
            .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "USER")
    void shouldDenyUserFromGettingUser() throws Exception {
        mockMvc.perform(get("/v1/admin/users/1"))
            .andExpect(status().isForbidden());
    }

    @Test
    void shouldDenyAnonymousAccess() throws Exception {
        mockMvc.perform(get("/v1/admin/users/1"))
            .andExpect(status().isUnauthorized());
    }
}
```

## Example 4: Custom Permission Evaluator

### Before: Inline Permission Check (Anti-Pattern)

```java
// NOT: inline permission checks in business logic
@Service
public class DocumentService {
    public Document getDocument(Long docId, User currentUser) {
        Document doc = repository.findById(docId)
            .orElseThrow(() -> new NotFoundException());

        if (!doc.getOwner().equals(currentUser.getUsername()) &&
            !currentUser.hasRole("ADMIN")) {
            throw new AccessDeniedException("Access denied");
        }
        return doc;
    }
}
```

### After: Declarative Security with Custom Evaluator

```java
@Service
public class DocumentService {

    @PreAuthorize("hasPermission(#docId, 'Document', 'READ')")
    public Document getDocument(Long docId) {
        return repository.findById(docId)
            .orElseThrow(() -> new NotFoundException());
    }
}

@Component
public class DocumentPermissionEvaluator implements PermissionEvaluator {

    @Override
    public boolean hasPermission(Authentication authentication,
                               Serializable targetId,
                               String targetType,
                               Object permission) {
        Document doc = repository.findById(targetId).orElse(null);
        if (doc == null) return false;
        return doc.getOwner().equals(authentication.getName()) ||
               authentication.getAuthorities().stream()
                 .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }
}

@SpringBootTest
@EnableMethodSecurity
class DocumentServiceSecurityTest {

    @MockitoBean private DocumentRepository documentRepository;
    @Autowired private DocumentService documentService;

    @Test
    @WithMockUser(username = "alice")
    void shouldAllowOwnerToReadDocument() {
        when(documentRepository.findById(1L))
          .thenReturn(Optional.of(new Document(1L, "alice")));
        assertThatCode(() -> documentService.getDocument(1L))
          .doesNotThrowAnyException();
    }

    @Test
    @WithMockUser(username = "alice")
    void shouldDenyNonOwnerFromReadingDocument() {
        when(documentRepository.findById(2L))
          .thenReturn(Optional.of(new Document(2L, "bob")));
        assertThatThrownBy(() -> documentService.getDocument(2L))
          .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void shouldAllowAdminToReadAnyDocument() {
        when(documentRepository.findById(2L))
          .thenReturn(Optional.of(new Document(2L, "bob")));
        assertThatCode(() -> documentService.getDocument(2L))
          .doesNotThrowAnyException();
    }
}
```

## Example 5: Expression-Based Security

### Before: Multiple Manual Checks (Anti-Pattern)

```java
// NOT: multiple manual security checks in business logic
@Service
public class ProfileService {

    public UserProfile updateProfile(Long userId, ProfileUpdate update, User currentUser) {
        if (!currentUser.getId().equals(userId) &&
            !currentUser.hasRole("ADMIN") &&
            !currentUser.hasRole("MODERATOR")) {
            throw new AccessDeniedException("Access denied");
        }
        return repository.update(userId, update);
    }
}
```

### After: Declarative Expression-Based Security

```java
@Service
public class ProfileService {

    @PreAuthorize("#userId == authentication.principal.id or hasAnyRole('ADMIN', 'MODERATOR')")
    public UserProfile updateProfile(Long userId, ProfileUpdate update) {
        return repository.update(userId, update);
    }
}

// Custom UserDetailsService for principal.id support
@Component
public class CustomUserDetailsService implements UserDetailsService {
    @Override
    public UserDetails loadUserByUsername(String username) {
        return new CustomUserDetails(username, ...);
    }
}

@SpringBootTest
@EnableMethodSecurity
class ProfileServiceSecurityTest {

    @MockitoBean private ProfileRepository profileRepository;
    @Autowired private ProfileService profileService;

    @Test
    @WithUserDetails("alice")
    void shouldAllowUserToUpdateOwnProfile() {
        assertThatCode(() -> profileService.updateProfile(1L, new ProfileUpdate("Alice")))
          .doesNotThrowAnyException();
    }

    @Test
    @WithUserDetails("alice")
    void shouldDenyUserFromUpdatingOtherProfile() {
        assertThatThrownBy(() -> profileService.updateProfile(2L, new ProfileUpdate("Hacked")))
          .isInstanceOf(AccessDeniedException.class);
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void shouldAllowAdminToUpdateAnyProfile() {
        assertThatCode(() -> profileService.updateProfile(2L, new ProfileUpdate("Admin")))
          .doesNotThrowAnyException();
    }
}
```

## Key Takeaways

1. Use declarative annotations instead of manual security checks
2. Separate security logic from business logic
3. Test both allow and deny cases
4. Use `@MockitoBean` (NOT `@MockBean`) for mocking in Spring context
5. Use `@WebMvcTest` for controller security, `@SpringBootTest` for service security
6. Extract complex permissions into reusable evaluators
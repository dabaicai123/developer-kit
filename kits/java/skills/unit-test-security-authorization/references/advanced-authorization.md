# Advanced Authorization Testing

> Service-level `@PreAuthorize` tests require `@SpringBootTest` + `@EnableMethodSecurity` for proxy interception. Custom evaluators can be tested directly without Spring context.

## Testing Expression-Based Authorization

### Complex Permission Expressions

```java
@Service
public class DocumentService {

  @PreAuthorize("hasRole('ADMIN') or authentication.principal.username == #owner")
  public Document getDocument(String owner, Long docId) {
    // get document
  }

  @PreAuthorize("hasPermission(#docId, 'Document', 'WRITE')")
  public void updateDocument(Long docId, String content) {
    // update logic
  }

  @PreAuthorize("#userId == authentication.principal.id")
  public UserProfile getUserProfile(Long userId) {
    // get profile
  }
}
```

### Tests

> `authentication.principal.id` requires a custom `UserDetailsService` that returns a principal with an `id` field. Use `@WithUserDetails`, **NOT** `@WithMockUser` (which creates a simple `User` without `id`).

```java
@SpringBootTest
@EnableMethodSecurity
class ExpressionBasedSecurityTest {

  @MockitoBean private DocumentRepository documentRepository;
  @Autowired private DocumentService documentService;

  @Test
  @WithMockUser(username = "alice", roles = "ADMIN")
  void shouldAllowAdminToAccessAnyDocument() {
    assertThatCode(() -> documentService.getDocument("bob", 1L))
      .doesNotThrowAnyException();
  }

  @Test
  @WithMockUser(username = "alice")
  void shouldAllowOwnerToAccessOwnDocument() {
    assertThatCode(() -> documentService.getDocument("alice", 1L))
      .doesNotThrowAnyException();
  }

  @Test
  @WithMockUser(username = "alice")
  void shouldDenyUserAccessToOtherUserDocument() {
    assertThatThrownBy(() -> documentService.getDocument("bob", 1L))
      .isInstanceOf(AccessDeniedException.class);
  }
}
```

For `authentication.principal.id` expressions, use `@WithUserDetails` with a custom `UserDetailsService`:

```java
@Test
@WithUserDetails("alice")
void shouldAllowUserToAccessOwnProfile() {
  assertThatCode(() -> documentService.getUserProfile(1L))
    .doesNotThrowAnyException();
}

@Test
@WithUserDetails("bob")
void shouldDenyUserAccessToOtherProfile() {
  assertThatThrownBy(() -> documentService.getUserProfile(999L))
    .isInstanceOf(AccessDeniedException.class);
}
```

## Testing Custom Permission Evaluator

> Custom evaluators implement `PermissionEvaluator` — test directly without Spring context. No proxy needed for pure logic.

```java
@Component
public class DocumentPermissionEvaluator implements PermissionEvaluator {

  private final DocumentRepository documentRepository;

  public DocumentPermissionEvaluator(DocumentRepository documentRepository) {
    this.documentRepository = documentRepository;
  }

  @Override
  public boolean hasPermission(Authentication authentication,
                               Object targetDomainObject,
                               Object permission) {
    if (authentication == null) return false;
    Document document = (Document) targetDomainObject;
    String username = authentication.getName();
    return document.getOwner().getUsername().equals(username) ||
           authentication.getAuthorities().stream()
             .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
  }

  @Override
  public boolean hasPermission(Authentication authentication,
                               Serializable targetId,
                               String targetType,
                               Object permission) {
    if (authentication == null) return false;
    if (!"Document".equals(targetType)) return false;
    Document document = documentRepository.findById((Long) targetId).orElse(null);
    if (document == null) return false;
    return hasPermission(authentication, document, permission);
  }
}
```

```java
class DocumentPermissionEvaluatorTest {

  private DocumentPermissionEvaluator evaluator;
  private DocumentRepository documentRepository;

  @BeforeEach
  void setUp() {
    documentRepository = mock(DocumentRepository.class);
    evaluator = new DocumentPermissionEvaluator(documentRepository);
  }

  @Test
  void shouldGrantPermissionToDocumentOwner() {
    Authentication userAuth = new UsernamePasswordAuthenticationToken(
      "alice", null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    Document document = new Document(1L, "Test Doc", new User("alice"));

    assertThat(evaluator.hasPermission(userAuth, document, "WRITE")).isTrue();
  }

  @Test
  void shouldDenyPermissionToNonOwner() {
    Authentication otherAuth = new UsernamePasswordAuthenticationToken(
      "bob", null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
    Document document = new Document(1L, "Test Doc", new User("alice"));

    assertThat(evaluator.hasPermission(otherAuth, document, "WRITE")).isFalse();
  }

  @Test
  void shouldGrantPermissionToAdmin() {
    Authentication adminAuth = new UsernamePasswordAuthenticationToken(
      "admin", null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));
    Document document = new Document(1L, "Test Doc", new User("alice"));

    assertThat(evaluator.hasPermission(adminAuth, document, "WRITE")).isTrue();
  }

  @Test
  void shouldDenyNullAuthentication() {
    Document document = new Document(1L, "Test Doc", new User("alice"));
    assertThat(evaluator.hasPermission(null, document, "WRITE")).isFalse();
  }

  @Test
  void shouldHandleDocumentNotFound() {
    when(documentRepository.findById(1L)).thenReturn(Optional.empty());
    Authentication adminAuth = new UsernamePasswordAuthenticationToken(
      "admin", null, List.of(new SimpleGrantedAuthority("ROLE_ADMIN")));

    assertThat(evaluator.hasPermission(adminAuth, 1L, "Document", "WRITE")).isFalse();
  }
}
```

## Common SpEL Expressions

### Authentication-Based

```java
@PreAuthorize("isAuthenticated()")
@PreAuthorize("isAnonymous()")
@PreAuthorize("isFullyAuthenticated()")   // NOT remember-me
```

### Role-Based

```java
@PreAuthorize("hasRole('ADMIN')")               // ROLE_ prefix added automatically
@PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")  // any of specified roles
@PreAuthorize("!hasRole('GUEST')")               // negation
```

### Principal-Based

> Custom principal properties (e.g. `id`) require `@WithUserDetails` with a custom `UserDetailsService`. **NOT** use `@WithMockUser` for `authentication.principal.id` — `@WithMockUser` creates a simple `User` without custom fields.

```java
@PreAuthorize("authentication.principal.username == #username")
@PreAuthorize("authentication.principal.accountNonLocked")
@PreAuthorize("authentication.principal.id == #userId")   // requires custom UserDetailsService
```

### Permission-Based

```java
@PreAuthorize("hasPermission(#objectId, 'READ')")
@PreAuthorize("hasPermission(#objectId, 'Document', 'WRITE')")
@PreAuthorize("hasPermission(#docId, 'READ') and hasPermission(#docId, 'WRITE')")
```

### Complex Expressions

```java
@PreAuthorize("hasRole('ADMIN') or #userId == authentication.principal.id")
@PreAuthorize("hasRole('ADMIN') and hasPermission(#docId, 'WRITE')")
@PreAuthorize("hasRole('ADMIN') and !isBanned(#username)")            // custom method — must register bean
@PreAuthorize("(hasRole('ADMIN') or #isOwner) and !isLocked(#userId)") // custom method — must register bean
```

> Custom methods in SpEL (e.g. `isBanned()`, `isLocked()`) must be registered as beans that Spring Security can resolve. **NOT** use custom SpEL methods without registration — they throw `SpelEvaluationException` at runtime.

## Testing `@PostAuthorize`

```java
@Service
public class MessageService {

  @PostAuthorize("returnObject.owner == authentication.principal.username")
  public Message getMessage(Long messageId) {
    // fetch and return message
  }
}
```

```java
@SpringBootTest
@EnableMethodSecurity
class MessageServiceSecurityTest {

  @MockitoBean private MessageRepository messageRepository;
  @Autowired private MessageService messageService;

  @Test
  @WithMockUser(username = "alice")
  void shouldAllowAccessToOwnMessage() {
    when(messageRepository.findById(1L)).thenReturn(Optional.of(new Message(1L, "alice")));
    assertThatCode(() -> messageService.getMessage(1L))
      .doesNotThrowAnyException();
  }

  @Test
  @WithMockUser(username = "alice")
  void shouldDenyAccessToOtherMessage() {
    when(messageRepository.findById(2L)).thenReturn(Optional.of(new Message(2L, "bob")));
    assertThatThrownBy(() -> messageService.getMessage(2L))
      .isInstanceOf(AccessDeniedException.class);
  }
}
```

## Testing `@PostFilter` and `@PreFilter`

```java
@Service
public class DataService {

  @PreFilter("hasPermission(filterObject, 'READ')")
  public void processData(List<Data> items) {
    // items filtered before method execution
  }

  @PostFilter("hasPermission(filterObject, 'READ')")
  public List<Data> getAllData() {
    return repository.findAll();
  }
}
```

```java
@SpringBootTest
@EnableMethodSecurity
class DataServiceSecurityTest {

  @MockitoBean private DataRepository dataRepository;
  @Autowired private DataService dataService;

  @Test
  @WithMockUser(roles = "ADMIN")
  void shouldFilterDataBasedOnPermissions() {
    Data data1 = new Data(1L, "public");
    Data data2 = new Data(2L, "private");
    Data data3 = new Data(3L, "public");

    assertThatCode(() -> dataService.processData(List.of(data1, data2, data3)))
      .doesNotThrowAnyException();
  }
}
```
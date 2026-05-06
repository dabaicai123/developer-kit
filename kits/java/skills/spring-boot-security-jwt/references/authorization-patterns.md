# Authorization Patterns Reference

## Anti-patterns

- NOT use `@EnableGlobalMethodSecurity` — removed in 6.4+; use `@EnableMethodSecurity`
- NOT add `@EnableWebSecurity` — auto-configured when `SecurityFilterChain` bean exists
- NOT use `hasRole('ADMIN')` with bare authority `"ADMIN"` — `hasRole` adds `ROLE_` prefix; use `hasAuthority('ADMIN')` for non-prefixed authorities
- NOT use `@PostAuthorize` as default — method body executes before check; prefer `@PreAuthorize`
- NOT use `allowedOrigins("*")` with `allowCredentials(true)` — rejected by Spring Security

## @EnableMethodSecurity

Spring Security 6.x replaces the deprecated `@EnableGlobalMethodSecurity` with `@EnableMethodSecurity`. The new annotation:

- Enables `@PreAuthorize`, `@PostAuthorize`, `@PreFilter`, `@PostFilter` by default
- Uses a new `AuthorizationManager`-based infrastructure (faster than the old AOP interceptor)
- Supports custom SpEL function registration via `@EnableMethodSecurity(prePostEnabled = true)`

```java
@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {
    private final JwtAuthenticationFilter jwtAuthFilter;
    private final AuthenticationProvider authenticationProvider;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**", "/swagger-ui/**", "/v3/api-docs/**").permitAll()
                .anyRequest().authenticated()
            )
            .authenticationProvider(authenticationProvider)
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}
```

> NOT use `@EnableGlobalMethodSecurity` — deprecated since 6.0, removed in 6.4+. Use `@EnableMethodSecurity`.

## @PreAuthorize with JWT Claims

### Role-Based Authorization

```java
@RestController
@RequestMapping("/api/admin")
public class AdminController {

    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping("/dashboard")
    public Result<DashboardData> getDashboard() {
        // Only users with ROLE_ADMIN can access
    }

    @PreAuthorize("hasAnyRole('ADMIN', 'MANAGER')")
    @GetMapping("/reports")
    public Result<List<Report>> getReports() {
        // Users with ROLE_ADMIN or ROLE_MANAGER
    }
}
```

> `hasRole('ADMIN')` adds `ROLE_` prefix automatically. If your JWT stores `["ADMIN"]` without prefix, use `hasAuthority('ADMIN')` instead.

### Authority-Based Authorization

```java
@RestController
@RequestMapping("/api/documents")
public class DocumentController {

    @PreAuthorize("hasAuthority('document:read')")
    @GetMapping("/{id}")
    public Result<Document> getDocument(@PathVariable Long id) {
        // Users with the 'document:read' authority
    }

    @PreAuthorize("hasAuthority('document:write')")
    @PostMapping
    public Result<Document> createDocument(@RequestBody DocumentRequest request) {
        // Users with the 'document:write' authority
    }

    @PreAuthorize("hasAnyAuthority('document:read', 'document:write')")
    @GetMapping("/list")
    public Result<List<Document>> listDocuments() {
        // Users with either authority
    }
}
```

### Claim-Based Authorization (Custom SpEL Functions)

JWT claims beyond roles/authorities (e.g., `tenantId`, `department`) require custom SpEL functions registered via `MethodSecurityExpressionHandler`:

```java
@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class MethodSecurityConfig {

    private final JwtClaimAccessor jwtClaimAccessor;

    @Bean
    public MethodSecurityExpressionHandler methodSecurityExpressionHandler() {
        DefaultMethodSecurityExpressionHandler handler = new DefaultMethodSecurityExpressionHandler();
        handler.setPermissionEvaluator(new CustomPermissionEvaluator());
        // Register custom SpEL root object with JWT claim accessors
        handler.setExpressionRootObjectProvider(() ->
            new JwtSecurityExpressionRoot(jwtClaimAccessor));
        return handler;
    }
}
```

```java
public class JwtSecurityExpressionRoot extends SecurityExpressionRoot {

    private final JwtClaimAccessor claimAccessor;

    public JwtSecurityExpressionRoot(Authentication authentication, JwtClaimAccessor claimAccessor) {
        super(authentication);
        this.claimAccessor = claimAccessor;
    }

    /**
     * SpEL function: hasTenant('X')
     * Checks if the current user's JWT contains the specified tenantId.
     */
    public boolean hasTenant(String tenantId) {
        String userTenant = claimAccessor.getCurrentTenantId();
        return userTenant != null && userTenant.equals(tenantId);
    }

    /**
     * SpEL function: hasClaim('key', 'value')
     * Checks if the current user's JWT contains a specific claim value.
     */
    public boolean hasClaim(String claimKey, String expectedValue) {
        Object claimValue = claimAccessor.getClaim(claimKey);
        return claimValue != null && claimValue.toString().equals(expectedValue);
    }

    /**
     * SpEL function: isResourceOwner(#resourceOwnerId)
     * Checks if the current user is the owner of the requested resource.
     */
    public boolean isResourceOwner(Long resourceOwnerId) {
        Long userId = claimAccessor.getCurrentUserId();
        return userId != null && userId.equals(resourceOwnerId);
    }
}
```

### Using Custom SpEL Functions

```java
@RestController
@RequestMapping("/api/tenants/{tenantId}/users")
public class TenantUserController {

    @PreAuthorize("hasTenant(#tenantId)")
    @GetMapping
    public Result<List<User>> listUsers(@PathVariable String tenantId) {
        // Only users belonging to this tenant
    }

    @PreAuthorize("hasTenant(#tenantId) and hasAuthority('user:read')")
    @GetMapping("/{userId}")
    public Result<User> getUser(@PathVariable String tenantId, @PathVariable Long userId) {
        // Tenant member with user:read authority
    }
}

@RestController
@RequestMapping("/api/documents")
public class DocumentController {

    @PreAuthorize("isResourceOwner(#ownerId) or hasRole('ADMIN')")
    @GetMapping("/{id}")
    public Result<Document> getDocument(@PathVariable Long id, @RequestParam Long ownerId) {
        // Owner or admin can access
    }
}
```

### JwtClaimAccessor Utility

```java
@Component
public class JwtClaimAccessor {

    public Object getClaim(String claimKey) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) return null;
        if (auth.getCredentials() instanceof Claims claims) {
            return claims.get(claimKey);
        }
        if (auth.getDetails() instanceof Map<?, ?> details) {
            return details.get(claimKey);
        }
        return null;
    }

    public String getCurrentTenantId() {
        return (String) getClaim("tenantId");
    }

    public Long getCurrentUserId() {
        Object userId = getClaim("userId");
        if (userId instanceof Integer) return ((Integer) userId).longValue();
        if (userId instanceof Long) return (Long) userId;
        return null;
    }

    public String getCurrentUsername() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth != null ? auth.getName() : null;
    }
}
```

## Role-Based vs Claim-Based Authorization

| Approach | Pattern | Granularity | Use Case | Example |
|----------|---------|-------------|----------|---------|
| Role-based | `hasRole('ADMIN')` | Coarse | Simple apps, few user types | Admin vs User |
| Authority-based | `hasAuthority('doc:write')` | Medium | Feature-level permissions | CRUD per resource |
| Claim-based | `hasTenant('X')` | Fine | Multi-tenant, contextual | Tenant isolation, department |
| Combined | `hasRole('ADMIN') and hasTenant(#t)` | Very fine | Complex business rules | Admin in specific tenant |

### Authority Naming Convention

Use a `resource:action` pattern for fine-grained permissions:

```
document:read    document:write    document:delete
user:read        user:create       user:update       user:delete
order:read       order:approve     order:cancel
report:view      report:export     report:admin
```

### JWT Claim Structure for Authorization

```java
// During token generation, store authorities in JWT
.claim("authorities", userDetails.getAuthorities().stream()
    .map(GrantedAuthority::getAuthority).toList())
.claim("tenantId", user.getTenantId())
.claim("userId", user.getId())

// During JWT filter authentication, reconstruct GrantedAuthority list
List<SimpleGrantedAuthority> authorities = claims.get("authorities", List.class)
    .stream()
    .map(auth -> new SimpleGrantedAuthority((String) auth))
    .toList();
```

## @WithMockUser Testing

### Basic Role Testing

```java
@WebMvcTest(OrderController.class)
@Import(SecurityConfig.class)
class OrderControllerSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    @WithMockUser(roles = "ADMIN")
    void shouldAllowAdminToAccessAllOrders() throws Exception {
        mockMvc.perform(get("/api/orders"))
            .andExpect(status().isOk());
    }

    @Test
    @WithMockUser(roles = "USER")
    void shouldDenyUserFromAdminEndpoint() throws Exception {
        mockMvc.perform(get("/api/admin/orders"))
            .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "alice", roles = {"USER", "MANAGER"})
    void shouldAllowManagerToApproveOrders() throws Exception {
        mockMvc.perform(post("/api/orders/{id}/approve", 1L))
            .andExpect(status().isOk());
    }

    @Test
    void shouldDenyUnauthenticatedAccess() throws Exception {
        mockMvc.perform(get("/api/orders"))
            .andExpect(status().isUnauthorized());
    }
}
```

### Custom Authority Testing

```java
@Test
@WithMockUser(authorities = {"document:read", "document:write"})
void shouldAllowUserWithDocumentWriteAuthority() throws Exception {
    mockMvc.perform(post("/api/documents")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\": \"Test\"}"))
        .andExpect(status().isOk());
}

@Test
@WithMockUser(authorities = {"document:read"})
void shouldDenyUserWithOnlyReadAuthority() throws Exception {
    mockMvc.perform(post("/api/documents")
            .contentType(MediaType.APPLICATION_JSON)
            .content("{\"title\": \"Test\"}"))
        .andExpect(status().isForbidden());
}
```

### @WithUserDetails for Custom UserDetails

When your application uses a custom `UserDetails` implementation, use `@WithUserDetails` to load a real user from the database:

```java
@Test
@WithUserDetails("admin@example.com")
void shouldAllowRealAdminUser() throws Exception {
    mockMvc.perform(get("/api/admin/dashboard"))
        .andExpect(status().isOk());
}

@Test
@WithUserDetails("user@example.com")
void shouldDenyRegularUserFromAdmin() throws Exception {
    mockMvc.perform(get("/api/admin/dashboard"))
        .andExpect(status().isForbidden());
}
```

### Custom @WithMockUser for JWT Claims

For testing claim-based authorization, create a custom security annotation:

```java
@Retention(RetentionPolicy.RUNTIME)
@WithSecurityContext(factory = WithJwtUserSecurityContextFactory.class)
public @interface WithJwtUser {
    String username() default "testuser";
    String[] authorities() default {"ROLE_USER"};
    Long userId() default 1L;
    String tenantId() default "default";
}

public class WithJwtUserSecurityContextFactory
    implements SecurityContextFactory<WithJwtUser> {

    @Override
    public SecurityContext createSecurityContext(WithJwtUser annotation) {
        List<SimpleGrantedAuthority> authorities = Arrays.stream(annotation.authorities())
            .map(SimpleGrantedAuthority::new)
            .toList();

        // Create authentication with JWT claims in details
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", annotation.userId());
        claims.put("tenantId", annotation.tenantId());

        UsernamePasswordAuthenticationToken auth =
            new UsernamePasswordAuthenticationToken(
                annotation.username(), null, authorities);
        auth.setDetails(claims);

        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(auth);
        return context;
    }
}
```

```java
@Test
@WithJwtUser(username = "alice", authorities = {"ROLE_ADMIN"}, userId = 1L, tenantId = "tenant-A")
void shouldAllowAdminInCorrectTenant() throws Exception {
    mockMvc.perform(get("/api/tenants/tenant-A/users"))
        .andExpect(status().isOk());
}

@Test
@WithJwtUser(username = "bob", authorities = {"ROLE_USER"}, userId = 2L, tenantId = "tenant-B")
void shouldDenyUserFromDifferentTenant() throws Exception {
    mockMvc.perform(get("/api/tenants/tenant-A/users"))
        .andExpect(status().isForbidden());
}
```

## SecurityFilterChain with JWT Filter

### Complete SecurityFilterChain Configuration

```java
@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthFilter;
    private final AuthenticationProvider authenticationProvider;
    private final AccessTokenBlacklist blacklist;

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(new JwtAuthenticationEntryPoint())
                .accessDeniedHandler(new JwtAccessDeniedHandler())
            )
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/manager/**").hasAnyRole("ADMIN", "MANAGER")
                .anyRequest().authenticated()
            )
            .authenticationProvider(authenticationProvider)
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .logout(l -> l
                .logoutUrl("/api/auth/logout")
                .addLogoutHandler(new JwtLogoutHandler(blacklist))
                .logoutSuccessHandler(new HttpStatusReturningLogoutSuccessHandler(HttpStatus.OK))
            )

            .build();
    }
}
```

### Custom Exception Handlers

```java
@Component
public class JwtAuthenticationEntryPoint implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
            AuthenticationException authException) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write("""
            {
              "code": 401,
              "message": "Unauthorized: %s",
              "data": null
            }
            """.formatted(authException.getMessage()));
    }
}

@Component
public class JwtAccessDeniedHandler implements AccessDeniedHandler {

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
            AccessDeniedException accessDeniedException) throws IOException {
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write("""
            {
              "code": 403,
              "message": "Forbidden: %s",
              "data": null
            }
            """.formatted(accessDeniedException.getMessage()));
    }
}
```

### Authentication Provider Configuration

```java
@Bean
public AuthenticationProvider authenticationProvider(UserDetailsService userDetailsService,
        PasswordEncoder passwordEncoder) {
    DaoAuthenticationProvider provider = new DaoAuthenticationProvider();
    provider.setUserDetailsService(userDetailsService);
    provider.setPasswordEncoder(passwordEncoder);
    return provider;
}

@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);    // Strength 12 for production
}
```

## Endpoint-Level Security

### Path-Based Authorization Rules

```java
.authorizeHttpRequests(auth -> auth
    .requestMatchers("/", "/index.html").permitAll()
    .requestMatchers("/api/auth/login", "/api/auth/register", "/api/auth/refresh").permitAll()
    .requestMatchers("/swagger-ui/**", "/v3/api-docs/**").permitAll()
    .requestMatchers("/actuator/health", "/actuator/info").permitAll()
    .requestMatchers("/public/**").permitAll()
    .requestMatchers("/api/admin/**").hasRole("ADMIN")
    .requestMatchers("/api/manager/**").hasAnyRole("ADMIN", "MANAGER")
    .requestMatchers(HttpMethod.GET, "/api/reports/**").hasAnyRole("ADMIN", "ANALYST")
    .requestMatchers(HttpMethod.POST, "/api/reports/**").hasRole("ADMIN")
    .requestMatchers("/api/documents/**").hasAuthority("document:access")
    .anyRequest().authenticated()
)
```

### Method-Level Authorization (More Granular)

Combine URL rules with method annotations for layered security:

```java
// URL rule: /api/admin/** requires ADMIN role
// Method annotation: additional fine-grained checks

@RestController
@RequestMapping("/api/admin/users")
@PreAuthorize("hasRole('ADMIN')")
public class AdminUserController {

    @GetMapping
    @PreAuthorize("hasAuthority('user:read')")
    public Result<List<User>> listUsers() {}

    @PostMapping
    @PreAuthorize("hasAuthority('user:create')")
    public Result<User> createUser(@RequestBody CreateUserRequest request) {}

    @DeleteMapping("/{userId}")
    @PreAuthorize("hasAuthority('user:delete') and isResourceOwner(#userId) or hasRole('SUPER_ADMIN')")
    public Result<Void> deleteUser(@PathVariable Long userId) {}
}
```

## CORS Configuration

### CORS for SPA/Mobile Backends

JWT-based APIs typically serve SPA frontends or mobile apps on different origins. Configure CORS explicitly:

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of(
        "https://app.example.com",
        "https://admin.example.com"
    ));
    config.setAllowedOriginPatterns(List.of("https://*.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));
    config.setAllowedHeaders(List.of(
        "Authorization", "Content-Type", "X-Requested-With", "Accept", "Origin", "Cache-Control"
    ));
    config.setExposedHeaders(List.of("Authorization", "X-Total-Count"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

### Integration with SecurityFilterChain

```java
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http
        .cors(Customizer.withDefaults())
        .csrf(AbstractHttpConfigurer::disable)
        // ...
        .build();
}
```

### Development CORS (Not for Production)

```java
@Bean
@Profile("dev")
public CorsConfigurationSource devCorsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("http://localhost:3000", "http://localhost:5173"));
    config.setAllowedMethods(List.of("*"));
    config.setAllowedHeaders(List.of("*"));
    config.setAllowCredentials(true);

    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

> NOT use `allowedOrigins("*")` with `allowCredentials(true)` — Spring Security rejects this. Use specific origins or `allowedOriginPatterns`.

## CSRF Configuration

For stateless JWT APIs, CSRF is irrelevant (tokens sent via Authorization header, not cookies):

```java
.csrf(AbstractHttpConfigurer::disable)
```

Enable CSRF only when JWTs are sent via cookies:

```java
.csrf(csrf -> csrf
    .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
    .csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler())
)
```

> `CookieCsrfTokenRepository.withHttpOnlyFalse()` lets the SPA read the CSRF token from a cookie. Required for cookie-based JWT auth.

## Custom PermissionEvaluator

### Implementation

```java
@Component
@RequiredArgsConstructor
public class CustomPermissionEvaluator implements PermissionEvaluator {

    private final DocumentRepository documentRepository;

    @Override
    public boolean hasPermission(Authentication authentication,
            Object targetDomainObject, Object permission) {
        if (authentication == null || targetDomainObject == null) return false;
        String username = authentication.getName();
        if (targetDomainObject instanceof Document doc) {
            return doc.getOwner().getUsername().equals(username) || hasAdminAuthority(authentication);
        }
        return false;
    }

    @Override
    public boolean hasPermission(Authentication authentication,
            Serializable targetId, String targetType, Object permission) {
        if (authentication == null || targetId == null) return false;
        String username = authentication.getName();
        if ("Document".equals(targetType)) {
            Document doc = documentRepository.findById((Long) targetId).orElse(null);
            if (doc == null) return false;
            return doc.getOwner().getUsername().equals(username) || hasAdminAuthority(authentication);
        }
        return false;
    }

    private boolean hasAdminAuthority(Authentication auth) {
        return auth.getAuthorities().stream()
            .anyMatch(a -> a.getAuthority().equals("ROLE_ADMIN"));
    }
}
```

### Registration

```java
@Configuration
@EnableMethodSecurity
@RequiredArgsConstructor
public class MethodSecurityConfig {

    private final CustomPermissionEvaluator permissionEvaluator;

    @Bean
    public MethodSecurityExpressionHandler methodSecurityExpressionHandler() {
        DefaultMethodSecurityExpressionHandler handler = new DefaultMethodSecurityExpressionHandler();
        handler.setPermissionEvaluator(permissionEvaluator);
        return handler;
    }
}
```

### Usage with @PreAuthorize

```java
@PreAuthorize("hasPermission(#docId, 'Document', 'READ')")
@GetMapping("/{docId}")
public Result<Document> readDocument(@PathVariable Long docId) {}

@PreAuthorize("hasPermission(#docId, 'Document', 'WRITE')")
@PutMapping("/{docId}")
public Result<Document> updateDocument(@PathVariable Long docId, @RequestBody DocumentUpdate request) {}

@PreAuthorize("hasPermission(#docId, 'Document', 'DELETE')")
@DeleteMapping("/{docId}")
public Result<Void> deleteDocument(@PathVariable Long docId) {}
```

## @PostAuthorize and @PostFilter

### @PostAuthorize -- Filter After Execution

```java
@Service
public class DocumentService {

    @PostAuthorize("returnObject.owner.username == authentication.name or hasRole('ADMIN')")
    public Document getDocument(Long id) {
        return documentRepository.findById(id).orElseThrow();
    }
}
```

> Prefer `@PreAuthorize` over `@PostAuthorize`. The method body executes before `@PostAuthorize` checks, which can leak data via side effects (caching, logging).

### @PostFilter -- Filter Collections After Execution

```java
@Service
public class DocumentService {

    @PostFilter("filterObject.owner.username == authentication.name or hasRole('ADMIN')")
    public List<Document> listDocuments() {
        return documentRepository.findAll();
    }
}
```

> `@PostFilter` removes non-matching elements from the returned collection. `filterObject` represents each element.

### @PreFilter -- Filter Input Collections Before Execution

```java
@Service
public class DocumentService {

    @PreFilter("filterObject.owner.username == authentication.name or hasRole('ADMIN')")
    public void batchUpdate(List<Document> documents) {
        documentRepository.saveAll(documents);
    }
}
```

> `@PreFilter` removes non-matching elements from the input collection before execution. `filterObject` represents each input element.

## SpEL Expression Reference

### Built-in Security Expressions

| Expression | Description | Example |
|-----------|-------------|---------|
| `hasRole('X')` | Has role ROLE_X (prefix added) | `hasRole('ADMIN')` |
| `hasAnyRole('X','Y')` | Has any of the roles | `hasAnyRole('ADMIN','MANAGER')` |
| `hasAuthority('X')` | Has authority X (no prefix) | `hasAuthority('doc:write')` |
| `hasAnyAuthority('X','Y')` | Has any of the authorities | `hasAnyAuthority('doc:read','doc:write')` |
| `isAuthenticated()` | Is authenticated (not anonymous) | `isAuthenticated()` |
| `isAnonymous()` | Is anonymous | `isAnonymous()` |
| `isFullyAuthenticated()` | Is authenticated (not remember-me) | `isFullyAuthenticated()` |
| `isRememberMe()` | Is remember-me authenticated | `isRememberMe()` |
| `permitAll` | Allow all access | `permitAll` |
| `denyAll` | Deny all access | `denyAll` |
| `authentication` | Access Authentication object | `authentication.name` |
| `principal` | Access principal object | `principal.username` |

### Combined Expressions

```java
// AND: both conditions must be true
@PreAuthorize("hasRole('ADMIN') and hasAuthority('user:delete')")

// OR: either condition can be true
@PreAuthorize("hasRole('ADMIN') or isResourceOwner(#userId)")

// NOT: negation
@PreAuthorize("!hasRole('GUEST')")

// Complex: parentheses for grouping
@PreAuthorize("(hasRole('ADMIN') or isResourceOwner(#userId)) and hasTenant(#tenantId)")

// Method parameter references
@PreAuthorize("#username == authentication.name")
public UserProfile getProfile(String username) {}

// Return object references (PostAuthorize only)
@PostAuthorize("returnObject.owner == authentication.name")
```

## JWT + Spring Security Testing Checklist

| Test Scenario | Annotation | Expected Result |
|--------------|-----------|-----------------|
| Unauthenticated access | none | 401 Unauthorized |
| Valid user, wrong role | `@WithMockUser(roles = "USER")` | 403 Forbidden |
| Valid user, correct role | `@WithMockUser(roles = "ADMIN")` | 200 OK |
| Valid user, missing authority | `@WithMockUser(authorities = {"doc:read"})` | 403 Forbidden |
| Valid user, correct authority | `@WithMockUser(authorities = {"doc:write"})` | 200 OK |
| Owner accessing own resource | `@WithMockUser(username = "alice")` | 200 OK |
| Non-owner accessing others resource | `@WithMockUser(username = "bob")` | 403 Forbidden |
| Token blacklisted | Custom test setup | 401 Unauthorized |
| Expired token | Custom JwtService mock | 401 Unauthorized |

## References

- [Spring Security 6.x Method Security](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html)
- [Spring Security 6.x Authorization](https://docs.spring.io/spring-security/reference/servlet/authorization/index.html)
- [Spring Security Test Reference](https://docs.spring.io/spring-security/reference/servlet/test.html)
- [SpEL Reference Documentation](https://docs.spring.io/spring-framework/reference/core/expressions.html)
- [JJWT 0.12.x Documentation](https://github.com/jwtk/jjwt)
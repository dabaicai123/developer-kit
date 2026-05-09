---
name: spring-boot-security-jwt
description: "JWT authentication and authorization for Spring Boot 3.5.x with JJWT, Bearer/cookie authentication, database/OAuth2 integration, and RBAC/permission-based access control using Spring Security 6.x. Use when implementing JWT-based authentication or authorization in Spring Boot applications."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot JWT Security

## When to use this skill

- Implementing JWT authentication / securing REST APIs with tokens
- Spring Security 6.x configuration / SecurityFilterChain setup
- Role-based access control (RBAC) / `@PreAuthorize`
- Refresh token rotation / token revocation
- Stateless authentication for SPA or mobile backends

## Quick Reference

### Dependencies

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.13.0</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.13.0</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId>
    <version>0.13.0</version>
    <scope>runtime</scope>
</dependency>
```

### Key Configuration

```yaml
jwt:
  secret: ${JWT_SECRET}
  access-token-expiration: 900000    # 15 min
  refresh-token-expiration: 604800000 # 7 days
  issuer: my-app
```

## Instructions

### JwtService

```java
@Service
public class JwtService {
    @Value("${jwt.secret}") private String secret;
    @Value("${jwt.access-token-expiration}") private long accessExpiration;
    @Value("${jwt.issuer}") private String issuer;

    public String generateAccessToken(UserDetails userDetails) {
        return Jwts.builder()
            .subject(userDetails.getUsername())
            .issuer(issuer)
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + accessExpiration))
            .claim("authorities", userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority).toList())
            .signWith(getSigningKey())
            .compact();
    }

    public boolean isTokenValid(String token, UserDetails userDetails) {
        try {
            String username = extractUsername(token);
            return username.equals(userDetails.getUsername()) && !isTokenExpired(token);
        } catch (JwtException e) {
            return false;
        }
    }

    private SecretKey getSigningKey() {
        return Keys.hmacShaKeyFor(Decoders.BASE64.decode(secret));
    }
}
```

### JWT Filter

```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
            HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            chain.doFilter(request, response);
            return;
        }
        String jwt = authHeader.substring(7);
        String username = jwtService.extractUsername(jwt);
        if (username != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            UserDetails userDetails = userDetailsService.loadUserByUsername(username);
            if (jwtService.isTokenValid(jwt, userDetails)) {
                var authToken = new UsernamePasswordAuthenticationToken(
                    userDetails, null, userDetails.getAuthorities());
                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                SecurityContextHolder.getContext().setAuthentication(authToken);
            }
        }
        chain.doFilter(request, response);
    }
}
```

### SecurityFilterChain

```java
@Configuration
@EnableWebSecurity
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

### Auth Endpoints

```java
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
    private final AuthService authService;

    @PostMapping("/authenticate")
    public Result<AuthResponse> authenticate(@RequestBody LoginRequest request) {
        return Result.success(authService.authenticate(request));
    }

    @PostMapping("/refresh")
    public Result<AuthResponse> refresh(@RequestBody RefreshRequest request) {
        return Result.success(authService.refreshToken(request.refreshToken()));
    }
}
```

## Best Practices

- Use minimum 256-bit secret keys — load from environment variables, never hardcode
- Set short access token lifetimes (15 min); use refresh tokens for longer sessions
- Implement token rotation: revoke old refresh token when issuing a new one
- Do not store sensitive data (passwords, PII) in JWT claims

## References

| File | Content |
|------|---------|
| [references/configuration.md](references/configuration.md) | Full SecurityFilterChain, CORS, CSRF config |
| [references/token-management.md](references/token-management.md) | Refresh token Data Object, rotation, Redis blacklisting |
| [references/authorization-patterns.md](references/authorization-patterns.md) | RBAC/ABAC, PermissionEvaluator, SpEL |

## Related Skills

- `spring-boot-security` — Spring Security configuration, CORS, CSRF, method security
- `unit-test-security-authorization` — testing @PreAuthorize, @Secured, RBAC
- `spring-boot-actuator` — securing management endpoints

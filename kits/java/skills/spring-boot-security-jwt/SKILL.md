---
name: spring-boot-security-jwt
description: "JWT auth with JJWT 0.13.0 and Spring Security 6.x. Bearer/cookie authentication, refresh token rotation, RBAC/permission-based access control."
version: "1.0.0"
type: skill
---

# Spring Boot JWT Security

## When to use

- JWT authentication / token-based REST API security
- SecurityFilterChain / Spring Security 6.x config
- RBAC / `@PreAuthorize` / permission-based access control
- Refresh token rotation / token revocation

## Anti-patterns

- NOT use `@Value` for JWT config — inject `JwtProperties` record via `@ConfigurationProperties`
- NOT use `@EnableGlobalMethodSecurity` — removed in 6.4+; use `@EnableMethodSecurity`
- NOT add `@EnableWebSecurity` — auto-configured when `SecurityFilterChain` bean exists
- NOT hardcode secrets — reference `${JWT_SECRET}` env var or secret manager
- NOT store passwords or PII in JWT claims — tokens are decodable without the secret
- NOT use `SignatureAlgorithm` enum — deprecated in JJWT 0.12+; use `Jwts.SIG.HS256` etc.

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

### Configuration Properties

```yaml
jwt:
  secret: ${JWT_SECRET}
  access-token-expiration: 900000    # 15 min
  refresh-token-expiration: 604800000 # 7 days
  issuer: my-app
```

```java
@ConfigurationProperties(prefix = "jwt")
@Validated
public record JwtProperties(
    @NotBlank String secret,
    @Positive long accessTokenExpiration,
    @Positive long refreshTokenExpiration,
    @NotBlank String issuer
) {}
```

### JwtService

```java
@Service
@RequiredArgsConstructor
public class JwtService {
    private final JwtProperties jwtProperties;
    private final Key signingKey;

    public String generateAccessToken(UserDetails userDetails) {
        return Jwts.builder()
            .subject(userDetails.getUsername())
            .issuer(jwtProperties.issuer())
            .issuedAt(new Date())
            .expiration(new Date(System.currentTimeMillis() + jwtProperties.accessTokenExpiration()))
            .claim("authorities", userDetails.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority).toList())
            .signWith(signingKey)
            .compact();
    }

    public boolean isTokenValid(String token, UserDetails userDetails) {
        try {
            Claims claims = Jwts.parser()
                .verifyWith((SecretKey) signingKey)
                .requireIssuer(jwtProperties.issuer())
                .clockSkewSeconds(30)
                .build()
                .parseSignedClaims(token)
                .getPayload();
            return claims.getSubject().equals(userDetails.getUsername());
        } catch (JwtException e) {
            return false;
        }
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

For base SecurityFilterChain config (CSRF, session, CORS), see `spring-boot-security` skill. JWT-specific registration:

```java
.addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
```

### Auth Endpoints

```java
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
    private final AuthService authService;

    @PostMapping("/authenticate")
    public Result<AuthResponse> authenticate(@RequestBody LoginCmd request) {
        return Result.success(authService.authenticate(request));
    }

    @PostMapping("/refresh")
    public Result<AuthResponse> refresh(@RequestBody RefreshRequest request) {
        return Result.success(authService.refreshToken(request.refreshToken()));
    }
}
```

## Best Practices

- 256-bit minimum secret keys from env vars, never hardcoded
- 15 min access token; 7 day refresh token with rotation
- Rotate refresh tokens: revoke old on issue of new; detect reuse — revoke all user tokens
- Validate `iss` and `aud` claims in production

## References

| File | Content |
|------|---------|
| [references/configuration.md](references/configuration.md) | SecurityFilterChain, CORS, CSRF, key config, algorithm selection |
| [references/token-management.md](references/token-management.md) | Refresh token entity, rotation, Redis blacklisting, cleanup |
| [references/authorization-patterns.md](references/authorization-patterns.md) | RBAC/ABAC, PermissionEvaluator, SpEL, testing |

## Related Skills

- `spring-boot-security`
- `unit-test-security-authorization`
- `spring-boot-actuator`
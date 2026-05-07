# Token Management Reference

## Token Lifecycle

The complete JWT token lifecycle consists of four phases:

1. **Create**: Generate access token + refresh token on successful authentication
2. **Validate**: Verify signature, claims, expiration, and revocation status on every request
3. **Refresh**: Issue a new access token (and optionally a new refresh token) using a valid refresh token
4. **Revoke**: Invalidate a token before its natural expiration via blacklisting or deletion

```
Login Request
    |
    v
[Create] ──> Access Token (short-lived, e.g. 15 min)
          ──> Refresh Token (long-lived, e.g. 7 days)
    |
    v
API Request (Access Token in header)
    |
    v
[Validate] ──> Signature OK? Claims OK? Not expired? Not revoked?
    |                                    |
    | Valid                              | Invalid / Expired
    v                                    v
  Process request                     Return 401
                                        |
                                        v
                                  Client sends Refresh Token
                                        |
                                        v
                                  [Refresh] ──> New Access Token
                                             ──> New Refresh Token (rotated)
                                             ──> Old Refresh Token revoked
                                        |
                                        v
                                  Client uses new Access Token
                                        |
                                        v
                                  Logout / Admin revoke
                                        |
                                        v
                                  [Revoke] ──> Blacklist Access Token
                                             ──> Delete Refresh Token
```

## Claim Structure

### Standard JWT Claims (RFC 7519)

| Claim | Key | Type | Required | Description |
|-------|-----|------|----------|-------------|
| Subject | `sub` | String | Yes | User identifier (username or user ID) |
| Issuer | `iss` | String | Yes | Token issuer (application name) |
| Issued At | `iat` | Date | Yes | Token creation timestamp |
| Expiration | `exp` | Date | Yes | Token expiration timestamp |
| JWT ID | `jti` | String | Recommended | Unique token identifier for revocation tracking |
| Audience | `aud` | String/List | Recommended | Intended recipient(s) of the token |
| Not Before | `nbf` | Date | Optional | Token is not valid before this timestamp |

### Custom Claims for Authorization

```java
public String generateAccessToken(UserDetails userDetails, Long userId) {
    return Jwts.builder()
        .subject(userDetails.getUsername())                 // sub: username
        .issuer(jwtProperties.issuer())                    // iss: my-app
        .audience().add(jwtProperties.audience()).and()    // aud: my-app-api
        .id(UUID.randomUUID().toString())                  // jti: unique ID for revocation
        .issuedAt(new Date())                              // iat: now
        .expiration(new Date(System.currentTimeMillis() + jwtProperties.accessTokenExpiration())) // exp
        .claim("userId", userId)                           // custom: user PK
        .claim("authorities", userDetails.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority).toList()) // custom: role/permission list
        .claim("tenantId", getCurrentTenantId())           // custom: multi-tenant
        .signWith(signingKey)
        .compact();
}
```

### Refresh Token Claims

Refresh tokens carry minimal claims to reduce exposure if leaked:

```java
public String generateRefreshToken(UserDetails userDetails, Long userId) {
    return Jwts.builder()
        .subject(userDetails.getUsername())                 // sub: username
        .issuer(jwtProperties.issuer())                    // iss: my-app
        .id(UUID.randomUUID().toString())                  // jti: unique ID
        .issuedAt(new Date())                              // iat: now
        .expiration(new Date(System.currentTimeMillis() + jwtProperties.refreshTokenExpiration())) // exp
        .claim("userId", userId)                           // minimal custom claim
        .claim("type", "refresh")                          // token type discriminator
        .signWith(signingKey)
        .compact();
}
```

> Do NOT include `authorities`, `roles`, or `tenantId` in refresh tokens. Refresh tokens are only used to obtain new access tokens; the authorization claims are re-fetched from the database during refresh.

## JTI Tracking

The `jti` (JWT ID) claim is essential for token revocation. Every token MUST have a unique `jti` to support:

- Blacklisting individual tokens
- Tracking which refresh token was used (rotation detection)
- Preventing token replay attacks

### JTI Generation Strategy

```java
// UUID-based JTI (recommended)
.id(UUID.randomUUID().toString())

// Time-based JTI with user prefix (sortable, useful for debugging)
.id(userDetails.getUsername() + "-" + System.currentTimeMillis())
```

### Storing JTI for Revocation

#### Option A: Database Storage

```java
@Entity
@Table(name = "refresh_tokens")
public class RefreshToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String jti;                    // JWT ID from the jti claim

    @Column(nullable = false)
    private String username;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Instant issuedAt;

    @Column(nullable = false)
    private Instant expiration;

    @Column(nullable = false)
    private boolean revoked;

    @Column
    private String replacedByJti;          // JTI of the token that replaced this one (rotation tracking)

    // Convenience method
    public boolean isExpired() {
        return expiration.isBefore(Instant.now());
    }

    public boolean isValid() {
        return !revoked && !isExpired();
    }
}
```

#### Option B: Redis Storage

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class RedisTokenStore {

    private final StringRedisTemplate redisTemplate;

    private static final String REFRESH_TOKEN_KEY_PREFIX = "refresh_token:";
    private static final String BLACKLIST_KEY_PREFIX = "blacklist:";
    private static final String USER_REFRESH_TOKEN_PREFIX = "user_refresh:";

    /**
     * Store refresh token JTI in Redis.
     * TTL matches the refresh token expiration for automatic cleanup.
     */
    public void storeRefreshToken(String jti, String username, long expirationMs) {
        String key = REFRESH_TOKEN_KEY_PREFIX + jti;
        String value = username;
        Duration ttl = Duration.ofMillis(expirationMs);
        redisTemplate.opsForValue().set(key, value, ttl);

        // Track the latest refresh token for this user
        String userKey = USER_REFRESH_TOKEN_PREFIX + username;
        redisTemplate.opsForValue().set(userKey, jti, ttl);
    }

    /**
     * Check if a refresh token is valid (exists and not revoked).
     */
    public boolean isRefreshTokenValid(String jti) {
        String key = REFRESH_TOKEN_KEY_PREFIX + jti;
        return Boolean.TRUE.equals(redisTemplate.hasKey(key));
    }

    /**
     * Revoke a refresh token by deleting its Redis key.
     */
    public void revokeRefreshToken(String jti) {
        redisTemplate.delete(REFRESH_TOKEN_KEY_PREFIX + jti);
    }

    /**
     * Blacklist an access token. TTL should match the access token remaining lifetime.
     */
    public void blacklistAccessToken(String jti, long remainingMs) {
        String key = BLACKLIST_KEY_PREFIX + jti;
        redisTemplate.opsForValue().set(key, "1", Duration.ofMillis(remainingMs));
    }

    /**
     * Check if an access token is blacklisted.
     */
    public boolean isAccessTokenBlacklisted(String jti) {
        String key = BLACKLIST_KEY_PREFIX + jti;
        return Boolean.TRUE.equals(redisTemplate.hasKey(key));
    }
}
```

## Refresh Token Patterns

### Pattern 1: Sliding Refresh (Simple)

The client uses the same refresh token repeatedly until it expires. Each refresh issues a new access token but keeps the same refresh token.

```
Login:   access_1 + refresh_A
Refresh: access_2 + refresh_A  (same refresh token)
Refresh: access_3 + refresh_A  (same refresh token)
...
refresh_A expires -> client must re-authenticate
```

```java
public AuthResponse refreshToken(String refreshToken) {
    // Validate refresh token
    Claims claims = parseRefreshToken(refreshToken);
    String username = claims.getSubject();
    String jti = claims.getId();

    // Check if refresh token is still valid (not revoked, not expired)
    if (!tokenStore.isRefreshTokenValid(jti)) {
        throw new TokenRevokedException("Refresh token has been revoked");
    }

    // Load user and generate NEW access token only
    UserDetails userDetails = userDetailsService.loadUserByUsername(username);
    String newAccessToken = jwtService.generateAccessToken(userDetails);

    // Return same refresh token (sliding pattern)
    return new AuthResponse(newAccessToken, refreshToken);
}
```

> **Warning**: Sliding refresh is simpler but less secure. If a refresh token is stolen, the attacker can use it indefinitely until expiration. Use rotating refresh for production.

### Pattern 2: Rotating Refresh (Recommended for Production)

Each refresh issues both a new access token AND a new refresh token. The old refresh token is immediately revoked.

```
Login:    access_1 + refresh_A
Refresh:  access_2 + refresh_B  (refresh_A revoked)
Refresh:  access_3 + refresh_C  (refresh_B revoked)
...
If refresh_A is used again (reuse detection) -> revoke entire family
```

```java
@Transactional
public AuthResponse refreshToken(String oldRefreshToken) {
    // Parse and validate old refresh token
    Claims claims = parseRefreshToken(oldRefreshToken);
    String username = claims.getSubject();
    String oldJti = claims.getId();
    Long userId = claims.get("userId", Long.class);

    // Check if old refresh token is valid
    if (!tokenStore.isRefreshTokenValid(oldJti)) {
        // Reuse detection: someone already used this refresh token
        // This means the refresh token was compromised
        // Revoke ALL refresh tokens for this user (family revocation)
        revokeAllTokensForUser(username);
        throw new TokenReuseException("Refresh token reuse detected. All tokens revoked.");
    }

    // Revoke the old refresh token
    tokenStore.revokeRefreshToken(oldJti);

    // Load user details fresh from database (re-evaluate roles/permissions)
    UserDetails userDetails = userDetailsService.loadUserByUsername(username);

    // Generate new access token
    String newAccessToken = jwtService.generateAccessToken(userDetails, userId);

    // Generate new refresh token (rotation)
    String newRefreshToken = jwtService.generateRefreshToken(userDetails, userId);
    String newJti = jwtService.extractId(newRefreshToken);

    // Store new refresh token
    tokenStore.storeRefreshToken(newJti, username, jwtProperties.refreshTokenExpiration());

    return new AuthResponse(newAccessToken, newRefreshToken);
}
```

### Reuse Detection (Security Critical)

When a previously used refresh token is presented again, it indicates a security breach: the attacker stole the refresh token and used it before the legitimate client could. The correct response is to revoke ALL tokens for that user:

```java
private void revokeAllTokensForUser(String username) {
    // Database approach: mark all refresh tokens for this user as revoked
    refreshTokenRepository.revokeAllByUsername(username);

    // Redis approach: delete all refresh token keys for this user
    String userKey = USER_REFRESH_TOKEN_PREFIX + username;
    String currentJti = redisTemplate.opsForValue().get(userKey);
    if (currentJti != null) {
        redisTemplate.delete(REFRESH_TOKEN_KEY_PREFIX + currentJti);
        redisTemplate.delete(userKey);
    }

    log.warn("SECURITY: Refresh token reuse detected for user {}. All tokens revoked.", username);
}
```

## Token Rotation Strategy

### Rotation with Family Tracking

A "token family" groups all refresh tokens that were issued in a chain from a single login. This enables:

- Detecting reuse of any token in the family (not just the most recent one)
- Revoking the entire family on compromise detection

```java
@Entity
@Table(name = "token_families")
public class TokenFamily {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String familyId;               // UUID assigned at login

    @Column(nullable = false)
    private String username;

    @Column(nullable = false)
    private boolean revoked;               // Entire family revoked on reuse detection

    @OneToMany(mappedBy = "family", cascade = CascadeType.ALL)
    private List<RefreshToken> tokens;
}
```

```java
public AuthResponse login(LoginRequest request) {
    // Authenticate user
    UserDetails userDetails = authenticate(request);

    // Create new token family
    String familyId = UUID.randomUUID().toString();
    TokenFamily family = new TokenFamily(familyId, userDetails.getUsername(), false);

    // Generate initial tokens
    String accessToken = jwtService.generateAccessToken(userDetails);
    String refreshToken = jwtService.generateRefreshToken(userDetails);

    // Store refresh token with family association
    RefreshToken storedToken = new RefreshToken(
        jwtService.extractId(refreshToken),
        userDetails.getUsername(),
        family
    );
    refreshTokenRepository.save(storedToken);

    return new AuthResponse(accessToken, refreshToken);
}
```

### Rotation Frequency

| Strategy | Rotation Frequency | Use Case |
|----------|-------------------|----------|
| Strict rotation | Every refresh (recommended) | Production, high-security apps |
| Periodic rotation | Every N refreshes or after time T | Medium-security, reduces DB writes |
| No rotation (sliding) | Never | Low-security, internal tools only |

## Revocation / Blacklisting

### Access Token Blacklisting

Access tokens are short-lived, so blacklisting is only needed for immediate logout or admin revocation. Two approaches:

#### Approach 1: Redis Blacklist (Recommended)

```java
@Component
@RequiredArgsConstructor
public class AccessTokenBlacklist {

    private final RedisTokenStore tokenStore;

    /**
     * Blacklist an access token.
     * The TTL should match the token's remaining lifetime -- no need to store after expiration.
     */
    public void blacklist(String token) {
        Claims claims = jwtService.parseClaims(token);
        String jti = claims.getId();
        long remainingMs = claims.getExpiration().getTime() - System.currentTimeMillis();

        if (remainingMs > 0) {
            tokenStore.blacklistAccessToken(jti, remainingMs);
        }
    }

    public boolean isBlacklisted(String token) {
        String jti = jwtService.extractId(token);
        return tokenStore.isAccessTokenBlacklisted(jti);
    }
}
```

#### Approach 2: Database Blacklist

```java
@Entity
@Table(name = "blacklisted_tokens", indexes = {
    @Index(name = "idx_jti", columnList = "jti"),
    @Index(name = "idx_expiration", columnList = "expiration")
})
public class BlacklistedToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private String jti;

    @Column(nullable = false)
    private String username;

    @Column(nullable = false)
    private Instant blacklistedAt;

    @Column(nullable = false)
    private Instant expiration;             // Original token expiration for cleanup

    @Column(length = 50)
    private String reason;                  // "logout", "admin_revoke", "reuse_detection"
}
```

### Integration with JWT Filter

The authentication filter MUST check the blacklist before accepting a token:

```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;
    private final AccessTokenBlacklist blacklist;

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

        // Check blacklist FIRST
        if (blacklist.isBlacklisted(jwt)) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.getWriter().write("Token has been revoked");
            return;
        }

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

### Logout with Blacklisting

```java
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final AccessTokenBlacklist blacklist;

    @PostMapping("/logout")
    public Result<Void> logout(@RequestHeader("Authorization") String authHeader) {
        String jwt = authHeader.substring(7);
        blacklist.blacklist(jwt);

        // Also revoke the refresh token if provided
        String refreshToken = extractRefreshTokenFromRequest();
        if (refreshToken != null) {
            authService.revokeRefreshToken(refreshToken);
        }

        return Result.success();
    }
}
```

## Cleanup Strategy

### Database Cleanup

Expired and blacklisted tokens accumulate over time. Schedule regular cleanup:

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class TokenCleanupTask {

    private final RefreshTokenRepository refreshTokenRepository;
    private final BlacklistedTokenRepository blacklistedTokenRepository;

    /**
     * Clean up expired refresh tokens every hour.
     */
    @Scheduled(fixedRate = Duration.ofHours(1).toMillis())
    public void cleanupExpiredRefreshTokens() {
        int deleted = refreshTokenRepository.deleteAllByExpirationBefore(Instant.now());
        log.info("Cleaned up {} expired refresh tokens", deleted);
    }

    /**
     * Clean up expired blacklisted tokens every 6 hours.
     * Blacklisted tokens past their original expiration are useless.
     */
    @Scheduled(fixedRate = Duration.ofHours(6).toMillis())
    public void cleanupExpiredBlacklistedTokens() {
        int deleted = blacklistedTokenRepository.deleteAllByExpirationBefore(Instant.now());
        log.info("Cleaned up {} expired blacklisted tokens", deleted);
    }
}
```

### Redis Cleanup

Redis automatically cleans up keys when their TTL expires. Ensure all stored keys have appropriate TTLs:

- **Refresh token keys**: TTL = `refreshTokenExpiration` (e.g., 7 days)
- **Blacklisted access token keys**: TTL = remaining access token lifetime (auto-cleanup after expiration)
- **User refresh token tracking keys**: TTL = same as the associated refresh token

> If you use Redis without TTLs, tokens will persist forever and consume memory. Always set TTLs.

### Cleanup Schedule Reference

| Token Type | Storage | Cleanup Method | Frequency |
|-----------|---------|---------------|-----------|
| Expired refresh tokens | Database | `@Scheduled` DELETE query | Every 1 hour |
| Expired blacklisted tokens | Database | `@Scheduled` DELETE query | Every 6 hours |
| Revoked refresh tokens | Redis | TTL auto-expiry | Automatic |
| Blacklisted access tokens | Redis | TTL auto-expiry | Automatic |
| Active refresh tokens | Database | On rotation/revocation | Event-driven |

## Complete Token Management Service

```java
@Service
@RequiredArgsConstructor
@Slf4j
@Transactional
public class TokenManagementService {

    private final JwtService jwtService;
    private final JwtProperties jwtProperties;
    private final UserDetailsService userDetailsService;
    private final RedisTokenStore tokenStore;

    /**
     * Create tokens on login.
     */
    public AuthResponse createTokens(UserDetails userDetails, Long userId) {
        String accessToken = jwtService.generateAccessToken(userDetails, userId);
        String refreshToken = jwtService.generateRefreshToken(userDetails, userId);

        String refreshJti = jwtService.extractId(refreshToken);
        tokenStore.storeRefreshToken(refreshJti, userDetails.getUsername(),
            jwtProperties.refreshTokenExpiration());

        return new AuthResponse(accessToken, refreshToken);
    }

    /**
     * Refresh tokens using rotating refresh pattern.
     */
    public AuthResponse refreshTokens(String oldRefreshToken) {
        Claims claims = jwtService.parseRefreshToken(oldRefreshToken);
        String username = claims.getSubject();
        String oldJti = claims.getId();
        Long userId = claims.get("userId", Long.class);

        if (!tokenStore.isRefreshTokenValid(oldJti)) {
            // Reuse detected: revoke all tokens for user
            tokenStore.revokeAllTokensForUser(username);
            log.warn("Refresh token reuse detected for user: {}", username);
            throw new TokenReuseException("Refresh token reuse detected");
        }

        // Revoke old refresh token
        tokenStore.revokeRefreshToken(oldJti);

        // Generate new tokens
        UserDetails userDetails = userDetailsService.loadUserByUsername(username);
        String newAccessToken = jwtService.generateAccessToken(userDetails, userId);
        String newRefreshToken = jwtService.generateRefreshToken(userDetails, userId);

        String newJti = jwtService.extractId(newRefreshToken);
        tokenStore.storeRefreshToken(newJti, username,
            jwtProperties.refreshTokenExpiration());

        return new AuthResponse(newAccessToken, newRefreshToken);
    }

    /**
     * Revoke tokens on logout.
     */
    public void revokeTokens(String accessToken, String refreshToken) {
        // Blacklist access token
        Claims accessClaims = jwtService.parseClaims(accessToken);
        String accessJti = accessClaims.getId();
        long remainingMs = accessClaims.getExpiration().getTime() - System.currentTimeMillis();
        if (remainingMs > 0) {
            tokenStore.blacklistAccessToken(accessJti, remainingMs);
        }

        // Revoke refresh token
        if (refreshToken != null) {
            Claims refreshClaims = jwtService.parseRefreshToken(refreshToken);
            tokenStore.revokeRefreshToken(refreshClaims.getId());
        }
    }

    /**
     * Admin: revoke all tokens for a user.
     */
    public void revokeAllTokensForUser(String username) {
        tokenStore.revokeAllTokensForUser(username);
        log.info("All tokens revoked for user: {}", username);
    }
}
```

## AuthResponse DTO

```java
public record AuthResponse(
    String accessToken,
    String refreshToken,
    long accessTokenExpiration,         // Milliseconds until access token expires
    String tokenType                     // Always "Bearer"
) {
    public AuthResponse(String accessToken, String refreshToken) {
        this(accessToken, refreshToken, 900_000L, "Bearer");
    }
}
```

```java
public record LoginRequest(
    @NotBlank String username,
    @NotBlank String password
) {}

public record RefreshRequest(
    @NotBlank String refreshToken
) {}
```

## References

- [RFC 7519: JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [JJWT 0.12.x Documentation](https://github.com/jwtk/jjwt)
- [OAuth 2.0 for Browser-Based Apps (BCP)](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-browser-based-apps)
- [Spring Security 6.x Reference](https://docs.spring.io/spring-security/reference/)
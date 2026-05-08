# JWT Configuration Reference

## Secret Key Configuration

### Minimum Requirements

JWT signing keys MUST meet these requirements:

- **HMAC-SHA**: minimum 256 bits (32 bytes) for HS256, 384 bits for HS384, 512 bits for HS512
- **RSA**: minimum 2048-bit key pair; 4096-bit recommended for production
- **ECDSA**: minimum 256-bit curve (P-256); P-384 or P-521 recommended for production

> Never hardcode secrets in source code. Always load from environment variables or a config center.

### Key Generation

#### HMAC Secret Key Generation

```java
import io.jsonwebtoken.security.Keys;
import io.jsonwebtoken.security.Strength;
import javax.crypto.SecretKey;

// Generate a 256-bit key for HS256
SecretKey key = Keys.secretKeyFor(SignatureAlgorithm.HS256);

// Generate a 384-bit key for HS384
SecretKey key = Keys.secretKeyFor(SignatureAlgorithm.HS384);

// Generate a 512-bit key for HS512
SecretKey key = Keys.secretKeyFor(SignatureAlgorithm.HS512);

// Using Strength enum (JJWT 0.13.0)
SecretKey normalKey = Keys.secretKeyFor(Keys.Strength.NORMAL);   // 256-bit
SecretKey mediumKey = Keys.secretKeyFor(Keys.Strength.MEDIUM);   // 384-bit
SecretKey strongKey = Keys.secretKeyFor(Keys.Strength.HIGH);     // 512-bit
```

#### Persisting a Generated Key

```java
import io.jsonwebtoken.io.Encoders;

// After generating, encode to Base64 for storage in config
String base64Key = Encoders.BASE64.encode(key.getEncoded());
// Store base64Key in environment variable or config center
// Example: JWT_SECRET=base64Key
```

#### RSA Key Pair Generation

```java
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;

KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance("RSA");
keyPairGenerator.initialize(2048); // Use 4096 for production
KeyPair keyPair = keyPairGenerator.generateKeyPair();

RSAPublicKey publicKey = (RSAPublicKey) keyPair.getPublic();
RSAPrivateKey privateKey = (RSAPrivateKey) keyPair.getPrivate();
```

#### RSA Key Pair from PEM Files

```java
import java.security.KeyFactory;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.nio.file.Files;
import java.nio.file.Path;

// Load private key from PEM
String privateKeyPem = Files.readString(Path.of("/config/keys/private.pem"))
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll("\\s", "");
PKCS8EncodedKeySpec privateKeySpec = new PKCS8EncodedKeySpec(
    Decoders.BASE64.decode(privateKeyPem));
RSAPrivateKey privateKey = (RSAPrivateKey) KeyFactory.getInstance("RSA")
    .generatePrivate(privateKeySpec);

// Load public key from PEM
String publicKeyPem = Files.readString(Path.of("/config/keys/public.pem"))
    .replace("-----BEGIN PUBLIC KEY-----", "")
    .replace("-----END PUBLIC KEY-----", "")
    .replaceAll("\\s", "");
X509EncodedKeySpec publicKeySpec = new X509EncodedKeySpec(
    Decoders.BASE64.decode(publicKeyPem));
RSAPublicKey publicKey = (RSAPublicKey) KeyFactory.getInstance("RSA")
    .generatePublic(publicKeySpec);
```

## Algorithm Selection

| Algorithm | Key Type | Key Size | Use Case | Performance |
|-----------|----------|----------|----------|-------------|
| HS256 | HMAC Secret | 256+ bit | Monolithic apps, single signing authority | Fastest |
| HS384 | HMAC Secret | 384+ bit | Higher security requirement, single authority | Fast |
| HS512 | HMAC Secret | 512+ bit | Maximum HMAC security, single authority | Fast |
| RS256 | RSA Key Pair | 2048+ bit | Microservices, multiple consumers need public key | Moderate |
| RS384 | RSA Key Pair | 2048+ bit | Higher RSA security, multiple consumers | Moderate |
| RS512 | RSA Key Pair | 2048+ bit | Maximum RSA security, multiple consumers | Slower |
| ES256 | ECDSA Key Pair | P-256 | Microservices, high security, compact tokens | Fast |
| ES384 | ECDSA Key Pair | P-384 | Higher ECDSA security, compact tokens | Moderate |
| ES512 | ECDSA Key Pair | P-521 | Maximum ECDSA security, compact tokens | Moderate |

### Choosing the Right Algorithm

- **Single-service deployment**: Use HMAC (HS256/HS384/HS512) -- simplest, fastest, single shared secret
- **Multi-service deployment**: Use RSA (RS256) or ECDSA (ES256) -- services verify tokens using the public key without needing the signing secret
- **High-volume production**: Prefer ECDSA over RSA for smaller token size and faster verification
- **Never mix algorithms**: Choose one algorithm and use it consistently across all tokens

## Spring Boot Properties Mapping

### Configuration Properties Class

```java
@ConfigurationProperties(prefix = "jwt")
@Validated
public record JwtProperties(
    @NotBlank String secret,
    @Positive long accessTokenExpiration,
    @Positive long refreshTokenExpiration,
    @NotBlank String issuer,
    String audience,
    @NotBlank String algorithm,
    String publicKeyPath,
    String privateKeyPath
) {
    // Default values via constructor
    public JwtProperties {
        if (accessTokenExpiration <= 0) accessTokenExpiration = 900_000L;    // 15 min
        if (refreshTokenExpiration <= 0) refreshTokenExpiration = 7_776_000_000L; // 7 days
        if (algorithm == null || algorithm.isBlank()) algorithm = "HS256";
    }
}
```

### application.yml

```yaml
jwt:
  secret: ${JWT_SECRET}                          # Base64-encoded, min 256-bit
  access-token-expiration: 900000                # 15 minutes in milliseconds
  refresh-token-expiration: 604800000            # 7 days in milliseconds
  issuer: my-app                                 # Token issuer claim
  audience: my-app-api                           # Token audience claim (optional)
  algorithm: HS256                               # Signing algorithm

  # For RSA/ECDSA algorithms (optional)
  public-key-path: ${JWT_PUBLIC_KEY_PATH:/config/keys/public.pem}
  private-key-path: ${JWT_PRIVATE_KEY_PATH:/config/keys/private.pem}
```

### application-dev.yml (Development Overrides)

```yaml
jwt:
  # Use a known dev secret for local testing -- NEVER in production
  secret: ${JWT_SECRET:Y2hhdGdwdC1kZW1vLXNlY3JldC1rZXktMjU2LWJpdHMtbG9uZw==}
  access-token-expiration: 3600000               # 60 min (longer for dev convenience)
  refresh-token-expiration: 864000000            # 10 days
```

### application-prod.yml (Production Overrides)

```yaml
jwt:
  secret: ${JWT_SECRET}                          # MUST come from env/secret manager
  access-token-expiration: 900000                # 15 min (strict for prod)
  refresh-token-expiration: 604800000            # 7 days
  algorithm: RS256                               # RSA for multi-service prod
  public-key-path: ${JWT_PUBLIC_KEY_PATH}
  private-key-path: ${JWT_PRIVATE_KEY_PATH}
```

## Signing Key Resolution by Algorithm

```java
@Service
@RequiredArgsConstructor
@Slf4j
public class JwtKeyProvider {

    private final JwtProperties jwtProperties;

    /**
     * Returns the appropriate signing key based on the configured algorithm.
     */
    public Key getSigningKey() {
        return switch (jwtProperties.algorithm()) {
            case "HS256", "HS384", "HS512" -> getHmacKey();
            case "RS256", "RS384", "RS512" -> getRsaPrivateKey();
            case "ES256", "ES384", "ES512" -> getEcPrivateKey();
            default -> throw new IllegalArgumentException(
                "Unsupported JWT algorithm: " + jwtProperties.algorithm());
        };
    }

    /**
     * Returns the appropriate verification key based on the configured algorithm.
     * For HMAC, the signing key is also the verification key.
     * For RSA/ECDSA, the public key is used for verification.
     */
    public Key getVerificationKey() {
        return switch (jwtProperties.algorithm()) {
            case "HS256", "HS384", "HS512" -> getHmacKey();
            case "RS256", "RS384", "RS512" -> getRsaPublicKey();
            case "ES256", "ES384", "ES512" -> getEcPublicKey();
            default -> throw new IllegalArgumentException(
                "Unsupported JWT algorithm: " + jwtProperties.algorithm());
        };
    }

    private SecretKey getHmacKey() {
        byte[] keyBytes = Decoders.BASE64.decode(jwtProperties.secret());
        return Keys.hmacShaKeyFor(keyBytes);
    }

    private RSAPrivateKey getRsaPrivateKey() {
        try {
            String pem = Files.readString(Path.of(jwtProperties.privateKeyPath()));
            String content = pem
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replaceAll("\\s", "");
            PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(Decoders.BASE64.decode(content));
            return (RSAPrivateKey) KeyFactory.getInstance("RSA").generatePrivate(spec);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to load RSA private key", e);
        }
    }

    private RSAPublicKey getRsaPublicKey() {
        try {
            String pem = Files.readString(Path.of(jwtProperties.publicKeyPath()));
            String content = pem
                .replace("-----BEGIN PUBLIC KEY-----", "")
                .replace("-----END PUBLIC KEY-----", "")
                .replaceAll("\\s", "");
            X509EncodedKeySpec spec = new X509EncodedKeySpec(Decoders.BASE64.decode(content));
            return (RSAPublicKey) KeyFactory.getInstance("RSA").generatePublic(spec);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to load RSA public key", e);
        }
    }

    private ECPrivateKey getEcPrivateKey() {
        // ECDSA key loading follows similar PEM parsing pattern
        // Use PKCS8EncodedKeySpec for EC private keys
        throw new UnsupportedOperationException("ECDSA key loading not yet implemented");
    }

    private ECPublicKey getEcPublicKey() {
        throw new UnsupportedOperationException("ECDSA key loading not yet implemented");
    }
}
```

## Issuer and Audience Claims

### Setting Issuer and Audience

```java
public String generateAccessToken(UserDetails userDetails) {
    return Jwts.builder()
        .subject(userDetails.getUsername())
        .issuer(jwtProperties.issuer())                   // iss claim
        .audience().add(jwtProperties.audience()).and()   // aud claim (JJWT 0.13.0)
        .issuedAt(new Date())
        .expiration(new Date(System.currentTimeMillis() + jwtProperties.accessTokenExpiration()))
        .claim("authorities", userDetails.getAuthorities().stream()
            .map(GrantedAuthority::getAuthority).toList())
        .signWith(getSigningKey())
        .compact();
}
```

### Validating Issuer and Audience

```java
public boolean isTokenValid(String token, UserDetails userDetails) {
    try {
        Claims claims = Jwts.parser()
            .verifyWith(getVerificationKey())
            .requireIssuer(jwtProperties.issuer())        // Validate iss
            .requireAudience(jwtProperties.audience())    // Validate aud (JJWT 0.13.0)
            .build()
            .parseSignedClaims(token)
            .getPayload();

        return claims.getSubject().equals(userDetails.getUsername())
            && !isTokenExpired(claims);
    } catch (JwtException e) {
        log.warn("JWT validation failed: {}", e.getMessage());
        return false;
    }
}
```

> Always validate `iss` and `aud` in production. These claims prevent token misuse across different services or environments.

## Nacos Config Center Integration

### JWT Properties in Nacos

Store JWT configuration in Nacos config center for centralized management and dynamic refresh.

#### Nacos Data ID: `jwt-config.yaml`

```yaml
jwt:
  secret: ${JWT_SECRET}
  access-token-expiration: 900000
  refresh-token-expiration: 604800000
  issuer: my-app
  audience: my-app-api
  algorithm: HS256
```

#### bootstrap.yml -- Nacos Connection

```yaml
spring:
  application:
    name: my-app
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}
  cloud:
    nacos:
      config:
        server-addr: ${NACOS_ADDR:localhost:8848}
        namespace: ${NACOS_NAMESPACE:dev}
        group: DEFAULT_GROUP
        file-extension: yaml
        shared-configs:
          - data-id: jwt-config.yaml
            group: SHARED_GROUP
            refresh: true
```

> JWT secret (`jwt.secret`) MUST NOT be stored directly in Nacos config. Always reference an environment variable (`${JWT_SECRET}`) that is injected from a secret manager (Vault, K8s Secrets, AWS Secrets Manager). Nacos should only hold non-sensitive settings like expiration times and issuer name.

### Dynamic Refresh for JWT Expiration

```java
@ConfigurationProperties(prefix = "jwt")
@RefreshScope
@Validated
public record JwtProperties(
    @NotBlank String secret,
    @Positive long accessTokenExpiration,
    @Positive long refreshTokenExpiration,
    @NotBlank String issuer,
    String audience,
    @NotBlank String algorithm,
    String publicKeyPath,
    String privateKeyPath
) {}
```

> `@RefreshScope` enables dynamic refresh of non-secret JWT properties (expiration, issuer) when Nacos config changes. The secret itself MUST remain static -- rotating secrets requires a coordinated deployment, not a config refresh.

## Expiration Settings Reference

### Recommended Expiration Values

| Environment | Access Token | Refresh Token | Rationale |
|-------------|-------------|--------------|-----------|
| Development | 60 min | 10 days | Convenience, fewer re-auths |
| Staging | 30 min | 7 days | Moderate, realistic testing |
| Production | 15 min | 7 days | Security-first, short window for compromise |
| High-security | 5 min | 1 day | Financial, healthcare, strict compliance |

### Token Expiration as Duration Constants

```java
public final class JwtConstants {
    // Access token durations
    public static final Duration ACCESS_TOKEN_SHORT  = Duration.ofMinutes(5);
    public static final Duration ACCESS_TOKEN_MEDIUM = Duration.ofMinutes(15);
    public static final Duration ACCESS_TOKEN_LONG   = Duration.ofMinutes(60);

    // Refresh token durations
    public static final Duration REFRESH_TOKEN_SHORT  = Duration.ofDays(1);
    public static final Duration REFRESH_TOKEN_MEDIUM = Duration.ofDays(7);
    public static final Duration REFRESH_TOKEN_LONG   = Duration.ofDays(30);

    // Clock skew tolerance for expiration validation
    public static final Duration CLOCK_SKEW_TOLERANCE = Duration.ofSeconds(30);
}
```

### Clock Skew Tolerance

Network latency and clock drift between servers can cause premature token rejection. Configure a clock skew window:

```java
public boolean isTokenValid(String token, UserDetails userDetails) {
    try {
        Claims claims = Jwts.parser()
            .verifyWith(getVerificationKey())
            .requireIssuer(jwtProperties.issuer())
            .clockSkewSeconds(30)                      // 30-second tolerance
            .build()
            .parseSignedClaims(token)
            .getPayload();

        return claims.getSubject().equals(userDetails.getUsername());
    } catch (ExpiredJwtException e) {
        // Token expired even with clock skew tolerance
        log.warn("JWT expired: {}", e.getMessage());
        return false;
    } catch (JwtException e) {
        log.warn("JWT validation failed: {}", e.getMessage());
        return false;
    }
}
```

## Security Best Practices for Configuration

1. **Never hardcode secrets**: Always use `${JWT_SECRET}` referencing environment variables or secret managers
2. **Rotate secrets regularly**: Change HMAC secrets at least every 90 days; use key rotation for RSA/ECDSA
3. **Separate keys per environment**: Dev, staging, and production MUST use different signing keys
4. **Base64-encode HMAC secrets**: Store secrets as Base64 strings; decode at runtime with `Decoders.BASE64.decode()`
5. **Validate key length at startup**: Assert that the decoded key meets the minimum bit requirement for the algorithm
6. **Use asymmetric keys for multi-service**: RSA/ECDSA allows verification without sharing the signing secret
7. **Store PEM files securely**: Private key PEM files MUST have restricted file permissions (0600 on Linux)
8. **Audit key access**: Log when signing keys are loaded; alert on unexpected key reloads

### Startup Key Validation

```java
@Configuration
@RequiredArgsConstructor
@Slf4j
public class JwtKeyValidationConfig {

    private final JwtProperties jwtProperties;

    @PostConstruct
    public void validateSigningKey() {
        if (jwtProperties.algorithm().startsWith("HS")) {
            byte[] keyBytes = Decoders.BASE64.decode(jwtProperties.secret());
            int bitLength = keyBytes.length * 8;

            int requiredBits = switch (jwtProperties.algorithm()) {
                case "HS256" -> 256;
                case "HS384" -> 384;
                case "HS512" -> 512;
                default -> 256;
            };

            if (bitLength < requiredBits) {
                throw new IllegalStateException(
                    "JWT secret key is %d bits, but %s requires at least %d bits".formatted(
                        bitLength, jwtProperties.algorithm(), requiredBits));
            }
            log.info("JWT signing key validated: {} bits for algorithm {}", bitLength, jwtProperties.algorithm());
        }
    }
}
```

## JJWT Parser Configuration (0.13.0)

### Modern Parser Builder API

JJWT 0.13.0 uses a new builder-based parser API. The old `Jwts.parserBuilder()` is replaced with `Jwts.parser()`:

```java
// JJWT 0.13.0 parser (new API)
JwtParser parser = Jwts.parser()
    .verifyWith(secretKey)                   // Verify signature (renamed from setSigningKey)
    .requireIssuer("my-app")                 // Validate issuer
    .requireAudience("my-app-api")           // Validate audience
    .clockSkewSeconds(30)                    // Clock skew tolerance
    .build();

// Parse and get claims
Claims claims = parser.parseSignedClaims(token).getPayload();
```

### JJWT Builder API (0.13.0)

```java
// JJWT 0.13.0 builder (new API)
String token = Jwts.builder()
    .subject("user123")
    .issuer("my-app")
    .audience().add("my-app-api").and()      // Audience uses Collection-style builder
    .issuedAt(new Date())
    .expiration(new Date(System.currentTimeMillis() + 900_000L))
    .claim("roles", List.of("ADMIN", "USER"))
    .signWith(secretKey)                     // Sign with key (renamed from setSigningKey)
    .compact();
```

### Key API Changes from JJWT 0.11.x to 0.13.0

| Old API (0.11.x) | New API (0.13.0) | Notes |
|-------------------|-------------------|-------|
| `Jwts.parserBuilder()` | `Jwts.parser()` | Builder renamed |
| `.setSigningKey(key)` | `.verifyWith(key)` | Method renamed |
| `.setSubject(sub)` | `.subject(sub)` | Property-style setter |
| `.setIssuer(iss)` | `.issuer(iss)` | Property-style setter |
| `.setIssuedAt(date)` | `.issuedAt(date)` | Property-style setter |
| `.setExpiration(date)` | `.expiration(date)` | Property-style setter |
| `.addClaim(key, val)` | `.claim(key, val)` | Method renamed |
| `.setAudience(aud)` | `.audience().add(aud).and()` | Audience now uses Collection builder |
| `.parseClaimsJws(token)` | `.parseSignedClaims(token)` | Method renamed |
| `.getBody()` | `.getPayload()` | Method renamed |

## References

- [JJWT 0.12.x Documentation](https://github.com/jwtk/jjwt#jjwt-012x)
- [Spring Security 6.x Reference](https://docs.spring.io/spring-security/reference/)
- [RFC 7519: JSON Web Token](https://datatracker.ietf.org/doc/html/rfc7519)
- [RFC 7518: JSON Web Algorithms](https://datatracker.ietf.org/doc/html/rfc7518)
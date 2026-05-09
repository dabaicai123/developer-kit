---
name: spring-boot-security
description: Spring Security best practices for authn/authz, validation, CSRF, secrets, headers, rate limiting, and dependency security in Java Spring Boot services.
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Security Checklist

## When to use this skill

- Reviewing security posture before release
- Configuring CORS, CSRF, or security headers
- Managing secrets (Vault, environment variables)
- Adding rate limiting or brute-force protection
- Scanning dependencies for CVEs

## Related Skills

- For JWT implementation → `spring-boot-security-jwt`
- For input validation → `spring-boot-validation`
- For testing security → `unit-test-security-authorization`

## Authorization

Use `@EnableMethodSecurity` + `@PreAuthorize` for method-level access control:

```java
@RestController
@RequestMapping("/v1/admin")
public class AdminController {

  @PreAuthorize("hasRole('ADMIN')")
  @GetMapping("/users")
  public Result<List<UserDTO>> listUsers() { return Result.success(userService.findAll()); }

  @PreAuthorize("@authz.isOwner(#id, authentication)")
  @DeleteMapping("/users/{id}")
  public Result<Void> deleteUser(@PathVariable Long id) { ... }
}
```

## Input Validation

For input validation, see `spring-boot-validation`.

## Password Encoding

- Always hash passwords with BCrypt or Argon2 — never store plaintext

```java
@Bean
public PasswordEncoder passwordEncoder() {
  return new BCryptPasswordEncoder(12);
}
```

## CSRF Protection

Disable CSRF for stateless Bearer-token APIs (keep enabled for browser session apps):

```java
http.csrf(csrf -> csrf.disable())
    .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
```

## Secrets Management

Never hardcode secrets; use environment variable placeholders:

```yaml
# BAD: Hardcoded
spring.datasource.password: mySecretPassword123

# GOOD: Environment variable
spring.datasource.password: ${DB_PASSWORD}
```

## Security Headers

```java
http.headers(headers -> headers
    .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))
    .frameOptions(HeadersConfigurer.FrameOptionsConfig::sameOrigin)
    .xssProtection(Customizer.withDefaults())
    .referrerPolicy(rp -> rp.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER)));
```

## CORS Configuration

Configure CORS at security filter level; restrict origins (never `*` in production):

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
  CorsConfiguration config = new CorsConfiguration();
  config.setAllowedOrigins(List.of("https://app.example.com"));
  config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
  config.setAllowCredentials(true);
  config.setMaxAge(3600L);

  UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
  source.registerCorsConfiguration("/api/**", config);
  return source;
}
```

## Rate Limiting

For rate limiting, see `spring-boot-resilience4j` (RateLimiter) or `spring-cloud-gateway` (RequestRateLimiter filter).

## Dependency Security

Run OWASP Dependency-Check or Snyk in CI; fail builds on known CVEs.

## Checklist Before Release

- [ ] `@EnableMethodSecurity` + `@PreAuthorize` on sensitive paths
- [ ] BCrypt/Argon2 password encoder configured
- [ ] No hardcoded secrets in application.yml (search for `${` usage)
- [ ] OWASP Dependency-Check passes in CI
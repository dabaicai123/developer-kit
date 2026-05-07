---
name: spring-boot-security
description: Spring Security best practices for authn/authz, validation, CSRF, secrets, headers, rate limiting, and dependency security in Java Spring Boot services.
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Security Checklist

Security best practices and checklist for Spring Boot services.

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

- Enable method security: `@EnableMethodSecurity`
- Use `@PreAuthorize("hasRole('ADMIN')")` or `@PreAuthorize("@authz.canEdit(#id)")`
- Deny by default; expose only required scopes

```java
@RestController
@RequestMapping("/api/admin")
public class AdminController {

  @PreAuthorize("hasRole('ADMIN')")
  @GetMapping("/users")
  public List<UserDto> listUsers() { return userService.findAll(); }

  @PreAuthorize("@authz.isOwner(#id, authentication)")
  @DeleteMapping("/users/{id}")
  public Result<Void> deleteUser(@PathVariable Long id) { ... }
}
```

## Input Validation

- Use Bean Validation with `@Valid` on controllers
- Apply constraints on DTOs: `@NotBlank`, `@Email`, `@Size`, custom validators
- Sanitize any HTML with a whitelist before rendering

> For detailed validation patterns, see `spring-boot-validation`.

## Password Encoding

- Always hash passwords with BCrypt or Argon2 — never store plaintext

```java
@Bean
public PasswordEncoder passwordEncoder() {
  return new BCryptPasswordEncoder(12);
}
```

## CSRF Protection

- For browser session apps, keep CSRF enabled
- For pure APIs with Bearer tokens, disable CSRF and rely on stateless auth

```java
http.csrf(csrf -> csrf.disable())
    .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS));
```

## Secrets Management

- No secrets in source; load from env or vault
- Keep `application.yml` free of credentials; use placeholders

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

- Configure CORS at the security filter level, not per-controller
- Restrict allowed origins — never use `*` in production

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

- Apply Bucket4j or gateway-level limits on expensive endpoints
- Return 429 with retry hints

## Dependency Security

- Run OWASP Dependency Check / Snyk in CI
- Keep Spring Boot and Spring Security on supported versions
- Fail builds on known CVEs

## Checklist Before Release

- [ ] Auth tokens validated and expired correctly
- [ ] Authorization guards on every sensitive path
- [ ] All inputs validated and sanitized
- [ ] No string-concatenated SQL
- [ ] CSRF posture correct for app type
- [ ] Secrets externalized; none committed
- [ ] Security headers configured
- [ ] Rate limiting on APIs
- [ ] Dependencies scanned and up to date
- [ ] Logs free of sensitive data
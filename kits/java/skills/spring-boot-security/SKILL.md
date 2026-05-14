---
name: spring-boot-security
description: "Spring Security: SecurityFilterChain, @EnableMethodSecurity, CSRF, CORS, security headers, password encoding, secrets management. Use when configuring authentication, authorization, or security filters in Java Spring Boot services."
version: "1.1.0"
---

# Spring Boot Security (Spring Boot 3.5.x)

## When to use this skill

- Configuring SecurityFilterChain, CORS, CSRF, or security headers
- Adding method-level authorization with `@EnableMethodSecurity`
- Managing secrets (Vault, environment variables)
- Adding rate limiting or brute-force protection
- Scanning dependencies for CVEs
- Reviewing security posture before release

## Instructions

### 1. Dependency Setup

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

For Gradle:

```gradle
implementation "org.springframework.boot:spring-boot-starter-security"
```

### 2. SecurityFilterChain Configuration

Use `SecurityFilterChain` bean with lambda DSL. NOT `WebSecurityConfigurerAdapter` (removed in Spring Security 6).

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/v1/public/**").permitAll()
                .requestMatchers("/v1/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .csrf(csrf -> csrf.disable())
            .sessionManagement(sm ->
                sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .cors(Customizer.withDefaults());
        return http.build();
    }
}
```

NOT `authorizeRequests` → use `authorizeHttpRequests`. NOT `antMatchers`/`mvcMatchers` → use `requestMatchers`. NOT `.and()` chaining → use lambda DSL.

### 3. Method-Level Authorization

Enable with `@EnableMethodSecurity`. NOT `@EnableGlobalMethodSecurity` (deprecated).

```java
@EnableMethodSecurity
@SpringBootApplication
public class Application { ... }
```

```java
@RestController
@RequestMapping("/v1/admin")
public class AdminController {

    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping("/users")
    public Result<List<UserDTO>> listUsers() {
        return Result.success(userService.findAll());
    }

    @PreAuthorize("@authz.isOwner(#id, authentication)")
    @DeleteMapping("/users/{id}")
    public Result<Void> deleteUser(@PathVariable Long id) { ... }
}
```

### 4. CSRF Protection

Disable CSRF for stateless Bearer-token APIs. NOT disable CSRF for browser-session apps — CSRF tokens protect against cross-site form submissions.

```java
// Stateless API: disable CSRF
http.csrf(csrf -> csrf.disable())
    .sessionManagement(sm ->
        sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS));

// Session-based app: keep CSRF enabled (default)
// Spring Security enables CSRF by default — no explicit config needed
```

### 5. Password Encoding

NOT store plaintext passwords. Use BCrypt or Argon2.

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}
```

NOT `new BCryptPasswordEncoder()` without cost factor — specify strength (10–12 recommended).

### 6. CORS Configuration

Configure CORS at `CorsConfigurationSource` bean. NOT use `*` for origins in production.

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

### 7. Security Headers

```java
http.headers(headers -> headers
    .contentSecurityPolicy(csp ->
        csp.policyDirectives("default-src 'self'"))
    .frameOptions(HeadersConfigurer.FrameOptionsConfig::sameOrigin)
    .xssProtection(Customizer.withDefaults())
    .referrerPolicy(rp ->
        rp.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER)));
```

### 8. Secrets Management

NOT hardcode secrets in configuration files. Use environment variable placeholders:

```yaml
spring.datasource.password: ${DB_PASSWORD}
```

NOT `spring.datasource.password: mySecretPassword123` → use `${DB_PASSWORD}`.

### 9. Rate Limiting

Resilience4j `@RateLimiter` for per-service limits → see `spring-boot-resilience4j`. Spring Cloud Gateway `RequestRateLimiter` filter for gateway-level limits → see `spring-cloud-gateway`.

### 10. Dependency Security

OWASP Dependency-Check Maven plugin or Snyk CLI in CI pipelines. Fail builds on HIGH/CRITICAL CVEs.

```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>12.1.0</version>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
    <configuration>
        <failOnCVSS>7</failOnCVSS>
    </configuration>
</plugin>
```

## Constraints and Warnings

**Anti-patterns**:

- **NOT use `WebSecurityConfigurerAdapter`** — removed in Spring Security 6. Use `SecurityFilterChain` bean.
- **NOT use `@EnableGlobalMethodSecurity`** — deprecated. Use `@EnableMethodSecurity`.
- **NOT use `antMatchers`/`mvcMatchers`** — deprecated. Use `requestMatchers`.
- **NOT use `authorizeRequests`** — deprecated. Use `authorizeHttpRequests`.
- **NOT use `.and()` method chaining** — deprecated. Use lambda DSL.
- **NOT use `javax.servlet`** — Spring Boot 3.5 uses `jakarta.servlet`.
- **NOT store plaintext passwords** — hash with BCrypt (cost 10–12) or Argon2.
- **NOT hardcode secrets in configuration** — use `${ENV_VAR}` placeholders or Vault.
- **NOT disable CSRF for browser-session apps** — CSRF tokens prevent cross-site form submission.
- **NOT use `*` for CORS origins in production** — restrict to specific domains.
- **NOT use `BCryptPasswordEncoder()` without cost factor** — specify strength explicitly.
- **NOT expose actuator endpoints without auth** — restrict `/actuator/**` in SecurityFilterChain.

**Technical constraints**:

- Spring Security 6.5 requires Java 17+ and Jakarta EE 10 (`jakarta.servlet`, `jakarta.validation`)
- `SecurityFilterChain` bean replaces all `WebSecurityConfigurerAdapter` usage
- CSRF enabled by default; disable only for stateless Bearer-token APIs
- CORS requires both `CorsConfigurationSource` bean and `.cors(Customizer.withDefaults())` in SecurityFilterChain

## Related Skills

- `spring-boot-security-jwt`
- `spring-boot-validation`
- `spring-boot-exception-handling`
- `spring-boot-resilience4j`
- `unit-test-security-authorization`
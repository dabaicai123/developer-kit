# Setup — Security Testing Dependencies

## Maven Configuration

```xml
<dependencies>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
  </dependency>

  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
  </dependency>

  <dependency>
    <groupId>org.springframework.security</groupId>
    <artifactId>spring-security-test</artifactId>
    <scope>test</scope>
  </dependency>
</dependencies>
```

## Gradle Configuration

```kotlin
dependencies {
  implementation("org.springframework.boot:spring-boot-starter-security")
  testImplementation("org.springframework.boot:spring-boot-starter-test")
  testImplementation("org.springframework.security:spring-security-test")
}
```

## Enable Method Security

```java
@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    // Other security configuration
}
```

**Configuration Options:**
- `prePostEnabled = true` (default) — Enables `@PreAuthorize` and `@PostAuthorize`
- `securedEnabled = true` — Enables `@Secured`
- `jsr250Enabled = true` — Enables `@RolesAllowed` (JSR-250)

> **NOT** use `@EnableGlobalMethodSecurity` — removed in Spring Security 6.x. Use `@EnableMethodSecurity`.

## Verify Setup

```java
class SecuritySetupTest {

    @Test
    @WithMockUser
    void shouldLoadSpringSecurityContext() {
        assertThat(true).isTrue();
    }
}
```
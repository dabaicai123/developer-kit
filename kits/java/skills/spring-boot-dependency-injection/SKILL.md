---
name: spring-boot-dependency-injection
description: "Spring Boot dependency injection with constructor-first design, optional collaborator handling, bean selection, and wiring validation. Use when creating services and configurations, replacing field injection, or troubleshooting Spring wiring."
version: "1.1.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Dependency Injection

## When to use this skill

Use this skill when:
- creating a new `@Service`, `@Component`, `@Repository`, or `@Configuration` class
- replacing field injection in legacy Spring code
- resolving multiple beans of the same type with qualifiers or primary beans
- handling optional features, adapters, or integrations without null-driven wiring
- reviewing circular dependencies or brittle context startup failures
- preparing code for direct constructor-based unit testing


## Instructions

### 1. Constructor injection for mandatory + optional collaborators

Put mandatory collaborators in the constructor (keep fields `final`). Optional ones use `ObjectProvider`, `Optional`, conditional beans, or no-op implementations.

Since Spring 4.3+, if a class has only one constructor, `@Autowired` is inferred automatically — no explicit annotation needed.

### 2. Resolve optional behavior intentionally

Good options include:
- `ObjectProvider<T>` when lazy access is useful
- `Optional<T>` when you want type-safe presence/absence semantics at the injection point
- `@ConditionalOnProperty` or `@ConditionalOnMissingBean` when wiring should change by configuration
- a no-op implementation when the caller should not care whether the feature is enabled

Nullable collaborators force null checks throughout the class and make behavior unpredictable. Use `ObjectProvider` or no-op implementations instead.

### 3. Use bean selection annotations only when needed

When multiple beans share the same type:
- use `@Primary` for the default implementation
- use `@Qualifier` for named variants
- keep the qualifier names stable and easy to grep

If selection rules become complex, move them into a dedicated configuration class instead of spreading them across services.

### 4. Keep wiring in configuration, not business code

Use `@Configuration` and `@Bean` methods when:
- the object comes from a third-party library
- conditional creation logic is needed
- you need environment-specific wiring or explicit composition

Business services should not know how infrastructure collaborators are instantiated.

### 5. Validate wiring explicitly

Verify wiring with a minimal `@ContextConfiguration` test first. Then write constructor-based unit tests (no Spring). Add slice or full-context tests only where they add value.

```java
@ExtendWith(SpringExtension.class)
@ContextConfiguration(classes = UserService.class)
class UserServiceWiringTest {
    @Autowired UserService userService;
    @Test void serviceIsInstantiated() { assertNotNull(userService); }
}
```

## Examples

### Example 1: Constructor-first application service

```java
@Service
@RequiredArgsConstructor
public class UserService {

    private final UserGateway userGateway;
    private final EmailSender emailSender;

    public User register(UserRegistrationRequest request) {
        User user = userGateway.save(User.from(request));
        emailSender.sendWelcome(user);
        return user;
    }
}
```

This class is easy to instantiate directly in a unit test with mocks. Uses `@RequiredArgsConstructor` (Lombok) to generate the constructor, keeping injection concise and fields `final`.

### Example 2: Optional dependency with a no-op fallback

```java
@Service
public class ReportService {

    private final ReportRepository reportRepository;
    private final NotificationGateway notificationGateway;

    public ReportService(
        ReportRepository reportRepository,
        ObjectProvider<NotificationGateway> notificationGatewayProvider
    ) {
        this.reportRepository = reportRepository;
        this.notificationGateway = notificationGatewayProvider.getIfAvailable(NotificationGateway::noOp);
    }
}
```

This keeps optional behavior explicit without leaking `null` handling through the rest of the class.

### Example 3: Multiple beans with clear selection

```java
@Configuration
public class PaymentConfiguration {

    @Bean
    @Primary
    PaymentGateway stripeGateway() {
        return new StripePaymentGateway();
    }

    @Bean
    @Qualifier("fallbackGateway")
    PaymentGateway mockGateway() {
        return new MockPaymentGateway();
    }
}
```

Use `@Primary` for the default path and `@Qualifier` only where a specific variant is required.

## Best Practices

- Prefer constructor injection for mandatory dependencies.
- Keep service constructors small; if a class needs too many collaborators, the design probably wants another abstraction.
- Use no-op or conditional beans instead of nullable optional dependencies — nullable collaborators force null checks throughout the class and make behavior unpredictable.
- Keep framework-specific creation logic in configuration classes.
- Test services without Spring first, then add container tests only where they add value.
- During refactors, replace field injection with constructor injection; never add new field-injected fields.

## Constraints and Warnings

- Field injection hides dependencies and makes tests harder to write.
- Circular dependencies are usually a design problem, not a wiring trick to solve with `@Lazy`.
- Overusing qualifiers can make the codebase hard to reason about; prefer better abstractions or clearer configuration.
- Optional collaborators still need deterministic behavior when absent.
- Full-context tests can hide the real source of wiring failures if used too early.

## References

- `references/examples.md` — ObjectProvider, Profile-based configuration, circular dependency resolution

## Related Skills

- `spring-boot-configuration-management` — @ConfigurationProperties, constructor binding, Nacos config
- `spring-boot-event-driven-patterns` — @TransactionalEventListener, event-driven architecture
- `spring-boot-rest-api-standards` — REST API design, DTOs, validation

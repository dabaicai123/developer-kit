---
name: spring-boot-dependency-injection
description: "Spring Boot dependency injection with constructor-first design, optional collaborator handling, bean selection, and wiring validation. Use when creating services, replacing field injection, or troubleshooting Spring wiring."
version: "1.2.0"
type: skill
---

# Spring Boot Dependency Injection

## When to use

- Creating `@Service`, `@Component`, `@Repository`, or `@Configuration` classes
- Replacing field injection in legacy code
- Resolving multiple beans of the same type
- Handling optional dependencies without null-driven wiring
- Reviewing circular dependencies or context startup failures

## Instructions

### 1. Constructor injection for all collaborators

Mandatory collaborators: constructor with `final` fields. Use `@RequiredArgsConstructor` (Lombok). Since Spring 4.3+, single-constructor classes infer `@Autowired` automatically.

```java
@Service
@RequiredArgsConstructor
public class UserService {
    private final UserGateway userGateway;
    private final EmailSender emailSender;
}
```

### 2. Optional dependencies

| Approach | When to use |
|----------|-------------|
| `ObjectProvider<T>` | Lazy access, fallback to no-op |
| `Optional<T>` | Type-safe presence/absence at injection point |
| `@ConditionalOnProperty` / `@ConditionalOnMissingBean` | Wiring changes by configuration |
| No-op implementation | Caller should not care if feature is enabled |

Never use nullable collaborators — they force null checks throughout the class.

```java
public ReportService(
    ReportRepository reportRepository,
    ObjectProvider<NotificationGateway> notificationProvider
) {
    this.reportRepository = reportRepository;
    this.notificationGateway = notificationProvider.getIfAvailable(NotificationGateway::noOp);
}
```

### 3. Bean selection

- `@Primary` for the default implementation
- `@Qualifier` for named variants
- If selection rules become complex, move to a dedicated `@Configuration` class

### 4. Configuration vs business code

Use `@Configuration` + `@Bean` when: third-party library objects, conditional creation, environment-specific wiring. Business services should not know how infrastructure is instantiated.

### 5. Validate wiring

Test services without Spring first (constructor-based unit tests with mocks). Add `@ContextConfiguration` tests only where container wiring adds value.

## Rules

- Constructor injection for mandatory dependencies — field injection hides dependencies
- Keep constructors small — too many collaborators signals missing abstraction
- Circular dependencies are design problems, not `@Lazy` tricks
- During refactors, replace field injection with constructor injection; never add new field-injected fields
- Optional collaborators need deterministic behavior when absent

## References

- `references/examples.md` — ObjectProvider, Profile-based configuration, circular dependency resolution

## Related Skills

- `spring-boot-configuration-management` — @ConfigurationProperties, constructor binding
- `ddd-cola` — Gateway pattern uses constructor injection throughout

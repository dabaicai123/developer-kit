---
name: spring-boot-slice-testing
description: "Creates Spring Boot slice tests for events, scheduled/async code, ConfigProps, @JsonTest, and caching that require Spring Context. Use when testing framework-integrated behavior rather than pure unit logic."
version: "1.0.0"
---

# Spring Boot Slice Testing

## Overview

Five slice testing patterns that depend on Spring Context (AOP proxy, Bean binding). NOT unit tests.

> **slice test != unit test** — slice tests verify framework integration; unit tests do NOT depend on Spring.

## When to use

- Test `ApplicationEventPublisher` / `@EventListener`
- Test `@Scheduled` / `@Async` methods
- Test `@ConfigurationProperties` binding and validation
- Test JSON serialization/deserialization (`@JsonTest`)
- Test `@Cacheable` / `@CacheEvict` / `@CachePut`

## Anti-patterns

- NOT use `@MockBean` (deprecated 3.4+, removed 4.0) → `@MockitoBean` (`org.springframework.test.context.bean.override.mockito`)
- NOT call `this.method()` for `@Cacheable`/`@Async`/`@EventListener` → bypasses AOP proxy, runs synchronously
- NOT use `Thread.sleep()` for async assertions → Awaitility
- NOT confuse slice tests with unit tests — slice tests need Spring Context
- NOT use `@SpringBootTest` for `@ConfigurationProperties` binding → `ApplicationContextRunner` (no full context)

## COLA Conventions

Follow COLA naming conventions (`UserServiceI` / `Result<T>` / `/v1/` prefix) — see `spring-boot-cola-architecture` skill.

---

## Section 1: Application Events Testing

**Mock `ApplicationEventPublisher`** + `ArgumentCaptor` verify publication; call Listener directly for side effects; Awaitility for async.

```java
public record UserCreatedEvent(User user) {}

// COLA: UserServiceI -> UserServiceImpl, Result<T>
public interface UserServiceI { Result<User> createUser(String name, String email); }

@Service
public class UserServiceImpl implements UserServiceI {
  private final ApplicationEventPublisher eventPublisher;
  private final UserRepository userRepository;
  public Result<User> createUser(String name, String email) {
    User saved = userRepository.save(new User(name, email));
    eventPublisher.publishEvent(new UserCreatedEvent(saved));
    return Result.success(saved);
  }
}

// Test: mock publisher + ArgumentCaptor
@ExtendWith(MockitoExtension.class)
class UserServiceEventTest {
  @Mock ApplicationEventPublisher eventPublisher;
  @Mock UserRepository userRepository;
  @InjectMocks UserServiceImpl userService;

  @Test
  void shouldPublishEvent() {
    when(userRepository.save(any())).thenReturn(new User(1L, "Alice", "a@b.com"));
    ArgumentCaptor<UserCreatedEvent> captor = ArgumentCaptor.forClass(UserCreatedEvent.class);
    userService.createUser("Alice", "a@b.com");
    verify(eventPublisher).publishEvent(captor.capture());
    assertThat(captor.getValue().user().getName()).isEqualTo("Alice");
  }
}

// Listener: call directly to verify side effects
@Test void shouldSendWelcomeEmail() {
  EmailServiceI email = mock(EmailServiceI.class);
  new UserEventListener(email).onUserCreated(new UserCreatedEvent(user));
  verify(email).sendWelcomeEmail("a@b.com");
}

// Async Listener: Awaitility
@Test void shouldProcessAsync() {
  Awaitility.await().atMost(2, TimeUnit.SECONDS)
    .untilAsserted(() -> verify(slowService).processUser(user));
}
```

> Full error scenario testing -> `references/advanced-examples.md`

---

## Section 2: Scheduled & Async Testing

**`@Scheduled`/`@Async` ineffective in unit tests** — call methods directly. `.get(timeout, unit)` for `CompletableFuture`. Awaitility for race conditions.

```java
// @Scheduled: call directly, mock dependencies
@Component
public class DataRefreshTask {
  private final DataRepository repo;
  @Scheduled(fixedDelay = 60000) public void refreshCache() { repo.findAll(); }
}
@Test void shouldRefreshCache() {
  DataRepository repo = mock(DataRepository.class);
  when(repo.findAll()).thenReturn(List.of(new Data(1L, "item1")));
  new DataRefreshTask(repo).refreshCache();
  verify(repo).findAll();
}

// @Async + CompletableFuture: COLA-style
public interface NotificationServiceI {
  CompletableFuture<Result<String>> notifyUserAsync(String userId);
}
@Test void shouldReturnFuture() throws Exception {
  Result<String> r = service.notifyUserAsync("user123").get(5, TimeUnit.SECONDS);
  assertThat(r.getData()).isEqualTo("Notification sent");
}
@Test void shouldHandleException() {
  doThrow(new RuntimeException("fail")).when(emailService).send(any());
  assertThatThrownBy(() -> service.notifyUserAsync("u1").get())
    .isInstanceOf(ExecutionException.class).hasCauseInstanceOf(RuntimeException.class);
}

// Awaitility for race conditions
@Test void shouldProcessAllItems() {
  worker.processItems(List.of("item1", "item2", "item3"));
  Awaitility.await().atMost(Duration.ofSeconds(5))
    .pollInterval(Duration.ofMillis(100))
    .untilAsserted(() -> assertThat(worker.getProcessedCount()).isEqualTo(3));
}
```

> Execution count, timeout testing -> `references/advanced-examples.md`

---

## Section 3: Configuration Properties Testing (ApplicationContextRunner)

**`ApplicationContextRunner`** — no full context, fast binding tests. `@Validated` for constraints. Type conversion: Duration/DataSize/List/Map.

```java
@ConfigurationProperties(prefix = "app.security") @Data
public class SecurityProperties {
  private String jwtSecret; private long jwtExpirationMs;
  private int maxLoginAttempts; private boolean enableTwoFactor;
}

// Basic binding
@Test void shouldBindProperties() {
  new ApplicationContextRunner()
    .withPropertyValues("app.security.jwtSecret=key", "app.security.jwtExpirationMs=3600000")
    .withBean(SecurityProperties.class)
    .run(ctx -> assertThat(ctx.getBean(SecurityProperties.class).getJwtSecret()).isEqualTo("key"));
}

// Validation constraints: @Validated
@ConfigurationProperties(prefix = "app.server") @Validated @Data
public class ServerProperties { @NotBlank private String host; @Min(1) @Max(65535) private int port = 8080; }
@Test void shouldFailWhenHostBlank() {
  new ApplicationContextRunner().withPropertyValues("app.server.host=", "app.server.port=8080")
    .withBean(ServerProperties.class)
    .run(ctx -> assertThat(ctx).hasFailed().getFailure().hasMessageContaining("host"));
}

// Type conversion: Duration, DataSize
@ConfigurationProperties(prefix = "app.features") @Data
public class FeatureProperties {
  private Duration cacheExpiry = Duration.ofMinutes(10);
  private DataSize maxUploadSize = DataSize.ofMegabytes(100);
}
@Test void shouldConvertTypes() {
  new ApplicationContextRunner()
    .withPropertyValues("app.features.cacheExpiry=30s", "app.features.maxUploadSize=50MB")
    .withBean(FeatureProperties.class)
    .run(ctx -> {
      FeatureProperties p = ctx.getBean(FeatureProperties.class);
      assertThat(p.getCacheExpiry()).isEqualTo(Duration.ofSeconds(30));
    });
}
```

> Nested properties, profiles, Map binding -> `references/advanced-examples.md`

---

## Section 4: JSON Serialization Testing (@JsonTest)

**`@JsonTest`** — only Jackson Beans. `JacksonTester<T>` type-safe assertions. Assert by JSON Path, NOT full string.

```java
@JsonTest
class UserDTOJsonTest {
  @Autowired JacksonTester<UserDTO> json;

  @Test void shouldSerialize() throws Exception {
    json.write(new UserDTO(1L, "Alice", "a@b.com"))
      .extractingJsonPathStringValue("$.name").isEqualTo("Alice");
  }
  @Test void shouldDeserialize() throws Exception {
    assertThat(json.parse("{\"id\":1,\"name\":\"Alice\"}").getObject().getName()).isEqualTo("Alice");
  }
}

// @JsonProperty / @JsonIgnore
public class Order {
  @JsonProperty("order_id") private Long id;
  @JsonIgnore private String internalNote;
}
@Test void shouldIgnoreInternal() throws Exception {
  assertThat(json.write(order).json).doesNotContain("internalNote");
}

// Polymorphism: @JsonTypeInfo
@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, property = "type")
@JsonSubTypes({ @JsonSubTypes.Type(value = CreditCard.class, name = "credit_card") })
public abstract class PaymentMethod {}
@Test void shouldDeserializeSubtype() throws Exception {
  assertThat(json.parse("{\"type\":\"credit_card\",\"id\":\"c1\"}").getObject()).isInstanceOf(CreditCard.class);
}
```

> DateTime, Custom Serializer, Null -> `references/advanced-examples.md`

---

## Section 5: Caching Testing (@SpringBootTest + @EnableCaching)

**`@Cacheable` depends on AOP proxy** — use `@SpringBootTest` + `@EnableCaching`. `ConcurrentMapCacheManager` (no Redis). `@MockitoBean` Repository to verify hit/miss. `@BeforeEach` clear cache.

```java
// COLA-style: UserServiceI -> UserServiceImpl, Result<T>
public interface UserServiceI { Result<User> getUserById(Long id); }

@Service
public class UserServiceImpl implements UserServiceI {
  @Cacheable("users")
  public Result<User> getUserById(Long id) {
    return Result.success(userRepository.findById(id).orElse(null));
  }
}

@SpringBootTest @EnableCaching
class UserServiceCachingTest {
  @Configuration @EnableCaching
  static class Config { @Bean CacheManager cm() { return new ConcurrentMapCacheManager("users"); } }

  @MockitoBean UserRepository userRepository;
  @Autowired UserServiceI userService;
  @Autowired CacheManager cacheManager;

  @BeforeEach void clear() { cacheManager.getCache("users").clear(); }

  @Test void shouldCacheHit() {
    when(userRepository.findById(1L)).thenReturn(Optional.of(new User(1L, "Alice")));
    userService.getUserById(1L); userService.getUserById(1L);
    verify(userRepository, times(1)).findById(1L);
  }
  @Test void shouldCacheMissAfterEviction() {
    when(userRepository.findById(1L)).thenReturn(Optional.of(new User(1L, "Alice")));
    userService.getUserById(1L);
    cacheManager.getCache("users").clear();
    userService.getUserById(1L);
    verify(userRepository, times(2)).findById(1L);
  }
}

// @CacheEvict
@Test void shouldEvictOnDelete() {
  productService.getProductById(1L); productService.getProductById(1L);
  verify(repo, times(1)).findById(1L);
  productService.deleteProduct(1L);
  productService.getProductById(1L);
  verify(repo, times(2)).findById(1L);
}

// Conditional cache: unless / condition
@Cacheable(value = "data", unless = "#result == null")
public Result<Data> getData(Long id) { ... }
@Test void shouldNotCacheNull() {
  service.getData(999L); service.getData(999L);
  verify(repo, times(2)).findById(999L);
}

// Composite key: SpEL
@Cacheable(value = "inv", key = "#productId + '-' + #warehouseId")
@Test void shouldUseCompoundKey() {
  service.getInventory(1L, 1L); service.getInventory(1L, 1L);
  verify(repo, times(1)).findByProductAndWarehouse(1L, 1L);
  service.getInventory(2L, 1L); // different key -> cache miss
}
```

> @CachePut, @CacheEvict(allEntries) -> `references/advanced-examples.md`

---

## Constraints

| Scenario | NOT | Instead |
|------|------|------|
| Events | NOT assume listener order → `@Order`; NOT `Thread.sleep()` | Awaitility |
| Async | NOT self-invoke `@Async` (bypasses proxy) | call through injected bean |
| CF | NOT `.get()` without timeout | `.get(timeout, unit)` |
| Scheduled | NOT assume execution order | `ThreadPoolTaskScheduler` |
| Config | NOT skip `@Validated` → validation silently ignored | always add `@Validated` |
| JSON | NOT use `@JsonTest` for circular refs | `@JsonManagedReference`/`@JsonBackReference` |
| Caching | NOT `this.method()` (bypasses proxy); NOT cache null by default | `unless = "#result == null"` |

## Troubleshooting

| Symptom | Fix |
|---------|------|
| Event not consumed | Event type must match Listener parameter |
| CF hangs | `.get(timeout, unit)`; check thread pool |
| Property binding fails | Check prefix + kebab-case |
| JSON assertion fails | Check `@JsonProperty` spelling |
| Cache not working | Confirm `@EnableCaching`; confirm NOT `this.method()` |

## References

- Advanced examples: `references/advanced-examples.md`

## Related Skills

- `spring-boot-event-driven-patterns` | `spring-boot-async-processing` | `spring-boot-scheduled-tasks`
- `spring-boot-configuration-management` | `spring-boot-openapi-documentation` | `spring-boot-jetcache`

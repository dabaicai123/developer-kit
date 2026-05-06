# Spring Boot Slice Testing — Advanced Examples

## 1. Application Events

### Error Scenario Testing

```java
@Test
void shouldNotThrowWhenEmailServiceFails() {
  EmailServiceI emailService = mock(EmailServiceI.class);
  doThrow(new RuntimeException("down")).when(emailService).sendWelcomeEmail(any());

  UserEventListener listener = new UserEventListener(emailService);
  assertThatCode(() -> listener.onUserCreated(new UserCreatedEvent(user)))
    .doesNotThrowAnyException();
}
```

## 2. Scheduled & Async

### Maven Dependencies

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter</artifactId>
</dependency>
<dependency>
  <groupId>org.junit.jupiter</groupId>
  <artifactId>junit-jupiter</artifactId>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.awaitility</groupId>
  <artifactId>awaitility</artifactId>
  <scope>test</scope>
</dependency>
<dependency>
  <groupId>org.assertj</groupId>
  <artifactId>assertj-core</artifactId>
  <scope>test</scope>
</dependency>
```

### Gradle Dependencies

```kotlin
dependencies {
  implementation("org.springframework.boot:spring-boot-starter")
  testImplementation("org.junit.jupiter:junit-jupiter")
  testImplementation("org.awaitility:awaitility")
  testImplementation("org.assertj:assertj-core")
}
```

### Async with Mocked Dependencies

```java
@ExtendWith(MockitoExtension.class)
class UserNotificationServiceAsyncTest {
  @Mock EmailServiceI emailService;
  @Mock SmsService smsService;
  @InjectMocks UserNotificationServiceImpl notificationService;

  @Test
  void shouldNotifyUserAsynchronously() throws Exception {
    CompletableFuture<Result<String>> result = notificationService.notifyUserAsync("user123");
    assertThat(result.get(5, TimeUnit.SECONDS).getData()).isEqualTo("Notification sent");
    verify(emailService).send("user123");
    verify(smsService).send("user123");
  }
}
```

### Scheduled Task Execution Count

```java
@Component
public class HealthCheckTask {
  private final HealthCheckService healthCheckService;
  private int executionCount = 0;

  @Scheduled(fixedRate = 5000)
  public void checkHealth() {
    executionCount++;
    healthCheckService.check();
  }
}

@Test
void shouldExecuteMultipleTimes() {
  HealthCheckService mockService = mock(HealthCheckService.class);
  HealthCheckTask task = new HealthCheckTask(mockService);
  task.checkHealth();
  task.checkHealth();
  task.checkHealth();
  assertThat(task.getExecutionCount()).isEqualTo(3);
  verify(mockService, times(3)).check();
}
```

### Awaitility Timeout Testing

```java
@Test
void shouldTimeoutWhenProcessingTakesTooLong() {
  BackgroundWorker worker = new BackgroundWorker();
  worker.processItems(List.of("item1"));
  assertThatThrownBy(() ->
    Awaitility.await().atMost(Duration.ofMillis(100)).until(() -> worker.getProcessedCount() == 10)
  ).isInstanceOf(ConditionTimeoutException.class);
}
```

## 3. Configuration Properties

### Nested Properties

```java
@ConfigurationProperties(prefix = "app.database")
@Data
public class DatabaseProperties {
  private String url;
  private String username;
  private Pool pool = new Pool();
  private List<Replica> replicas = new ArrayList<>();

  @Data
  public static class Pool {
    private int maxSize = 10;
    private int minIdle = 5;
    private long connectionTimeout = 30000;
  }

  @Data
  public static class Replica {
    private String name;
    private String url;
    private int priority;
  }
}

@Test
void shouldBindNestedProperties() {
  new ApplicationContextRunner()
    .withPropertyValues(
      "app.database.url=jdbc:mysql://localhost/db",
      "app.database.username=admin",
      "app.database.pool.maxSize=20",
      "app.database.pool.minIdle=10"
    )
    .withBean(DatabaseProperties.class)
    .run(ctx -> {
      DatabaseProperties p = ctx.getBean(DatabaseProperties.class);
      assertThat(p.getPool().getMaxSize()).isEqualTo(20);
    });
}

@Test
void shouldBindListOfReplicas() {
  new ApplicationContextRunner()
    .withPropertyValues(
      "app.database.replicas[0].name=replica-1",
      "app.database.replicas[0].url=jdbc:mysql://replica1/db",
      "app.database.replicas[0].priority=1"
    )
    .withBean(DatabaseProperties.class)
    .run(ctx -> {
      assertThat(ctx.getBean(DatabaseProperties.class).getReplicas()).hasSize(1);
    });
}
```

### Profile-Specific Configurations

```java
@Configuration @Profile("prod")
class ProductionConfiguration {
  @Bean
  public SecurityProperties securityProperties() {
    SecurityProperties props = new SecurityProperties();
    props.setEnableTwoFactor(true);
    props.setMaxLoginAttempts(3);
    return props;
  }
}

@Test
void shouldLoadProductionConfig() {
  new ApplicationContextRunner()
    .withPropertyValues("spring.profiles.active=prod")
    .withUserConfiguration(ProductionConfiguration.class)
    .run(ctx -> {
      SecurityProperties p = ctx.getBean(SecurityProperties.class);
      assertThat(p.isEnableTwoFactor()).isTrue();
      assertThat(p.getMaxLoginAttempts()).isEqualTo(3);
    });
}
```

### Map-Based Properties

```java
@ConfigurationProperties(prefix = "app.feature-flags")
@Data
public class FeatureFlagProperties {
  private Map<String, Boolean> flags = new HashMap<>();
  private Map<String, FeatureConfig> features = new HashMap<>();

  @Data
  public static class FeatureConfig {
    private boolean enabled;
    private String description;
  }
}

@Test
void shouldBindBooleanMap() {
  new ApplicationContextRunner()
    .withPropertyValues(
      "app.feature-flags.flags.dark-mode=true",
      "app.feature-flags.flags.beta-features=false"
    )
    .withBean(FeatureFlagProperties.class)
    .run(ctx -> {
      assertThat(ctx.getBean(FeatureFlagProperties.class).getFlags())
        .containsEntry("dark-mode", true);
    });
}
```

### DataSize and Duration Advanced

```java
@ConfigurationProperties(prefix = "app.upload")
@Data
public class UploadProperties {
  private DataSize maxFileSize = DataSize.ofMegabytes(10);
  private DataSize maxTotalSize = DataSize.ofGigabytes(1);
  private Duration timeout = Duration.ofSeconds(30);
}

@Test
void shouldConvertVariousDurationFormats() {
  new ApplicationContextRunner()
    .withPropertyValues(
      "app.upload.timeout=2h30m",
      "app.upload.maxFileSize=25MB",
      "app.upload.maxTotalSize=5GB"
    )
    .withBean(UploadProperties.class)
    .run(ctx -> {
      UploadProperties p = ctx.getBean(UploadProperties.class);
      assertThat(p.getTimeout()).isEqualTo(Duration.ofHours(2).plusMinutes(30));
      assertThat(p.getMaxFileSize()).isEqualTo(DataSize.ofMegabytes(25));
    });
}
```

## 4. JSON Serialization

### Date/Time Formatting

```java
@JsonTest
class DateTimeJsonTest {
  @Autowired JacksonTester<Event> json;

  @Test
  void shouldFormatDateTime() throws Exception {
    LocalDateTime dt = LocalDateTime.of(2024, 1, 15, 10, 30, 0);
    json.write(new Event("Conference", dt))
      .extractingJsonPathStringValue("$.scheduledAt").isEqualTo("2024-01-15T10:30:00");
  }
}
```

### Custom Serializer

```java
public class CustomMoneySerializer extends JsonSerializer<BigDecimal> {
  @Override
  public void serialize(BigDecimal value, JsonGenerator gen, SerializerProvider serializers) throws IOException {
    gen.writeString(value == null ? null : String.format("$%.2f", value));
  }
}

@JsonTest
class CustomSerializerTest {
  @Autowired JacksonTester<Price> json;

  @Test
  void shouldUseCustomSerializer() throws Exception {
    json.write(new Price(new BigDecimal("99.99")))
      .extractingJsonPathStringValue("$.amount").isEqualTo("$99.99");
  }
}
```

### Null Handling

```java
@Test
void shouldHandleNullFields() throws Exception {
  UserDTO user = json.parse("{\"id\":1,\"name\":null,\"email\":\"alice@example.com\"}").getObject();
  assertThat(user.getName()).isNull();
}
```

## 5. Caching

### @CachePut

```java
@Service
public class OrderServiceImpl implements OrderServiceI {
  @Cacheable("orders")
  public Result<Order> getOrder(Long id) {
    return Result.success(orderRepository.findById(id).orElse(null));
  }

  @CachePut(value = "orders", key = "#order.id")
  public Result<Order> updateOrder(Order order) {
    return Result.success(orderRepository.save(order));
  }
}

@SpringBootTest @EnableCaching
class OrderCachePutTest {
  @Configuration @EnableCaching
  static class TestConfig {
    @Bean CacheManager cacheManager() { return new ConcurrentMapCacheManager("orders"); }
  }

  @MockitoBean OrderRepository orderRepository;
  @Autowired OrderServiceI orderService;

  @Test
  void shouldUpdateCacheOnPut() {
    Order original = new Order(1L, "Pending", 100.0);
    Order updated = new Order(1L, "Shipped", 100.0);
    when(orderRepository.findById(1L)).thenReturn(Optional.of(original));
    when(orderRepository.save(updated)).thenReturn(updated);

    orderService.getOrder(1L);      // cache original
    orderService.updateOrder(updated); // @CachePut updates cache
    verify(orderRepository, times(1)).findById(1L); // only initial call hits repository
  }
}
```

### @CacheEvict(allEntries = true)

```java
@Test
void shouldClearAllEntries() {
  when(productRepository.findById(anyLong())).thenAnswer(i ->
    Optional.of(new Product(i.getArgument(0), "Product", 10.0)));

  productService.getProductById(1L);
  productService.getProductById(2L);
  productService.clearAllProducts(); // @CacheEvict(allEntries = true)

  productService.getProductById(1L);
  productService.getProductById(2L);
  verify(productRepository, times(4)).findById(anyLong());
}
```

## References

- [Spring Boot ConfigurationProperties](https://docs.spring.io/spring-boot/docs/current/reference/html/configuration-metadata.html)
- [ApplicationContextRunner Testing](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/test/context/runner/ApplicationContextRunner.html)
- [Spring Boot Validation](https://docs.spring.io/spring-boot/docs/current/reference/html/features.html#features.validation)
- [Relaxed Binding](https://docs.spring.io/spring-boot/docs/current/reference/html/configuration-metadata.html#configuration-metadata.annotation-processor)
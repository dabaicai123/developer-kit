# Spring Boot Dependency Injection - Examples

> **Target**: Java 17+, Spring Boot 3.5.x, Jakarta EE 10. All examples assume constructor-first injection with Spring Framework 6.x semantics.

## Example 1: Constructor Injection (Recommended)

The preferred pattern for mandatory dependencies.

```java
// With Lombok @RequiredArgsConstructor (RECOMMENDED)
@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;

    public User registerUser(CreateUserRequest request) {
        log.info("Registering user: {}", request.getEmail());
        
        User user = User.builder()
            .email(request.getEmail())
            .name(request.getName())
            .password(passwordEncoder.encode(request.getPassword()))
            .build();
        
        User saved = userRepository.save(user);
        emailService.sendWelcomeEmail(saved.getEmail());
        
        return saved;
    }
}

// Without Lombok (Explicit)
@Service
public class UserService {
    private final UserRepository userRepository;
    private final EmailService emailService;
    private final PasswordEncoder passwordEncoder;

    // Single constructor → @Autowired inferred automatically (Spring 4.3+)
    public UserService(UserRepository userRepository,
                      EmailService emailService,
                      PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.emailService = emailService;
        this.passwordEncoder = passwordEncoder;
        // Spring constructor injection already guarantees non-null;
        // Objects.requireNonNull is redundant here.
    }

    public User registerUser(CreateUserRequest request) {
        // Implementation
    }
}
```

### Test (Easy - No Spring Needed)

```java
@Test
void shouldRegisterUserAndSendEmail() {
    // Arrange - Create mocks manually
    UserRepository mockRepository = mock(UserRepository.class);
    EmailService mockEmailService = mock(EmailService.class);
    PasswordEncoder mockEncoder = mock(PasswordEncoder.class);
    
    UserService service = new UserService(mockRepository, mockEmailService, mockEncoder);
    
    User user = User.builder().email("test@example.com").build();
    when(mockRepository.save(any())).thenReturn(user);
    when(mockEncoder.encode("password")).thenReturn("encoded");

    // Act
    User result = service.registerUser(new CreateUserRequest("test@example.com", "Test", "password"));

    // Assert
    assertThat(result.getEmail()).isEqualTo("test@example.com");
    verify(mockEmailService).sendWelcomeEmail("test@example.com");
}
```

---

## Example 2: Optional Dependencies with ObjectProvider and No-op Fallback

Use `ObjectProvider<T>` with a no-op default for optional dependencies. This avoids null checks scattered throughout the class and keeps behavior deterministic when the optional bean is absent.

```java
@Service
public class ReportService {
    private final ReportRepository reportRepository;
    private final NotificationGateway notificationGateway;

    // Single constructor → @Autowired inferred automatically
    public ReportService(
            ReportRepository reportRepository,
            ObjectProvider<NotificationGateway> notificationGatewayProvider) {
        this.reportRepository = reportRepository;
        // No-op fallback: behavior is deterministic even when no NotificationGateway bean exists
        this.notificationGateway = notificationGatewayProvider.getIfAvailable(NotificationGateway::noOp);
    }

    public Report generateReport(ReportRequest request) {
        Report report = reportRepository.create(request.getTitle());
        // No null check needed — noOp implementation handles absence gracefully
        notificationGateway.sendReportNotification(report);
        return report;
    }
}

// No-op implementation ensures deterministic behavior when feature is absent
public class NoOpNotificationGateway implements NotificationGateway {
    @Override
    public void sendReportNotification(Report report) {
        // intentionally empty — caller does not need to know whether notifications are enabled
    }

    public static NotificationGateway noOp() {
        return new NoOpNotificationGateway();
    }
}
```

> **Why this over `@Autowired(required = false)` setter injection**: Nullable setters force `if (x != null)` checks throughout the class, making behavior unpredictable. `ObjectProvider` + no-op keeps optional behavior explicit and deterministic without leaking null handling.

> **Alternative**: `Optional<T>` in constructor parameters also works for optional dependencies. Spring injects `Optional.empty()` when no matching bean exists:
> ```java
> public ReportService(ReportRepository repo, Optional<NotificationGateway> gatewayOpt) {
>     this.reportRepository = repo;
>     this.notificationGateway = gatewayOpt.orElse(NotificationGateway.noOp());
> }
> ```

---

## Example 3: Configuration with Third-party Bean Definitions

Use `@Configuration` and `@Bean` when the object comes from a third-party library or needs conditional creation logic. Spring Boot 3.5 auto-configures DataSource, JpaTransactionManager, and other infrastructure beans — only override when you need custom behavior.

```java
@Configuration
public class AppConfig {

    // Third-party library bean — not auto-configured by Spring Boot
    @Bean
    public RestTemplate restTemplate(RestTemplateBuilder builder) {
        return builder
            .rootUri("https://api.example.com")
            .setConnectTimeout(Duration.ofSeconds(5))
            .setReadTimeout(Duration.ofSeconds(30))
            .build();
    }

    // Conditional creation — only when feature is enabled
    @Bean
    @ConditionalOnProperty(name = "feature.notifications.enabled", havingValue = "true")
    public NotificationClient notificationClient(@Value("${notification.api-key}") String apiKey) {
        return new NotificationClient(apiKey);
    }

    // Repository adapter — bridges domain interface to infrastructure implementation
    @Bean
    public UserRepository userRepository(UserJpaRepository jpaRepository) {
        return new UserRepositoryAdapter(jpaRepository);
    }

    // Service composition — explicit wiring for complex dependency graphs
    @Bean
    public UserService userService(UserRepository repository, NotificationClient client) {
        return new UserService(repository, client);
    }
}
```

> **Rule**: Business services should not know how infrastructure collaborators are instantiated. Keep creation logic in `@Configuration` classes.

---

## Example 4: Resolving Ambiguities with `@`Qualifier

```java
@Configuration
public class DataSourceConfig {
    
    @Bean(name = "primaryDB")
    public DataSource primaryDataSource() {
        return new HikariDataSource();
    }

    @Bean(name = "secondaryDB")
    public DataSource secondaryDataSource() {
        return new HikariDataSource();
    }
}

@Service
public class MultiDatabaseService {
    private final DataSource primaryDataSource;
    private final DataSource secondaryDataSource;

    // Using @Qualifier to resolve ambiguity
    public MultiDatabaseService(
            @Qualifier("primaryDB") DataSource primary,
            @Qualifier("secondaryDB") DataSource secondary) {
        this.primaryDataSource = primary;
        this.secondaryDataSource = secondary;
    }

    public void performOperation() {
        // Use primary for writes
        executeUpdate(primaryDataSource);
        
        // Use secondary for reads
        executeQuery(secondaryDataSource);
    }
}

// Alternative: Using @Primary
@Configuration
public class PrimaryDataSourceConfig {
    
    @Bean
    @Primary  // This bean is preferred when multiple exist
    public DataSource primaryDataSource() {
        return new HikariDataSource();
    }

    @Bean
    public DataSource secondaryDataSource() {
        return new HikariDataSource();
    }
}
```

---

## Example 5: Conditional Bean Registration

```java
@Configuration
public class OptionalFeatureConfig {

    // Only create if feature is enabled
    @Bean
    @ConditionalOnProperty(name = "feature.notifications.enabled", havingValue = "true")
    public NotificationService notificationService() {
        return new EmailNotificationService();
    }

    // Fallback if no other bean exists
    @Bean
    @ConditionalOnMissingBean(NotificationService.class)
    public NotificationService defaultNotificationService() {
        return new NoOpNotificationService();
    }

    // Only create if class is on classpath
    @Bean
    @ConditionalOnClass(RedisTemplate.class)
    public CacheService cacheService() {
        return new RedisCacheService();
    }
}

@Service
public class OrderService {
    private final NotificationService notificationService;

    public OrderService(NotificationService notificationService) {
        this.notificationService = notificationService;  // Works regardless of implementation
    }

    public void createOrder(Order order) {
        // Always works, but behavior depends on enabled features
        notificationService.sendConfirmation(order);
    }
}
```

---

## Example 6: Profiles and Environment-Specific Configuration

```java
@Configuration
@Profile("production")
public class ProductionConfig {

    @Bean
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://prod-db:5432/production");
        config.setMaximumPoolSize(30);
        config.setMaxLifetime(1800000);  // 30 minutes
        return new HikariDataSource(config);
    }

    @Bean
    public SecurityService securityService() {
        return new StrictSecurityService();
    }
}

@Configuration
@Profile("test")
public class TestConfig {

    @Bean
    public DataSource dataSource() {
        return new EmbeddedDatabaseBuilder()
            .setType(EmbeddedDatabaseType.H2)
            .addScript("classpath:schema.sql")
            .addScript("classpath:test-data.sql")
            .build();
    }

    @Bean
    public SecurityService securityService() {
        return new PermissiveSecurityService();
    }
}

@Configuration
@Profile("development")
public class DevelopmentConfig {

    @Bean
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setJdbcUrl("jdbc:postgresql://localhost:5432/dev");
        return new HikariDataSource(config);
    }

    @Bean
    public SecurityService securityService() {
        return new DebugSecurityService();
    }
}
```

**Usage:**
```bash
export SPRING_PROFILES_ACTIVE=production
# or in application.properties:
# spring.profiles.active=production
```

---

## Example 7: Lazy Initialization

```java
@Slf4j
@Configuration
public class ExpensiveResourceConfig {

    @Bean
    @Lazy  // Created only when first accessed
    public ExpensiveService expensiveService() {
        log.info("ExpensiveService initialized (lazy)");
        return new ExpensiveService();
    }

    @Bean
    public NormalService normalService(ExpensiveService expensive) {
        // ExpensiveService not created yet — lazy proxy injected here
        return new NormalService(expensive);
    }
}

@SpringBootTest
class LazyInitializationTest {
    @Test
    void shouldInitializeExpensiveServiceLazy() {
        ApplicationContext context = new AnnotationConfigApplicationContext(ExpensiveResourceConfig.class);
        
        // ExpensiveService not initialized yet
        assertThat(context.getBean(NormalService.class)).isNotNull();
        
        // Now ExpensiveService is initialized
        ExpensiveService service = context.getBean(ExpensiveService.class);
        assertThat(service).isNotNull();
    }
}
```

---

## Example 8: Circular Dependency Resolution with Events

```java
// ❌ BAD - Circular dependency
@Service
public class UserService {
    private final OrderService orderService;
    
    public UserService(OrderService orderService) {
        this.orderService = orderService;  // Circular!
    }
}

@Service
public class OrderService {
    private final UserService userService;
    
    public OrderService(UserService userService) {
        this.userService = userService;  // Circular!
    }
}

// ✅ GOOD - Use events to decouple (Spring Framework 6.x: publish any object, no ApplicationEvent subclass needed)
public record UserRegisteredEvent(String userId) {}

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserRepository userRepository;
    private final ApplicationEventPublisher eventPublisher;

    public User registerUser(CreateUserRequest request) {
        User user = userRepository.save(User.create(request));
        // Publish any POJO/record — Spring Framework 6.x does not require ApplicationEvent subclass
        eventPublisher.publishEvent(new UserRegisteredEvent(user.getId()));
        return user;
    }
}

@Service
@RequiredArgsConstructor
public class OrderService {
    private final OrderRepository orderRepository;

    @EventListener
    public void onUserRegistered(UserRegisteredEvent event) {
        Order welcomeOrder = Order.createWelcomeOrder(event.userId());
        orderRepository.save(welcomeOrder);
    }
}
```

> **Spring Framework 6.x improvement**: You no longer need to extend `ApplicationEvent`. Use a Java record or plain POJO as the event object — `ApplicationEventPublisher.publishEvent(Object)` accepts any type. This makes events lighter, immutable (with records), and easier to test.

---

## Example 9: Component Scanning

> In Spring Boot 3.5, `@SpringBootApplication` already includes `@ComponentScan` for the main class's package and sub-packages. Explicit `@ComponentScan` is only needed when you must scan packages outside the main class's hierarchy or apply custom filters.

```java
// Typical Spring Boot app — @ComponentScan is implicit
@SpringBootApplication  // Implies @ComponentScan("package.of.main.class")
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

// Explicit scan — ONLY when scanning packages outside the main class hierarchy
@Configuration
@ComponentScan(basePackages = {
    "com.example.users",
    "com.example.products",
    "com.example.orders"
})
public class AppConfig {
}

// Exclude packages — rarely needed, but available for edge cases
@Configuration
@ComponentScan(basePackages = "com.example",
    excludeFilters = @ComponentScan.Filter(type = FilterType.REGEX,
        pattern = "com\\.example\\.internal\\..*"))
public class AppConfig {
}
```

---

## Example 10: Testing with Constructor Injection

```java
// ❌ Service with field injection (hard to test)
@Service
public class BadUserService {
    @Autowired
    private UserRepository userRepository;
    
    public User getUser(Long id) {
        return userRepository.findById(id).orElse(null);
    }
}

@Test
void testBadService() {
    // Must use Spring to test this
    UserService service = new BadUserService();
    // Can't inject mocks without reflection or Spring
}

// ✅ Service with constructor injection (easy to test)
@Service
@RequiredArgsConstructor
public class GoodUserService {
    private final UserRepository userRepository;
    
    public User getUser(Long id) {
        return userRepository.findById(id).orElse(null);
    }
}

@Test
void testGoodService() {
    // Can test directly without Spring
    UserRepository mockRepository = mock(UserRepository.class);
    UserService service = new GoodUserService(mockRepository);
    
    User mockUser = new User(1L, "Test");
    when(mockRepository.findById(1L)).thenReturn(Optional.of(mockUser));
    
    User result = service.getUser(1L);
    assertThat(result.getName()).isEqualTo("Test");
}

// Integration test
@SpringBootTest
@ActiveProfiles("test")
class UserServiceIntegrationTest {
    @Autowired
    private UserService userService;
    
    @Autowired
    private UserRepository userRepository;
    
    @Test
    void shouldFetchUserFromDatabase() {
        User user = User.create("test@example.com");
        userRepository.save(user);
        
        User retrieved = userService.getUser(user.getId());
        assertThat(retrieved.getEmail()).isEqualTo("test@example.com");
    }
}
```

These examples cover constructor injection (recommended), ObjectProvider for optional dependencies, configuration, conditional beans, events, testing patterns, and common best practices for dependency injection in Spring Boot 3.5.

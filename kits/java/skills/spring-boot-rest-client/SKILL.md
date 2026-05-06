---
name: spring-boot-rest-client
description: "Spring Boot HTTP client: RestClient configuration, YAML timeout/factory properties, error handling, OAuth2, @RestClientTest, MockServerRestClientCustomizer, OkHttp3/RestTemplate migration. Use when making external HTTP calls."
version: "2.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot REST Client Patterns

## When to use

- Choosing between RestClient, RestTemplate, and OkHttp3
- Configuring RestClient with timeouts, connection pooling, interceptors
- Testing RestClient with @RestClientTest or MockServerRestClientCustomizer
- Handling HTTP errors, retries, and resilience patterns
- Migrating from RestTemplate or OkHttp3 to RestClient

## HTTP Client Selection

| Client | Use for | Dependency | Spring Status |
|--------|---------|------------|---------------|
| **RestClient** | Default choice (synchronous) | `spring-boot-starter-web` | Recommended (Spring 6.1+) |
| **RestTemplate** | Legacy code maintenance | `spring-boot-starter-web` | Maintenance mode — prefer RestClient |
| **OkHttp3** | WebSocket / custom interceptor | Manual dependency + explicit version | NOT managed by Spring Boot parent |

Rules: Default to RestClient. Use RestTemplate only for legacy code; OkHttp3 only for WebSocket/custom interceptors (requires explicit version).

## RestClient Configuration

### Basic Setup

```java
@Configuration
public class RestClientConfig {

    @Bean
    public RestClient authRestClient(RestClient.Builder builder) {
        return builder
            .baseUrl("https://auth.example.com")
            .defaultHeader("Accept", MediaType.APPLICATION_JSON_VALUE)
            .build();
    }

    @Bean
    public RestClient paymentRestClient(RestClient.Builder builder) {
        return builder
            .baseUrl("https://payment.example.com")
            .build();
    }
}
```

### YAML Timeout and Factory (Spring Boot 3.4+)

Spring Boot 3.4+ supports `spring.http.client.*` properties for global timeout and HTTP client factory selection:

```yaml
spring:
  http:
    client:
      factory: http-components   # jdk | http-components | jetty | reactor-netty
      connect-timeout: 5s
      read-timeout: 10s
      redirects: follow
```

`factory: http-components` enables connection pooling and full timeout control. Without it, Spring Boot defaults to JDK HttpClient (no connection pooling).

Requires Apache HttpClient 5 on classpath when `factory: http-components`:

```xml
<dependency>
    <groupId>org.apache.httpcomponents.client5</groupId>
    <artifactId>httpclient5</artifactId>
</dependency>
```

Apache HttpClient 5 version is managed by `spring-boot-starter-parent`.

### Programmatic Timeout Override

Use when per-client timeout differs from global defaults:

```java
@Bean
public RestClient restClient(RestClient.Builder builder) {
    HttpComponentsClientHttpRequestFactory factory = new HttpComponentsClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofSeconds(5));
    factory.setConnectionRequestTimeout(Duration.ofSeconds(2));
    factory.setReadTimeout(Duration.ofSeconds(10));

    return builder
        .requestFactory(factory)
        .baseUrl("https://api.example.com")
        .build();
}
```

NOT override `ClientHttpRequestFactory` for global settings — use `spring.http.client.*` YAML properties instead. Programmatic override is for per-client customization only.

### Request Interceptor (Logging)

```java
@Bean
public RestClient restClient(RestClient.Builder builder) {
    return builder
        .requestInterceptor(new LoggingInterceptor())
        .baseUrl("https://api.example.com")
        .build();
}

public class LoggingInterceptor implements ClientHttpRequestInterceptor {
    @Override
    public ClientHttpResponse intercept(HttpRequest request, byte[] body, ClientHttpRequestExecution execution) throws IOException {
        log.debug("HTTP {} {} headers={}", request.getMethod(), request.getURI(), request.getHeaders());
        ClientHttpResponse response = execution.execute(request, body);
        log.debug("HTTP response status={}", response.getStatusCode());
        return response;
    }
}
```

### RestClientCustomizer for Cross-Cutting Config

`RestClientCustomizer` beans apply to all `RestClient.Builder` instances (prototype scoped):

```java
@Bean
RestClientCustomizer commonRestClientCustomizer() {
    return builder -> builder.defaultHeader("X-App-Name", "my-service");
}
```

NOT manually inject `RestClient.Builder` and set headers one-by-one — use `RestClientCustomizer` for common defaults.

## Usage Patterns

### GET Request

```java
@Component
@RequiredArgsConstructor
public class AuthClient {
    private final RestClient authRestClient;

    public UserInfo getUserInfo(String token) {
        return authRestClient.get()
            .uri("/user/info")
            .header("Authorization", "Bearer " + token)
            .retrieve()
            .body(UserInfo.class);
    }
}
```

### POST Request with Body

```java
public TokenResponse exchangeToken(String code) {
    return authRestClient.post()
        .uri("/oauth/token")
        .body(new TokenRequest(code, clientId, clientSecret))
        .retrieve()
        .body(TokenResponse.class);
}
```

### GET with Query Parameters

```java
public PageResult<ItemDTO> searchItems(String keyword, int page, int size) {
    return restClient.get()
        .uri(uriBuilder -> uriBuilder
            .path("/items")
            .queryParam("keyword", keyword)
            .queryParam("page", page)
            .queryParam("size", size)
            .build())
        .retrieve()
        .body(new ParameterizedTypeReference<PageResult<ItemDTO>>() {});
}
```

NOT use string concatenation for query parameters — `UriBuilder` handles encoding and ordering correctly. `Map.of()` does not guarantee parameter order.

### Error Handling

```java
public UserInfo getUserInfo(String token) {
    return authRestClient.get()
        .uri("/user/info")
        .header("Authorization", "Bearer " + token)
        .retrieve()
        .onStatus(HttpStatusCode::is4xxClientError, (request, response) -> {
            throw new BusinessException(response.getStatusCode().value(),
                "Client error from auth service: " + response.getStatusCode());
        })
        .onStatus(HttpStatusCode::is5xxServerError, (request, response) -> {
            throw new ServiceUnavailableException("Auth service");
        })
        .body(UserInfo.class);
}
```

## Testing

### @RestClientTest (Recommended)

`@RestClientTest` auto-configures Jackson, `RestClient.Builder`, and `MockRestServiceServer`:

```java
@RestClientTest(AuthClient.class)
class AuthClientTest {

    @Autowired
    private AuthClient authClient;

    @Autowired
    private MockRestServiceServer mockServer;

    @Test
    void shouldReturnUserInfo() {
        mockServer.expect(requestTo(containsString("/user/info")))
            .andExpect(method(HttpMethod.GET))
            .andRespond(withSuccess("{\"name\":\"Alice\"}", MediaType.APPLICATION_JSON));

        UserInfo info = authClient.getUserInfo("token123");
        assertThat(info.getName()).isEqualTo("Alice");

        mockServer.verify();
    }
}
```

NOT use `@SpringBootTest` for RestClient unit tests — `@RestClientTest` limits component scanning to the tested client only.

### MockServerRestClientCustomizer (Multiple Clients)

When multiple RestClient beans exist, inject `MockServerRestClientCustomizer` to bind a mock server to a specific builder:

```java
@ExtendWith(MockitoExtension.class)
class MultiClientTest {

    private MockServerRestClientCustomizer customizer;
    private RestClient restClient;
    private AuthClient authClient;

    @BeforeEach
    void setUp() {
        customizer = new MockServerRestClientCustomizer();
        RestClient.Builder builder = RestClient.builder();
        customizer.customize(builder);
        restClient = builder.baseUrl("https://auth.example.com").build();
        authClient = new AuthClient(restClient);
    }

    @Test
    void shouldReturnUserInfo() {
        customizer.getServer().expect(requestTo(containsString("/user/info")))
            .andRespond(withSuccess("{\"name\":\"Alice\"}", MediaType.APPLICATION_JSON));

        UserInfo info = authClient.getUserInfo("token123");
        assertThat(info.getName()).isEqualTo("Alice");
    }
}
```

NOT use `MockRestServiceServer.createServer(restClient)` — it is fragile with Spring Boot prototype-scoped `RestClient.Builder`. Use `MockServerRestClientCustomizer` for manual setup or `@RestClientTest` for single-client tests.

### URL Parameter Order Trap

NOT use exact URL string matching for query parameters — `Map.of()` and `UriComponentsBuilder` may reorder parameters:

```java
// WRONG: exact URL matching fails due to parameter order
mockServer.expect(requestTo("/api?key=value&name=test"))

// RIGHT: flexible matching ignores parameter order
mockServer.expect(requestTo(containsString("/api")))
    .andExpect(queryParam("key", equalTo("value")))
    .andExpect(queryParam("name", equalTo("test")));
```

## Declarative HTTP Clients

Spring Boot 3.2+ (Spring 6.1+) supports `@HttpExchange` interfaces via `HttpServiceProxyFactory`:

```java
@HttpExchange
public interface UserClient {
    @GetExchange("/users/{id}")
    User getUser(@PathVariable Long id);
}

@Configuration
public class ClientConfig {
    @Bean
    UserClient userClient(RestClient.Builder builder) {
        RestClient client = builder.baseUrl("https://api.example.com").build();
        return HttpServiceProxyFactory
            .builderFor(RestClientAdapter.create(client))
            .build()
            .createClient(UserClient.class);
    }
}
```

## Anti-patterns

- NOT use `MockRestServiceServer.createServer(restClient)` for testing — fragile with prototype-scoped builder; use `@RestClientTest` or `MockServerRestClientCustomizer`
- NOT use `@SpringBootTest` for RestClient unit tests — `@RestClientTest` limits context to the tested client
- NOT use exact URL string matching for MockRestServiceServer query parameters — use `containsString()` and `queryParam()` matchers
- NOT use string concatenation for query parameters — `UriBuilder` handles encoding and ordering
- NOT override `ClientHttpRequestFactory` for global timeout settings — use `spring.http.client.*` YAML properties
- NOT use RestTemplate for new code — it is in maintenance mode; RestClient is the recommended synchronous client
- NOT omit Apache HttpClient 5 when connection pooling or full timeout control is needed — add `httpclient5` dependency and set `spring.http.client.factory=http-components`
- NOT place external HTTP calls inside `@Transactional` — HTTP calls are not transactional resources

## Technical Constraints

- RestClient requires Spring 6.1+ (Spring Boot 3.2+)
- Spring Boot provides `RestClient.Builder` only (prototype scoped); NOT a singleton RestClient bean
- `RestClient.Builder` instances are prototype scoped — each injection gets a new builder
- OkHttp3 is NOT managed by `spring-boot-starter-parent` — requires explicit version
- Apache HttpClient 5 IS managed by `spring-boot-starter-parent` — version resolves automatically
- Mockito mocks return `null` for String by default; `anyString()` won't match null, use `any()`

## Related Skills

- `ddd-cola` — COLA architecture places HTTP clients in `infrastructure/external/`
- `spring-boot-exception-handling` — `onStatus()` error handling maps to `BusinessException`
- `spring-boot-resilience4j` — retry, circuit breaker, rate limiter for HTTP calls
- `spring-boot-transaction-management` — NOT place HTTP calls inside `@Transactional`

## Keywords

RestClient, RestTemplate, HTTP client, @RestClientTest, MockServerRestClientCustomizer, MockRestServiceServer, timeout, onStatus, UriBuilder, connection pooling, Apache HttpClient, OkHttp, declarative client, HttpServiceProxyFactory, spring.http.client.factory
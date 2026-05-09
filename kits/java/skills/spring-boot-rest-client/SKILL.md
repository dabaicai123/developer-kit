---
name: spring-boot-rest-client
description: "Spring Boot HTTP client best practices: RestClient configuration, timeout, error handling, OAuth2 integration, MockRestServiceServer testing, and OkHttp3/RestTemplate migration. Use when making external HTTP calls from Spring Boot services."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot REST Client Best Practices

## When to use this skill

- Choosing between RestClient, RestTemplate, and OkHttp3 for external API calls
- Configuring RestClient with timeouts, connection pooling, interceptors
- Testing RestClient calls with MockRestServiceServer or WireMock
- Integrating OAuth2 client credentials with HTTP client
- Handling HTTP errors, retries, and resilience patterns

## HTTP Client Selection

| Client | Use for | Dependency | Spring Status |
|--------|---------|------------|---------------|
| **RestClient** | Default choice (synchronous) | `spring-boot-starter-web` (already included) | **Recommended (Spring 6.1+)** |
| **RestTemplate** | Legacy code maintenance | `spring-boot-starter-web` | Maintenance mode — deprecated Spring 7.1 |
| **OkHttp3** | WebSocket / custom interceptor | Manual dependency + explicit version | Not managed by Spring Boot parent |

**Rules**: Default: RestClient. Use RestTemplate only for legacy code; OkHttp3 only for WebSocket/custom interceptors (requires explicit version).

## RestClient Configuration

### Basic Setup

RestClient uses `RestClient.Builder` (auto-configured by Spring Boot):

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

### Timeout Configuration

Spring Boot auto-detects the underlying HTTP client. For explicit timeout control:

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

Requires Apache HttpClient on classpath:

```xml
<dependency>
    <groupId>org.apache.httpcomponents.client5</groupId>
    <artifactId>httpclient5</artifactId>
</dependency>
```

> Apache HttpClient 5 is managed by `spring-boot-starter-parent`. If not on classpath, Spring Boot defaults
> to JDK HttpURLConnection (no connection pooling, limited timeout control).

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
}
```

> **Important**: Use `UriBuilder` for query parameters, not manual string concatenation.
> `Map.of()` does not guarantee parameter order; `UriBuilder` handles encoding and ordering correctly.

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

## Testing with MockRestServiceServer

### Basic Pattern

```java
@ExtendWith(MockitoExtension.class)
class AuthClientTest {

    @InjectMocks
    private AuthClient authClient;

    private MockRestServiceServer mockServer;
    private RestClient restClient;

    @BeforeEach
    void setUp() {
        restClient = RestClient.builder().baseUrl("https://auth.example.com").build();
        mockServer = MockRestServiceServer.createServer(restClient);
        authClient = new AuthClient(restClient);
    }

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

### URL Parameter Order Trap

`Map.of()` does not guarantee insertion order; `UriComponentsBuilder.queryParam()` may alphabetically sort.
Never use exact URL string matching for query parameters:

```java
// ❌ Exact URL matching — fails due to parameter order
mockServer.expect(requestTo("/api?key=value&name=test"))

// ✅ Flexible matching — ignores parameter order
mockServer.expect(requestTo(containsString("/api")))
    .andExpect(queryParam("key", equalTo("value")))
    .andExpect(queryParam("name", equalTo("test")));
```

## Declarative HTTP Clients

Spring Boot 3.x supports `@HttpExchange` interfaces via `HttpServiceProxyFactory`:

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


## Constraints and Warnings

- **RestClient requires Spring 6.1+ (Spring Boot 3.2+)** — not available in Spring Boot 2.x or Spring 5.x
- **MockRestServiceServer URL parameter order** — use `containsString()` and `queryParam()` matchers, not exact URLs
- **Mock default returns** — Mockito mocks return `null` for String by default; `anyString()` won't match null, use `any()`
- **OkHttp3 not managed by Spring Boot parent** — requires explicit `<version>` or `<properties>` entry
- **Apache HttpClient 5 is managed** — version resolves from `spring-boot-starter-parent`
- **No auto-configured RestClient bean** — Spring Boot provides `RestClient.Builder` only; you must create `@Bean` RestClient instances

## Related Skills

- `ddd-cola` — COLA architecture places HTTP clients in `infrastructure/external/`
- `spring-boot-exception-handling` — `onStatus()` error handling maps to `BusinessException`
- `spring-boot-resilience4j` — retry, circuit breaker, rate limiter for HTTP calls
- `unit-test-wiremock-rest-api` — WireMock testing patterns (alternative to MockRestServiceServer)
- `spring-boot-transaction-management` — external HTTP calls should NOT be inside `@Transactional`

## Keywords

RestClient, RestTemplate, HTTP client, MockRestServiceServer, WireMock, timeout, OAuth2, onStatus, UriBuilder, connection pooling, Apache HttpClient, OkHttp, declarative client, HttpServiceProxyFactory, virtual threads
---
name: unit-test-wiremock-rest-api
description: "Unit testing external REST APIs with WireMock: response stubs, request verification, failure simulation, HTTP client behavior validation."
version: "1.1.0"
type: skill
---

# Unit Testing REST APIs with WireMock

## When to use

- Testing services that call external REST APIs
- Stubbing HTTP responses for deterministic test behavior
- Verifying request details (headers, query params, body)
- Simulating error scenarios (timeouts, 4xx/5xx, malformed responses)

## Instructions

### 1. Add dependencies

**Spring Boot projects — use `@EnableWireMock` integration:**

```xml
<dependency>
    <groupId>org.wiremock.integrations</groupId>
    <artifactId>wiremock-spring-boot</artifactId>
    <scope>test</scope>
</dependency>
```

**Non-Spring tests — use standalone JUnit 5 extension:**

```xml
<dependency>
    <groupId>org.wiremock</groupId>
    <artifactId>wiremock</artifactId>
    <scope>test</scope>
</dependency>
```

NOT use `com.github.tomakehurst:wiremock-jre8` — legacy coordinate superseded by `org.wiremock:wiremock` since WireMock 3.x.

**Jetty 12 compatibility for Spring Boot 3.5:**

WireMock core ships Jetty 11; Spring Boot 3.5 uses Jetty 12. When running WireMock inside a Spring Boot test context, add the Jetty 12 variant — see [WireMock Jetty 12 docs](https://wiremock.org/docs/jetty-12/) for the dependency.

NOT skip this when using `@EnableWireMock` with `@SpringBootTest` — missing Jetty 12 causes `ClassNotFoundException` at startup.

### 2. Register WireMock

**Spring Boot `@EnableWireMock` (preferred for Spring Boot 3.5):**

```java
@SpringBootTest
@EnableWireMock({
    @ConfigureWireMock(name = "weather-api", baseUrlProperties = "weather-api.url")
})
class WeatherServiceTest {

    @Autowired
    private WeatherService weatherService;

    @Test
    void shouldFetchWeatherData() {
        stubFor(get(urlEqualTo("/weather?city=London"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody("{\"city\":\"London\",\"temperature\":15}")));

        assertThat(weatherService.getWeather("London").getCity()).isEqualTo("London");
    }
}
```

NOT use `@RegisterExtension WireMockExtension` inside `@SpringBootTest` — `@EnableWireMock` auto-injects base URL as a Spring property and handles port lifecycle.

**Standalone JUnit 5 extension (non-Spring tests):**

```java
import com.github.tomakehurst.wiremock.junit5.WireMockExtension;
import static com.github.tomakehurst.wiremock.core.WireMockConfiguration.wireMockConfig;
import org.junit.jupiter.api.extension.RegisterExtension;

class WeatherApiClientTest {

    @RegisterExtension
    static WireMockExtension wireMock = WireMockExtension.newInstance()
        .options(wireMockConfig().dynamicPort())
        .build();

    @Test
    void shouldFetchWeatherData() {
        wireMock.stubFor(get(urlEqualTo("/weather?city=London"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody("{\"city\":\"London\",\"temperature\":15}")));

        String baseUrl = wireMock.getRuntimeInfo().getHttpBaseUrl();
        WeatherApiClient client = new WeatherApiClient(baseUrl);
        assertThat(client.getWeather("London").getCity()).isEqualTo("London");
    }
}
```

NOT hardcode `http://localhost:8080` — always use `dynamicPort()` or Spring property injection to avoid port conflicts.

### 3. Stub, execute, verify

See `references/advanced-examples.md` for error scenarios, body verification, timeout simulation, and stateful testing.

## Best Practices

- One concern per test — NOT stub unrelated endpoints in one test method
- Always stub third-party endpoints — NOT call real external APIs in unit tests
- Use `urlEqualTo` for exact URL matching — NOT use `urlPathEqualTo` when query params matter

## Constraints

- Stub precedence: more specific matchers override general ones
- NOT rely on stub registration order — WireMock matches by specificity, not insertion order
- NOT use `@RegisterExtension` with `@SpringBootTest` — use `@EnableWireMock`
- Keep stubs aligned with actual API contracts — stale stubs hide integration drift

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Stub not matching | Check URL encoding, header names; use `urlEqualTo` for query params |
| `ClassNotFoundException` for Jetty/Servlet | Add WireMock Jetty 12 dependency |
| Tests hanging | Configure connection timeouts; use `withFixedDelay()` for timeout simulation |
| Port conflicts | Use `dynamicPort()` or `@EnableWireMock` |

## References

- `references/advanced-examples.md` — Error scenarios, body verification, timeouts

## Related Skills

- `spring-boot-rest-client`
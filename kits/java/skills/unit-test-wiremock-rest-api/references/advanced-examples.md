# WireMock Advanced Examples

Error scenarios, body verification, timeout simulation, fault injection, and stateful testing.

## Error Scenario Testing (4xx/5xx)

NOT only test happy paths — always verify error handling for external API calls.

```java
@Test
void shouldHandleNotFoundError() {
    stubFor(get(urlEqualTo("/api/users/999"))
        .willReturn(aResponse()
            .withStatus(404)
            .withBody("{\"error\":\"User not found\"}")));

    assertThatThrownBy(() -> client.getUser(999))
        .isInstanceOf(UserNotFoundException.class)
        .hasMessageContaining("User not found");
}

@Test
void shouldHandleServerError() {
    stubFor(get(urlEqualTo("/api/data"))
        .willReturn(aResponse()
            .withStatus(500)
            .withBody("{\"error\":\"Internal server error\"}")));

    assertThatThrownBy(() -> client.fetchData())
        .isInstanceOf(ServerErrorException.class);
}
```

## Request Body Verification

NOT skip request verification — stubs confirm the response, `verify()` confirms the request was sent correctly.

```java
@Test
void shouldVerifyRequestBody() {
    stubFor(post(urlEqualTo("/api/users"))
        .willReturn(aResponse()
            .withStatus(201)
            .withBody("{\"id\":123,\"name\":\"Alice\"}")));

    UserResponse response = client.createUser("Alice");
    assertThat(response.getId()).isEqualTo(123);

    verify(postRequestedFor(urlEqualTo("/api/users"))
        .withRequestBody(matchingJsonPath("$.name", equalTo("Alice")))
        .withHeader("Content-Type", containing("application/json")));
}
```

## Timeout Simulation

NOT use `Thread.sleep()` to simulate slow responses — use WireMock `withFixedDelay()` for deterministic timeout testing.

```java
@Test
void shouldHandleTimeout() {
    stubFor(get(urlEqualTo("/api/slow"))
        .willReturn(aResponse()
            .withFixedDelay(5000)
            .withStatus(200)));

    // Client timeout < 5000ms
    assertThatThrownBy(() -> client.fetchSlowEndpoint())
        .isInstanceOf(SocketTimeoutException.class);
}
```

## Fault Injection

WireMock supports connection-level failures beyond simple delayed responses.

NOT only test HTTP status errors — network-level faults (connection reset, malformed response) can occur in production.

```java
@Test
void shouldHandleConnectionReset() {
    stubFor(get(urlEqualTo("/api/unstable"))
        .willReturn(aResponse().withFault(Fault.CONNECTION_RESET_BY_PEER)));

    assertThatThrownBy(() -> client.fetchUnstableEndpoint())
        .isInstanceOf(IOException.class);
}

@Test
void shouldHandleMalformedResponse() {
    stubFor(get(urlEqualTo("/api/malformed"))
        .willReturn(aResponse()
            .withStatus(200)
            .withFault(Fault.MALFORMED_RESPONSE_CHUNK)));

    assertThatThrownBy(() -> client.fetchMalformedEndpoint())
        .isInstanceOf(IOException.class);
}
```

## Scenarios (Stateful Behavior)

NOT use `Thread.sleep()` for polling tests — use WireMock scenarios for state transitions.

```java
@Test
void shouldSupportStatefulScenarios() {
    stubFor(get(urlEqualTo("/api/status"))
        .inScenario("OrderWorkflow")
        .whenScenarioStateIs(STARTED)
        .willSetStateTo("PROCESSING")
        .willReturn(aResponse()
            .withStatus(202)
            .withBody("{\"status\":\"processing\"}")));

    stubFor(get(urlEqualTo("/api/status"))
        .inScenario("OrderWorkflow")
        .whenScenarioStateIs("PROCESSING")
        .willSetStateTo("COMPLETED")
        .willReturn(aResponse()
            .withStatus(200)
            .withBody("{\"status\":\"completed\"}")));

    assertThat(client.getOrderStatus().getStatus()).isEqualTo("processing");
    assertThat(client.getOrderStatus().getStatus()).isEqualTo("completed");
}
```

## RestClient with @EnableWireMock (Spring Boot 3.5)

Spring Boot 3.5 prefers `RestClient` over `RestTemplate`. `@ConfigureWireMock(baseUrlProperties = "...")` auto-sets the base URL as a Spring property.

```java
@SpringBootTest
@EnableWireMock({
    @ConfigureWireMock(name = "user-api", baseUrlProperties = "user-api.url")
})
class UserServiceRestClientTest {

    @Autowired
    private UserService userService;

    @Test
    void shouldFetchUserViaRestClient() {
        stubFor(get(urlEqualTo("/api/users/1"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody("{\"id\":1,\"name\":\"Alice\"}")));

        User user = userService.getUser(1);
        assertThat(user.getName()).isEqualTo("Alice");
    }
}
```

NOT use `RestTemplate` for new code in Spring Boot 3.5 — use `RestClient` which provides a modern, fluent API. See `spring-boot-rest-client` skill for RestClient configuration and error handling patterns.
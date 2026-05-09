---
name: spring-boot-tdd
description: Test-driven development for Spring Boot using JUnit 5, Mockito, MockMvc, Testcontainers, and JaCoCo. Use when adding features, fixing bugs, or refactoring.
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot TDD Workflow

TDD guidance for Spring Boot services with 80%+ coverage (unit + integration).

## When to use this skill

- New features or endpoints
- Bug fixes or refactors
- Adding data access logic or security rules

## Workflow

1) Write tests first (they should fail)
2) Implement minimal code to pass
3) Refactor with tests green
4) Enforce coverage (JaCoCo)

## Test Strategies by Layer

> For detailed code examples per layer, see the dedicated testing skills:
> - `unit-test-service-layer` — Mockito patterns for service testing
> - `unit-test-controller-layer` — MockMvc patterns for REST controllers
> - `unit-test-mapper-converter` — MapStruct converter + MyBatis mapper testing

| Layer | Tool | Skill Reference |
|-------|------|-----------------|
| Service | Mockito + `@ExtendWith(MockitoExtension.class)` | `unit-test-service-layer` |
| Controller | `@WebMvcTest` + MockMvc | `unit-test-controller-layer` |
| Mapper | Testcontainers + `@SpringBootTest` | `unit-test-mapper-converter` |
| Integration | `@SpringBootTest` + `@AutoConfigureMockMvc` | This skill (see below) |

## Integration Test Pattern

```java
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MarketIntegrationTest {
  @Autowired MockMvc mockMvc;

  @Test
  void createsMarket() throws Exception {
    mockMvc.perform(post("/api/markets")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
          {"name":"Test","description":"Desc","endDate":"2030-01-01T00:00:00Z","categories":["general"]}
        """))
      .andExpect(status().isOk());
  }
}
```

## Coverage (JaCoCo)

Maven snippet:
```xml
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <version>0.8.14</version>
  <executions>
    <execution>
      <goals><goal>prepare-agent</goal></goals>
    </execution>
    <execution>
      <id>report</id>
      <phase>verify</phase>
      <goals><goal>report</goal></goals>
    </execution>
  </executions>
</plugin>
```

## Assertions

- Prefer AssertJ (`assertThat`) for readability
- For JSON responses, use `jsonPath`
- For exceptions: `assertThatThrownBy(...)`

## Mockito Pitfalls

### Strict Stubbing vs setUp()

When `@BeforeEach setUp()` stubs mocks globally (e.g., `when(strategy.supportedChannel()).thenReturn(...)`),
but some test paths throw exceptions before reaching the stubbed call, Mockito throws `UnnecessaryStubbingException`.

Fix options:
1. **Preferred**: Move stubs into each test method — keeps stubs minimal per scenario
2. `@MockitoSettings(strictness = Strictness.LENIENT)` on the test class — disables strict stubbing checks

```java
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PushCmdExeTest { ... }
```

### Mock Delegation Trap

**Mockito mock objects do NOT delegate internally** — calling `mock.method2Param()` on a mock will NOT invoke
`mock.method3Param()` even if the real `method2Param()` calls `method3Param()` internally. Each method signature
on a mock is independent; you must stub every method that will be called.

```java
// Real code: httpClient.postJson(url, body) internally calls httpClient.postJson(url, body, Map.of())
// ❌ Stubbing only the 2-param version — 3-param call returns null
when(httpClient.postJson(anyString(), anyString())).thenReturn(response);

// ✅ Stub BOTH signatures if both may be called
when(httpClient.postJson(anyString(), anyString())).thenReturn(response);
when(httpClient.postJson(anyString(), anyString(), anyMap())).thenReturn(response);
```

### Mock Default Returns

Mockito mocks return **default values** when a stub doesn't match:
- `String` → `null` (not empty string)
- `int/long` → `0`
- `boolean` → `false`

`anyString()` will NOT match `null`. If a mock method returns null by default, use `any()` instead of
`anyString()`, or stub the method explicitly to return a non-null value.

### MockRestServiceServer URL Parameter Ordering

When testing with `MockRestServiceServer`, never use exact URL string matching for query parameters.
`Map.of()` does not guarantee insertion order, and `UriComponentsBuilder.queryParam()` may alphabetically
sort parameters. Expected `key=value&name=test` may arrive as `name=test&key=value`.

```java
// Required Hamcrest imports
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;

// ❌ Exact URL matching — fails due to parameter order
mockServer.expect(requestTo("/api?key=value&name=test"))

// ✅ Flexible matching — ignores parameter order
mockServer.expect(requestTo(containsString("/api")))
  .andExpect(queryParam("key", equalTo("value")))
  .andExpect(queryParam("name", equalTo("test")));
```

## Test Data Builders

```java
class MarketBuilder {
  private String name = "Test";
  MarketBuilder withName(String name) { this.name = name; return this; }
  Market build() { return new Market(null, name, MarketStatus.ACTIVE); }
}
```

## CI Commands

- Maven: `mvn -T 4 test` or `mvn verify`
- Gradle: `./gradlew test jacocoTestReport`

**Remember**: Keep tests fast, isolated, and deterministic. Test behavior, not implementation details.

- **Verify imports after writing test files**: common missing imports include `java.util.Map`, Hamcrest matchers (`containsString`, `equalTo`), and sealed interface types

## Related Skills

- `unit-test-service-layer` — Mockito patterns for service layer testing
- `unit-test-controller-layer` — MockMvc patterns for REST controller testing
- `unit-test-bean-validation` — Jakarta Bean Validation testing
- `spring-boot-verification` — full build → lint → test → security scan pipeline
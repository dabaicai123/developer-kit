---
name: spring-boot-tdd
description: "TDD workflow for Spring Boot using JUnit 5, Mockito 5, MockMvc, Testcontainers, and JaCoCo. Use when adding features, fixing bugs, or refactoring."
version: "1.1.0"
---

# Spring Boot TDD Workflow

TDD for Spring Boot 3.5.x services with 80%+ coverage (unit + integration).

## When to use

- New features or endpoints
- Bug fixes or refactors
- Data access or security logic changes

## Workflow

1. Write failing test
2. Implement minimal passing code
3. Refactor while green
4. Enforce coverage via JaCoCo

## Test Strategies by Layer

| Layer | Tool | Reference |
|-------|------|-----------|
| Service | Mockito 5 + `@ExtendWith(MockitoExtension.class)` | `references/service-layer-testing.md` |
| Controller | `@WebMvcTest` + MockMvc | `references/controller-layer-testing.md` |
| Mapper | Testcontainers + `@SpringBootTest` | `references/mapper-testing.md` |
| Validation | Hibernate Validator 8 + JUnit 5 | `references/validation-testing.md` |
| Integration | `@SpringBootTest` + `@AutoConfigureMockMvc` | See below |

## Integration Test Pattern

```java
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class MarketIntegrationTest {
  @Autowired MockMvc mockMvc;

  @Test
  void createsMarket() throws Exception {
    mockMvc.perform(post("/v1/markets")
        .contentType(MediaType.APPLICATION_JSON)
        .content("""
          {"name":"Test","description":"Desc","endDate":"2030-01-01T00:00:00Z","categories":["general"]}
        """))
      .andExpect(status().isOk());
  }
}
```

## Coverage (JaCoCo)

```xml
<plugin>
  <groupId>org.jacoco</groupId>
  <artifactId>jacoco-maven-plugin</artifactId>
  <version>0.8.12</version>
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

## Anti-patterns

- NOT stub mocks in `@BeforeEach setUp()` globally — unused stubs in some test paths trigger `UnnecessaryStubbingException`. Move stubs into each test method.
- NOT assume `mock.method2Param()` delegates to `mock.method3Param()` — Mockito mocks do NOT delegate internally. Stub every signature that will be called.
- NOT use `anyString()` for nullable parameters — `anyString()` rejects `null`. Use `any()` or explicit stub instead.
- NOT match query parameters by exact URL string in `MockRestServiceServer` — `Map.of()` order is undefined. Use `containsString()` + `queryParam()` per-key matching.

## Assertions

- Prefer AssertJ (`assertThat`) for readability
- JSON responses: `jsonPath`
- Exceptions: `assertThatThrownBy(...)`

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

## Rules

- Unit tests run < 1s each
- NOT share state between tests — each test must be independent
- NOT assert internal method calls — assert observable behavior (output, state changes)
- Verify imports after writing tests: common missing imports include `java.util.Map`, Hamcrest matchers, sealed interface types

## References

- `references/service-layer-testing.md` — Mockito patterns for ServiceI / CmdExe
- `references/controller-layer-testing.md` — MockMvc patterns for Controller + Exception Handler
- `references/mapper-testing.md` — MapStruct Mapper and Converter testing
- `references/validation-testing.md` — Jakarta Bean Validation testing
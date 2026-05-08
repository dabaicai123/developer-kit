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

## Related Skills

- `unit-test-service-layer` — Mockito patterns for service layer testing
- `unit-test-controller-layer` — MockMvc patterns for REST controller testing
- `unit-test-bean-validation` — Jakarta Bean Validation testing
- `spring-boot-verification` — full build → lint → test → security scan pipeline
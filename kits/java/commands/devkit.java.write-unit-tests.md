---
description: Generates comprehensive unit tests for a Java class using JUnit 5 and Mockito. Adapts test strategy based on class type (Service, Controller, Mapper, Utility).
argument-hint: "[class-file-path]"
allowed-tools: Read, Write, Bash, Glob, Grep
model: inherit
---

## Write Unit Tests Command

Generates unit tests for a Java class, adapting strategy based on class type.

### Usage

`/devkit.java.write-unit-tests [class-file-path]`

**class-file-path**: Path to the Java class to test (e.g., `src/main/java/com/example/service/UserServiceImpl.java`)

### Execution

1. Invoke the `spring-boot-unit-testing-expert` agent
2. Detect class type from the file:
   - **ServiceImpl** → Use `unit-test-service-layer` skill, mock Mapper
   - **Controller** → Use `unit-test-controller-layer` skill, use MockMvc
   - **Utility** → Use `unit-test-utility-methods` skill, pure unit tests
   - **Mapper/Converter** → Use `unit-test-mapper-converter` skill
   - **Exception Handler** → Use `unit-test-exception-handler` skill
3. Generate tests following pattern:
   - Test class in matching test package
   - `@ExtendWith(MockitoExtension.class)` for Service tests
   - `@WebMvcTest` for Controller tests
   - AAA pattern (Arrange-Act-Assert)
   - Naming: `methodName_scenario_expectedResult`
4. Cover: happy path, error cases, edge cases
5. Verify tests compile and pass
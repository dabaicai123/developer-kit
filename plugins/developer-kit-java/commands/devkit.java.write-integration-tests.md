---
description: Generates integration tests for Spring Boot services using Testcontainers for PostgreSQL and Redis. Tests MyBatis-Plus mapper integration, service transactions, and end-to-end flows.
argument-hint: "[class-or-package-path]"
allowed-tools: Read, Write, Bash, Glob, Grep
model: inherit
---

## Write Integration Tests Command

Generates integration tests for Spring Boot using Testcontainers.

### Usage

`/devkit.java.write-integration-tests [class-or-package-path]`

**class-or-package-path**: Path to the class or package to test

### Execution

1. Invoke the `spring-boot-unit-testing-expert` agent
2. Identify integration test scope:
   - MyBatis-Plus Mapper SQL tests
   - Service transaction tests
   - End-to-end flow tests
3. Set up Testcontainers:
   - PostgreSQL container for database tests
   - Redis container for cache tests
4. Generate integration tests:
   - `@SpringBootTest` or `@DataJpaTest` + Testcontainers
   - `@Testcontainers` + `@Container` annotations
   - `@Transactional(readOnly = true)` with auto-rollback
   - MyBatis-Plus mapper tests: verify actual SQL execution
   - Service integration: verify transaction boundaries
5. Verify tests compile and pass against containers
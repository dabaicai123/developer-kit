# Developer Kit - Java

Comprehensive Java/Spring Boot development toolkit with MyBatis-Plus, Spring Cloud Alibaba, testing, security, DDD architecture, and DevOps integration.

## Tech Stack

- Java 21 + Spring Boot 3.5.x
- MyBatis-Plus (ORM) + PostgreSQL
- Spring Cloud Alibaba (Nacos, Sentinel, RocketMQ) + OpenFeign (prefer over Dubbo)
- JetCache + Redisson (caching + distributed services)
- Spring Security 6.x with JWT (JJWT 0.12.6)
- SpringDoc OpenAPI 2.8.6
- JUnit 5 + Mockito + MockMvc + Testcontainers + JaCoCo

## Skills (46)

### Project Setup
| Skill | Description |
|-------|-------------|
| `ddd-cola` | COLA DDD architecture + project scaffolding + POM dependencies |
| `graalvm-native-image` | GraalVM Native Image builds |

### Data Access
| Skill | Description |
|-------|-------------|
| `mybatis-plus-patterns` | MyBatis-Plus mapper/entity/service patterns |
| `mybatis-plus-generator` | Code generation from database tables |
| `postgresql-table-design` | PostgreSQL schema design |
| `jetcache` | JetCache + Redisson caching & distributed services |

### Core Spring Boot
| Skill | Description |
|-------|-------------|
| `spring-boot-dependency-injection` | DI patterns and best practices |
| `spring-boot-event-driven-patterns` | Event-driven architecture patterns |
| `spring-boot-exception-handling` | Global exception handling |
| `spring-boot-logging` | Logging configuration and patterns |
| `spring-boot-rest-api-standards` | REST API design standards |
| `spring-boot-validation` | Input validation patterns |

### Security
| Skill | Description |
|-------|-------------|
| `springboot-security` | Spring Security configuration |
| `spring-boot-security-jwt` | JWT authentication with JJWT |

### Documentation & API
| Skill | Description |
|-------|-------------|
| `spring-boot-openapi-documentation` | SpringDoc OpenAPI integration |
| `create-readme` | README generation |
| `documentation-writer` | Documentation writing patterns |

### Microservices & Cloud
| Skill | Description |
|-------|-------------|
| `spring-cloud-alibaba` | Spring Cloud Alibaba (Nacos, Sentinel, RocketMQ) |
| `spring-cloud-gateway` | Spring Cloud Gateway patterns |
| `spring-cloud-openfeign` | OpenFeign client patterns |
| `spring-kafka` | Spring Kafka patterns |

### Resilience & Monitoring
| Skill | Description |
|-------|-------------|
| `spring-boot-actuator` | Actuator endpoints and monitoring |
| `spring-boot-resilience4j` | Resilience4j patterns |

### Testing (17)
| Skill | Description |
|-------|-------------|
| `unit-test-service-layer` | Service layer unit testing |
| `unit-test-controller-layer` | Controller layer unit testing |
| `unit-test-bean-validation` | Bean validation testing |
| `unit-test-exception-handler` | Exception handler testing |
| `unit-test-boundary-conditions` | Boundary condition testing |
| `unit-test-parameterized` | Parameterized testing |
| `unit-test-mapper-converter` | Mapper/converter testing |
| `unit-test-json-serialization` | JSON serialization testing |
| `unit-test-caching` | Caching testing |
| `unit-test-config-properties` | Configuration testing |
| `unit-test-security-authorization` | Security authorization testing |
| `unit-test-application-events` | Application events testing |
| `unit-test-scheduled-async` | Scheduled/async testing |
| `unit-test-utility-methods` | Utility methods testing |
| `unit-test-wiremock-rest-api` | WireMock REST API testing |
| `springboot-tdd` | TDD workflow |
| `springboot-verification` | Verification patterns |

### Architecture
| Skill | Description |
|-------|-------------|
| `ddd-cola` | COLA DDD architecture + project scaffolding |
| `ddd-event-driven` | Event-driven DDD patterns |

### DevOps & Workflow
| Skill | Description |
|-------|-------------|
| `git-commit` | Git commit conventions |
| `docker-expert` | Docker patterns |

### Project Management
| Skill | Description |
|-------|-------------|
| `architecture-decision-records` | ADR drafting |
| `code-refactoring-refactor-clean` | Code refactoring and cleanup |
| `ab-test-setup` | A/B testing setup |

## Agents (6)

| Agent | Description | Model |
|-------|-------------|-------|
| `database-reviewer` | PostgreSQL specialist | sonnet |
| `spring-boot-backend-development-expert` | Spring Boot feature implementation | sonnet |
| `spring-boot-code-review-expert` | Code quality review | sonnet |
| `spring-boot-unit-testing-expert` | Testing strategy | sonnet |
| `java-refactor-expert` | Refactoring patterns | sonnet |
| `java-security-expert` | Security audit | sonnet |

## Commands (11)

| Command | Description |
|---------|-------------|
| `/devkit.java.code-review` | Code quality review |
| `/devkit.java.generate-crud` | Generate CRUD with MyBatis-Plus |
| `/devkit.java.refactor-class` | Refactor a class |
| `/devkit.java.architect-review` | Architecture review |
| `/devkit.java.dependency-audit` | Dependency audit |
| `/devkit.java.generate-docs` | Generate documentation |
| `/devkit.java.security-review` | Security review |
| `/devkit.java.upgrade-dependencies` | Upgrade dependencies |
| `/devkit.java.write-unit-tests` | Write unit tests |
| `/devkit.java.write-integration-tests` | Write integration tests |
| `/devkit.java.generate-refactoring-tasks` | Generate refactoring tasks |

## Rules (5)

| Rule | Applies to |
|------|------------|
| `naming-conventions` | `**/*.java` |
| `project-structure` | `**/*.java` |
| `language-best-practices` | `**/*.java` |
| `error-handling` | `**/*.java` |
| `mybatis-plus-conventions` | `**/*Mapper.java`, `**/*Service.java`, `**/*ServiceImpl.java` |

## Installation

```bash
make install
```
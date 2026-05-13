# Java Skills Index

This file is the lightweight routing table for Java agents. Agent frontmatter should keep only resident core skills; load optional skills only when task text, changed files, dependencies, or package structure clearly indicate the technology.

## Resident Core For Feature Agent

- `mybatis-plus-patterns`: MyBatis-Plus DO/Mapper/query/write patterns.
- `spring-boot-rest-api-standards`: REST, Result/PageResult, controller conventions.
- `spring-boot-validation`: Jakarta Bean Validation for request objects.
- `spring-boot-exception-handling`: BusinessException and global exception handling.
- `spring-boot-transaction-management`: write transaction boundaries.
- `spring-boot-dependency-injection`: constructor injection and bean wiring.
- `spring-boot-logging`: structured logging rules.
- `ddd-cola`: resident because COLA/DDD is common in this Java kit; keep SKILL.md lightweight and load references only for detailed module work.

## Optional Routing

| Trigger | Load skill |
| --- | --- |
| table DDL, index, PostgreSQL data type, schema review | `postgresql-table-design` |
| OpenAPI, Swagger, `@Operation`, API docs | `spring-boot-openapi-documentation` |
| JWT, token, auth, authorization, `@PreAuthorize` | `spring-boot-security-jwt`, `spring-boot-security` |
| Feign, `@FeignClient`, inter-service API client | `spring-cloud-openfeign` |
| Nacos, Sentinel, RocketMQ, Spring Cloud Alibaba | `spring-cloud-alibaba` |
| Gateway route/filter | `spring-cloud-gateway` |
| Kafka topic/producer/consumer | `spring-kafka` |
| RabbitMQ, AMQP, listener/container | `spring-boot-amqp` |
| JetCache, Redis cache, distributed lock | `spring-boot-jetcache` |
| RestClient, outbound HTTP client | `spring-boot-rest-client` |
| resilience, retry, circuit breaker, rate limiter | `spring-boot-resilience4j` |
| configuration properties, profile, Nacos config | `spring-boot-configuration-management` |
| actuator, metrics, health endpoint | `spring-boot-actuator` |
| async, `@Async`, CompletableFuture, executor | `spring-boot-async-processing` |
| scheduled job, cron, XXL-JOB | `spring-boot-scheduled-tasks` |
| file upload/download, MinIO, OSS, EasyExcel | `spring-boot-file-handling` |
| Jackson, ObjectMapper, serialization | `spring-boot-jackson-config` |
| MapStruct, converter, mapper interface | `mapstruct-patterns` |
| native image, GraalVM, AOT | `graalvm-native-image` |
| domain events, event sourcing, outbox, projection | `ddd-event-driven` |
| Dockerfile, compose, container runtime | `docker-expert` |

## Conflict Priority

- Existing project structure wins over generic guidance.
- User's explicit architecture request wins over default MVC/COLA selection.
- DDD/COLA rules win for COLA module boundaries; Spring REST/MyBatis rules still apply inside their layers.
- PostgreSQL table design wins for SQL schema decisions; MyBatis-Plus wins for Java mapping decisions.
- Security skills win for authentication, authorization, secret handling, and sensitive response fields.
- Transaction rules win for DB write boundaries and event publication timing.

## Reference Loading Rule

When a skill has `references/full-guide.md`, read the short `SKILL.md` first. Read `full-guide.md` only when the task requires complete examples, templates, detailed troubleshooting, or a design decision not covered by the quick rules.


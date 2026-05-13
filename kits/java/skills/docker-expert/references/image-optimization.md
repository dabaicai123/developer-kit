# Image Size Optimization

## Size Comparison

| Strategy | Typical Size | Trade-off |
|----------|-------------|-----------|
| `eclipse-temurin:21` (full JDK) | ~450 MB | Full tooling; debugging-friendly |
| `eclipse-temurin:21-jre` (JRE only) | ~220 MB | No compiler; production baseline |
| `eclipse-temurin:21-jre` + distroless | ~180 MB | No shell; HEALTHCHECK needs workaround |
| GraalVM native + `debian:bookworm-slim` | ~80 MB | No JVM; sub-second startup; limited reflection |
| GraalVM native + distroless | ~50 MB | Smallest; no shell; hardest to debug |

## Distroless Java Pattern

```dockerfile
FROM eclipse-temurin:21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn package -DskipTests -B

FROM gcr.io/distroless/java21-debian12
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
# Note: distroless has no curl/shell — use separate health check mechanism
# or include a custom health-check binary in the build stage
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-XX:+UseContainerSupport", \
            "-XX:+ExitOnOutOfMemoryError", "-jar", "app.jar"]
```

## Distroless Health Check Workaround

Since distroless images lack `curl` and `sh`, health checks must be handled externally or via a custom binary:

```dockerfile
# Build a static health-check binary in a separate stage
FROM eclipse-temurin:21 AS healthcheck-builder
# Compile a minimal Java health-check app or use a statically compiled wget
# Alternatively, rely on Kubernetes liveness probes or external monitoring
```

In Docker Compose, use an external health check approach:

```yaml
services:
  app:
    # No HEALTHCHECK directive for distroless
    # Use Spring Boot Actuator readiness/liveness probes via Kubernetes or external monitoring
```

## Layered JAR for Fine-Grained Docker Layer Caching

Spring Boot supports layered JARs that split dependencies, snapshot dependencies, and application classes into separate Docker layers:

```dockerfile
FROM eclipse-temurin:21-jre AS runtime
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract
COPY --chown=appuser:appgroup dependencies/ ./
COPY --chown=appuser:appgroup spring-boot-loader/ ./
COPY --chown=appuser:appgroup snapshot-dependencies/ ./
COPY --chown=appuser:appgroup application/ ./
USER appuser
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-XX:+UseContainerSupport", "-jar", "app.jar"]
```

Benefit: When only application code changes, only the `application` layer rebuilds. Dependencies layers remain cached.

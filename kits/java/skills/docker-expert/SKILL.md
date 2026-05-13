---
name: docker-expert
description: "Docker containerization for Java/Spring Boot applications: multi-stage builds, JVM optimization, Compose orchestration, and production hardening."
version: "1.1.0"
type: skill
---

# Docker Expert (Java/Spring Boot)

Covers multi-stage builds with Maven/Gradle, JVM container-aware optimization, Docker Compose orchestration, security hardening, and production deployment strategies.

## When invoked:

1. Analyze the project for existing Dockerfile patterns, base images, build tool, and running containers
2. Identify the specific problem category and complexity level
3. Apply the appropriate solution strategy from the expertise below
4. Validate: `docker build --no-cache`, verify runtime with `docker run`, check security with `docker scout quickview`

## Multi-Stage Build Pattern

```dockerfile
# ---- Stage 1: Dependency resolution (cached layer) ----
FROM eclipse-temurin:21 AS deps
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B

# ---- Stage 2: Build ----
FROM deps AS build
COPY src ./src
RUN mvn package -DskipTests -B

# ---- Stage 3: Runtime ----
FROM eclipse-temurin:21-jre AS runtime
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app
COPY --chown=appuser:appgroup --from=build /app/target/*.jar app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-XX:+UseContainerSupport", \
            "-XX:+ExitOnOutOfMemoryError", "-jar", "app.jar"]
```

**Gradle alternative** — only the dependency resolution step differs:

```dockerfile
# Replace Stage 1 (deps) with:
FROM eclipse-temurin:21 AS deps
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY gradle ./gradle
RUN gradle dependencies --no-daemon || return 0
# Stage 2: gradle bootJar --no-daemon -x test
# Stage 3 COPY: /app/build/libs/*.jar
```

## JVM Container-Aware Optimization

Modern JVMs (JDK 11+) are container-aware by default. Explicit flags help for fine-tuning.

| Flag | Purpose | Recommended Value |
|------|---------|-------------------|
| `-XX:+UseContainerSupport` | Container-aware memory/CPU detection | Default on JDK 11+; set explicitly for clarity |
| `-XX:MaxRAMPercentage=75.0` | Cap heap at 75% of container memory | 75.0 for single-service containers |
| `-XX:InitialRAMPercentage=50.0` | Initial heap size relative to container memory | 50.0 |
| `-XX:+UseG1GC` | Low-latency garbage collector | Default on JDK 21; explicit for older JDKs |
| `-Djava.security.egd=file:/dev/./urandom` | Faster SecureRandom for startup | Recommended for non-crypto use |
| `-XX:+ExitOnOutOfMemoryError` | Crash immediately on OOM instead of hanging | Always recommended in containers |
| `-XX:+HeapDumpOnOutOfMemoryError` | Generate heap dump before OOM crash | Useful for diagnostics |

**Production ENTRYPOINT pattern:**

```dockerfile
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-XX:InitialRAMPercentage=50.0", \
  "-XX:+UseG1GC", \
  "-XX:+ExitOnOutOfMemoryError", \
  "-XX:+HeapDumpOnOutOfMemoryError", \
  "-Djava.security.egd=file:/dev/./urandom", \
  "-jar", "app.jar"]
```

**Memory sizing guidelines:**
- Spring Boot minimal: 256 MB container limit (MaxRAMPercentage=75.0 => ~192 MB heap)
- Spring Boot typical: 512 MB => ~384 MB heap
- Heavy caching/processing: 1 GB => ~750 MB heap
- Always leave 25% overhead for metaspace, thread stacks, off-heap, and native memory

## Security Hardening

**Non-root user + read-only filesystem + capability restrictions:**

```dockerfile
FROM eclipse-temurin:21-jre
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app
COPY --chown=appuser:appgroup target/*.jar app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-XX:+UseContainerSupport", \
            "-XX:+ExitOnOutOfMemoryError", "-jar", "app.jar"]
```

**Runtime security in Compose:**

```yaml
services:
  app:
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
```

**Build-time secrets with BuildKit:**

```dockerfile
RUN --mount=type=secret,id=keystore_password \
    KS_PASS=$(cat /run/secrets/keystore_password) && \
    keytool -importcert -storepass "$KS_PASS" ...
```

## Health Checks

Spring Boot Actuator provides structured health endpoints for Docker HEALTHCHECK:

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      probes:
        enabled: true
      group:
        liveness:
          include: livenessState
        readiness:
          include: readinessState,db,redis
```

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health/liveness || exit 1
```

## Build Cache Optimization (BuildKit)

```dockerfile
FROM eclipse-temurin:21 AS build
WORKDIR /app
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn dependency:go-offline -B
COPY src ./src
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn package -DskipTests -B
```

## Cross-Platform Builds

```bash
docker buildx create --name multiarch-builder --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myapp:latest --push .
```

Eclipse Temurin provides multi-arch images. For GraalVM native images, the build must run on the target architecture.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Full JDK in production | +230 MB unnecessary tooling | Use `eclipse-temurin:21-jre` or distroless |
| No `MaxRAMPercentage` | JVM defaults to 25% or exceeds limit, causing OOM kills | Set `-XX:MaxRAMPercentage=75.0` |
| Source in production stage | Exposes code, bloats image | Copy only the JAR into final stage |
| Running as root | Security liability | Create non-root user with `USER` directive |
| `version: '3.8'` in Compose | Deprecated, ignored by Compose V2 | Remove entirely |
| Hardcoded passwords in env | Visible in `docker inspect` | Use Docker secrets or external secret management |
| Missing HEALTHCHECK | Docker cannot detect crashed process | Use Actuator `/actuator/health` |
| No dependency caching | Re-downloads all deps every build | Multi-stage resolution or BuildKit cache mounts |
| No `.dockerignore` | Sends `.git`, IDE files, logs to daemon | Add comprehensive `.dockerignore` |
| Ignoring memory limits | JVM exceeds container limit, kernel OOM-kills | Set `deploy.resources.limits.memory` + match JVM flags |

## Constraints & Warnings

- Pin Eclipse Temurin to specific tags (e.g., `eclipse-temurin:21-jre-alpine`) for reproducible builds. Avoid floating tags in production.
- Alpine-based images use musl libc — verify native library compatibility (PostgreSQL JDBC native SSL, SQLite).
- `-XX:+ExitOnOutOfMemoryError` causes container exit on OOM. Pair with `restart: unless-stopped` in Compose or liveness probes in Kubernetes.
- Distroless images have no shell — `docker exec` fails. Use only for mature production deployments.
- Spring Boot Actuator health endpoint must be accessible without authentication for Docker HEALTHCHECK.

## Code Review Checklist

1. [ ] Dependencies resolved in separate stage before copying source
2. [ ] Production stage uses `eclipse-temurin:21-jre` (not full JDK)
3. [ ] Production stage contains only the JAR — no source, no build tooling
4. [ ] Non-root user created and `USER` directive set
5. [ ] `-XX:MaxRAMPercentage` set to match container memory limits
6. [ ] `-XX:+ExitOnOutOfMemoryError` enabled
7. [ ] Secrets via Docker secrets, not environment variables
8. [ ] Service dependencies use `condition: service_healthy`
9. [ ] HEALTHCHECK uses Actuator endpoint with appropriate `start_period`
10. [ ] No deprecated `version` key in Compose files

## Related Skills

- **graalvm-native-image**: Native executable compilation for sub-second startup and minimal images (~50-80 MB)
- **spring-boot-actuator**: Health check endpoints, liveness/readiness probes, Prometheus metrics
- **spring-boot-database-migration**: SQL changesets for PostgreSQL in Docker Compose

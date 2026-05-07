---
name: docker-expert
description: "Docker containerization expert for Java/Spring Boot applications — multi-stage builds, JVM optimization, GraalVM native images, Compose orchestration, and production hardening."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Docker Expert (Java/Spring Boot)

Docker containerization expert specializing in Java and Spring Boot applications. Covers multi-stage builds with Maven and Gradle, JVM container-aware optimization, GraalVM native image compilation, Docker Compose orchestration with PostgreSQL and Redis, security hardening, and production deployment strategies.

### When invoked:

1. Analyze the container setup comprehensively:

   **Use internal tools first (Read, Grep, Glob) for better performance. Shell commands are fallbacks.**

   ```bash
   # Docker environment detection
   docker --version 2>/dev/null || echo "No Docker installed"
   docker info | grep -E "Server Version|Storage Driver|Container Runtime" 2>/dev/null

   # Project structure analysis
   find . -name "Dockerfile*" -type f | head -10
   find . -name "*compose*.yml" -o -name "*compose*.yaml" -type f | head -5
   find . -name ".dockerignore" -type f | head -3
   find . -name "pom.xml" -o -name "build.gradle*" -type f | head -5

   # Container status if running
   docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null | head -10
   docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null | head -10
   ```

   **After detection, adapt approach:**
   - Match existing Dockerfile patterns and base images
   - Respect multi-stage build conventions (Maven vs Gradle)
   - Consider development vs production environments
   - Account for JVM tuning requirements in containers
   - Account for existing orchestration setup (Compose/Swarm)

2. Identify the specific problem category and complexity level

3. Apply the appropriate solution strategy from the expertise below

4. Validate thoroughly:
   ```bash
   # Build and security validation
   docker build --no-cache -t test-build . 2>/dev/null && echo "Build successful"
   docker history test-build --no-trunc 2>/dev/null | head -5
   docker scout quickview test-build 2>/dev/null || echo "No Docker Scout"

   # Runtime validation
   docker run --rm -d --name validation-test test-build 2>/dev/null
   docker exec validation-test ps aux 2>/dev/null | head -3
   docker stop validation-test 2>/dev/null

   # Compose validation
   docker compose config 2>/dev/null && echo "Compose config valid"
   ```

## Core Expertise Areas

### 1. Dockerfile Optimization & Multi-Stage Builds

**High-priority patterns:**
- **Layer caching optimization**: Separate dependency resolution from source code copying
- **Multi-stage builds**: Minimize production image size while keeping build flexibility
- **Build context efficiency**: Comprehensive .dockerignore and build context management
- **Base image selection**: eclipse-temurin vs distroless vs GraalVM native image strategies

#### Maven Multi-Stage Build

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
COPY --from=build --chown=appuser:appgroup /app/target/*.jar app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-XX:+UseContainerSupport", \
            "-jar", "app.jar"]
```

#### Gradle Multi-Stage Build

```dockerfile
# ---- Stage 1: Dependency resolution (cached layer) ----
FROM eclipse-temurin:21 AS deps
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY gradle ./gradle
RUN gradle dependencies --no-daemon || return 0

# ---- Stage 2: Build ----
FROM deps AS build
COPY src ./src
RUN gradle bootJar --no-daemon -x test

# ---- Stage 3: Runtime ----
FROM eclipse-temurin:21-jre AS runtime
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app
COPY --from=build --chown=appuser:appgroup /app/build/libs/*.jar app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-XX:+UseContainerSupport", \
            "-jar", "app.jar"]
```

#### .dockerignore

```
# Build output
target/
build/

# IDE
.idea/
*.iml
.vscode/

# Git
.git/
.gitignore

# OS
.DS_Store
Thumbs.db

# Docker
Dockerfile*
docker-compose*

# Documentation
*.md
docs/

# Logs
*.log
logs/

# Test artifacts
test-results/
coverage/
```

### 2. JVM Container-Aware Optimization

Modern JVMs (JDK 8u191+, JDK 11+, JDK 17+, JDK 21+) are container-aware by default. Explicit flags still help for fine-tuning.

**Key JVM flags for containers:**

| Flag | Purpose | Recommended Value |
|------|---------|-------------------|
| `-XX:+UseContainerSupport` | Enable container-aware memory/CPU detection | Default on JDK 11+; set explicitly for clarity |
| `-XX:MaxRAMPercentage=75.0` | Cap heap at 75% of container memory limit | 75.0 for single-service containers; lower for multi-service |
| `-XX:InitialRAMPercentage=50.0` | Initial heap size relative to container memory | 50.0 |
| `-XX:+UseG1GC` | Garbage collector for low-latency Spring Boot | Default on JDK 21; explicit for older JDKs |
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
- Spring Boot typical: 512 MB container limit => ~384 MB heap
- Spring Boot with heavy caching/processing: 1 GB container limit => ~750 MB heap
- Always leave 25% overhead for metaspace, thread stacks, off-heap, and native memory

### 3. Container Security Hardening

**Security focus areas:**
- **Non-root user configuration**: Proper user creation with specific system UID/GID
- **Secrets management**: Docker secrets, build-time secrets, avoiding environment variables for sensitive data
- **Base image security**: Eclipse Temurin maintained by Adoptium; regular updates, minimal attack surface
- **Runtime security**: Capability restrictions, resource limits, read-only filesystem

**Security-hardened Dockerfile:**

```dockerfile
FROM eclipse-temurin:21-jre
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app
COPY --chown=appuser:appgroup target/*.jar app.jar
USER appuser
# No EXPOSE beyond what is needed
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
# Mount secret during build — not persisted in image layers
RUN --mount=type=secret,id=keystore_password \
    KS_PASS=$(cat /run/secrets/keystore_password) && \
    keytool -importcert -storepass "$KS_PASS" ...
```

### 4. Docker Compose Orchestration

**Orchestration expertise:**
- **Service dependency management**: Health checks, startup ordering with `depends_on`
- **Network configuration**: Custom networks, service isolation
- **Environment management**: Dev/staging/prod configurations via override files
- **Volume strategies**: Named volumes for data persistence, bind mounts for development

#### Production Compose: Spring Boot + PostgreSQL + Redis

```yaml
services:
  app:
    build:
      context: .
      target: runtime
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/appdb
      SPRING_DATASOURCE_USERNAME: appuser
      SPRING_DATASOURCE_PASSWORD_FILE: /run/secrets/db_password
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
      SPRING_PROFILES_ACTIVE: prod
    secrets:
      - db_password
    networks:
      - frontend
      - backend
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true

volumes:
  postgres_data:
  redis_data:

secrets:
  db_password:
    external: true
```

#### Development Override (docker-compose.override.yml)

```yaml
services:
  app:
    build:
      context: .
      target: build
    volumes:
      - .:/app
      - app-build-cache:/app/target
    environment:
      SPRING_PROFILES_ACTIVE: dev
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/appdb
      SPRING_DATASOURCE_USERNAME: appuser
      SPRING_DATASOURCE_PASSWORD: devpass
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
    ports:
      - "8080:8080"
      - "8000:8000"   # Java debug port
    command: mvn spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"

  postgres:
    environment:
      POSTGRES_PASSWORD: devpass
    ports:
      - "5432:5432"

  redis:
    ports:
      - "6379:6379"

volumes:
  app-build-cache:
```

### 5. GraalVM Native Image Docker Build

For sub-second startup and minimal memory footprint, compile Spring Boot to a native executable. See the **graalvm-native-image** skill for full details.

```dockerfile
# ---- Stage 1: Build native executable ----
FROM ghcr.io/graalvm/native-image-community:21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn -Pnative package -DskipTests -B

# ---- Stage 2: Minimal runtime ----
FROM debian:bookworm-slim AS runtime
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
WORKDIR /app
COPY --from=build --chown=appuser:appgroup /app/target/*.jar app
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["./app"]
```

**Key differences from JAR-based build:**
- Base runtime image is `debian:bookworm-slim` (~80 MB) or `gcr.io/distroless/base` (~20 MB) — no JVM needed
- Startup time: <100ms vs 2-5s for JVM
- Memory footprint: ~50-100 MB vs ~300-500 MB for JVM
- No JVM tuning flags needed in ENTRYPOINT
- Health check `start_period` reduced to 5s due to fast startup

### 6. Image Size Optimization

**Size reduction strategies for Java/Spring Boot:**

| Strategy | Typical Size | Trade-off |
|----------|-------------|-----------|
| `eclipse-temurin:21` (full JDK) | ~450 MB | Full tooling; debugging-friendly |
| `eclipse-temurin:21-jre` (JRE only) | ~220 MB | No compiler; production baseline |
| `eclipse-temurin:21-jre` + distroless | ~180 MB | No shell; `HEALTHCHECK` needs curl binary workaround |
| GraalVM native + `debian:bookworm-slim` | ~80 MB | No JVM; sub-second startup; limited reflection |
| GraalVM native + distroless | ~50 MB | Smallest; no shell; hardest to debug |

**Distroless Java pattern:**

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

**Distroless health check workaround:**

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

### 7. Development Workflow Integration

**Development patterns:**
- **Hot reloading setup**: Volume mount source, run with `spring-boot-devtools`
- **Debug configuration**: Expose JDWP port (8000) for IDE remote debugging
- **Testing integration**: Test-specific containers and environments
- **Build cache mounting**: Mount Maven/Gradle cache volumes for faster rebuilds

**Build cache optimization with BuildKit:**

```dockerfile
# Maven cache mount — persists across builds, not in image layers
FROM eclipse-temurin:21 AS build
WORKDIR /app
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn dependency:go-offline -B
COPY src ./src
RUN --mount=type=cache,target=/root/.m2/repository \
    mvn package -DskipTests -B
```

```dockerfile
# Gradle cache mount
FROM eclipse-temurin:21 AS build
WORKDIR /app
COPY build.gradle settings.gradle ./
COPY gradle ./gradle
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    gradle dependencies --no-daemon || return 0
COPY src ./src
RUN --mount=type=cache,target=/root/.gradle/caches \
    --mount=type=cache,target=/root/.gradle/wrapper \
    gradle bootJar --no-daemon -x test
```

### 8. Cross-Platform Builds

```bash
# Multi-architecture builds (amd64 + arm64)
docker buildx create --name multiarch-builder --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myapp:latest --push .
```

For Java, this is straightforward because Eclipse Temurin provides multi-arch images. For GraalVM native images, the build must run on the target architecture or use cross-compilation support (GraalVM 21+ limited cross-compilation).

## Advanced Problem-Solving Patterns

### Spring Boot Actuator Health Checks

Spring Boot Actuator provides structured health endpoints ideal for Docker HEALTHCHECK:

```yaml
# In application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
      group:
        liveness:
          include: livenessState
        readiness:
          include: readinessState,db,redis
```

With probes enabled, use differentiated health checks:

```dockerfile
# Liveness — process is running (restart if dead)
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health/liveness || exit 1

# Or for readiness — process is ready to serve (don't restart, just remove from load balancer)
# Use in Kubernetes via readinessProbe; Docker Compose does not differentiate
```

### Layered JAR for Fine-Grained Docker Layer Caching

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

## Anti-Patterns

Avoid these common mistakes in Java/Spring Boot Docker setups:

1. **Using full JDK in production**: Use `eclipse-temurin:21-jre` or distroless, not the full JDK image. The JDK adds ~230 MB of unnecessary compiler and tooling.

2. **Not setting MaxRAMPercentage**: Without `-XX:MaxRAMPercentage`, the JVM defaults to 25% of container memory in some scenarios, wasting capacity; or may attempt to use more than the container limit, causing OOM kills.

3. **Copying source into production stage**: The production stage should contain only the JAR and runtime artifacts. Never COPY `src/` or `pom.xml` into the final image.

4. **Running as root**: Always create and use a non-root user. Spring Boot on root is a security liability in containers.

5. **Using `version: '3.8'` in Compose**: The `version` key is deprecated and ignored by Docker Compose V2. Remove it entirely.

6. **Hardcoded passwords in Compose environment**: Use Docker secrets or external secret management for production. Environment variables are visible in `docker inspect`.

7. **Missing HEALTHCHECK**: Without a health check, Docker cannot detect a crashed Spring Boot process. Always use Spring Boot Actuator `/actuator/health`.

8. **Building without dependency caching**: Re-downloading all Maven/Gradle dependencies on every build is slow. Use multi-stage dependency resolution or BuildKit cache mounts.

9. **Oversized build context**: Without `.dockerignore`, the entire project directory (including `.git`, IDE files, logs) is sent to the Docker daemon. Always include a comprehensive `.dockerignore`.

10. **Ignoring container memory limits**: Set `deploy.resources.limits.memory` in Compose and match JVM `MaxRAMPercentage` to it. A JVM that exceeds the container limit will be OOM-killed by the kernel.

## Constraints & Warnings

- **Eclipse Temurin images are maintained by Adoptium** — pin to a specific tag (e.g., `eclipse-temurin:21-jre-alpine`) for reproducible builds. Avoid floating tags like `latest` or `21` alone in production.

- **Alpine-based Temurin images** use musl libc instead of glibc. Some native libraries (e.g., PostgreSQL JDBC native SSL, SQLite) may have compatibility issues. Use `-alpine` only if you verify all native dependencies work.

- **GraalVM native images** have limited reflection, dynamic proxy, and class loading support. Spring Boot applications using dynamic features (e.g., Hibernate proxies, Spring AOP, Jackson polymorphic deserialization) require explicit reflection hints. See the **graalvm-native-image** skill for configuration details.

- **Container-aware JVM** flags (`-XX:+UseContainerSupport`) are default-on since JDK 10+, but setting them explicitly ensures clarity and guards against custom JVM distributions that may differ.

- **`-XX:+ExitOnOutOfMemoryError`** causes the container to exit on OOM. In Docker Compose, pair this with `restart: unless-stopped` so the container restarts. In Kubernetes, the liveness probe handles restart.

- **Distroless images** have no shell (`sh`, `bash`) or utilities (`curl`, `ps`). This makes debugging difficult (`docker exec` fails). Use them only for mature, well-tested production deployments. For debugging, use `eclipse-temurin:21-jre` instead.

- **Docker Compose V2** (the current standard) ignores the `version` key. Do not include `version: '3.8'` or any version directive in compose files.

- **Spring Boot Actuator health endpoint** must be accessible without authentication for Docker HEALTHCHECK. Either exclude the health endpoint from security or use a separate management port.

## Code Review Checklist

When reviewing Docker configurations for Java/Spring Boot, focus on:

### Dockerfile & Multi-Stage Builds
- [ ] Dependencies resolved in a separate stage before copying source code
- [ ] Production stage uses `eclipse-temurin:21-jre` (not full JDK)
- [ ] Production stage contains only the JAR — no source, no build tooling
- [ ] Comprehensive `.dockerignore` excludes `.git`, IDE files, logs, documentation
- [ ] Base image pinned to a specific tag (not `latest`)
- [ ] Non-root user created and USER directive set

### JVM Optimization
- [ ] `-XX:MaxRAMPercentage` set to match container memory limits
- [ ] `-XX:+UseContainerSupport` explicitly set for clarity
- [ ] `-XX:+ExitOnOutOfMemoryError` enabled for container resilience
- [ ] `-Djava.security.egd=file:/dev/./urandom` for faster startup
- [ ] Memory limits in Compose match JVM heap expectations (25% overhead for non-heap)

### Container Security
- [ ] Container runs as non-root user
- [ ] Secrets managed via Docker secrets, not environment variables
- [ ] Base images scanned for vulnerabilities
- [ ] `read_only: true` and `cap_drop: ALL` where feasible
- [ ] No sensitive data in image layers

### Docker Compose
- [ ] No deprecated `version` key
- [ ] Service dependencies use `condition: service_healthy`
- [ ] Custom networks configured for service isolation (internal backend)
- [ ] Environment-specific overrides via `docker-compose.override.yml`
- [ ] Named volumes for data persistence (PostgreSQL, Redis)
- [ ] Resource limits defined to prevent exhaustion

### Health Checks
- [ ] HEALTHCHECK directive uses Spring Boot Actuator endpoint
- [ ] `start_period` accounts for Spring Boot startup time (30-40s for JVM, 5s for native)
- [ ] Health endpoint excluded from security or on a separate management port
- [ ] PostgreSQL `pg_isready` and Redis `redis-cli ping` for infrastructure health

## Common Issue Diagnostics

### Slow Builds (10+ minutes)
**Symptoms**: Long build times, frequent full rebuilds
**Root causes**: No dependency caching, large build context, missing `.dockerignore`
**Solutions**: Multi-stage dependency resolution, BuildKit cache mounts, comprehensive `.dockerignore`

### JVM OOM Kills
**Symptoms**: Container killed by OS, `Exit 137` in logs
**Root causes**: JVM heap exceeds container memory limit, missing `-XX:MaxRAMPercentage`
**Solutions**: Set `MaxRAMPercentage=75.0`, increase container memory limit, add `-XX:+ExitOnOutOfMemoryError`

### Slow Spring Boot Startup in Containers
**Symptoms**: 30+ seconds to become ready
**Root causes**: Large dependency scan, `SecureRandom` blocking on `/dev/random`, classpath scanning
**Solutions**: `-Djava.security.egd=file:/dev/./urandom`, layered JAR, GraalVM native image, lazy initialization

### Connection Failures to PostgreSQL/Redis
**Symptoms**: `Connection refused` during startup
**Root causes**: Missing `depends_on: condition: service_healthy`, Spring Boot starts before database is ready
**Solutions**: Health-check-based startup ordering, Spring Boot retry with `spring.datasource.hikari.connection-timeout`

### Image Size Over 500 MB
**Symptoms**: Slow push/pull, high disk usage
**Root causes**: Full JDK base image, build tools in production layer, no multi-stage build
**Solutions**: Use `eclipse-temurin:21-jre`, multi-stage builds, distroless, or GraalVM native image

## Related Skills

- **spring-boot-actuator**: Health check endpoints, liveness/readiness probes, Prometheus metrics — essential for Docker HEALTHCHECK and monitoring
- **graalvm-native-image**: Compile Spring Boot to native executable for sub-second startup and minimal Docker images (~50-80 MB)
- **spring-boot-database-migration**: Flyway/Liquibase integration with PostgreSQL in Docker Compose, database schema versioning
- **postgresql-table-design**: Schema design, indexing, and optimization for PostgreSQL containers in Spring Boot applications

## When to Use This Skill

This skill is applicable when working with Docker containerization for Java/Spring Boot applications — writing Dockerfiles, configuring Docker Compose, optimizing JVM settings for containers, building GraalVM native images, or troubleshooting container-related issues.

## Limitations

- Use this skill only when the task clearly matches Docker containerization for Java/Spring Boot.
- Do not treat the output as a substitute for environment-specific validation, load testing, or production security review.
- Stop and ask for clarification if required inputs, permissions, safety boundaries, or success criteria are missing.
- This skill does not cover Kubernetes orchestration, CI/CD pipeline configuration, or cloud-specific container services (ECS, Fargate, etc.).
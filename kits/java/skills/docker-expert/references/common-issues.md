# Common Issue Diagnostics — Docker (Java/Spring Boot)

## Slow Builds (10+ minutes)
**Symptoms**: Long build times, frequent full rebuilds
**Root causes**: No dependency caching, large build context, missing `.dockerignore`
**Solutions**: Multi-stage dependency resolution, BuildKit cache mounts, comprehensive `.dockerignore`

## JVM OOM Kills
**Symptoms**: Container killed by OS, `Exit 137` in logs
**Root causes**: JVM heap exceeds container memory limit, missing `-XX:MaxRAMPercentage`
**Solutions**: Set `MaxRAMPercentage=75.0`, increase container memory limit, add `-XX:+ExitOnOutOfMemoryError`

## Slow Spring Boot Startup in Containers
**Symptoms**: 30+ seconds to become ready
**Root causes**: Large dependency scan, `SecureRandom` blocking on `/dev/random`, classpath scanning
**Solutions**: `-Djava.security.egd=file:/dev/./urandom`, layered JAR, GraalVM native image, lazy initialization

## Connection Failures to PostgreSQL/Redis
**Symptoms**: `Connection refused` during startup
**Root causes**: Missing `depends_on: condition: service_healthy`, Spring Boot starts before database is ready
**Solutions**: Health-check-based startup ordering, Spring Boot retry with `spring.datasource.hikari.connection-timeout`

## Image Size Over 500 MB
**Symptoms**: Slow push/pull, high disk usage
**Root causes**: Full JDK base image, build tools in production layer, no multi-stage build
**Solutions**: Use `eclipse-temurin:21-jre`, multi-stage builds, distroless, or GraalVM native image
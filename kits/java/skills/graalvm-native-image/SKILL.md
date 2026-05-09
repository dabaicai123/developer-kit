---
name: graalvm-native-image
description: "GraalVM Native Image for Java applications: native binary compilation, cold start optimization, memory reduction, reflection/resource configuration, and framework-specific support (Spring Boot, Quarkus, Micronaut). Use when converting JVM applications to native binaries or optimizing startup time."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# GraalVM Native Image for Java Applications

## When to use this skill

Use this skill when:
- Converting a JVM-based Java application to a GraalVM native executable
- Optimizing cold start times for serverless or containerized deployments
- Reducing memory footprint (RSS) of Java microservices
- Configuring Maven or Gradle with GraalVM Native Build Tools
- Resolving `ClassNotFoundException`, `NoSuchMethodException`, or missing resource errors in native builds
- Generating or editing `reflect-config.json`, `resource-config.json`, or other GraalVM metadata files
- Using the GraalVM tracing agent to collect reachability metadata
- Implementing `RuntimeHints` for Spring Boot native support
- Building native images with Quarkus or Micronaut

## Instructions

### 1. Contextual Project Analysis

Detect build tool (pom.xml = Maven, build.gradle = Gradle), framework, and Java version. Identify reflection-heavy libraries (Jackson, Hibernate) as potential challenges.

### 2. Build Tool Configuration

Configure the appropriate build tool plugin based on the detected environment.

**For Maven projects**, add a dedicated `native` profile to keep the standard build clean. See the [Maven Native Profile Reference](references/maven-native-profile.md) for full configuration.

Key Maven setup:

```xml
<profiles>
  <profile>
    <id>native</id>
    <build>
      <plugins>
        <plugin>
          <groupId>org.graalvm.buildtools</groupId>
          <artifactId>native-maven-plugin</artifactId>
          <version>0.10.6</version>
          <extensions>true</extensions>
          <executions>
            <execution>
              <id>build-native</id>
              <goals>
                <goal>compile-no-fork</goal>
              </goals>
              <phase>package</phase>
            </execution>
          </executions>
          <configuration>
            <imageName>${project.artifactId}</imageName>
            <buildArgs>
              <buildArg>--no-fallback</buildArg>
            </buildArgs>
          </configuration>
        </plugin>
      </plugins>
    </build>
  </profile>
</profiles>
```

Build with: `./mvnw -Pnative package`

**For Gradle projects**, apply the `org.graalvm.buildtools.native` plugin. See the [Gradle Native Plugin Reference](references/gradle-native-plugin.md) for full configuration.

Key Gradle setup (Kotlin DSL):

```kotlin
plugins {
    id("org.graalvm.buildtools.native") version "0.10.6"
}

graalvmNative {
    binaries {
        named("main") {
            imageName.set(project.name)
            buildArgs.add("--no-fallback")
        }
    }
}
```

Build with: `./gradlew nativeCompile`

### 3. Framework-Specific Configuration

Each framework has its own AOT strategy. Apply the correct configuration based on the detected framework.

**Spring Boot** (3.x+): Spring Boot has built-in GraalVM support with AOT processing. See the [Spring Boot Native Reference](references/spring-boot-native.md) for patterns including `RuntimeHints`, `@RegisterReflectionForBinding`, and test support.

Key points:
- Use `spring-boot-starter-parent` 3.x+ which includes the native profile
- Register reflection hints via `RuntimeHintsRegistrar`
- Run AOT processing with `process-aot` goal
- Build with: `./mvnw -Pnative native:compile` or `./gradlew nativeCompile`

**Quarkus and Micronaut**: These frameworks are designed native-first and require minimal additional configuration. See the [Quarkus & Micronaut Reference](references/quarkus-micronaut-native.md).

### 4. GraalVM Reachability Metadata

Native Image uses a closed-world assumption — all code paths must be known at build time. Dynamic features like reflection, resources, and proxies require explicit metadata configuration.

**Metadata files** live in `META-INF/native-image/<group>/<artifact>/`. See [reflection-resource-config.md](references/reflection-resource-config.md) for format and examples.

### 5. The Iterative Fix Engine

Native image builds often fail due to missing metadata. Follow this iterative approach:

**Step 1 — Execute the native build:**

```bash
# Maven
./mvnw -Pnative package 2>&1 | tee native-build.log

# Gradle
./gradlew nativeCompile 2>&1 | tee native-build.log
```

**Step 2 — Parse build errors and identify the root cause:**

Common error patterns and their fixes:

| Error Pattern | Cause | Fix |
|---------------|-------|-----|
| `ClassNotFoundException: com.example.MyClass` | Missing reflection metadata | Add to `reflect-config.json` or use `@RegisterReflectionForBinding` |
| `NoSuchMethodException` | Method not registered for reflection | Add method to reflection config |
| `MissingResourceException` | Resource not included in native image | Add to `resource-config.json` |
| `Proxy class not found` | Dynamic proxy not registered | Add interface list to `proxy-config.json` |
| `UnsupportedFeatureException: Serialization` | Missing serialization metadata | Add to `serialization-config.json` |

**Step 3 — Apply fixes** by updating the appropriate metadata file or using framework annotations.

**Step 4 — Rebuild and verify.** Repeat until the build succeeds.

**Step 5 — If manual fixes are insufficient**, use the GraalVM tracing agent to collect reachability metadata automatically. See the [Tracing Agent Reference](references/tracing-agent.md).

### 6. Validation and Benchmarking

Once the native build succeeds:

**Verify the executable runs correctly:**

```bash
# Run the native executable
./target/<app-name>

# For Spring Boot, verify the application context loads
curl http://localhost:8080/actuator/health
```

**Measure startup time:**

```bash
# Time the startup
time ./target/<app-name>

# For Spring Boot, check the startup log
./target/<app-name> 2>&1 | grep "Started .* in"
```

**Measure memory footprint (RSS):**

```bash
# On Linux
ps -o rss,vsz,comm -p $(pgrep <app-name>)

# On macOS
ps -o rss,vsz,comm -p $(pgrep <app-name>)
```

**Compare with JVM baseline:**

| Metric | JVM | Native | Improvement |
|--------|-----|--------|-------------|
| Startup time | ~2-5s | ~50-200ms | 10-100x |
| Memory (RSS) | ~200-500MB | ~30-80MB | 3-10x |
| Binary size | JRE + JARs | Single binary | Simplified |

### 7. Docker Integration

Build minimal container images with native executables:

```dockerfile
# Multi-stage build
FROM ghcr.io/graalvm/native-image-community:21 AS builder
WORKDIR /app
COPY . .
RUN ./mvnw -Pnative package -DskipTests

# Minimal runtime image
FROM debian:bookworm-slim
COPY --from=builder /app/target/<app-name> /app/<app-name>
EXPOSE 8080
ENTRYPOINT ["/app/<app-name>"]
```

For Spring Boot applications, use `paketobuildpacks/builder-jammy-tiny` with Cloud Native Buildpacks:

```bash
./mvnw -Pnative spring-boot:build-image
```

## Best Practices

1. **Start with the tracing agent** on complex projects to generate an initial metadata baseline
2. **Use the `native` profile** to keep native-specific config separate from standard builds
3. **Prefer `--no-fallback`** to ensure a true native build (no JVM fallback)
4. **Test with `nativeTest`** to run JUnit tests in native mode
5. **Use GraalVM Reachability Metadata Repository** for third-party library metadata
6. **Minimize reflection** — prefer constructor injection and compile-time DI where possible
7. **Include resource patterns** explicitly rather than relying on classpath scanning
8. **Profile before and after** — always measure startup and memory improvements
9. **Use Java 21+** for the best GraalVM compatibility and performance
10. **Keep GraalVM and Native Build Tools versions aligned**

## Examples

### Example 1: Adding Native Support to a Spring Boot Maven Project

**Scenario:** You have a Spring Boot 3.x REST API and want to compile it to a native executable.

**Step 1 — Add the native profile to `pom.xml`:**

```xml
<profiles>
  <profile>
    <id>native</id>
    <build>
      <plugins>
        <plugin>
          <groupId>org.springframework.boot</groupId>
          <artifactId>spring-boot-maven-plugin</artifactId>
          <executions>
            <execution>
              <id>process-aot</id>
              <goals>
                <goal>process-aot</goal>
              </goals>
            </execution>
          </executions>
        </plugin>
        <plugin>
          <groupId>org.graalvm.buildtools</groupId>
          <artifactId>native-maven-plugin</artifactId>
        </plugin>
      </plugins>
    </build>
  </profile>
</profiles>
```

**Step 2 — Register reflection hints for DTOs:**

```java
@RestController
@RegisterReflectionForBinding({UserDto.class, OrderDto.class})
public class UserController {

    @GetMapping("/users/{id}")
    public UserDto getUser(@PathVariable Long id) {
        return userService.findById(id);
    }
}
```

**Step 3 — Build and run:**

```bash
./mvnw -Pnative native:compile
./target/myapp
# Started MyApplication in 0.089 seconds
```

### Example 2: Resolving a Reflection Error in Native Build

**Scenario:** Native build fails with `ClassNotFoundException` for a Jackson-serialized DTO.

**Error output:**

```
com.oracle.svm.core.jdk.UnsupportedFeatureError:
  Reflection registration missing for class com.example.dto.PaymentResponse
```

**Fix — Add to `src/main/resources/META-INF/native-image/reachability-metadata.json`:**

```json
{
  "reflection": [
    {
      "type": "com.example.dto.PaymentResponse",
      "allDeclaredConstructors": true,
      "allDeclaredMethods": true,
      "allDeclaredFields": true
    }
  ]
}
```

**Or use the Spring Boot annotation approach:**

```java
@RegisterReflectionForBinding(PaymentResponse.class)
@Service
public class PaymentService { /* ... */ }
```

### Example 3: Using the Tracing Agent for a Complex Project

**Scenario:** A project with many third-party libraries needs comprehensive reachability metadata.

```bash
# 1. Build the JAR
./mvnw package -DskipTests

# 2. Run with the tracing agent
java -agentlib:native-image-agent=config-output-dir=src/main/resources/META-INF/native-image \
    -jar target/myapp.jar

# 3. Exercise all endpoints
curl http://localhost:8080/api/users
curl -X POST http://localhost:8080/api/orders -H 'Content-Type: application/json' -d '{"item":"test"}'
curl http://localhost:8080/actuator/health

# 4. Stop the application (Ctrl+C), then build native
./mvnw -Pnative native:compile

# 5. Verify
./target/myapp
```

## Constraints, Pitfalls, and Troubleshooting

- **Closed-world assumption**: All code paths must be known at build time — dynamic class loading, runtime bytecode generation, and `MethodHandles.Lookup` may not work
- **GraalVM Native Image requires Java 17+** (Java 21+ recommended for best compatibility)
- **Build time and memory**: Native compilation is resource-intensive — expect 2-10 minutes and 4-8 GB RAM for typical projects
- **Not all libraries are compatible**: Libraries relying heavily on reflection, dynamic proxies, or CGLIB may require extensive metadata configuration
- **AOT profiles are fixed at build time**: Spring Boot `@Profile` and `@ConditionalOnProperty` are evaluated during AOT processing, not at runtime
- **Forgetting `--no-fallback`**: Without this flag, the build may silently produce a JVM fallback image instead of a true native executable
- **Incomplete tracing agent coverage**: The agent only captures code paths exercised during the run — ensure all features are tested
- **Version mismatches**: Keep GraalVM JDK, Native Build Tools plugin, and framework versions aligned to avoid incompatibilities
- **Classpath differences**: The classpath at AOT/build time must match runtime — adding/removing JARs after native compilation causes failures
- **Native executables are not tamper-proof**. Never embed secrets; pass via environment variables or external config at runtime.

| Issue | Solution |
|-------|----------|
| Build runs out of memory | Increase build memory: `-J-Xmx8g` in `buildArgs` |
| Build takes too long | Use build cache, reduce classpath, enable quick build mode for dev |
| Application crashes at runtime | Missing reflection/resource metadata — run tracing agent |
| Spring Boot context fails to load | Check `@Conditional` beans and profile-dependent config |
| Third-party library not compatible | Check GraalVM Reachability Metadata repo or add manual hints |

## Related Skills

- `spring-boot-actuator` — native image health checks and monitoring endpoints
- `docker-expert` — minimal Docker images for native executables

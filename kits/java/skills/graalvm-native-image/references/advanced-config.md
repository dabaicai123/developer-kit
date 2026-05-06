# GraalVM Native Image — Advanced Configuration

Supplement to the SKILL.md. Covers Gradle setup, reflection/resource config, and tracing agent usage.

## Gradle Native Image Plugin

```groovy
plugins {
    id 'org.graalvm.buildtools.native' version '0.10.3'
}

graalvmNative {
    binaries {
        main {
            imageName = 'my-app'
            mainClass = 'com.example.Application'
            buildArgs = [
                '--no-fallback',
                '-H:+ReportExceptionStackTraces',
                '--initialize-at-build-time=org.slf4j',
                '--initialize-at-run-time=com.example.domain'
            ]
        }
    }
    metadataRepository { enabled = true }
}
```

## Reflection & Resource Configuration

### Reachability Metadata Repository (Recommended)

GraalVM metadata repo provides pre-built metadata for common libraries. Enable in Maven/Gradle configs (see SKILL.md for Maven). For Gradle: `metadataRepository { enabled = true }`.

### RuntimeHints (Spring Boot 3.5+ — Preferred Over Manual JSON)

```java
@Component
public class OrderRuntimeHints implements RuntimeHintsRegistrar {
    @Override
    public void registerHints(RuntimeHints hints, ClassLoader classLoader) {
        hints.reflection()
            .registerType(Order.class, MemberCategory.INVOKE_PUBLIC_METHODS,
                MemberCategory.INVOKE_PUBLIC_CONSTRUCTORS);
        hints.resources().registerPattern(".*\\.xml");
    }
}
```

Register via `@ImportRuntimeHints(OrderRuntimeHints.class)` or SpringFactories.

### Manual Config (Fallback)

```json
// META-INF/native-image/reflect-config.json
[{"name":"com.example.domain.model.Order","allPublicFields":true,"allPublicMethods":true}]
// META-INF/native-image/resource-config.json
{"resources":{"includes":[{"pattern":".*\\.xml$"}]}}
```

## Tracing Agent

Run on JVM first to capture runtime reflection/resource access:

```bash
# Step 1: Run with tracing agent
java -agentlib:native-image-agent=config-output-dir=src/main/resources/META-INF/native-image \
    -jar target/my-app.jar
# Step 2: Exercise all runtime paths (API calls, serialization, dynamic proxies)
curl http://localhost:8080/v1/orders
# Step 3: Stop — agent writes reflect-config.json, resource-config.json
# Step 4: Build native image
./mvnw -Pnative native:compile
```

### Agent Modes

| Mode | Flag | Use When |
|------|------|---------|
| config-output-dir | Write new configs | First run |
| config-merge-dir | Merge into existing | Iterative runs |
| config-write-period-secs | Periodic write | Long-running services |

**Pitfall**: only paths exercised during tracing are captured. Miss any endpoint = runtime error. Deduplicate with `jq 'unique'`.
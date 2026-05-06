---
name: maven-dependencies
description: Manages Apache Maven POM configuration, plugins, lifecycle, and dependency management with BOMs. Use when configuring Maven builds, managing dependencies, setting up build plugins, or troubleshooting build issues.
version: "1.0.0"
---

# Maven Dependencies

Master Apache Maven for Java project builds and dependency management.

## Quick Reference

```xml
<project>
    <properties>
        <java.version>21</java.version>
    </properties>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>3.5.14</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>
</project>
```

## Lifecycle Phases

```
validate → compile → test → package → verify → install → deploy
```

## Commands

| Command | Description |
|---------|-------------|
| `mvn dependency:tree` | View dependencies |
| `mvn dependency:analyze` | Find unused/undeclared |
| `mvn versions:display-dependency-updates` | Check updates |
| `mvn help:effective-pom` | View effective POM |
| `mvn -B verify` | Batch mode build |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Dependency not found | Check repository, version |
| Version conflict | Use BOM or enforcer |
| Build OOM | `MAVEN_OPTS=-Xmx1g` |

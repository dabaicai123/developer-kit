---
description: Upgrades Maven/Gradle dependencies to latest stable versions while maintaining compatibility. Handles Spring Boot version upgrades, MyBatis-Plus updates, and security patching.
argument-hint: "[pom.xml-or-build.gradle-path] [target-versions]"
allowed-tools: Read, Write, Edit, Bash
model: inherit
---

## Upgrade Dependencies Command

Upgrades project dependencies to latest compatible versions.

### Usage

`/devkit.java.upgrade-dependencies [pom.xml-path] [target-versions]`

**pom.xml-path**: Path to pom.xml (defaults to `pom.xml`)
**target-versions**: Optional target versions (e.g., `spring-boot=3.5.2 mybatis-plus=3.5.10`)

### Execution

1. Invoke the `spring-boot-backend-development-expert` agent
2. Use the `maven-dependencies` skill for version management patterns
3. Read current dependency file
4. Identify upgrade targets:
   - Spring Boot BOM managed versions
   - MyBatis-Plus and related libraries
   - Spring Cloud Alibaba components
   - Security-critical libraries (JJWT, Spring Security, etc.)
5. Check compatibility between versions
6. Apply upgrades to pom.xml
7. Verify build compiles: `mvn clean compile`
8. Run tests: `mvn test`
9. Report changes with before/after version comparison
---
description: Audits Maven/Gradle dependencies for vulnerabilities, outdated versions, unnecessary dependencies, and version conflicts. Checks for known CVEs and recommends updates.
argument-hint: "[pom.xml-or-build.gradle-path]"
allowed-tools: Read, Bash, Grep
model: inherit
---

## Dependency Audit Command

Audits project dependencies for security, compatibility, and maintenance issues.

### Usage

`/devkit.java.dependency-audit [pom.xml-or-build.gradle-path]`

**pom.xml-or-build.gradle-path**: Path to the dependency file (defaults to `pom.xml`)

### Execution

1. Invoke the `spring-boot-backend-development-expert` agent
2. Parse the dependency file:
   - Extract all direct and transitive dependencies
   - Check for known CVEs using OWASP dependency-check (if available)
3. Identify issues:
   - **Outdated versions**: Dependencies with newer stable releases
   - **Security vulnerabilities**: Known CVEs in current versions
   - **Conflicts**: Version conflicts between transitive dependencies
   - **Unnecessary**: Dependencies not used in code
   - **Redundant**: Dependencies already provided by Spring Boot BOM
4. Generate audit report with:
   - Severity levels (CRITICAL, HIGH, MEDIUM, LOW)
   - Recommended update versions
   - Compatibility notes
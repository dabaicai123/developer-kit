---
name: spring-boot-verification
description: "Verification loop for Spring Boot projects: build, static analysis, tests with coverage, security scans, and diff review before release or PR."
version: "1.1.0"
type: skill
---

# Spring Boot Verification Loop

Run before PRs, after major changes, and pre-deploy.

## When to use

- Before opening a pull request
- After major refactoring or dependency upgrades
- Pre-deployment verification for staging or production
- Validating test coverage meets thresholds

## Phase 1: Build

```bash
./mvnw -T 4 clean verify -DskipTests
# or
./gradlew clean assemble -x test
```

If build fails, stop and fix.

## Phase 2: Static Analysis

```bash
./mvnw -T 4 spotbugs:check pmd:check checkstyle:check
# or
./gradlew checkstyleMain pmdMain spotbugsMain
```

## Phase 3: Tests + Coverage

```bash
./mvnw -T 4 test
./mvnw jacoco:report   # verify 80%+ coverage
# or
./gradlew test jacocoTestReport
```

Report: total tests passed/failed, coverage % (lines/branches).

> For detailed test patterns, see `spring-boot-tdd` skill.

## Phase 4: Security Scan

```bash
# Dependency CVEs
./mvnw org.owasp:dependency-check-maven:check
# or
./gradlew dependencyCheckAnalyze

# Secrets in source
grep -rn "password\s*=\s*\"" src/ --include="*.java" --include="*.yml" --include="*.properties"
grep -rn "sk-\|api_key\|secret" src/ --include="*.java" --include="*.yml"

# Secrets in git history
git secrets --scan  # if configured
```

### Security Findings Checklist

```bash
# System.out.println (NOT use in production — use SLF4J logger)
grep -rn "System\.out\.print" src/main/ --include="*.java"

# Raw exception messages in responses (NOT expose e.getMessage() to clients)
grep -rn "e\.getMessage()" src/main/ --include="*.java"

# Wildcard CORS (NOT use allowedOrigins="*" or allowedOriginPatterns="*")
grep -rn "allowedOrigins.*\*\|allowedOriginPatterns.*\*" src/main/ --include="*.java"

# javax.* imports (NOT use javax.* in Spring Boot 3.x — use jakarta.*)
grep -rn "import javax\." src/main/ --include="*.java"
```

## Phase 5: Lint/Format

```bash
./mvnw spotless:check   # or spotless:apply to auto-fix
./gradlew spotlessCheck
```

## Phase 6: Diff Review

```bash
git diff --stat
git diff
```

Checklist:
- No `System.out.println` or unguarded `log.debug` remaining
- Error responses use structured error codes; HTTP status matches error semantics
- Transactions and validation present where needed
- Config changes documented

## Anti-patterns

- NOT use `javax.*` imports — Spring Boot 3.5.x requires `jakarta.*` (Jakarta EE 10)
- NOT expose `e.getMessage()` in API responses — leaks internal details, no structured error code
- NOT use wildcard CORS (`allowedOrigins="*"`) — use origin whitelist or `allowedOriginPatterns` with explicit domains
- NOT hardcode secrets in source or config — use environment variables or Spring Cloud Config
- NOT skip static analysis on "minor" changes — `spotbugs:check`, `pmd:check`, `checkstyle:check` must pass with exit code 0
- NOT run `mvn` directly — use `./mvnw` (Maven wrapper) to ensure consistent build tool version

## Output Template

```
VERIFICATION REPORT
===================
Build:     [PASS/FAIL]
Static:    [PASS/FAIL] (spotbugs/pmd/checkstyle)
Tests:     [PASS/FAIL] (X/Y passed, Z% coverage)
Security:  [PASS/FAIL] (CVE findings: N)
Diff:      [X files changed]

Overall:   [READY / NOT READY]

Issues to Fix:
1. ...
2. ...
```

## Continuous Mode

- Re-run phases on significant changes or every 30-60 minutes in long sessions
- Quick feedback loop: `./mvnw -T 4 test` + spotbugs

## Related Skills

- `spring-boot-tdd`
- `spring-boot-actuator`
- `spring-boot-logging`
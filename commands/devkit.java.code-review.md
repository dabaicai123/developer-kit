---
description: Validates Java code quality for Spring Boot applications with MyBatis-Plus, security, performance, architecture, and best practices analysis. Use when reviewing code changes or before merging pull requests.
argument-hint: "[review-type] [file/directory-path]"
allowed-tools: Read, Write, Bash, Edit, Grep, Glob
model: inherit
---

## Code Review Command

Reviews Java/Spring Boot code for quality, security, and pattern compliance.

### Usage

`/devkit.java.code-review [review-type] [path]`

**Review types:**
- `full` — Complete review (architecture, security, performance, testing, patterns)
- `security` — Security-focused review (OWASP, JWT, SQL injection, authorization)
- `performance` — Performance review (N+1, caching, pagination, queries)
- `architecture` — Architecture review (layer separation, package organization, DDD)
- `testing` — Testing review (coverage, mocking strategy, test quality)
- `mybatis-plus` — MyBatis-Plus pattern review (LambdaQueryWrapper, ServiceImpl, pagination)

**Path**: File or directory to review. Defaults to `git diff` if not specified.

### Execution

1. Detect review scope from arguments or `git diff`
2. Run the `spring-boot-code-review-expert` agent
3. Apply the relevant skills based on review type:
   - `full` → spring-boot-rest-api-standards, spring-boot-security, mybatis-plus-patterns, spring-boot-exception-handling
   - `security` → spring-boot-security, spring-boot-security-jwt, spring-boot-validation
   - `mybatis-plus` → mybatis-plus-patterns, jetcache
4. Generate structured report with P0-P3 severity levels
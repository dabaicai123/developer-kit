---
description: Security review for Spring Boot applications covering OWASP Top 10, JWT configuration, Spring Security setup, input validation, and MyBatis-Plus SQL injection prevention.
argument-hint: "[file/directory-path]"
allowed-tools: Read, Bash, Grep, Glob
model: inherit
---

## Security Review Command

Reviews Spring Boot application security for vulnerabilities and compliance.

### Usage

`/devkit.java.security-review [file/directory-path]`

**file/directory-path**: Path to review (defaults to project root)

### Execution

1. Invoke the `java-security-expert` agent
2. Use the `spring-boot-security` and `spring-boot-security-jwt` skills
3. Run security audit phases:
   - **Authentication**: JWT config, token storage, refresh rotation
   - **Authorization**: Endpoint access control, RBAC, method security
   - **Input Validation**: @Valid usage, SQL injection (LambdaQueryWrapper), XSS
   - **MyBatis-Plus**: LambdaQueryWrapper usage, ${} vs #{} in mapper XML
   - **Headers**: CORS config, security headers (X-Content-Type-Options, etc.)
   - **Dependencies**: Known CVEs, outdated security-critical versions
4. Generate security report with OWASP categorization and severity ratings
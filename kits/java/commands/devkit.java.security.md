---
description: Security audit for Spring Boot applications — JWT, OWASP, input validation, authorization, file handling, and dependency security. Delegates to devkit:java:security.
argument-hint: "[auth|validation|owasp|dependency|full] [path]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

Invoke the `devkit:java:security` agent. If a path is given, audit that file/directory. If no path given, scan the entire project. Pass the audit type as focus if provided.
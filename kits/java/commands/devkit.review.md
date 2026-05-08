---
description: Review Java/Spring Boot code for quality, security, architecture, and pattern compliance. Defaults to git diff. Delegates to spring-boot-code-review-expert.
argument-hint: "[full|security|performance|architecture|mybatis-plus] [path]"
allowed-tools: Read, Bash, Grep, Glob
model: inherit
---

Invoke the `spring-boot-code-review-expert` agent. Use `git diff` as scope if no path given. Pass the review type as focus if provided.

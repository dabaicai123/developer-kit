---
description: Generate unit or integration tests for a Java class. Auto-detects class type (Service, Controller, Mapper, Utility). Delegates to spring-boot-unit-testing-expert.
argument-hint: "<class-file-path> [unit|integration]"
allowed-tools: Read, Write, Bash, Glob, Grep
model: inherit
---

Invoke the `spring-boot-unit-testing-expert` agent with the target file. Detect test type from the second argument or infer from class type.

---
description: Generate unit or integration tests for a Java class. Auto-detects class type (Service, Controller, Mapper, Utility). Delegates to devkit:java:test.
argument-hint: "<class-file-path> [unit|integration]"
allowed-tools: Read, Write, Bash, Glob, Grep
model: inherit
---

Invoke the `devkit:java:test` agent with the target file. Detect test type from the second argument or infer from class type.
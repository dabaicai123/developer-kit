---
description: Refactor a Java class or generate a refactoring task list for a module. Delegates to devkit:java:refactor.
argument-hint: "[class-file-path|directory]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

Invoke the `devkit:java:refactor` agent. If a file is given, refactor it. If a directory is given, generate a prioritized refactoring task list.
---
description: Refactor a Java class or generate a refactoring task list for a module. Delegates to java-refactor-expert.
argument-hint: "[class-file-path|directory]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

Invoke the `java-refactor-expert` agent. If a file is given, refactor it. If a directory is given, generate a prioritized refactoring task list.

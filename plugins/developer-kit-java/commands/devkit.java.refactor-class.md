---
description: Refactors a Java class following clean code principles, SOLID patterns, and Java 21 features. Analyzes complexity, suggests improvements, and applies modern patterns.
argument-hint: "[class-file-path]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

## Refactor Class Command

Refactors a Java class to improve quality, reduce complexity, and modernize to Java 21.

### Usage

`/devkit.java.refactor-class [class-file-path]`

**class-file-path**: Path to the Java file to refactor (e.g., `src/main/java/com/example/service/UserServiceImpl.java`)

### Execution

1. Invoke the `java-refactor-expert` agent
2. Read and analyze the target class:
   - Cyclomatic complexity (threshold: 10)
   - Method length (threshold: 20 lines)
   - Class coupling and dependency count
   - Naming conventions
   - Java 21 modernization opportunities
3. Identify refactoring targets ordered by impact/effort
4. Apply refactoring patterns:
   - Extract Method for long methods
   - Replace Conditional with Polymorphism
   - Constructor injection instead of field injection
   - LambdaQueryWrapper instead of QueryWrapper (MyBatis-Plus)
   - Records for immutable DTOs
   - Pattern matching where applicable
5. Verify existing tests still pass after each refactoring
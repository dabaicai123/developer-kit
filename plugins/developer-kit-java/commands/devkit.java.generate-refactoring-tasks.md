---
description: Analyzes a Java project or codebase and generates prioritized refactoring task list with effort estimates. Identifies code smells, complexity hotspots, and modernization opportunities.
argument-hint: "[project-or-package-path]"
allowed-tools: Read, Bash, Glob, Grep
model: inherit
---

## Generate Refactoring Tasks Command

Analyzes a project and generates a prioritized refactoring task list.

### Usage

`/devkit.java.generate-refactoring-tasks [project-or-package-path]`

**project-or-package-path**: Path to analyze (defaults to `src/main/java/`)

### Execution

1. Invoke the `java-refactor-expert` agent
2. Scan project for code quality indicators:
   - Cyclomatic complexity per method (threshold: 10)
   - Method length per method (threshold: 20 lines)
   - Class coupling and dependency count
   - Duplication patterns
   - Java 21 modernization opportunities
3. Detect code smells:
   - Long methods, God classes, Feature envy
   - Duplicated code, Dead code
   - Tight coupling, Multiple responsibilities
   - MyBatis-Plus anti-patterns (QueryWrapper, direct BaseMapper calls)
4. Prioritize by impact/effort matrix:
   - **High impact, Low effort** → Do first
   - **High impact, High effort** → Plan carefully
   - **Low impact, Low effort** → Quick wins
   - **Low impact, High effort** → Consider skipping
5. Generate task list with:
   - Task description, file path, effort estimate
   - Priority ranking, expected impact
   - Recommended refactoring approach
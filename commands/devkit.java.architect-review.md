---
description: Reviews Spring Boot project architecture for DDD alignment, layer separation, package organization, and design pattern compliance. Evaluates COLA/DDD architecture adherence.
argument-hint: "[project-path]"
allowed-tools: Read, Bash, Glob, Grep
model: inherit
---

## Architecture Review Command

Reviews the architecture of a Spring Boot project for pattern compliance and structure quality.

### Usage

`/devkit.java.architect-review [project-path]`

**project-path**: Path to the project root (defaults to current project)

### Execution

1. Invoke the `spring-boot-backend-development-expert` agent
2. Scan project structure:
   - Package organization (MVC vs COLA/DDD)
   - Layer separation verification
   - Dependency direction check (no upward dependencies)
3. Verify architecture patterns:
   - **MVC**: Controller → Service → Mapper
   - **COLA**: Adapter → App → Domain → Infrastructure
   - Check for layer violations (Controller calling Mapper, etc.)
4. Evaluate MyBatis-Plus integration:
   - Mapper/Service/ServiceImpl pattern usage
   - LambdaQueryWrapper adoption rate
   - @TableLogic soft delete consistency
5. Generate architecture report with:
   - Pattern compliance score
   - Anti-patterns found
   - Recommended improvements
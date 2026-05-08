---
description: Generates comprehensive documentation for Spring Boot REST APIs using SpringDoc OpenAPI. Creates API documentation, Swagger UI setup, and annotated controllers.
argument-hint: "[controller-or-project-path]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

## Generate Docs Command

Generates API documentation for Spring Boot REST controllers.

### Usage

`/devkit.java.generate-docs [controller-or-project-path]`

**controller-or-project-path**: Path to controller files or project root

### Execution

1. Invoke the `spring-boot-backend-development-expert` agent
2. Use the `spring-boot-openapi-documentation` skill for annotation patterns
3. Use the `documentation-writer` skill for documentation style
4. Scan controllers for missing OpenAPI annotations
5. Add annotations to each endpoint:
   - `@Tag` on controller class
   - `@Operation` on each method
   - `@ApiResponse` for success and error responses
   - `@Parameter` for path/query parameters
6. Configure SpringDoc if not already set up
7. Generate API documentation summary
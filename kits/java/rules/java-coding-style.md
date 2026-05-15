---
paths:
  - "**/*.java"
---

# Java Coding Style

## Core Principles

- **KISS**: prefer the simplest solution that works.
- **DRY**: extract repeated logic only when the repetition is real.
- **YAGNI**: do not introduce abstractions before they are needed.
- **Immutability**: prefer `record`, `final` fields, and `List.copyOf()` when they improve clarity and safety.

## Formatting

- Use `google-java-format` or project Checkstyle when configured.
- One public top-level type per file.
- Match the project's existing indentation style.
- Member order: constants, fields, constructors, public methods, protected methods, private methods.
- Files should usually stay between 200 and 400 lines; 800 lines is the practical upper bound.
- Organize by feature/domain, not by technical type, when the project already follows domain-first layout.

## Modern Java (Java 21)

Use modern language features when they improve clarity:

- `record` for immutable DTOs or value types.
- Sealed classes for closed type hierarchies.
- Pattern matching for `instanceof`.
- Pattern matching in `switch` for exhaustive sealed type handling.
- Text blocks for multi-line strings.
- Switch expressions with arrow syntax.
- `var` only when the local type is obvious from the right-hand side.

```java
if (shape instanceof Circle c) {
    return Math.PI * c.radius() * c.radius();
}

public sealed interface PaymentMethod permits CreditCard, BankTransfer, Wallet {
}

String label = switch (status) {
    case ACTIVE -> "Active";
    case CLOSED -> "Closed";
};
```

## Optional

- Return `Optional<T>` from finder methods when absence is expected.
- Never call `Optional.get()` without checking presence.
- Do not use `Optional` as a field type or method parameter.

```java
return repository.findById(id)
    .map(ResponseDto::from)
    .orElseThrow(() -> new OrderNotFoundException(id));
```

## Streams

- Keep pipelines short, usually three or four operations at most.
- Prefer method references when they remain readable.
- Avoid side effects in stream pipelines.
- Use a simple loop when stream logic becomes hard to read.

## Comments & Javadoc

Use comments to explain business meaning and non-obvious decisions, not to restate code.

- Production classes, interfaces, and enums need concise Chinese Javadoc that states responsibility.
- Public and protected production methods need Javadoc when they are API, service, executor, gateway, mapper, or extension points.
- DO / DTO / BO / Cmd / Qry fields need a `/** */` business comment. DTO / Cmd / Qry fields also use `@Schema(description = "...")` when OpenAPI is enabled.
- Private methods need Javadoc only for non-trivial business rules or algorithms.
- Inline comments explain WHY: business constraints, workarounds, ordering requirements, external system behavior, or algorithms.
- Do not add comments that merely translate names or repeat assignments.
- Generated test methods should express scenarios through method names and assertions, not Chinese scenario comments.
- Test classes and test methods do not need Chinese Javadoc only to restate the scenario. Comment tests only for non-obvious setup, fixtures, external constraints, or workarounds.

Layer-specific emphasis:

- ServiceI implementations document delegation to CmdExe/QryExe rather than owning business logic.
- CmdExe / QryExe document the use case and workflow.
- Gateway methods use domain language, not database update details.
- Client DTO/Cmd/Qry comments describe API contracts and do not mention domain internals.

## Import Completeness

- After writing source/test files, verify all symbols have explicit imports.
- Common misses: `java.util.Map`, sealed interfaces, Hamcrest matchers, `ParameterObject`.

## Cross-Cutting References

- Error handling: follow `error-handling.md` and the `spring-boot-exception-handling` skill.
- Input validation: validate system boundaries; use the `spring-boot-validation` skill for Bean Validation patterns.
- Data access, batch operations, and N+1 avoidance: follow `mybatis-plus-conventions.md` and `transaction-conventions.md`.

## Code Smells

- **Deep nesting**: prefer early returns.
- **Magic numbers**: use named constants.
- **Long functions**: split into focused methods.

## Anti-Patterns

- `@Autowired` on fields for required dependencies - use constructor injection.
- Mutable state where immutable values are enough - default to `final`.
- Comments that repeat the code - write WHY, not WHAT.

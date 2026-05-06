---
paths:
  - "**/*.java"
---

# Java Coding Style

## Core Principles

- **KISS**: simplest solution that works; optimize for clarity over cleverness
- **DRY**: extract repeated logic; introduce abstractions when repetition is real, not speculative
- **YAGNI**: don't build features/abstractions before they're needed; start simple, refactor under pressure
- **Immutability**: prefer immutable data — `record`, `final` fields, `List.copyOf()`. Prevents hidden side effects and enables safe concurrency

## Formatting

- **google-java-format** or **Checkstyle** (Google or Sun style) for enforcement
- One public top-level type per file
- Consistent indent: 2 or 4 spaces (match project standard)
- Member order: constants, fields, constructors, public methods, protected, private
- Files: 200-400 lines typical, 800 max. Organize by feature/domain, not by type

## Modern Java (Java 21)

Use modern features where they improve clarity:

- **Records** for immutable DTOs/value types (Java 16+)
- **Sealed classes** for closed type hierarchies (Java 17+)
- **Pattern matching** `instanceof` — no explicit cast (Java 16+)
- **Pattern matching in switch** — exhaustive sealed type handling (Java 21+)
- **Text blocks** for multi-line strings (Java 15+)
- **Switch expressions** with arrow syntax (Java 14+)
- **`var`** for obvious local variable types

```java
if (shape instanceof Circle c) { return Math.PI * c.radius() * c.radius(); }
public sealed interface PaymentMethod permits CreditCard, BankTransfer, Wallet {}
String label = switch (status) { case ACTIVE -> "Active"; case CLOSED -> "Closed"; };
```

## Optional

- Return `Optional<T>` from finder methods; use `map()/flatMap()/orElseThrow()`
- Never call `get()` without `isPresent()`; never use `Optional` as field type or parameter

```java
return repository.findById(id).map(ResponseDto::from).orElseThrow(() -> new OrderNotFoundException(id));
```

## Streams

- Keep pipelines short (3-4 operations max); prefer method references
- Avoid side effects; for complex logic, prefer a loop over a convoluted pipeline

## Javadoc

- Every class: one-line description of responsibility
- Every public method: explain WHAT it does
- Every field in domain objects, DTOs, VOs, DOs: explain business meaning (e.g., `/** Order total amount including tax */`)
- Write WHY, not WHAT — skip comments that just repeat the code

## Import Completeness

- After writing source/test files, verify all symbols have explicit imports
- Common misses: `java.util.Map`, sealed interfaces, Hamcrest matchers

## Never Loop Individual IO

- For-loop DB calls, HTTP requests, MQ publishes, file reads = N+1 anti-pattern
- Use batch methods (`saveBatch`, `listByIds`, `IN` clause), parallel/async (`CompletableFuture`), or batch APIs

## Error Handling

- Prefer unchecked exceptions for domain errors; create domain-specific `RuntimeException` subclasses
- Avoid broad `catch (Exception e)` unless at top-level handlers; include context in messages
- See `error-handling.md` rule and `spring-boot-exception-handling` skill for full patterns

## Input Validation

- Validate all user input at system boundaries; fail fast with clear error messages
- Never trust external data (API responses, user input, file content)
- See `spring-boot-validation` skill for Jakarta Bean Validation patterns

## Code Smells

- **Deep nesting**: prefer early returns over nested conditionals
- **Magic numbers**: use named constants for thresholds, delays, limits
- **Long functions**: split into focused pieces (<50 lines each)

## Anti-Patterns

- `SELECT *` — always specify needed columns
- Catching generic `Exception` — use specific business exceptions
- `@Autowired` on fields for required deps — use constructor injection
- Mutable state where immutable suffices — default to `final`
- Comments that repeat the code (`// set the name`) — write WHY, not WHAT
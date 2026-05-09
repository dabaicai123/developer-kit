---
name: unit-test-scheduled-async
description: "Unit testing @Scheduled and @Async methods with JUnit 5, CompletableFuture, Awaitility, and Mockito: task execution, timing, cron expressions, retry behavior, and thread pool behavior. Use when testing background tasks, cron jobs, or scheduled execution."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Unit Testing `@Scheduled` and `@Async` Methods

## Overview

Patterns for unit testing Spring `@Scheduled` and `@Async` methods with JUnit 5. Test `CompletableFuture` results, use Awaitility for race conditions, mock scheduled task execution, and validate error handling — without waiting for real scheduling intervals.

## When to use this skill

- Testing `@Scheduled` method logic
- Testing `@Async` method behavior
- Verifying `CompletableFuture` results
- Testing async error handling
- Testing cron expression logic without waiting for actual scheduling
- Validating thread pool behavior and execution counts
- Testing background task logic in isolation

## Instructions

1. **Call `@Async` methods directly** — bypass Spring's async proxy; the annotation is irrelevant in unit tests
2. **Mock dependencies** with `@Mock` and `@InjectMocks` (Mockito)
3. **Wait for completion** — use `CompletableFuture.get(timeout, unit)` or `await().atMost(...).untilAsserted(...)`
4. **Call `@Scheduled` methods directly** — do not wait for cron/fixedRate; the annotation is ignored in unit tests
5. **Test exception paths** — verify `ExecutionException` wrapping on `CompletableFuture.get()`

**Debugging tips:**
- After `CompletableFuture.get()`, assert the returned value before verifying mock interactions
- If `ExecutionException` is thrown, check `.getCause()` to identify the root exception
- If Awaitility times out, increase `atMost()` duration or reduce `pollInterval()` until the condition is reachable
- After multiple task invocations, assert execution counts before `verify()` calls

## Examples

Key patterns — complete examples in `references/examples.md`:

```java
// @Async: call directly, wait with CompletableFuture.get(timeout, unit)
@Service
class EmailService {
  @Async
  public CompletableFuture<Boolean> sendEmailAsync(String to) {
    return CompletableFuture.supplyAsync(() -> true);
  }
}
@Test
void shouldReturnCompletedFuture() throws Exception {
  EmailService service = new EmailService();
  Boolean result = service.sendEmailAsync("test@example.com").get(5, TimeUnit.SECONDS);
  assertThat(result).isTrue();
}

// @Scheduled: call directly, mock the repository
@Component
class DataRefreshTask {
  private final DataRepository dataRepository;
  public DataRefreshTask(DataRepository dataRepository) { this.dataRepository = dataRepository; }
  @Scheduled(fixedDelay = 60000) public void refreshCache() { /* ... */ }
}
@Test
void shouldRefreshCache() {
  DataRepository dataRepository = mock(DataRepository.class);
  when(dataRepository.findAll()).thenReturn(List.of(new Data(1L, "item1")));
  DataRefreshTask task = new DataRefreshTask(dataRepository);
  task.refreshCache();
  verify(dataRepository).findAll();
}

// Awaitility: use for race conditions with shared mutable state
@Test
void shouldProcessAllItems() {
  BackgroundWorker worker = new BackgroundWorker();
  worker.processItems(List.of("item1", "item2", "item3"));
  Awaitility.await()
    .atMost(Duration.ofSeconds(5))
    .pollInterval(Duration.ofMillis(100))
    .untilAsserted(() -> assertThat(worker.getProcessedCount()).isEqualTo(3));
}

// Mocked dependencies with exception handling
@Test
void shouldHandleAsyncExceptionGracefully() {
  doThrow(new RuntimeException("Email failed")).when(emailService).send(any());
  CompletableFuture<String> result = service.notifyUserAsync("user123");
  assertThatThrownBy(result::get)
    .isInstanceOf(ExecutionException.class)
    .hasCauseInstanceOf(RuntimeException.class);
}
```

Full Maven/Gradle dependencies, additional test classes, and execution count patterns: see `references/examples.md`.

## Best Practices

- Always set a **timeout** on `CompletableFuture.get()` to prevent hanging tests
- Use **Awaitility** only for race conditions; prefer direct calls for simple async methods

## Common Pitfalls

- Relying on Spring's async executor instead of calling methods directly
- Not mocking dependencies that async methods invoke internally

## Constraints and Warnings

- **`@Async` self-invocation**: calling `@Async` from another method in the same class executes synchronously — the Spring proxy is bypassed
- **Thread pool ordering**: `ThreadPoolTaskScheduler` does not guarantee execution order
- **CompletableFuture chaining**: exceptions in intermediate stages can be silently lost — test each stage
- **Awaitility timeout**: always set a reasonable `atMost()`; infinite waits hang the test suite

## References

- [Spring `@Async` Documentation](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/annotation/Async.html)
- [Spring `@Scheduled` Documentation](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/scheduling/annotation/Scheduled.html)
- [Awaitility Testing Library](https://github.com/awaitility/awaitility)
- [CompletableFuture API](https://docs.oracle.com/javase/21/docs/api/java.base/java/util/concurrent/CompletableFuture.html)
- Code examples: `references/examples.md`

## Related Skills

- `spring-boot-async-processing` — @Async patterns, CompletableFuture, TaskExecutor
- `spring-boot-scheduled-tasks` — @Scheduled patterns, XXL-Job, distributed scheduling

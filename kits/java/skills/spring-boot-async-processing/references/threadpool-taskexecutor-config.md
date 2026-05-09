# ThreadPoolTaskExecutor Configuration

Primary reference for ThreadPoolTaskExecutor configuration. See async-method-patterns.md for @Async usage patterns.

## Bean configuration with detailed properties

### Full Java bean configuration

```java
@Configuration
@EnableAsync
public class AsyncExecutorConfig {

    @Bean("ioExecutor")
    public Executor ioExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(8);       // Minimum threads kept alive even when idle
        executor.setMaxPoolSize(16);       // Maximum threads the pool can create
        executor.setQueueCapacity(200);    // Tasks queued before creating new threads beyond corePoolSize
        executor.setKeepAliveSeconds(60);  // Idle threads above corePoolSize terminated after 60 seconds
        executor.setThreadNamePrefix("io-async-");  // Thread name prefix for debugging and logging
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);  // Wait for tasks on application shutdown
        executor.setAwaitTerminationSeconds(30);  // Maximum wait time on shutdown
        executor.setTaskDecorator(new ThreadContextTaskDecorator());  // Propagate ThreadContext to async threads
        executor.initialize();
        return executor;
    }
}
```

### Property explanation

| Property | Description |
|----------|-------------|
| **corePoolSize** | Minimum number of threads kept alive in the pool even when idle. Tasks submitted when pool has fewer than corePoolSize threads create new threads. |
| **maxPoolSize** | Maximum number of threads the pool can create. New threads are created only when queueCapacity is full and pool has fewer than maxPoolSize threads. |
| **queueCapacity** | Number of tasks that can be queued before the pool creates new threads beyond corePoolSize. When the queue is full and pool < maxPoolSize, new threads are created. |
| **keepAliveSeconds** | Time in seconds that idle threads above corePoolSize are kept alive before being terminated. Default is 60. |
| **threadNamePrefix** | Prefix for thread names created by this executor. Useful for identifying threads in logs and debugging. E.g., `io-async-1`, `io-async-2`. |
| **rejectedExecutionHandler** | Strategy for handling tasks that cannot be accepted (queue full, pool at maxPoolSize). See rejection policies section. |
| **waitForTasksToCompleteOnShutdown** | When true, the executor waits for currently executing tasks to finish on application shutdown. Essential for graceful shutdown. |
| **awaitTerminationSeconds** | Maximum time in seconds to wait for task completion on shutdown. After this timeout, remaining tasks are interrupted. |
| **taskDecorator** | Decorator applied to each Runnable before execution. Used for context propagation (ThreadContext, SecurityContext). |

### Thread creation flow

Understanding when threads are created is critical for pool sizing:

```
Task submitted →
  1. If pool < corePoolSize → create new thread (no queuing)
  2. If pool >= corePoolSize → queue the task
  3. If queue is full AND pool < maxPoolSize → create new thread
  4. If queue is full AND pool >= maxPoolSize → rejectedExecutionHandler
```

**Example:** With `corePoolSize=4`, `maxPoolSize=8`, `queueCapacity=200`:
- Tasks 1-4: create 4 core threads immediately
- Tasks 5-204: queued (200 capacity)
- Tasks 205-208: queue full, create 4 additional threads (reach maxPoolSize=8)
- Task 209+: queue full, pool full → rejection policy applies

## Rejection policies

### CallerRunsPolicy (recommended for production)

```java
executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
```

When the pool is full, the caller thread executes the task itself. This:
- Prevents silent task loss — tasks always execute
- Naturally throttles the caller — it cannot submit new tasks while running the rejected one
- Provides backpressure without requiring external rate limiting

**Best for:** Most production scenarios where task loss is unacceptable.

### AbortPolicy (default in Java ThreadPoolExecutor)

```java
executor.setRejectedExecutionHandler(new ThreadPoolExecutor.AbortPolicy());
```

Throws `RejectedExecutionException` when the pool is full. The caller must handle the exception.

**Best for:** Scenarios where you want explicit error signaling and the caller can retry or fail fast.

### DiscardPolicy

```java
executor.setRejectedExecutionHandler(new ThreadPoolExecutor.DiscardPolicy());
```

Silently discards the rejected task — no exception, no execution.

**Best for:** Never. Silent task loss is dangerous in production. Use only for truly disposable tasks like analytics where losing data is acceptable.

### DiscardOldestPolicy

```java
executor.setRejectedExecutionHandler(new ThreadPoolExecutor.DiscardOldestPolicy());
```

Discards the oldest queued task and retries submitting the new task. The new task may also be rejected if the queue is still full.

**Best for:** Time-sensitive tasks where older tasks are less valuable than newer ones. Rarely appropriate for most business scenarios.

### Custom rejection handler

```java
executor.setRejectedExecutionHandler((r, executor) -> {
    log.warn("Task rejected — pool full. Core: {}, Max: {}, Queue: {}, Active: {}",
        executor.getPoolSize(),
        executor.getMaximumPoolSize(),
        executor.getQueue().size(),
        executor.getActiveCount());
    // Fallback: persist to database for later retry
    taskRetryRepository.save(new PendingTask(r.toString(), LocalDateTime.now()));
});
```

## Sizing guidelines: CPU-bound vs IO-bound tasks

- **CPU-bound**: core ≈ CPU cores, max ≈ cores * 2. More threads than cores increases context-switching overhead without improving throughput.
- **IO-bound**: core ≈ cores * 2, max ≈ cores * 4-8, depending on expected IO latency. Threads waiting on IO do not consume CPU, so more threads improve throughput.

### Mixed workload

Use separate executors for different task types:

```java
@Configuration
@EnableAsync
public class AsyncExecutorConfig {
    private static final int CPU_CORES = Runtime.getRuntime().availableProcessors();

    @Bean("ioExecutor")
    public Executor ioExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(CPU_CORES * 2);
        executor.setMaxPoolSize(CPU_CORES * 4);
        executor.setQueueCapacity(200);
        executor.setThreadNamePrefix("io-async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }

    @Bean("computeExecutor")
    public Executor computeExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(CPU_CORES);
        executor.setMaxPoolSize(CPU_CORES * 2);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("compute-async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }
}
```

Route tasks to appropriate executors:

```java
@Service
public class ReportService {
    @Async("computeExecutor")  // CPU-intensive report generation
    public CompletableFuture<ReportDto> generateReport(String reportId) { ... }

    @Async("ioExecutor")  // IO-intensive file upload
    public void uploadToCloud(String filePath) { ... }
}
```

## Monitoring: ThreadPoolTaskExecutor statistics via Spring Actuator

### Expose executor metrics as Actuator endpoints

```java
@Configuration
public class ExecutorMetricsConfig {

    @Bean
    public ExecutorMetrics ioExecutorMetrics(@Qualifier("ioExecutor") Executor ioExecutor) {
        ThreadPoolTaskExecutor taskExecutor = (ThreadPoolTaskExecutor) ioExecutor;
        return new ExecutorMetrics("ioExecutor", taskExecutor);
    }

    public record ExecutorMetrics(String name, ThreadPoolTaskExecutor executor) {
        public int getActiveCount() { return executor.getActiveCount(); }
        public int getPoolSize() { return executor.getPoolSize(); }
        public int getCorePoolSize() { return executor.getCorePoolSize(); }
        public int getMaxPoolSize() { return executor.getMaxPoolSize(); }
        public long getCompletedTaskCount() { return executor.getThreadPoolExecutor().getCompletedTaskCount(); }
        public int getQueueSize() { return executor.getThreadPoolExecutor().getQueue().size(); }
        public int getQueueRemainingCapacity() { return executor.getThreadPoolExecutor().getQueue().remainingCapacity(); }
    }
}
```

### Spring Boot Actuator auto-registers executor metrics

When you use `spring-boot-starter-actuator`, Spring Boot auto-registers `ThreadPoolTaskExecutor` beans as Micrometer metrics:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

Available metrics (under `executor.` prefix):

| Metric | Description |
|--------|-------------|
| `executor.pool.size` | Current number of threads in the pool |
| `executor.pool.core` | Core pool size |
| `executor.pool.max` | Maximum pool size |
| `executor.active` | Number of threads actively executing tasks |
| `executor.completed` | Total number of completed tasks |
| `executor.queue.size` | Current queue size |
| `executor.queue.remainingCapacity` | Remaining queue capacity |

### Application.yml to expose metrics

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

### Custom health check for executor saturation

```java
@Component
@RequiredArgsConstructor
public class ExecutorHealthIndicator extends AbstractHealthIndicator {
    private final @Qualifier("ioExecutor") Executor ioExecutor;

    @Override
    protected void doHealthCheck(Health.Builder builder) {
        ThreadPoolTaskExecutor taskExecutor = (ThreadPoolTaskExecutor) ioExecutor;
        ThreadPoolExecutor pool = taskExecutor.getThreadPoolExecutor();

        int activeCount = pool.getActiveCount();
        int maxPoolSize = pool.getMaximumPoolSize();
        int queueSize = pool.getQueue().size();
        int queueCapacity = pool.getQueue().remainingCapacity() + queueSize;

        double utilization = (double) activeCount / maxPoolSize;
        double queueUtilization = (double) queueSize / queueCapacity;

        builder.withDetail("activeThreads", activeCount)
            .withDetail("maxPoolSize", maxPoolSize)
            .withDetail("poolUtilization", String.format("%.2f%%", utilization * 100))
            .withDetail("queueSize", queueSize)
            .withDetail("queueCapacity", queueCapacity)
            .withDetail("queueUtilization", String.format("%.2f%%", queueUtilization * 100));

        if (utilization > 0.8 || queueUtilization > 0.8) {
            builder.status(Status.OUT_OF_SERVICE)
                .withDetail("warning", "Thread pool approaching saturation");
        } else {
            builder.status(Status.UP);
        }
    }
}
```

## Application.yml configuration approach vs Java bean approach

### Java bean approach (recommended)

```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {
    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("async-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.setTaskDecorator(new ThreadContextTaskDecorator());
        executor.initialize();
        return executor;
    }

    @Override
    public AsyncUncaughtExceptionHandler getAsyncUncaughtExceptionHandler() {
        return (ex, method, params) -> {
            log.error("Async exception in {}: {}", method.getName(), ex.getMessage(), ex);
        };
    }
}
```

**Advantages:**
- Full control over all properties including `taskDecorator`, `rejectedExecutionHandler`
- Can create multiple named executor beans with `@Async("beanName")` routing
- `AsyncConfigurer` provides default executor + exception handler in one place
- IDE validation and type safety

### Application.yml approach (limited)

```yaml
spring:
  task:
    execution:
      pool:
        core-size: 4
        max-size: 8
        queue-capacity: 100
        keep-alive: 60s
      thread-name-prefix: async-
      shutdown:
        await-termination: true
        await-termination-period: 30s
```

**Limitations:**
- Cannot configure `rejectedExecutionHandler` (defaults to `AbortPolicy` in Spring Boot config)
- Cannot set `taskDecorator` for context propagation
- Cannot create multiple named executor beans — only one default executor
- Cannot configure `AsyncUncaughtExceptionHandler`
- Suitable only for simple single-executor setups

### Externalized configuration with Java bean (best of both worlds)

Use `application.yml` for pool sizing values, Java bean for behavior:

```yaml
# application.yml — externalized pool sizing
async:
  executors:
    io:
      core-pool-size: 8
      max-pool-size: 16
      queue-capacity: 200
      keep-alive-seconds: 60
      thread-name-prefix: "io-async-"
    compute:
      core-pool-size: 4
      max-pool-size: 8
      queue-capacity: 100
      keep-alive-seconds: 60
      thread-name-prefix: "compute-async-"
```

```java
@Configuration
@EnableAsync
@ConfigurationProperties(prefix = "async")
public class AsyncExecutorConfig {
    private Map<String, ExecutorProperties> executors = new HashMap<>();

    public static record ExecutorProperties(
        int corePoolSize, int maxPoolSize, int queueCapacity,
        int keepAliveSeconds, String threadNamePrefix
    ) {}

    // Getter/setter for executors map

    @Bean("ioExecutor")
    public Executor ioExecutor() {
        ExecutorProperties props = executors.get("io");
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(props.corePoolSize());
        executor.setMaxPoolSize(props.maxPoolSize());
        executor.setQueueCapacity(props.queueCapacity());
        executor.setKeepAliveSeconds(props.keepAliveSeconds());
        executor.setThreadNamePrefix(props.threadNamePrefix());
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setTaskDecorator(new ThreadContextTaskDecorator());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }

    @Bean("computeExecutor")
    public Executor computeExecutor() {
        ExecutorProperties props = executors.get("compute");
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(props.corePoolSize());
        executor.setMaxPoolSize(props.maxPoolSize());
        executor.setQueueCapacity(props.queueCapacity());
        executor.setKeepAliveSeconds(props.keepAliveSeconds());
        executor.setThreadNamePrefix(props.threadNamePrefix());
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setTaskDecorator(new ThreadContextTaskDecorator());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(30);
        executor.initialize();
        return executor;
    }
}
```

This approach allows:
- Pool sizing tuned per environment (dev vs staging vs production) via yml
- Full control over `taskDecorator`, `rejectedExecutionHandler` in Java
- Multiple named executors with routing via `@Async("beanName")`

## Graceful shutdown configuration

Enable: `server.shutdown: graceful` + `spring.lifecycle.timeout-per-shutdown-phase: 30s`. Set `waitForTasksToCompleteOnShutdown(true)` and `awaitTerminationSeconds(30)` on each executor. Ensure `awaitTerminationSeconds` is less than `spring.lifecycle.timeout-per-shutdown-phase`.
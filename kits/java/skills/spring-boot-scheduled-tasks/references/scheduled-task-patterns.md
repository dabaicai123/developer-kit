# Scheduled Task Patterns — Detailed Reference

## @Scheduled fixedDelay — delay after previous execution completes

`fixedDelay` waits N milliseconds after the previous execution finishes before starting the next. This prevents task pile-up when execution takes longer than the interval.

```java
@Component
@Slf4j
public class HeartbeatTask {

    @Scheduled(fixedDelayString = "${app.task.heartbeat-delay:10000}")
    public void sendHeartbeat() {
        log.info("[HeartbeatTask] sending heartbeat");
        // If this takes 5s, next execution starts 10s after this one finishes
        // Total cycle = execution time + fixedDelay
        heartbeatClient.ping();
    }
}
```

Use `fixedDelayString` for configurable values. NOT use `fixedDelay` (hardcoded, inflexible).

## @Scheduled fixedRate — execute at fixed interval regardless of completion

`fixedRate` starts a new execution every N milliseconds regardless of whether the previous one finished. If execution takes longer than the interval, tasks queue up with the default single-thread scheduler.

```java
@Component
@Slf4j
public class MetricsCollectTask {

    @Scheduled(fixedRateString = "${app.task.metrics-rate:5000}")
    public void collectMetrics() {
        // Executes every 5 seconds regardless of previous completion
        // With pool.size=1, if this takes 8s, the next execution waits
        metricsService.collect();
    }
}
```

**Warning**: With `pool.size=1`, `fixedRate` tasks that exceed their interval queue up. Either:
- Increase `spring.task.scheduling.pool.size`
- Switch to `fixedDelay` for long-running tasks
- NOT combine @Async + @Scheduled — self-invocation bypasses proxy, @Async won't apply

## @Scheduled initialDelay — delay before first execution

`initialDelay` postpones first execution by N milliseconds after startup. Combine with `fixedRate` or `fixedDelay` — it only affects the first execution.

```java
@Component
@Slf4j
public class CacheWarmupTask {

    /**
     * Wait 30 seconds after startup before first execution,
     * then execute every 5 minutes.
     */
    @Scheduled(initialDelayString = "${app.task.warmup-delay:30000}",
               fixedRateString = "${app.task.warmup-rate:300000}")
    public void warmupCache() {
        log.info("[CacheWarmupTask] warming up cache");
        cacheService.warmup();
    }
}
```

Combine `initialDelay` with `fixedRate` or `fixedDelay`. Only affects first execution.

## @Scheduled cron — cron expression syntax

`cron` allows complex schedule patterns using cron expressions. Spring cron uses 6 fields (seconds, minutes, hours, day-of-month, month, day-of-week).

```java
@Component
@Slf4j
public class NightlyTask {

    /**
     * Execute at 2:30 AM every day.
     * Cron expression from config for runtime adjustment.
     */
    @Scheduled(cron = "${app.task.nightly-cron:0 30 2 * * ?}")
    public void nightlyDataSync() {
        log.info("[NightlyTask] starting nightly sync");
        dataSyncService.syncAll();
    }
}
```

See `cron-expression-reference.md` for full cron syntax and common patterns.

## Task pool configuration: SchedulingConfigurer with custom TaskScheduler

When you need more control than `spring.task.scheduling.pool.size`, implement `SchedulingConfigurer` to provide a custom `TaskScheduler`.

```java
@Configuration
@Slf4j
public class SchedulingConfig implements SchedulingConfigurer {

    @Override
    public void configureTasks(ScheduledTaskRegistrar taskRegistrar) {
        taskRegistrar.setTaskScheduler(taskScheduler());
    }

    @Bean
    public TaskScheduler taskScheduler() {
        ThreadPoolTaskScheduler scheduler = new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(4);
        scheduler.setThreadNamePrefix("scheduled-");
        scheduler.setAwaitTerminationSeconds(60);
        scheduler.setWaitForTasksToCompleteOnShutdown(true);
        scheduler.setErrorHandler(t -> log.error("Scheduled task error", t));
        scheduler.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        return scheduler;
    }
}
```

Key settings:
- `poolSize` — thread count for scheduled tasks
- `threadNamePrefix` — identifiable thread names for debugging
- `waitForTasksToCompleteOnShutdown` + `awaitTerminationSeconds` — graceful shutdown
- `errorHandler` — catch unhandled exceptions (NOT let them silently stop the task)
- `rejectedExecutionHandler` — `CallerRunsPolicy` runs on caller thread when pool is full

## Conditional scheduling: @ConditionalOnProperty to enable/disable tasks

Disable scheduled tasks in certain environments (e.g., disable in dev, enable in prod).

```java
@Component
@Slf4j
@ConditionalOnProperty(
    name = "app.task.data-sync.enabled",
    havingValue = "true",
    matchIfMissing = false       // Default: disabled unless explicitly set
)
public class DataSyncTask {

    @Scheduled(fixedDelayString = "${app.task.sync-delay:30000}")
    public void syncData() {
        log.info("[DataSyncTask] sync started");
        dataSyncService.sync();
    }
}
```

```yaml
# application-prod.yml — enable the task
app:
  task:
    data-sync:
      enabled: true

# application-dev.yml — disable the task
app:
  task:
    data-sync:
      enabled: false
```

`matchIfMissing = false` = disabled when property absent. Use `matchIfMissing = true` for enabled-by-default.

## Dynamic scheduling: TaskScheduler for runtime task registration

For tasks that need to be registered or cancelled at runtime, use `TaskScheduler` directly instead of `@Scheduled`.

```java
@Service
@Slf4j
public class DynamicTaskService {

    private final ThreadPoolTaskScheduler taskScheduler;
    private final Map<String, ScheduledFuture<?>> scheduledTasks = new ConcurrentHashMap<>();

    public DynamicTaskService(ThreadPoolTaskScheduler taskScheduler) {
        this.taskScheduler = taskScheduler;
    }

    /**
     * Register a new scheduled task at runtime.
     */
    public void scheduleTask(String taskId, Runnable task, String cronExpression) {
        ScheduledFuture<?> future = taskScheduler.schedule(task,
            new CronTrigger(cronExpression, TimeZone.getTimeZone("Asia/Shanghai")));
        scheduledTasks.put(taskId, future);
        log.info("[DynamicTaskService] registered task: {}", taskId);
    }

    /**
     * Cancel a running scheduled task.
     */
    public void cancelTask(String taskId) {
        ScheduledFuture<?> future = scheduledTasks.get(taskId);
        if (future != null) {
            future.cancel(false);  // false = don't interrupt if currently running
            scheduledTasks.remove(taskId);
            log.info("[DynamicTaskService] cancelled task: {}", taskId);
        }
    }

    /**
     * List all active scheduled tasks.
     */
    public Set<String> getActiveTaskIds() {
        return scheduledTasks.keySet();
    }
}
```

## Monitoring: logging execution time, failure tracking

Every scheduled task must log start, end, and elapsed time. NOT swallow exceptions silently — unhandled exceptions stop `@Scheduled` tasks permanently.

```java
@Component
@Slf4j
public class MonitoredTask {

    @Scheduled(cron = "${app.task.sync-cron:0 0/10 * * * ?}")
    public void syncData() {
        long start = System.currentTimeMillis();
        String taskName = "DataSync";
        log.info("[{}] START", taskName);

        try {
            dataSyncService.sync();
            long elapsed = System.currentTimeMillis() - start;
            log.info("[{}] END — elapsed={}ms", taskName, elapsed);

            // Alert if execution takes too long
            if (elapsed > 30_000) {
                log.warn("[{}] SLOW — elapsed={}ms exceeds threshold 30000ms",
                    taskName, elapsed);
            }
        } catch (Exception e) {
            long elapsed = System.currentTimeMillis() - start;
            log.error("[{}] FAIL — elapsed={}ms, error={}",
                taskName, elapsed, e.getMessage(), e);
        }
    }
}
```

Pattern: `[TaskName] START`, `[TaskName] END — elapsed=Nms`, `[TaskName] FAIL — elapsed=Nms`.

For production monitoring:
- Micrometer: `timer.record(elapsed, TimeUnit.MILLISECONDS)` per execution
- Actuator custom health indicator: mark DOWN if critical task fails repeatedly
- XXL-Job admin console: built-in execution log and alerting
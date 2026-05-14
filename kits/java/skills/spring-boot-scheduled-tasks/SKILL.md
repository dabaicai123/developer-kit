---
name: spring-boot-scheduled-tasks
description: "Implements Spring Boot scheduled tasks with @Scheduled, XXL-Job distributed scheduling, cron expressions, thread pools, and misfire handling. Use when creating periodic jobs, cron tasks, or distributed schedules."
version: "1.0.0"
---

# Spring Boot Scheduled Tasks

@Scheduled and XXL-Job patterns for single-instance and distributed scheduling.

## When to use

- Adding `@Scheduled` or XXL-Job tasks
- Writing/debugging cron expressions
- Configuring thread pools or misfire handling for scheduled tasks

## Project Setup

### @EnableScheduling (single-instance)

```java
@SpringBootApplication
@EnableScheduling
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

### XXL-Job (distributed)

```xml
<dependency>
    <groupId>com.xuxueli</groupId>
    <artifactId>xxl-job-core</artifactId>
    <version>2.4.2</version>
</dependency>
```

XXL-Job admin is a standalone web application — deploy separately from [xuxueli/xxl-job](https://github.com/xuxueli/xxl-job).

## Instructions

### Simple scheduling with @Scheduled

Use `@Scheduled` for single-instance applications:
- `fixedDelay` — wait N ms after previous execution completes
- `fixedRate` — execute every N ms regardless of previous completion
- `cron` — schedule by cron expression

Extract cron expressions to configuration for runtime adjustment.

### Distributed scheduling with XXL-Job

Use XXL-Job when multiple service instances exist. It ensures single-instance execution, supports sharding broadcast, and provides a web console.

Steps: deploy admin console, add dependency, configure `XxlJobConfig` bean, register `@XxlJob("handlerName")` methods, return via `XxlJobHelper.handleSuccess/handleFail`.

### Cron expression reference

Spring uses 6-field cron (seconds, minutes, hours, day, month, weekday). XXL-Job uses 7-field Quartz cron (adds year). See `references/cron-expression-reference.md`.

## Examples

### Example 1: @Scheduled fixedDelay + pool configuration

```yaml
spring:
  task:
    scheduling:
      pool:
        size: 4
      time-zone: Asia/Shanghai
```

```java
@Component
@Slf4j
@RequiredArgsConstructor
public class DataSyncTask {

    private final DataSyncService dataSyncService;

    /** Execute 30s after previous completion. Safe for long-running tasks. */
    @Scheduled(fixedDelayString = "${app.task.sync-delay:30000}")
    public void syncData() {
        long start = System.currentTimeMillis();
        log.info("[DataSyncTask] start sync");
        try {
            dataSyncService.syncFromExternal();
            log.info("[DataSyncTask] sync completed in {}ms", System.currentTimeMillis() - start);
        } catch (Exception e) {
            log.error("[DataSyncTask] sync failed", e);
        }
    }
}
```

### Example 2: Dynamic cron from configuration

```java
@Component
@Slf4j
@RequiredArgsConstructor
public class ReportTask {

    private final ReportService reportService;

    /** Daily report at 9:00 AM weekdays. Cron adjustable via Nacos/properties. */
    @Scheduled(cron = "${app.task.report-cron:0 0 9 ? * MON-FRI}")
    public void generateDailyReport() {
        long start = System.currentTimeMillis();
        log.info("[ReportTask] start generating daily report");
        try {
            reportService.generateDailyReport();
            log.info("[ReportTask] report generated in {}ms", System.currentTimeMillis() - start);
        } catch (Exception e) {
            log.error("[ReportTask] report generation failed", e);
        }
    }
}
```

### Example 3: XXL-Job handler + configuration

```java
@Configuration
public class XxlJobConfig {

    @Value("${xxl.job.admin.addresses}")
    private String adminAddresses;
    @Value("${xxl.job.executor.appname}")
    private String appname;
    @Value("${xxl.job.executor.port:9999}")
    private int port;
    @Value("${xxl.job.executor.logpath:/data/applogs/xxl-job/jobhandler}")
    private String logPath;
    @Value("${xxl.job.accessToken:}")
    private String accessToken;

    @Bean
    public XxlJobSpringExecutor xxlJobExecutor() {
        XxlJobSpringExecutor executor = new XxlJobSpringExecutor();
        executor.setAdminAddresses(adminAddresses);
        executor.setAppname(appname);
        executor.setPort(port);
        executor.setLogPath(logPath);
        executor.setAccessToken(accessToken);
        return executor;
    }
}
```

```java
@Component
@Slf4j
@RequiredArgsConstructor
public class XxlJobHandlers {

    private final OrderService orderService;

    @XxlJob("closeTimeoutOrders")
    public ReturnT<String> closeTimeoutOrders() {
        long start = System.currentTimeMillis();
        XxlJobHelper.log("[closeTimeoutOrders] start processing");
        try {
            int count = orderService.closeTimeoutOrders();
            XxlJobHelper.log("[closeTimeoutOrders] closed {} orders in {}ms",
                count, System.currentTimeMillis() - start);
            return XxlJobHelper.handleSuccess("closed " + count + " orders");
        } catch (Exception e) {
            XxlJobHelper.log("[closeTimeoutOrders] failed: " + e.getMessage());
            return XxlJobHelper.handleFail(e.getMessage());
        }
    }
}
```

## Constraints and Warnings

- **Default pool size is 1** — set `spring.task.scheduling.pool.size > 1` for multiple tasks
- **NOT use @Scheduled in distributed deployment** — every instance runs the task; use XXL-Job
- **NOT put @Transactional on @Scheduled methods** — self-invocation bypasses proxy; delegate to a separate @Transactional bean
- **NOT hardcode cron expressions** — extract to configuration for runtime adjustment
- **NOT use fixedRate for long-running tasks** — tasks pile up; use fixedDelay instead
- **Misfire**: Spring @Scheduled has no built-in misfire policy; XXL-Job supports skip or retry
- **Batch deletion**: use iterative LIMIT + loop to avoid large transactions
- **Use @ConditionalOnProperty** to enable/disable tasks per environment
- **Log start/end with elapsed time** for observability

## References

- `references/scheduled-task-patterns.md` — detailed @Scheduled patterns
- `references/xxl-job-integration.md` — XXL-Job handler patterns
- `references/cron-expression-reference.md` — cron syntax and common patterns
- `references/advanced-examples.md` — batch processing, sharding broadcast, parameter passing

## Related Skills

- `spring-boot-async-processing`
- `spring-boot-actuator`
- `spring-boot-transaction-management`

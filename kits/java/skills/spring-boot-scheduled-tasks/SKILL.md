---
name: spring-boot-scheduled-tasks
description: "Spring Boot scheduled tasks: @Scheduled, XXL-Job distributed scheduling, cron expressions, thread pools, misfire handling. Use for implementing scheduled or periodic tasks."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Scheduled Tasks

@Scheduled and XXL-Job patterns for single-instance and distributed scheduling.

## When to use

- Adding `@Scheduled` tasks
- Setting up XXL-Job for distributed scheduling
- Writing or debugging cron expressions
- Configuring thread pools for scheduled tasks
- Implementing batch processing with scheduled tasks + MyBatis-Plus
- Handling misfire scenarios (skip vs. catch-up)
- Monitoring scheduled task execution

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

Dependency:

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

Use `@Scheduled` for single-instance applications. Three scheduling modes:

- `fixedDelay` — wait N milliseconds after previous execution completes before next execution
- `fixedRate` — execute every N milliseconds regardless of previous completion
- `cron` — schedule by cron expression

Extract cron expressions to configuration files for runtime adjustment.

### Distributed scheduling with XXL-Job

Use XXL-Job when multiple service instances exist. XXL-Job ensures only one instance executes a task at a given time, supports sharding broadcast, and provides a web console for task management.

Key steps:
1. Deploy XXL-Job admin console
2. Add `xxl-job-core` dependency
3. Configure `XxlJobConfig` bean (admin addresses, executor appname, port, log path, access token)
4. Register handler methods with `@XxlJob("handlerName")`
5. Return `ReturnT` via `XxlJobHelper.handleSuccess` / `XxlJobHelper.handleFail`

### Cron expression reference

Spring uses 6-field cron (seconds, minutes, hours, day, month, weekday). XXL-Job uses 7-field Quartz cron (adds year). See `references/cron-expression-reference.md` for full syntax and common patterns.

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
public class DataSyncTask {

    private final DataSyncService dataSyncService;

    public DataSyncTask(DataSyncService dataSyncService) {
        this.dataSyncService = dataSyncService;
    }

    /**
     * Execute 30 seconds after previous completion.
     * Safe for long-running tasks — won't pile up.
     */
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

### Example 2: @Scheduled cron — complex schedule patterns

```java
@Component
@Slf4j
public class ReportTask {

    private final ReportService reportService;

    public ReportTask(ReportService reportService) {
        this.reportService = reportService;
    }

    /**
     * Generate daily report at 9:00 AM on weekdays.
     * Cron from config — allows runtime adjustment via Nacos/properties.
     */
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

    /**
     * Cleanup expired tokens at 2:00 AM daily.
     * NOT annotate @Scheduled methods with @Transactional directly —
     * delegate to a separate @Transactional service method to avoid self-invocation proxy bypass.
     */
    @Scheduled(cron = "${app.task.cleanup-cron:0 0 2 * * ?}")
    public void cleanupExpiredTokens() {
        log.info("[ReportTask] start cleanup expired tokens");
        tokenCleanupService.cleanupExpired();
        log.info("[ReportTask] cleanup completed");
    }
}
```

### Example 3: XXL-Job handler registration and configuration

**XxlJobConfig bean:**

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

**Handler method:**

```java
@Component
@Slf4j
public class XxlJobHandlers {

    private final OrderService orderService;

    public XxlJobHandlers(OrderService orderService) {
        this.orderService = orderService;
    }

    /**
     * XXL-Job handler: close timeout orders.
     * Register in XXL-Job admin console with handler name "closeTimeoutOrders".
     */
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

### Example 4: Scheduled task + MyBatis-Plus batch processing pattern

```java
@Component
@Slf4j
public class DataCleanupTask {

    private final OrderMapper orderMapper;
    private final OrderLogMapper orderLogMapper;

    public DataCleanupTask(OrderMapper orderMapper, OrderLogMapper orderLogMapper) {
        this.orderMapper = orderMapper;
        this.orderLogMapper = orderLogMapper;
    }

    /**
     * Batch cleanup completed orders older than 90 days.
     * Process in batches of 500 to avoid large single transactions.
     */
    @Scheduled(cron = "${app.task.cleanup-cron:0 0 3 * * ?}")
    public void cleanupOldOrders() {
        long start = System.currentTimeMillis();
        log.info("[DataCleanupTask] start order cleanup");

        LocalDateTime threshold = LocalDateTime.now().minusDays(90);
        int totalDeleted = 0;

        while (true) {
            // Query a batch of IDs first
            List<Long> ids = new LambdaQueryWrapper<OrderDO>()
                .eq(OrderDO::getStatus, OrderStatus.COMPLETED)
                .lt(OrderDO::getCreatedAt, threshold)
                .select(OrderDO::getId)
                .last("LIMIT 500")
                .stream()
                .map(OrderDO::getId)
                .toList();

            if (ids.isEmpty()) {
                break;
            }

            // Delete logs then orders in a transaction
            deleteBatch(ids);
            totalDeleted += ids.size();
            log.info("[DataCleanupTask] deleted batch of {}, total {}", ids.size(), totalDeleted);
        }

        log.info("[DataCleanupTask] cleanup completed: {} orders in {}ms",
            totalDeleted, System.currentTimeMillis() - start);
    }

    @Transactional
    public void deleteBatch(List<Long> ids) {
        orderLogMapper.delete(new LambdaQueryWrapper<OrderLogDO>()
            .in(OrderLogDO::getOrderId, ids));
        orderMapper.deleteBatchIds(ids);
    }
}
```

### Example 5: XXL-Job executor configuration (application.yml, executor registry, log path)

```yaml
# application.yml — XXL-Job executor configuration
xxl:
  job:
    admin:
      addresses: http://xxl-job-admin:8080/xxl-job-admin
    executor:
      appname: order-service-executor
      port: 9999
      logpath: /data/applogs/xxl-job/jobhandler
      logretentiondays: 30
    accessToken: default_token

# For sharding broadcast tasks, XXL-Job automatically assigns shard parameters.
# Access via XxlJobHelper.getShardIndex() and XxlJobHelper.getTotalShard()
```

**Sharding broadcast handler — process data across multiple instances:**

```java
@Component
@Slf4j
public class ShardingDataProcessHandler {

    private final DataService dataService;

    public ShardingDataProcessHandler(DataService dataService) {
        this.dataService = dataService;
    }

    @XxlJob("shardingDataProcess")
    public ReturnT<String> shardingDataProcess() {
        int shardIndex = XxlJobHelper.getShardIndex();   // Current instance shard index
        int shardTotal = XxlJobHelper.getTotalShard();   // Total shard count

        XxlJobHelper.log("[shardingDataProcess] shardIndex={}, shardTotal={}",
            shardIndex, shardTotal);

        // Each instance processes its own shard: id % shardTotal == shardIndex
        int count = dataService.processShard(shardIndex, shardTotal);

        return XxlJobHelper.handleSuccess("processed " + count + " items on shard " + shardIndex);
    }
}
```

**Parameter passing handler — receive parameters from admin console:**

```java
@Component
@Slf4j
public class ParamAwareHandler {

    private final ReportService reportService;

    public ParamAwareHandler(ReportService reportService) {
        this.reportService = reportService;
    }

    @XxlJob("generateReport")
    public ReturnT<String> generateReport() {
        // Get task parameter from XXL-Job admin console
        String param = XxlJobHelper.getJobParam();
        XxlJobHelper.log("[generateReport] param={}", param);

        if (param == null || param.isBlank()) {
            return XxlJobHelper.handleFail("parameter is required: reportType");
        }

        String reportType = param;
        reportService.generateByType(reportType);
        return XxlJobHelper.handleSuccess("report generated: " + reportType);
    }
}
```

## Constraints and Warnings

- **Default pool size is 1** — all `@Scheduled` tasks share one thread. Set `spring.task.scheduling.pool.size > 1` for multiple tasks
- **NOT use @Scheduled in distributed deployment** — every instance runs the task. Use XXL-Job instead
- **NOT put @Transactional on @Scheduled methods** — self-invocation bypasses proxy. Delegate to a separate @Transactional bean → see `spring-boot-transaction-management`
- **NOT hardcode cron expressions** — extract to configuration for runtime adjustment via Nacos/properties
- **NOT use fixedRate for long-running tasks** — tasks pile up when execution exceeds interval. Use fixedDelay
- **NOT block scheduled threads** with long-running operations — break into async steps or use XXL-Job sharding
- **Cron timezone**: set `spring.task.scheduling.time-zone` for time-sensitive cron tasks
- **XXL-Job ReturnT is required** — always return `XxlJobHelper.handleSuccess()` or `XxlJobHelper.handleFail()`
- **XXL-Job admin is a separate application** — not part of your Spring Boot app
- **Misfire strategy**: Spring @Scheduled has no built-in misfire policy. XXL-Job supports skip (for reporting) or retry (for data sync)
- **Batch deletion**: use iterative LIMIT + loop to avoid large single transactions → see `spring-boot-transaction-management`
- **Use @ConditionalOnProperty** to enable/disable tasks per environment
- **Log start/end with elapsed time**: `log.info("[TaskName] start")` / `log.info("[TaskName] completed in {}ms", elapsed)`

## References

- Detailed `@Scheduled` patterns and configuration: `references/scheduled-task-patterns.md`
- XXL-Job integration and handler patterns: `references/xxl-job-integration.md`
- Cron expression syntax and common patterns: `references/cron-expression-reference.md`

## Related Skills

- `spring-boot-async-processing` — async execution patterns for offloading work from scheduled threads
- `spring-boot-actuator` — monitoring and health probes for scheduled task observability

## Keywords

@Scheduled, XXL-Job, cron, fixedDelay, fixedRate, distributed scheduling, misfire, task executor, sharding broadcast, SchedulingConfigurer
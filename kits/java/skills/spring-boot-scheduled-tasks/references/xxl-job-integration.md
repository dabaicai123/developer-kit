# XXL-Job Integration — Detailed Reference

## XXL-Job dependency: xxl-job-core

```xml
<!-- pom.xml -->
<dependency>
    <groupId>com.xuxueli</groupId>
    <artifactId>xxl-job-core</artifactId>
    <version>2.4.2</version>
</dependency>
```

XXL-Job is a distributed scheduling framework with admin console, sharding broadcast, and failure retry.

## XxlJobConfig bean configuration

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

    @Value("${xxl.job.executor.logretentiondays:30}")
    private int logRetentionDays;

    @Value("${xxl.job.accessToken:}")
    private String accessToken;

    @Bean
    public XxlJobSpringExecutor xxlJobExecutor() {
        XxlJobSpringExecutor executor = new XxlJobSpringExecutor();
        executor.setAdminAddresses(adminAddresses);
        executor.setAppname(appname);
        executor.setPort(port);
        executor.setLogPath(logPath);
        executor.setLogRetentionDays(logRetentionDays);
        executor.setAccessToken(accessToken);
        return executor;
    }
}
```

**application.yml:**

```yaml
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
```

Configuration notes:
- `port` must differ from application port
- NOT leave `accessToken` as default_token in production

## @XxlJob handler method registration

Handler methods use `@XxlJob("handlerName")`. The handler name must match the name configured in XXL-Job admin console.

```java
@Component
@Slf4j
public class OrderJobHandler {

    private final OrderService orderService;

    public OrderJobHandler(OrderService orderService) {
        this.orderService = orderService;
    }

    /**
     * Close timeout unpaid orders.
     * Handler name: "closeTimeoutOrders" — must match admin console configuration.
     */
    @XxlJob("closeTimeoutOrders")
    public ReturnT<String> closeTimeoutOrders() {
        long start = System.currentTimeMillis();
        XxlJobHelper.log("[closeTimeoutOrders] START");

        try {
            int count = orderService.closeTimeoutOrders();
            long elapsed = System.currentTimeMillis() - start;
            XxlJobHelper.log("[closeTimeoutOrders] END — closed={} orders, elapsed={}ms",
                count, elapsed);
            return XxlJobHelper.handleSuccess("closed " + count + " orders");
        } catch (Exception e) {
            long elapsed = System.currentTimeMillis() - start;
            XxlJobHelper.log("[closeTimeoutOrders] FAIL — elapsed={}ms, error={}",
                elapsed, e.getMessage());
            return XxlJobHelper.handleFail(e.getMessage());
        }
    }

    /**
     * Generate monthly settlement report.
     * Accepts task parameter from admin console.
     */
    @XxlJob("monthlySettlement")
    public ReturnT<String> monthlySettlement() {
        String param = XxlJobHelper.getJobParam();
        XxlJobHelper.log("[monthlySettlement] param={}", param);

        if (param == null || param.isBlank()) {
            return XxlJobHelper.handleFail("parameter required: month, e.g. '2026-04'");
        }

        try {
            SettlementResult result = settlementService.generateMonthly(param);
            XxlJobHelper.log("[monthlySettlement] result={}", result.getSummary());
            return XxlJobHelper.handleSuccess(result.getSummary());
        } catch (Exception e) {
            XxlJobHelper.log("[monthlySettlement] FAIL: {}", e.getMessage());
            return XxlJobHelper.handleFail(e.getMessage());
        }
    }
}
```

Key methods from `XxlJobHelper`:
- `XxlJobHelper.log(String msg)` — write execution log visible in admin console
- `XxlJobHelper.handleSuccess(String msg)` — return success result
- `XxlJobHelper.handleFail(String msg)` — return failure result
- `XxlJobHelper.getJobParam()` — get task parameter configured in admin console
- `XxlJobHelper.getShardIndex()` — get current shard index (sharding broadcast mode)
- `XxlJobHelper.getTotalShard()` — get total shard count (sharding broadcast mode)

## XXL-Job admin console setup and task configuration

### Deploy admin console

Deploy from xuxueli/xxl-job releases. Initialize DB with `tables_xxl_job.sql`. Console: http://localhost:8080/xxl-job-admin (default: admin/123456).

### Configure a task in admin console

1. **Executor Management** — register your executor appname (e.g., `order-service-executor`)
2. **Task Management** — create a new task:
   - JobHandler: `closeTimeoutOrders` (must match `@XxlJob` annotation)
   - ScheduleType: CRON
   - Cron: `0 0/5 * * * ?` (every 5 minutes, Quartz 7-field format)
   - ExecutorHandler: `closeTimeoutOrders`
   - ExecutorRouteStrategy: ROUND (round-robin dispatch to instances)
   - MisfireStrategy: DO_NOTHING (skip missed executions) or IGNORE_MISFIRE (execute immediately)
   - BlockStrategy: SERIAL_EXECUTION (wait for previous completion) or DISCARD_LATER (skip if still running)

### Route strategies

| Strategy | Description |
|----------|-------------|
| ROUND | Round-robin across executor instances |
| FIRST | Always dispatch to first registered instance |
| LAST | Always dispatch to last registered instance |
| RANDOM | Random instance selection |
| CONSISTENT_HASH | Hash-based consistent routing |
| LEAST_FREQUENTLY_USED | Dispatch to least frequently used instance |
| LEAST_RECENTLY_USED | Dispatch to least recently used instance |
| FAILOVER | Try first instance, failover to next on failure |
| BUSYOVER | Try first instance, bypass to next if busy |
| SHARDING_BROADCAST | Broadcast to all instances with shard parameters |

## Sharding broadcast: XxlJobHelper.getShardIndex() / getTotalShard()

Sharding broadcast dispatches a task to all executor instances simultaneously. Each instance gets a shard index and total count to process its own partition.

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
        int shardIndex = XxlJobHelper.getShardIndex();
        int shardTotal = XxlJobHelper.getTotalShard();

        XxlJobHelper.log("[shardingDataProcess] shardIndex={}, shardTotal={}",
            shardIndex, shardTotal);

        if (shardTotal <= 0) {
            return XxlJobHelper.handleFail("shardTotal must be > 0");
        }

        try {
            // Each instance processes: id % shardTotal == shardIndex
            int count = dataService.processShard(shardIndex, shardTotal);
            XxlJobHelper.log("[shardingDataProcess] processed {} items on shard {}",
                count, shardIndex);
            return XxlJobHelper.handleSuccess("shard " + shardIndex + " processed " + count + " items");
        } catch (Exception e) {
            XxlJobHelper.log("[shardingDataProcess] FAIL: {}", e.getMessage());
            return XxlJobHelper.handleFail(e.getMessage());
        }
    }
}
```

**Service layer sharding:**

```java
@Service
@Slf4j
public class DataService {

    private final DataMapper dataMapper;

    public DataService(DataMapper dataMapper) {
        this.dataMapper = dataMapper;
    }

    public int processShard(int shardIndex, int shardTotal) {
        // Query data assigned to this shard
        List<DataDO> items = dataMapper.selectList(
            new LambdaQueryWrapper<DataDO>()
                .eq(DataDO::getStatus, Status.PENDING)
                .apply("MOD(id, {0}) = {1}", shardTotal, shardIndex)
        );

        // Process each item
        for (DataDO item : items) {
            processItem(item);
        }

        return items.size();
    }
}
```

Sharding tips:
- Use `MOD(id, shardTotal) = shardIndex` to partition data by ID
- NOT use non-numeric keys for MOD sharding — use hash-based sharding instead
- All instances must complete before task is marked done

## Parameter passing: XxlJobHelper.getJobParam()

Tasks can receive parameters from the admin console. Parameters are set in the task configuration or passed dynamically via API.

```java
@Component
@Slf4j
public class ReportJobHandler {

    private final ReportService reportService;

    public ReportJobHandler(ReportService reportService) {
        this.reportService = reportService;
    }

    /**
     * Generate report by type.
     * Parameter format: "type=DAILY;date=2026-05-07"
     */
    @XxlJob("generateReport")
    public ReturnT<String> generateReport() {
        String param = XxlJobHelper.getJobParam();
        XxlJobHelper.log("[generateReport] param={}", param);

        if (param == null || param.isBlank()) {
            return XxlJobHelper.handleFail("parameter required: type=DAILY;date=2026-05-07");
        }

        // Parse parameters
        Map<String, String> paramMap = parseParam(param);
        String type = paramMap.getOrDefault("type", "DAILY");
        String date = paramMap.getOrDefault("date", LocalDate.now().toString());

        try {
            ReportResult result = reportService.generate(type, date);
            return XxlJobHelper.handleSuccess(result.getSummary());
        } catch (Exception e) {
            XxlJobHelper.log("[generateReport] FAIL: {}", e.getMessage());
            return XxlJobHelper.handleFail(e.getMessage());
        }
    }

    private Map<String, String> parseParam(String param) {
        Map<String, String> map = new HashMap<>();
        for (String kv : param.split(";")) {
            String[] parts = kv.split("=");
            if (parts.length == 2) {
                map.put(parts[0].trim(), parts[1].trim());
            }
        }
        return map;
    }
}
```

## Log handling: XxlJobHelper.log() for task execution logs

`XxlJobHelper.log()` writes logs that are visible in the XXL-Job admin console's execution log page. These logs are separate from application logs (SLF4J/Log4j2).

```java
@XxlJob("dataMigration")
public ReturnT<String> dataMigration() {
    XxlJobHelper.log("=== dataMigration START ===");

    int total = 0;
    int batchSize = 500;

    while (true) {
        List<DataDO> batch = dataService.fetchBatch(batchSize);
        if (batch.isEmpty()) {
            XxlJobHelper.log("no more data to process, breaking loop");
            break;
        }

        dataService.migrateBatch(batch);
        total += batch.size();
        XxlJobHelper.log("processed batch: count={}, total={}", batch.size(), total);
    }

    XxlJobHelper.log("=== dataMigration END — total={} ===", total);
    return XxlJobHelper.handleSuccess("migrated " + total + " records");
}
```

Log notes:
- `XxlJobHelper.log()` writes to local log file AND admin console
- Viewable in admin console: Task Management → Execution Log → View Log
- Auto-cleaned after `logRetentionDays`
- NOT log every single item — log key milestones (batch counts, totals)

## Executor registration and discovery

Executor auto-registers with admin console on startup via embedded Netty server. Same appname, different IP:port. Graceful shutdown: auto-unregister on app stop.

## Common integration patterns

### Pattern 2: GLUE mode (inline script)

Tasks managed entirely in admin console — code edited online. NOT use for production-critical tasks.

### Pattern 3: Task chaining

Execute multiple handlers in sequence within one handler:

```java
@XxlJob("chainedTask")
public ReturnT<String> chainedTask() {
    try {
        // Step 1: data extraction
        dataService.extractData();
        XxlJobHelper.log("step 1 completed: data extraction");

        // Step 2: data transformation
        dataService.transformData();
        XxlJobHelper.log("step 2 completed: data transformation");

        // Step 3: data loading
        dataService.loadData();
        XxlJobHelper.log("step 3 completed: data loading");

        return XxlJobHelper.handleSuccess("all steps completed");
    } catch (Exception e) {
        XxlJobHelper.log("chained task failed at step: {}", e.getMessage());
        return XxlJobHelper.handleFail(e.getMessage());
    }
}
```

### Pattern 4: Retry with exponential backoff

```java
@XxlJob("retryTask")
public ReturnT<String> retryTask() {
    int maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
        try {
            externalService.call();
            return XxlJobHelper.handleSuccess("call succeeded on attempt " + (i + 1));
        } catch (Exception e) {
            XxlJobHelper.log("attempt {} failed: {}", i + 1, e.getMessage());
            if (i < maxRetries - 1) {
                try { Thread.sleep((long) Math.pow(2, i) * 1000); } catch (InterruptedException ignored) {}
            }
        }
    }
    return XxlJobHelper.handleFail("all retries exhausted");
}
```
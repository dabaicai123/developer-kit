# Advanced Scheduled Task Examples

## Batch Processing with MyBatis-Plus

Iterative batch deletion pattern — process in small batches to avoid large single transactions.

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

## XXL-Job Sharding Broadcast

Distribute data processing across multiple instances. Each instance processes its own shard based on `id % shardTotal == shardIndex`.

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

        // Each instance processes its own shard
        int count = dataService.processShard(shardIndex, shardTotal);

        return XxlJobHelper.handleSuccess("processed " + count + " items on shard " + shardIndex);
    }
}
```

## XXL-Job Parameter Passing

Receive parameters from the XXL-Job admin console at runtime.

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
        String param = XxlJobHelper.getJobParam();
        XxlJobHelper.log("[generateReport] param={}", param);

        if (param == null || param.isBlank()) {
            return XxlJobHelper.handleFail("parameter is required: reportType");
        }

        reportService.generateByType(param);
        return XxlJobHelper.handleSuccess("report generated: " + param);
    }
}
```

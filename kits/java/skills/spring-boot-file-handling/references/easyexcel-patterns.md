# EasyExcel Patterns

## Dependency

```xml
<dependency>
    <groupId>com.alibaba</groupId>
    <artifactId>easyexcel</artifactId>
    <version>4.0.3</version>
</dependency>
```

## Export Patterns

### Simple Export — Write Data to Excel and Stream as HTTP Response

```java
@GetMapping("/export/users")
public void exportUsers(HttpServletResponse response) throws IOException {
    // 1. Set response headers (required before writing)
    response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    response.setCharacterEncoding("utf-8");
    String filename = URLEncoder.encode("User List", StandardCharsets.UTF_8).replaceAll("\\+", "%20");
    response.setHeader("Content-Disposition", "attachment; filename=" + filename + ".xlsx");

    // 2. Query data
    List<UserExportDTO> data = userService.findAllForExport();

    // 3. Write Excel to response output stream
    EasyExcel.write(response.getOutputStream(), UserExportDTO.class)
            .sheet("User List")
            .doWrite(data);
}
```

### Export DTO with @ExcelProperty

```java
@Data
public class UserExportDTO {
    @ExcelProperty("User ID")
    private Long id;

    @ExcelProperty("Username")
    private String username;

    @ExcelProperty("Email")
    private String email;

    @ExcelProperty(value = "Status", converter = StatusConverter.class)
    private String status;

    @ExcelProperty(value = "Registration Time")
    @DateTimeFormat("yyyy-MM-dd HH:mm:ss")
    private LocalDateTime createdAt;

    @ExcelProperty(value = "Salary")
    @NumberFormat("#,##0.00")
    private BigDecimal salary;
}
```

### Dynamic Columns — Custom Head Design

When column structure is dynamic (e.g., user selects columns to export), build `List<List<String>>` heads instead of using `@ExcelProperty`:

```java
@GetMapping("/export/users-dynamic")
public void exportUsersDynamic(
        @RequestParam List<String> columns,
        HttpServletResponse response) throws IOException {

    response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    response.setCharacterEncoding("utf-8");
    response.setHeader("Content-Disposition", "attachment; filename=users.xlsx");

    // Build dynamic heads based on selected columns
    List<List<String>> heads = columns.stream()
            .map(col -> {
                Map<String, String> colNameMap = Map.of(
                    "id", "User ID", "username", "Username",
                    "email", "Email", "createdAt", "Registration Time"
                );
                return List.of(colNameMap.getOrDefault(col, col));
            })
            .toList();

    // Build data rows as List<List<Object>>
    List<List<Object>> data = userService.findDynamicData(columns);

    EasyExcel.write(response.getOutputStream())
            .head(heads)
            .sheet("User List")
            .doWrite(data);
}
```

### Multiple Sheets — WriteSheet Pattern

```java
@GetMapping("/export/multi-sheet")
public void exportMultiSheet(HttpServletResponse response) throws IOException {
    response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    response.setCharacterEncoding("utf-8");
    response.setHeader("Content-Disposition", "attachment; filename=report.xlsx");

    ExcelWriter excelWriter = EasyExcel.write(response.getOutputStream()).build();

    // Sheet 1: Users
    WriteSheet userSheet = EasyExcel.writerSheet(0, "User List").head(UserExportDTO.class).build();
    List<UserExportDTO> users = userService.findAllForExport();
    excelWriter.write(users, userSheet);

    // Sheet 2: Orders
    WriteSheet orderSheet = EasyExcel.writerSheet(1, "Order List").head(OrderExportDTO.class).build();
    List<OrderExportDTO> orders = orderService.findAllForExport();
    excelWriter.write(orders, orderSheet);

    // Must finish writer
    excelWriter.finish();
}
```

### Custom Cell Style — AbstractCellWriteHandler

```java
public class HeaderStyleWriteHandler extends AbstractCellWriteHandler {

    @Override
    public void afterCellDispose(WriteSheetHolder writeSheetHolder,
                                  WriteTableHolder writeTableHolder,
                                  List<WriteCellData<?>> cellDataList,
                                  Cell cell,
                                  Head head,
                                  Integer relativeRowIndex,
                                  Boolean isHead) {
        if (isHead) {
            // Style header cells
            Workbook workbook = writeSheetHolder.getSheet().getWorkbook();
           CellStyle style = workbook.createCellStyle();
            style.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            style.setFont(createHeaderFont(workbook));
            cell.setCellStyle(style);
        }
    }

    private Font createHeaderFont(Workbook workbook) {
        Font font = workbook.createFont();
        font.setFontHeightInPoints((short) 12);
        font.setBold(true);
        return font;
    }
}

// Usage in export
EasyExcel.write(response.getOutputStream(), UserExportDTO.class)
        .registerWriteHandler(new HeaderStyleWriteHandler())
        .sheet("User List")
        .doWrite(data);
```

## Import Patterns

### ReadListener — AnalysisEventListener for Batch Processing

```java
@Slf4j
public class UserImportReadListener extends AnalysisEventListener<UserImportDTO> {

    private static final int BATCH_SIZE = 1000;
    private final UserService userService;
    private final List<UserImportDTO> batchList = new ArrayList<>();
    private int totalRows = 0;
    private int successRows = 0;
    private final List<ImportError> errors = new ArrayList<>();

    public UserImportReadListener(UserService userService) {
        this.userService = userService;
    }

    @Override
    public void invoke(UserImportDTO data, AnalysisContext context) {
        totalRows++;
        try {
            validateRow(data, context.readRowHolder().getRowIndex());
            batchList.add(data);
            if (batchList.size() >= BATCH_SIZE) {
                userService.batchCreate(batchList);
                successRows += batchList.size();
                batchList.clear();
            }
        } catch (ValidationException e) {
            errors.add(new ImportError(context.readRowHolder().getRowIndex(), e.getMsg()));
        }
    }

    @Override
    public void doAfterAllAnalysed(AnalysisContext context) {
        // Process remaining rows in batch
        if (!batchList.isEmpty()) {
            userService.batchCreate(batchList);
            successRows += batchList.size();
        }
        log.info("Import completed: total={}, success={}, errors={}", totalRows, successRows, errors.size());
    }

    @Override
    public void onException(Exception exception, AnalysisContext context) {
        log.error("Excel parse error at row {}", context.readRowHolder().getRowIndex(), exception);
        if (exception instanceof ExcelDataConvertException) {
            ExcelDataConvertException e = (ExcelDataConvertException) exception;
            errors.add(new ImportError(e.getRowIndex(),
                "Column " + e.getColumnIndex() + ": data type mismatch — " + e.getMessage()));
        }
    }

    private void validateRow(UserImportDTO data, int rowIndex) {
        if (StringUtils.isBlank(data.getUsername())) {
            throw new ValidationException("Username is required");
        }
        if (StringUtils.isBlank(data.getEmail()) || !data.getEmail().contains("@")) {
            throw new ValidationException("Valid email is required");
        }
    }

    public ImportResult getResult() {
        return new ImportResult(totalRows, successRows, errors);
    }
}
```

### Controller Using ReadListener

```java
@PostMapping("/import/users")
public Result<ImportResult> importUsers(@RequestParam("file") MultipartFile file) {
    // 1. Validate file
    String extension = getFileExtension(file.getOriginalFilename());
    if (!"xlsx".equals(extension)) {
        throw new ValidationException("Only .xlsx files are supported");
    }

    // 2. Read with ReadListener
    UserImportReadListener listener = new UserImportReadListener(userService);
    try {
        EasyExcel.read(file.getInputStream(), UserImportDTO.class, listener)
                .sheet()
                .headRowNumber(1)  // skip header row
                .doRead();
    } catch (Exception e) {
        log.error("Excel import failed", e);
        throw new BusinessException(500, "Excel import failed");
    }

    // 3. Return result
    return Result.success(listener.getResult());
}
```

### Import DTO with @ExcelProperty

```java
@Data
public class UserImportDTO {
    @ExcelProperty("Username")
    private String username;

    @ExcelProperty("Email")
    private String email;

    @ExcelProperty("Age")
    private Integer age;

    @ExcelProperty(value = "Join Date", converter = LocalDateConverter.class)
    private LocalDate hireDate;
}
```

### Read with Head Row Number Configuration

```java
// Skip N header rows (e.g., title rows before column headers)
EasyExcel.read(file.getInputStream(), UserImportDTO.class, listener)
        .sheet()
        .headRowNumber(2)  // first 2 rows are title/description, row 3 is column header
        .doRead();

// Read specific sheet by name or index
EasyExcel.read(file.getInputStream(), UserImportDTO.class, listener)
        .sheet("User Data")  // by sheet name
        .doRead();

EasyExcel.read(file.getInputStream(), UserImportDTO.class, listener)
        .sheet(0)  // by sheet index
        .doRead();
```

### Batch Commit — Process Rows in Batches

The `ReadListener` processes rows incrementally via `invoke()`. Accumulate rows in a list and batch-insert to database when list reaches `BATCH_SIZE`:

```java
@Override
public void invoke(UserImportDTO data, AnalysisContext context) {
    batchList.add(data);
    if (batchList.size() >= BATCH_SIZE) {
        userService.batchCreate(batchList);  // MyBatis-Plus: userService.saveBatch(batchList)
        successRows += batchList.size();
        batchList.clear();
    }
}

@Override
public void doAfterAllAnalysed(AnalysisContext context) {
    if (!batchList.isEmpty()) {
        userService.batchCreate(batchList);
        successRows += batchList.size();
    }
}
```

This avoids loading the entire file into memory. Each batch of 1000 rows is persisted and cleared, keeping memory usage constant regardless of file size.

### Error Handling — onException in ReadListener

```java
@Override
public void onException(Exception exception, AnalysisContext context) {
    if (exception instanceof ExcelDataConvertException) {
        // Data type conversion error (e.g., text in numeric column)
        ExcelDataConvertException e = (ExcelDataConvertException) exception;
        errors.add(new ImportError(
            e.getRowIndex(),
            "Column " + e.getColumnIndex() + ": type mismatch — expected " + e.getExpectedType()
        ));
    } else if (exception instanceof ExcelAnalysisException) {
        // Structural error (e.g., missing required columns)
        errors.add(new ImportError(-1, "File structure error: " + exception.getMessage()));
    } else {
        // Unexpected error — stop processing
        log.error("Unexpected import error", exception);
        throw new BusinessException(500, "Import processing error");
    }
}
```

## DTO Mapping — @ExcelProperty Annotations

### Basic Column Mapping

```java
@Data
public class OrderExportDTO {
    // Map by column name (matches Excel header text)
    @ExcelProperty("Order Number")
    private String orderNo;

    // Map by column index (0-based, useful when header names vary)
    @ExcelProperty(index = 1)
    private String productName;

    // Map with converter
    @ExcelProperty(value = "Order Status", converter = OrderStatusConverter.class)
    private OrderStatus status;
}
```

### Nested Header Mapping (Multi-level Headers)

```java
@Data
public class SalesReportDTO {
    // Two-level header: "Sales Data" > "Order Count"
    @ExcelProperty(value = {"Sales Data", "Order Count"})
    private Integer orderCount;

    @ExcelProperty(value = {"Sales Data", "Amount"})
    @NumberFormat("#,##0.00")
    private BigDecimal amount;

    @ExcelProperty(value = {"Customer Info", "Customer Name"})
    private String customerName;
}
```

## Number Format, Date Format, and Custom Converter

### Number Format

```java
@ExcelProperty(value = "Salary")
@NumberFormat("#,##0.00")  // display as "12,500.00"
private BigDecimal salary;

@ExcelProperty(value = "Percentage")
@NumberFormat("0.00%")  // display as "85.50%"
private Double percentage;
```

### Date Format

```java
@ExcelProperty(value = "Registration Time")
@DateTimeFormat("yyyy-MM-dd HH:mm:ss")
private LocalDateTime createdAt;

@ExcelProperty(value = "Birthday")
@DateTimeFormat("yyyy-MM-dd")
private LocalDate birthday;
```

### Custom Converter — Enum to String

```java
public class OrderStatusConverter implements CellConverter {
    @Override
    public WriteCellData<?> convertToExcelData(OrderStatus value, ExcelContentProperty property,
                                                 GlobalConfiguration globalConfiguration) {
        // Enum -> Excel cell display text
        Map<OrderStatus, String> labelMap = Map.of(
            OrderStatus.PENDING, "Pending",
            OrderStatus.CONFIRMED, "Confirmed",
            OrderStatus.SHIPPED, "Shipped",
            OrderStatus.COMPLETED, "Completed"
        );
        return new WriteCellData<>(labelMap.getOrDefault(value, value.name()));
    }

    @Override
    public OrderStatus convertToJavaData(ReadCellData<?> cellData, ExcelContentProperty property,
                                           GlobalConfiguration globalConfiguration) {
        // Excel cell text -> Enum
        String text = cellData.getStringValue();
        Map<String, OrderStatus> reverseMap = Map.of(
            "Pending", OrderStatus.PENDING,
            "Confirmed", OrderStatus.CONFIRMED,
            "Shipped", OrderStatus.SHIPPED,
            "Completed", OrderStatus.COMPLETED
        );
        return reverseMap.getOrDefault(text, OrderStatus.valueOf(text));
    }
}
```

### Custom Converter — LocalDate

```java
public class LocalDateConverter implements CellConverter {
    private static final String PATTERN = "yyyy-MM-dd";

    @Override
    public WriteCellData<?> convertToExcelData(LocalDate value, ExcelContentProperty property,
                                                 GlobalConfiguration globalConfiguration) {
        return new WriteCellData<>(value.format(PATTERN));
    }

    @Override
    public LocalDate convertToJavaData(ReadCellData<?> cellData, ExcelContentProperty property,
                                         GlobalConfiguration globalConfiguration) {
        if (cellData.getType() == CellDataTypeEnum.NUMBER) {
            // Excel stores dates as numbers internally
            Date date = cellData.getDateValue();
            return date.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
        }
        return LocalDate.parse(cellData.getStringValue(), DateTimeFormatter.ofPattern(PATTERN));
    }
}
```

## Import Result and Error Tracking

```java
@Data
@AllArgsConstructor
public class ImportResult {
    private int totalRows;
    private int successRows;
    private List<ImportError> errors;
}

@Data
@AllArgsConstructor
public class ImportError {
    private int rowIndex;   // Excel row number where error occurred
    private String message; // Error description
}
```

## Common Gotchas

1. **Response headers must be set before `EasyExcel.write()`** — once the output stream is written, headers cannot be modified
2. **`ExcelWriter` must call `finish()`** — without it, the file will be incomplete/corrupted
3. **ReadListener `invoke()` processes one row at a time** — batch accumulation and persistence is your responsibility
4. **`onException()` catches per-cell errors** — but uncaught exceptions in `invoke()` stop the entire read process
5. **Never use `file.getBytes()` for import** — always use `file.getInputStream()` for streaming
6. **Column index mapping (`@ExcelProperty(index=N)`) breaks if columns reorder** — prefer name-based mapping for maintainability
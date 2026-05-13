# EasyExcel Import — ReadListener Pattern

Complete example of batch-processing Excel rows with `AnalysisEventListener`.

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
                "Column " + e.getColumnIndex() + ": data type mismatch"));
        }
    }

    private void validateRow(UserImportDTO data, int rowIndex) {
        if (!StringUtils.hasText(data.getUsername())) {
            throw new ValidationException("Username is required");
        }
        if (!StringUtils.hasText(data.getEmail()) || !data.getEmail().contains("@")) {
            throw new ValidationException("Valid email is required");
        }
    }

    public ImportResult getResult() {
        return new ImportResult(totalRows, successRows, errors);
    }
}

@Data
public class UserImportDTO {
    @ExcelProperty("Username")
    private String username;

    @ExcelProperty("Email")
    private String email;

    @ExcelProperty("Age")
    private Integer age;
}
```

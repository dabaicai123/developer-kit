# Code Examples

Detailed code examples for each COLA layer. These are reference implementations — the SKILL.md contains the rules and conventions, this file contains the concrete code.

## client Module

### Service Interface + Feign Client

```java
// api/CustomerServiceI.java — the API contract, returns Result<T>
public interface CustomerServiceI {
    Result<Void> addCustomer(CustomerAddCmd cmd);
    Result<List<CustomerDTO>> listByName(CustomerListByNameQry qry);
    PageResult<CustomerDTO> pageList(CustomerListQry qry);
}

// api/CustomerFeignClient.java — recommended pattern: Feign inherits ServiceI
@FeignClient(name = "customer-service", path = "/customer")
public interface CustomerFeignClient extends CustomerServiceI {
}
```

> **When FeignClient extends ServiceI**: Only when ALL ServiceI methods are external-facing. If some methods are internal-only (e.g., batch processing triggered by scheduler), split into separate interfaces: keep `CustomerServiceI` for internal use, create `CustomerExternalApi` for Feign.

### Command / Query Base Classes

```java
// common/dto/Command.java — marker base class for CQRS write identification
public abstract class Command implements Serializable {
}

// common/dto/Query.java — marker base class for CQRS read identification
public abstract class Query implements Serializable {
}
```

> `Result<T>`, `PageResult<T>`, `BusinessException` are reused from existing project conventions — see `spring-boot-rest-api-standards` and `spring-boot-exception-handling` skills. They are placed in `client/common/result/` and `client/common.exception/` packages so all modules can access them.

### DTO Examples

```java
// dto/CustomerAddCmd.java
public class CustomerAddCmd extends Command {
    @NotBlank
    private String companyName;
    private String customerType;
}

// dto/CustomerListByNameQry.java
public class CustomerListByNameQry extends Query {
    @NotBlank
    private String name;
}

// dto/data/CustomerDTO.java
@Data
public class CustomerDTO {
    private String customerId;
    private String companyName;
    private String customerType;

    public static CustomerDTO fromDO(CustomerDO customerDO) { /* MapStruct or manual */ }
}
```

## adapter Module

```java
// web/CustomerController.java
@RestController
@RequiredArgsConstructor
public class CustomerController {
    private final CustomerServiceI customerService;

    @PostMapping("/customer")
    public Result<Void> addCustomer(@RequestBody CustomerAddCmd cmd) {
        return customerService.addCustomer(cmd);
    }

    @GetMapping("/customer/listByName")
    public Result<List<CustomerDTO>> listByName(@RequestParam String name) {
        return customerService.listByName(new CustomerListByNameQry(name));
    }
}
```

> Adapter is a routing layer — no business logic, no DTO conversion. Controller delegates to ServiceI directly.

## app Module

```java
// customer/CustomerServiceImpl.java — thin facade, pure delegation
@Service
@RequiredArgsConstructor
public class CustomerServiceImpl implements CustomerServiceI {
    private final CustomerAddCmdExe customerAddCmdExe;
    private final CustomerListByNameQryExe customerListByNameQryExe;

    @Override
    public Result<Void> addCustomer(CustomerAddCmd cmd) {
        return customerAddCmdExe.execute(cmd);
    }

    @Override
    public Result<List<CustomerDTO>> listByName(CustomerListByNameQry qry) {
        return customerListByNameQryExe.execute(qry);
    }
}

// customer/executor/CustomerAddCmdExe.java — write handler
@Component
@RequiredArgsConstructor
public class CustomerAddCmdExe {
    private final CustomerGateway customerGateway;

    @Transactional
    public Result<Void> execute(CustomerAddCmd cmd) {
        Customer customer = Customer.create(cmd.getCompanyName(), cmd.getCustomerType());
        customerGateway.save(customer);
        return Result.success();
    }
}

// customer/executor/query/CustomerListByNameQryExe.java — read handler
@Component
@RequiredArgsConstructor
public class CustomerListByNameQryExe {
    private final CustomerMapper customerMapper;

    public Result<List<CustomerDTO>> execute(CustomerListByNameQry qry) {
        List<CustomerDO> records = customerMapper.selectList(
            new LambdaQueryWrapper<CustomerDO>().eq(CustomerDO::getCompanyName, qry.getName()));
        return Result.success(records.stream().map(CustomerDTO::fromDO).toList());
    }
}
```

> **CmdExe converts Cmd to Domain params**: Domain Entity receives plain parameters (not Cmd object). This keeps Domain decoupled from client DTOs.

## domain Module

```java
// domain/customer/Customer.java — plain Java class, bare name, @Data for convenience
@Data
public class Customer {
    private String customerId;
    private String companyName;
    private CustomerType customerType;

    // Factory method: receives plain params, not Cmd — Domain is decoupled from client DTOs
    public static Customer create(String companyName, String customerType) {
        Customer customer = new Customer();
        customer.setCustomerId(IdUtil.simpleUUID());
        customer.setCompanyName(companyName);
        customer.setCustomerType(CustomerType.valueOf(customerType));
        return customer;
    }
}

// domain/customer/gateway/CustomerGateway.java — persistence port
public interface CustomerGateway {
    void save(Customer customer);     // INSERT only
    void update(Customer customer);   // UPDATE only
    Optional<Customer> findById(String id);
}

// domain/customer/gateway/CreditGateway.java — external service port
public interface CreditGateway {
    Credit getCredit(String customerId);
}
```

## infrastructure Module

```java
// customer/CustomerGatewayImpl.java
@Repository
@RequiredArgsConstructor
public class CustomerGatewayImpl implements CustomerGateway {
    private final CustomerMapper customerMapper;

    @Override
    public void save(Customer customer) {
        customerMapper.insert(CustomerDO.fromDomain(customer));
    }

    @Override
    public void update(Customer customer) {
        customerMapper.updateById(CustomerDO.fromDomain(customer));
    }

    @Override
    public Optional<Customer> findById(String id) {
        return Optional.ofNullable(customerMapper.selectOne(
            new LambdaQueryWrapper<CustomerDO>().eq(CustomerDO::getCustomerId, id)))
            .map(CustomerDO::toDomain);
    }
}

// customer/CustomerDO.java — see mybatis-plus-patterns for full DO conventions
@TableName("customer")
@Data
public class CustomerDO {
    @TableId(type = IdType.ASSIGN_ID)
    private Long id;
    private String customerId;
    private String companyName;
    private String customerType;

    @TableLogic(value = "", delval = "now()")
    private LocalDateTime deletedAt;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;

    @Version
    private Integer version;

    // Use MapStruct → see mapstruct-patterns
    public static CustomerDO fromDomain(Customer customer) { /* MapStruct converter */ }
    public Customer toDomain() { /* MapStruct converter */ }
}

// customer/CreditGatewayImpl.java — external service via RestClient
@Repository
@RequiredArgsConstructor
public class CreditGatewayImpl implements CreditGateway {
    private final RestClient creditRestClient;

    @Override
    public Credit getCredit(String customerId) {
        return creditRestClient.get()
            .uri("/credit/{customerId}", customerId)
            .retrieve()
            .body(Credit.class);
    }
}
```

## start Module

```java
@SpringBootApplication
@EnableDiscoveryClient
@EnableFeignClients(basePackages = "com.example")
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```
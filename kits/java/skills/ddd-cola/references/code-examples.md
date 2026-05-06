# Code Examples

Detailed code examples for each COLA layer. These are reference implementations — the SKILL.md contains the rules and conventions, this file contains the concrete code.

**Import note**: All validation annotations use `jakarta.validation.constraints.*` (Spring Boot 3.x), not `javax.validation.constraints.*` (Spring Boot 2.x legacy).

## client Module

### Service Interface + Feign Client

```java
// api/CustomerServiceI.java — the API contract, returns Result<T>
public interface CustomerServiceI {
    Result<Void> addCustomer(CustomerAddCmd cmd);
    Result<List<CustomerDTO>> listByName(CustomerListByNameQry qry);
}

// api/CustomerFeignClient.java — recommended pattern: Feign inherits ServiceI
@FeignClient(name = "customer-service", path = "/customer")
public interface CustomerFeignClient extends CustomerServiceI {
}
```

### Command / Query Base Classes

```java
// common/dto/Command.java — marker base class for CQRS write identification
public abstract class Command implements Serializable {
}

// common/dto/Query.java — marker base class for CQRS read identification
public abstract class Query implements Serializable {
}
```

> `Result<T>`, `PageResult<T>`, `BusinessException` → see `spring-boot-rest-api-standards` and `spring-boot-exception-handling`.

### DTO Examples

```java
// dto/CustomerAddCmd.java
@Data
public class CustomerAddCmd extends Command {
    @NotBlank
    private String companyName;
    private String customerType;
}

// dto/CustomerListByNameQry.java
@Data
@AllArgsConstructor
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
}
```

## adapter Module

```java
// web/CustomerController.java
@RestController
@RequestMapping("/v1/customers")
@RequiredArgsConstructor
public class CustomerController {
    private final CustomerServiceI customerService;

    @PostMapping
    public Result<Void> addCustomer(@Valid @RequestBody CustomerAddCmd cmd) {
        return customerService.addCustomer(cmd);
    }

    @GetMapping("/listByName")
    public Result<List<CustomerDTO>> listByName(@RequestParam String name) {
        return customerService.listByName(new CustomerListByNameQry(name));
    }
}
```

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
        CustomerType type;
        try {
            type = CustomerType.valueOf(cmd.getCustomerType());
        } catch (IllegalArgumentException e) {
            throw new BusinessException(ErrorCode.INVALID_CUSTOMER_TYPE, "Invalid customer type: " + cmd.getCustomerType());
        }
        Customer customer = Customer.create(cmd.getCompanyName(), type);
        customerGateway.save(customer);
        return Result.success();
    }
}

// customer/executor/query/CustomerListByNameQryExe.java — read handler
@Component
@RequiredArgsConstructor
public class CustomerListByNameQryExe {
    private final CustomerMapper customerMapper;
    private final CustomerDOConverter customerDOConverter;

    public Result<List<CustomerDTO>> execute(CustomerListByNameQry qry) {
        List<CustomerDO> records = customerMapper.selectList(
            new LambdaQueryWrapper<CustomerDO>().eq(CustomerDO::getCompanyName, qry.getName()));
        return Result.success(records.stream().map(customerDOConverter::toDTO).toList());
    }
}
```

## domain Module

```java
// domain/customer/Customer.java — plain Java class, bare name, @Data for convenience
@Data
public class Customer {
    private String customerId;
    private String companyName;
    private CustomerType customerType;

    // Factory method: receives plain params, not Cmd — Domain is decoupled from client DTOs
    // CmdExe parses enum before calling factory; Domain receives typed CustomerType directly
    public static Customer create(String companyName, CustomerType customerType) {
        Customer customer = new Customer();
        customer.setCustomerId(UUID.randomUUID().toString().replace("-", ""));
        customer.setCompanyName(companyName);
        customer.setCustomerType(customerType);
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
    private final CustomerDomainConverter customerDomainConverter;

    @Override
    public void save(Customer customer) {
        customerMapper.insert(customerDomainConverter.fromDomain(customer));
    }

    @Override
    public void update(Customer customer) {
        customerMapper.updateById(customerDomainConverter.fromDomain(customer));
    }

    @Override
    public Optional<Customer> findById(String id) {
        return Optional.ofNullable(customerMapper.selectOne(
            new LambdaQueryWrapper<CustomerDO>().eq(CustomerDO::getCustomerId, id)))
            .map(customerDomainConverter::toDomain);
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
}

// customer/CustomerDomainConverter.java — MapStruct converter for DO↔Domain (in infrastructure module)
@Mapper(componentModel = "spring")
public interface CustomerDomainConverter {
    CustomerDO fromDomain(Customer customer);
    Customer toDomain(CustomerDO customerDO);
}

// customer/CustomerDOConverter.java — MapStruct converter for DO→DTO (in app module)
@Mapper(componentModel = "spring")
public interface CustomerDOConverter {
    CustomerDTO toDTO(CustomerDO customerDO);
}

// customer/CreditGatewayImpl.java — external service via RestClient
@Repository
@RequiredArgsConstructor
public class CreditGatewayImpl implements CreditGateway {
    private final RestClient creditRestClient;

    @Override
    public Credit getCredit(String customerId) {
        try {
            return creditRestClient.get()
                .uri("/credit/{customerId}", customerId)
                .retrieve()
                .body(Credit.class);
        } catch (RestClientException e) {
            throw new BusinessException(ErrorCode.EXTERNAL_SERVICE_ERROR,
                "Failed to get credit for customer: " + customerId, e);
        }
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
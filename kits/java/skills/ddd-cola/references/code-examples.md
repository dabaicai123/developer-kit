# Code Examples

Detailed code examples for each COLA layer. These are reference implementations — the SKILL.md contains the rules and conventions, this file contains the concrete code.

**Import note**: All validation annotations use `jakarta.validation.constraints.*` (Spring Boot 3.x), not `javax.validation.constraints.*` (Spring Boot 2.x legacy).

## common Module

Shared kernel types — depended on by both `client` and `domain`, keeping them as leaf modules.

```java
// common/dto/Command.java — marker base class for CQRS write identification
public abstract class Command implements Serializable {
}

// common/dto/Query.java — marker base class for CQRS read identification
// Note: Unlike official COLA, Query does NOT extend Command — read and write are semantically distinct
public abstract class Query implements Serializable {
}
```

> `Result<T>`, `PageResult<T>`, `BusinessException`, `ErrorCode` are detailed in `spring-boot-rest-api-standards` and `spring-boot-exception-handling`. They live here in `common` so every other module can reference them without pulling in Spring or MyBatis.

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

> `Result<T>`, `PageResult<T>`, `BusinessException`, `Command`, `Query` live in the `common` module. See `spring-boot-rest-api-standards` and `spring-boot-exception-handling`. The `common` module is depended on by both `client` and `domain` so neither has to know about the other.

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

### Complex Structure: DTO (client) vs VO (domain)

When a structure like `ConditionGroup` must cross the API boundary, define two types — flat DTO in client, behavior-carrying VO in domain. The app `DtoVoConvertor` bridges them. This is how `client` and `domain` stay as independent leaf modules.

```java
// client — dto/data/ConditionGroupDTO.java
// Flat, serializable, NO behavior. Consumers can JSON-deserialize without any domain dependency.
@Data
public class ConditionGroupDTO {
    private String operator;              // "AND" or "OR" as string
    private List<ConditionDTO> conditions;
    private List<ConditionGroupDTO> nestedGroups;
}

// client — dto/data/ConditionDTO.java
@Data
public class ConditionDTO {
    private String field;
    private String op;
    private Object value;
}
```

```java
// domain — taskrule/vo/ConditionGroup.java
// Behavior-carrying domain value object. Lives in domain, uses domain types.
@Value
@Builder
public class ConditionGroup {
    LogicalOperator operator;         // domain enum, not String
    List<Condition> conditions;
    List<ConditionGroup> nestedGroups;

    public boolean matches(EvaluationContext ctx) {
        return operator == LogicalOperator.AND
            ? allMatch(ctx)
            : anyMatch(ctx);
    }

    private boolean allMatch(EvaluationContext ctx) {
        return conditions.stream().allMatch(c -> c.matches(ctx))
            && nestedGroups.stream().allMatch(g -> g.matches(ctx));
    }

    private boolean anyMatch(EvaluationContext ctx) {
        return conditions.stream().anyMatch(c -> c.matches(ctx))
            || nestedGroups.stream().anyMatch(g -> g.matches(ctx));
    }
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

// customer/convertor/CustomerDtoVoConvertor.java — MapStruct bridge between client DTO and domain VO
// This lives in app because app is the only module that knows both client and domain.
@Mapper(componentModel = "spring")
public interface CustomerDtoVoConvertor {
    // Example: ConditionGroupDTO (client, flat, operator as String) → ConditionGroup (domain, rich, LogicalOperator enum)
    @Mapping(target = "operator", source = "operator", qualifiedByName = "operatorToEnum")
    ConditionGroup toVo(ConditionGroupDTO dto);

    @Named("operatorToEnum")
    default LogicalOperator operatorToEnum(String operator) {
        return operator == null ? null : LogicalOperator.valueOf(operator.toUpperCase());
    }
}

// customer/executor/CustomerAddCmdExe.java — write handler
@Component
@RequiredArgsConstructor
public class CustomerAddCmdExe {
    private final CustomerGateway customerGateway;

    @Transactional(rollbackFor = Exception.class)
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

> When Cmd fields are primitives (as in this `CustomerAddCmd` example), a Convertor is overkill — CmdExe maps directly. Use `DtoVoConvertor` when Cmd carries nested DTOs that correspond to domain VOs (e.g., a `TaskRuleAddCmd` with `List<ConditionGroupDTO>` that needs to become `List<ConditionGroup>`).

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

**Package layout** (domain-first + `craftsman`-style nested sub-packages):

```
com.example.customer/
├── CustomerGatewayImpl.java             # domain-level facade
├── CreditGatewayImpl.java               # external-service facade
└── gatewayimpl/
    ├── database/
    │   ├── CustomerMapper.java
    │   ├── CustomerDomainConverter.java
    │   └── dataobject/
    │       └── CustomerDO.java
    └── rpc/                             # optional — only when calling external services
        ├── CreditRpcClient.java
        └── dataobject/
            └── CreditRpcDO.java
```

```java
// customer/CustomerGatewayImpl.java — domain facade, composes database adapter
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

// customer/gatewayimpl/database/dataobject/CustomerDO.java — see mybatis-plus-patterns for full DO conventions
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

// customer/gatewayimpl/database/CustomerDomainConverter.java — MapStruct converter for DO↔Domain (in infrastructure module)
@Mapper(componentModel = "spring")
public interface CustomerDomainConverter {
    CustomerDO fromDomain(Customer customer);
    Customer toDomain(CustomerDO customerDO);
}

// app module — customer/convertor/CustomerDOConverter.java — MapStruct converter for DO→DTO (read path)
@Mapper(componentModel = "spring")
public interface CustomerDOConverter {
    CustomerDTO toDTO(CustomerDO customerDO);
}

// customer/CreditGatewayImpl.java — external-service facade; delegates to gatewayimpl/rpc/ adapter
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

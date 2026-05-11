---
name: mapstruct-patterns
description: "MapStruct object mapping for DDD/COLA architecture: Domain ↔ DO, Domain ↔ DTO/Cmd conversions, update mapping, nested objects, and Maven config with Lombok. Use when creating mappers for COLA layer boundaries or configuring MapStruct with Spring Boot."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# MapStruct Patterns (DDD Context)

## When to use this skill

- Creating mappers between Domain entities and Infrastructure DOs (Domain ↔ DO)
- Creating mappers between Domain entities and Adapter DTOs/Cmds (Domain ↔ DTO/Cmd)
- Configuring MapStruct annotation processing with Lombok in Spring Boot
- Implementing update mappings with `@MappingTarget` for partial updates

> For mapper unit testing, see `unit-test-mapper-converter`. For COLA architecture context, see `ddd-cola`.

## Dependencies + Maven Config

```xml
<properties>
    <mapstruct.version>1.6.3</mapstruct.version>
</properties>

<dependencies>
    <dependency>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct</artifactId>
        <version>${mapstruct.version}</version>
    </dependency>
</dependencies>

<!-- In maven-compiler-plugin annotationProcessorPaths -->
<!-- Order matters: Lombok → MapStruct → Binding -->
<path>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>${lombok.version}</version>
</path>
<path>
    <groupId>org.mapstruct</groupId>
    <artifactId>mapstruct-processor</artifactId>
    <version>${mapstruct.version}</version>
</path>
<path>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok-mapstruct-binding</artifactId>
    <version>0.2.0</version>
</path>
```

Set default component model globally:

```xml
<compilerArgs>
    <arg>-Amapstruct.defaultComponentModel=spring</arg>
</compilerArgs>
```

## Converter Naming (anchored to ddd-cola)

Two converter types, two distinct names — do NOT use the same suffix for both:

| Converter | Direction | Location | Class Name |
|-----------|-----------|----------|------------|
| `XxxDomainConverter` | Domain ↔ DO | `infrastructure/{domain}/gatewayimpl/database/` | e.g. `OrderDomainConverter` |
| `XxxDOConverter` | DO → DTO (read path) | `app/{domain}/converter/` | e.g. `OrderDOConverter` |

> Naming alignment: matches `ddd-cola` and `mybatis-plus-generator`. Never name a Domain↔DO converter `XxxDOConverter` — that suffix is reserved for the DO→DTO converter used by `QryExe`.

## Converter Location in COLA Layers

```
demo-adapter/
└── web/
    └── OrderController.java
demo-app/
└── order/                              # domain-first
    ├── OrderServiceImpl.java
    ├── converter/                      # Read-path mappers (App layer)
    │   ├── OrderDTOConverter.java      # Domain ↔ DTO/Cmd (when CmdExe returns Domain)
    │   └── OrderDOConverter.java       # DO → DTO (for QryExe direct Mapper reads)
    └── executor/
demo-domain/
└── domain/order/
    ├── Order.java                      # bare name, @Data, NO ORM annotations
    └── gateway/
        └── OrderGateway.java
demo-infrastructure/
└── order/                              # domain-first + craftsman-style nesting
    ├── OrderGatewayImpl.java           # domain-level facade
    └── gatewayimpl/
        ├── database/
        │   ├── OrderMapper.java
        │   ├── OrderDomainConverter.java   # Domain ↔ DO mapper (Infrastructure layer)
        │   └── dataobject/
        │       └── OrderDO.java        # MyBatis-Plus annotations
        └── rpc/                        # optional — external services
            ├── XxxRpcClient.java
            └── dataobject/
                └── XxxRpcDO.java
```

**Dependency direction**: converters depend on Domain (read domain types), but Domain never depends on converters.

## Domain ↔ DO Mapper (Infrastructure Layer)

Replaces manual `OrderDO.fromDomain(order)` / `OrderDO.toDomain()`:

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDomainConverter {

    OrderDO toDO(Order order);

    Order toDomain(OrderDO orderDO);
}
```

No `@Mapping(target = "xxx", ignore = true)` needed for audit fields. `unmappedTargetPolicy = IGNORE` auto-skips fields absent from the source — Domain `Order` has no `id`/`createdAt`/`updatedAt`/`version`/`deletedAt`, so MapStruct silently omits them.

**Only add explicit `@Mapping(target = "xxx", ignore = true)` when source and target share a field name with different semantics** (e.g., Domain `id` = business ID vs DO `id` = database PK).

Use in GatewayImpl (see `ddd-cola` for the full Gateway pattern context):

```java
@Repository
@RequiredArgsConstructor
public class OrderGatewayImpl implements OrderGateway {
    private final OrderMapper orderMapper;
    private final OrderDomainConverter orderDomainConverter;

    @Override
    public void save(Order order) {
        orderMapper.insert(orderDomainConverter.toDO(order));
    }

    @Override
    public Optional<Order> findById(String id) {
        return Optional.ofNullable(orderMapper.selectOne(
            new LambdaQueryWrapper<OrderDO>().eq(OrderDO::getOrderId, id)))
            .map(orderDomainConverter::toDomain);
    }
}
```

Audit fields (`id`, `createdAt`, `updatedAt`, `version`, `deletedAt`) are managed by MyBatis-Plus or the database — never map them from Domain.

## DO → DTO Mapper (App Layer, Read Path)

For `QryExe` that reads `Mapper` directly and returns `DTO` — bypassing Domain for performance:

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDOConverter {

    OrderDTO toDTO(OrderDO orderDO);

    List<OrderDTO> toDTOList(List<OrderDO> orderDOs);
}
```

Use in QryExe:

```java
@Component
@RequiredArgsConstructor
public class OrderListQryExe {
    private final OrderMapper orderMapper;
    private final OrderDOConverter orderDOConverter;

    public Result<List<OrderDTO>> execute(OrderListQry qry) {
        List<OrderDO> records = orderMapper.selectList(
            new LambdaQueryWrapper<OrderDO>().eq(OrderDO::getStatus, qry.getStatus()));
        return Result.success(orderDOConverter.toDTOList(records));
    }
}
```

## Domain ↔ DTO/Cmd Mapper (App Layer, Write Path)

For complex Cmd → Domain construction. Many CmdExe build Domain entities by direct factory method (`Customer.create(...)`) and do not need a converter — only use this pattern when Cmd has 5+ fields that map 1:1 to Domain.

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDTOConverter {

    OrderDTO toDTO(Order order);

    Order fromCreateCmd(CreateOrderCmd cmd);
}
```

Use in CmdExe (not Controller — adapter stays thin):

```java
@Component
@RequiredArgsConstructor
public class CreateOrderCmdExe {
    private final OrderGateway orderGateway;
    private final OrderDTOConverter orderDTOConverter;

    @Transactional
    public Result<OrderDTO> execute(CreateOrderCmd cmd) {
        Order order = orderDTOConverter.fromCreateCmd(cmd);
        orderGateway.save(order);
        return Result.success(orderDTOConverter.toDTO(order));
    }
}
```

## Update Mapping

Use `@MappingTarget` for partial updates — only non-null fields are applied:

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDomainConverter {

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateDOFromDomain(Order order, @MappingTarget OrderDO orderDO);
}
```

`@BeanMapping(nullValuePropertyMappingStrategy = IGNORE)` ensures partial updates don't overwrite existing DO fields with null from Domain.

```java
@Repository
@RequiredArgsConstructor
public class OrderGatewayImpl implements OrderGateway {
    private final OrderMapper orderMapper;
    private final OrderDomainConverter orderDomainConverter;

    @Override
    public void update(Order order) {
        OrderDO existing = orderMapper.selectOne(
            new LambdaQueryWrapper<OrderDO>().eq(OrderDO::getOrderId, order.getOrderId()));
        orderDomainConverter.updateDOFromDomain(order, existing);
        orderMapper.updateById(existing);
    }
}
```

## Nested Objects + Collection

Use `uses` to compose mappers for nested objects:

```java
@Mapper(componentModel = "spring", uses = {OrderItemDomainConverter.class})
public interface OrderDomainConverter {
    OrderDO toDO(Order order);
    Order toDomain(OrderDO orderDO);
}

@Mapper(componentModel = "spring")
public interface OrderItemDomainConverter {
    OrderItemDO toDO(OrderItem item);
    OrderItem toDomain(OrderItemDO itemDO);
    List<OrderItemDO> toDOList(List<OrderItem> items);
    List<OrderItem> toDomainList(List<OrderItemDO> itemDOs);
}
```

## Custom Methods for Complex Conversion

> **Enum ↔ String mapping is built-in**: MapStruct automatically maps `Enum` ↔ `String` via `Enum.name()` and `Enum.valueOf(String)`. Do NOT write `default mapStatus(...)` methods for routine `OrderStatus` ↔ `String` cases — that's framework duplication. Only add custom methods when the enum needs **non-name** serialization (e.g., a `getCode()` int, a lowercase string, or a legacy database value).

Use default methods in interfaces for simple custom logic — MapStruct auto-selects them by type matching:

```java
@Mapper(componentModel = "spring")
public interface OrderDomainConverter {
    OrderDO toDO(Order order);
    Order toDomain(OrderDO orderDO);

    // Example of a JUSTIFIED custom method: enum uses a non-name code
    default String mapStatusCode(OrderStatus status) {
        return status == null ? null : status.getCode();
    }
}
```

If you need `@Named` qualifiers to distinguish multiple methods with the same source/target type, **use `org.mapstruct.Named`** — never `jakarta.inject.Named`:

```java
@Mapper(componentModel = "spring")
public interface UserDomainConverter {
    @Mapping(target = "displayName", qualifiedByName = "fullName")
    UserDO toDO(User user);

    @Named("fullName")
    default String toFullName(User user) {
        return user.getFirstName() + " " + user.getLastName();
    }
}
```

Use abstract class when you need injected dependencies:

```java
@Mapper(componentModel = "spring", uses = {RoleDomainConverter.class})
public abstract class UserDomainConverter {

    @Autowired
    protected RoleGateway roleGateway;

    public abstract UserDO toDO(User user);
    public abstract User toDomain(UserDO userDO);

    // Custom method: resolve roles by IDs from gateway
    protected Set<Role> mapRoleIds(Set<String> roleIds) {
        if (roleIds == null) return Set.of();
        return roleIds.stream()
            .map(id -> roleGateway.findById(id).orElseThrow())
            .collect(Collectors.toSet());
    }
}
```

## Best Practices

- **Converters belong at layer boundaries**: Domain ↔ DO in `infrastructure/{domain}/gatewayimpl/database/` as `XxxDomainConverter`; DO → DTO in `app/{domain}/converter/` as `XxxDOConverter`; Domain ↔ DTO/Cmd (when justified) in `app/{domain}/converter/` as `XxxDTOConverter`
- **Domain never depends on converters**: converters import domain types; domain never imports converters
- **Audit fields auto-excluded via `unmappedTargetPolicy = IGNORE`** (see Domain <-> DO Mapper section). Only add explicit `@Mapping(target = "xxx", ignore = true)` for same-name-but-different-meaning fields
- **Use `@BeanMapping(nullValuePropertyMappingStrategy = IGNORE)`** for partial updates — don't overwrite existing values with null
- **Use `uses` to compose mappers** for nested objects instead of writing `expression = "java(...)"`
- **Use abstract class** only when you need injected dependencies; use interface for simple mappings
- **Annotation processor order**: Lombok → MapStruct → lombok-mapstruct-binding
- **Don't map entity to entity** — MapStruct is for layer boundary conversion only
- **Don't put `@Mapper` on domain entities or DO classes** — mappers are separate interfaces/classes

## Constraints and Warnings

| Anti-pattern | Why | Correct |
|---|---|---|
| Mapping entity → entity | Breaks change tracking, loses domain semantics | Only map across layer boundaries |
| `fromDomain()` / `toDomain()` on DO class | Couples DO to domain, grows with every field | Separate Converter interface |
| Expression for complex logic | Hard to test, not compile-time validated | Custom method in abstract class |
| Mapping domain fields into DO audit columns | Overwrites MyBatis-Plus managed fields | Domain doesn't have these fields — `unmappedTargetPolicy = IGNORE` handles it automatically |
| DO class depending on domain | Violates dependency inversion | Converter depends on both; DO is standalone |

## Related Skills

- `ddd-cola` — COLA architecture layers, naming conventions, Gateway pattern
- `mybatis-plus-patterns` — DO class conventions, GatewayImpl patterns
- `unit-test-mapper-converter` — MapStruct mapper testing patterns
- `spring-boot-dependency-injection` — constructor injection for converter classes
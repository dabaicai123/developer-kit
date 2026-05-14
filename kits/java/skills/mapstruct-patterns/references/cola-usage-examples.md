# COLA Usage Examples for MapStruct Converters

## Converter Location in COLA Layers

```
demo-app/
└── order/
    ├── convertor/
    │   ├── OrderDtoVoConvertor.java    # client DTO/Cmd ↔ domain VO
    │   └── OrderDOConverter.java       # DO → client DTO (for QryExe)
    └── executor/
demo-infrastructure/
└── order/
    └── gatewayimpl/
        └── database/
            ├── OrderDomainConverter.java   # Domain ↔ DO
            └── dataobject/
                └── OrderDO.java
```

## GatewayImpl Usage (Domain ↔ DO)

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

    @Override
    public void update(Order order) {
        OrderDO existing = orderMapper.selectOne(
            new LambdaQueryWrapper<OrderDO>().eq(OrderDO::getOrderId, order.getOrderId()));
        orderDomainConverter.updateDOFromDomain(order, existing);
        orderMapper.updateById(existing);
    }
}
```

## QryExe Usage (DO → DTO)

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

## CmdExe Usage (DTO/Cmd ↔ Domain VO)

```java
@Component
@RequiredArgsConstructor
public class CreateOrderCmdExe {
    private final OrderGateway orderGateway;
    private final OrderDtoVoConvertor orderDtoVoConvertor;

    @Transactional
    public Result<OrderDTO> execute(CreateOrderCmd cmd) {
        OrderRule rule = orderDtoVoConvertor.toOrderRule(cmd.getRule());
        Order order = Order.create(cmd.getBuyerId(), rule);
        orderGateway.save(order);
        return Result.success();
    }
}
```

## @Named Qualifier Example

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

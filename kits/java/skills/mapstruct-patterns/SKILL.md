---
name: mapstruct-patterns
description: "MapStruct object mapping for DDD/COLA architecture: Domain ↔ DO, Domain ↔ DTO/Cmd conversions, update mapping, nested objects, and Maven config with Lombok. Use when creating mappers for COLA layer boundaries or configuring MapStruct with Spring Boot."
version: "1.0.0"
type: skill
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

> Never name a Domain↔DO converter `XxxDOConverter` — that suffix is reserved for the DO→DTO converter used by `QryExe`.

For COLA module structure and converter placement, see `ddd-cola` skill.

## Domain ↔ DO Mapper (Infrastructure Layer)

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDomainConverter {
    OrderDO toDO(Order order);
    Order toDomain(OrderDO orderDO);
}
```

`unmappedTargetPolicy = IGNORE` auto-skips audit fields (`id`, `createdAt`, `updatedAt`, `version`, `deletedAt`) absent from Domain. Only add explicit `@Mapping(target = "xxx", ignore = true)` when source and target share a field name with different semantics.

## DO → DTO Mapper (App Layer, Read Path)

For `QryExe` that reads `Mapper` directly and returns `DTO` — bypassing Domain for performance:

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDOConverter {
    OrderDTO toDTO(OrderDO orderDO);
    List<OrderDTO> toDTOList(List<OrderDO> orderDOs);
}
```

## Domain ↔ DTO/Cmd Mapper (App Layer, Write Path)

Only use when Cmd has 5+ fields that map 1:1 to Domain. Many CmdExe build Domain via factory method and do not need a converter.

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDTOConverter {
    OrderDTO toDTO(Order order);
    Order fromCreateCmd(CreateOrderCmd cmd);
}
```

## Update Mapping

Use `@MappingTarget` + `@BeanMapping(nullValuePropertyMappingStrategy = IGNORE)` for partial updates:

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDomainConverter {
    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateDOFromDomain(Order order, @MappingTarget OrderDO orderDO);
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

## Custom Methods

Enum ↔ String mapping is built-in via `Enum.name()` / `Enum.valueOf()`. Only add custom methods for non-name serialization (e.g., `getCode()` int, legacy DB values).

Use default methods for simple custom logic; use `@Named` qualifiers (`org.mapstruct.Named`, never `jakarta.inject.Named`) to disambiguate same-type methods.

Use abstract class only when injected dependencies are needed:

```java
@Mapper(componentModel = "spring", uses = {RoleDomainConverter.class})
public abstract class UserDomainConverter {
    @Autowired
    protected RoleGateway roleGateway;

    public abstract UserDO toDO(User user);
    public abstract User toDomain(UserDO userDO);

    protected Set<Role> mapRoleIds(Set<String> roleIds) {
        if (roleIds == null) return Set.of();
        return roleIds.stream()
            .map(id -> roleGateway.findById(id).orElseThrow())
            .collect(Collectors.toSet());
    }
}
```

## Constraints and Warnings

| Anti-pattern | Why | Correct |
|---|---|---|
| Mapping entity → entity | Breaks change tracking | Only map across layer boundaries |
| `fromDomain()`/`toDomain()` on DO class | Couples DO to domain | Separate Converter interface |
| Expression for complex logic | Hard to test | Custom method in abstract class |
| Mapping domain fields into DO audit columns | Overwrites MP-managed fields | `unmappedTargetPolicy = IGNORE` handles it |
| DO class depending on domain | Violates dependency inversion | Converter depends on both; DO is standalone |

## Related Skills

- `ddd-cola`, `mybatis-plus-patterns`, `unit-test-mapper-converter`, `spring-boot-dependency-injection`

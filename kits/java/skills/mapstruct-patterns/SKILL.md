---
name: mapstruct-patterns
description: "MapStruct object mapping for DDD/COLA architecture: DTO ↔ domain VO, DO → DTO read models, Domain ↔ DO persistence mapping, update mapping, nested objects, and Maven config with Lombok. Use when creating mappers for COLA layer boundaries or configuring MapStruct with Spring Boot."
version: "1.0.0"
---

# MapStruct Patterns (DDD Context)

## When to use this skill

- Creating mappers between Domain entities and Infrastructure DOs (Domain ↔ DO)
- Creating app-layer mappers between flat client DTO/Cmd objects and behavior-carrying domain VOs (`XxxDtoVoConvertor`)
- Creating app-layer read mappers from Infrastructure DOs to client DTOs (`XxxDOConverter`)
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

Three converter roles, distinct names - do NOT use the same suffix for different boundaries:

| Converter | Direction | Location | Class Name |
|-----------|-----------|----------|------------|
| `XxxDtoVoConvertor` | client DTO/Cmd ↔ domain VO (when needed) | `app/{domain}/convertor/` | e.g. `OrderDtoVoConvertor` |
| `XxxDOConverter` | DO → client DTO (read path) | `app/{domain}/convertor/` | e.g. `OrderDOConverter` |
| `XxxDomainConverter` | Domain ↔ DO | `infrastructure/{domain}/gatewayimpl/database/` | e.g. `OrderDomainConverter` |

> Never name a Domain↔DO converter `XxxDOConverter`; that suffix is reserved for the DO→DTO converter used by `QryExe`.

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

## DTO/Cmd ↔ Domain VO Convertor (App Layer, Write Path)

Only use when a Cmd carries nested DTOs or value-object-shaped data that must become domain VOs. Many CmdExe classes build the domain entity via factory methods from primitive fields and do not need this convertor. Domain entities must not receive client Cmd/DTO directly.

```java
@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface OrderDtoVoConvertor {
    OrderRule toOrderRule(OrderRuleDTO dto);
    OrderRuleDTO toOrderRuleDTO(OrderRule rule);
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

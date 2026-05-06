# Mapper and Converter Unit Testing Reference

Unit testing for DO-to-DTO mapping using MapStruct 1.6.x and custom Converters without Spring container.

## Dependency Configuration

### Maven

MapStruct requires both the runtime dependency AND the annotation processor:

```xml
<properties>
  <org.mapstruct.version>1.6.3</org.mapstruct.version>
</properties>

<dependencies>
  <dependency>
    <groupId>org.mapstruct</groupId>
    <artifactId>mapstruct</artifactId>
    <version>${org.mapstruct.version}</version>
  </dependency>
  <dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.assertj</groupId>
    <artifactId>assertj-core</artifactId>
    <scope>test</scope>
  </dependency>
</dependencies>

<build>
  <plugins>
    <plugin>
      <groupId>org.apache.maven.plugins</groupId>
      <artifactId>maven-compiler-plugin</artifactId>
      <version>3.14.1</version>
      <configuration>
        <annotationProcessorPaths>
          <path>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct-processor</artifactId>
            <version>${org.mapstruct.version}</version>
          </path>
        </annotationProcessorPaths>
      </configuration>
    </plugin>
  </plugins>
</build>
```

### Gradle

```kotlin
dependencies {
  implementation("org.mapstruct:mapstruct:1.6.3")
  annotationProcessor("org.mapstruct:mapstruct-processor:1.6.3")
  testAnnotationProcessor("org.mapstruct:mapstruct-processor:1.6.3")
  testImplementation("org.junit.jupiter:junit-jupiter")
  testImplementation("org.assertj:assertj-core")
}
```

NOT omit `mapstruct-processor` — without it, no mapper implementation classes are generated and tests fail at compile time.

## Basic Testing Patterns

### MapStruct Mapper Testing

Use `Mappers.getMapper()` to create a pure mapper instance for unit testing (no Spring dependency):

```java
@Mapper(componentModel = "spring")
public interface UserMapper {
  UserDTO toDto(User user);
  User toDO(UserDTO dto);
  List<UserDTO> toDtos(List<User> users);
}

class UserMapperTest {
  private final UserMapper userMapper = Mappers.getMapper(UserMapper.class);

  @Test
  void shouldMapUserToDto() {
    User user = new User(1L, "Alice", "alice@example.com", 25);
    UserDTO dto = userMapper.toDto(user);

    assertThat(dto)
      .isNotNull()
      .extracting(UserDTO::getName, UserDTO::getEmail)
      .containsExactly("Alice", "alice@example.com");
  }

  @Test
  void shouldMapDtoToDO() {
    UserDTO dto = new UserDTO(1L, "Alice", "alice@example.com", 25);
    User user = userMapper.toDO(dto);

    assertThat(user)
      .isNotNull()
      .hasFieldOrPropertyWithValue("id", 1L)
      .hasFieldOrPropertyWithValue("name", "Alice");
  }

  @Test
  void shouldMapListOfUsers() {
    List<User> users = List.of(
      new User(1L, "Alice", "alice@example.com", 25),
      new User(2L, "Bob", "bob@example.com", 30)
    );
    List<UserDTO> dtos = userMapper.toDtos(users);

    assertThat(dtos)
      .hasSize(2)
      .extracting(UserDTO::getName)
      .containsExactly("Alice", "Bob");
  }

  @Test
  void shouldHandleNullDO() {
    assertThat(userMapper.toDto(null)).isNull();
  }
}
```

Note: `componentModel = "spring"` makes the mapper a Spring bean in production, but `Mappers.getMapper()` creates a plain instance for unit tests. For integration tests, inject the Spring-managed mapper via `@Autowired`.

### Verify Generated Class Exists

```bash
# Maven
ls target/generated-sources/

# Gradle
ls build/generated/sources/
```

## Null Handling

```java
assertThat(mapper.toDto(null)).isNull();
```

If null should return empty/default value instead of null, configure `nullValueMappingStrategy` in `@Mapper`.

NOT assume MapStruct returns empty collections for null input — default behavior returns null unless `nullValueMappingStrategy` is configured.

## Bidirectional Mapping (Round Trip)

```java
@Test
void shouldMaintainDataInRoundTrip() {
  User original = new User(1L, "Alice", "alice@example.com", 25);
  UserDTO dto = mapper.toDto(original);
  User restored = mapper.toDO(dto);

  assertThat(restored).usingRecursiveComparison().isEqualTo(original);
}

@Test
void shouldPreserveAllFieldsInBothDirections() {
  Address address = new Address("123 Main", "NYC", "NY", "10001");
  User user = new User(1L, "Alice", "alice@example.com", 25, address);
  UserDTO dto = mapper.toDto(user);
  User restored = mapper.toDO(dto);

  assertThat(restored).usingRecursiveComparison().isEqualTo(user);
}
```

NOT skip round-trip testing for bidirectional mappers — forward and reverse mappings may produce asymmetric results.

## Nested Object Mapping

```java
@Test
void shouldMapNestedAddress() {
  Address address = new Address("123 Main St", "New York", "NY", "10001");
  User user = new User(1L, "Alice", address);
  UserDTO dto = mapper.toDto(user);

  assertThat(dto.getAddress())
    .isNotNull()
    .hasFieldOrPropertyWithValue("street", "123 Main St");
}

@Test
void shouldHandleNullNestedObjects() {
  User user = new User(1L, "Alice", null);
  assertThat(mapper.toDto(user).getAddress()).isNull();
}
```

## Custom Mapping Methods and Expressions

```java
@Mapper(componentModel = "spring")
public interface ProductMapper {
  @Mapping(source = "name", target = "productName")
  @Mapping(source = "price", target = "salePrice")
  @Mapping(target = "discount", expression = "java(product.getPrice() * 0.1)")
  ProductDTO toDto(Product product);
}

@Test
void shouldMapFieldsWithCustomNames() {
  Product product = new Product(1L, "Laptop", 999.99);
  ProductDTO dto = mapper.toDto(product);

  assertThat(dto)
    .hasFieldOrPropertyWithValue("productName", "Laptop")
    .hasFieldOrPropertyWithValue("salePrice", 999.99);
}

@Test
void shouldCalculateDiscountFromExpression() {
  Product product = new Product(1L, "Laptop", 100.0);
  ProductDTO dto = mapper.toDto(product);

  assertThat(dto.getDiscount()).isEqualTo(10.0);
}
```

NOT skip testing `@Mapping(expression=...)` — expressions are NOT verified at compile time. Every expression must be explicitly tested.

## Enum Mapping

```java
@Mapper(componentModel = "spring")
public interface StatusMapper {
  @ValueMapping(source = "ACTIVE", target = "ENABLED")
  @ValueMapping(source = "INACTIVE", target = "DISABLED")
  @ValueMapping(source = "SUSPENDED", target = "LOCKED")
  UserStatusDto toStatusDto(UserStatus status);
}

@Test
void shouldMapActiveToEnabled() {
  assertThat(mapper.toStatusDto(UserStatus.ACTIVE)).isEqualTo(UserStatusDto.ENABLED);
}

@Test
void shouldMapAllEnumValues() {
  for (UserStatus status : UserStatus.values()) {
    assertThat(mapper.toStatusDto(status)).isNotNull();
  }
}
```

## Custom Type Converters

```java
public class DateFormatter {
  private static final DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");

  public static String format(LocalDate date) {
    return date != null ? date.format(formatter) : null;
  }

  public static LocalDate parse(String dateString) {
    return dateString != null ? LocalDate.parse(dateString, formatter) : null;
  }
}

@Test
void shouldFormatLocalDateToString() {
  assertThat(DateFormatter.format(LocalDate.of(2024, 1, 15))).isEqualTo("2024-01-15");
}

@Test
void shouldParseStringToLocalDate() {
  assertThat(DateFormatter.parse("2024-01-15")).isEqualTo(LocalDate.of(2024, 1, 15));
}

@Test
void shouldHandleNullInFormat() {
  assertThat(DateFormatter.format(null)).isNull();
}

@Test
void shouldThrowOnInvalidDateFormat() {
  assertThatThrownBy(() -> DateFormatter.parse("invalid-date"))
    .isInstanceOf(DateTimeParseException.class);
}
```

## Partial Update (Update Mapping)

```java
@Mapper(componentModel = "spring")
public interface UserMapper {
  void updateDO(@MappingTarget User user, UserDTO dto);
}

@Test
void shouldUpdateExistingDO() {
  User existing = new User(1L, "Alice", "alice@old.com", 25);
  UserDTO dto = new UserDTO(1L, "Alice", "alice@new.com", 26);
  mapper.updateDO(existing, dto);

  assertThat(existing)
    .hasFieldOrPropertyWithValue("email", "alice@new.com")
    .hasFieldOrPropertyWithValue("age", 26);
}

@Test
void shouldNotUpdateFieldsNotInDto() {
  User existing = new User(1L, "Alice", "alice@example.com", 25);
  UserDTO dto = new UserDTO(1L, "Bob", null, 0);
  mapper.updateDO(existing, dto);

  assertThat(existing.getEmail()).isEqualTo("alice@example.com");
}
```

## Minimum Test Set per Public Method

For each public Mapper method, cover: valid input, null input, round trip.

## Troubleshooting Guide

| Issue | Cause | Solution |
|------|------|----------|
| Generated class missing | MapStruct processor not compiled | Run `mvn compile` / `./gradlew compileJava`; confirm annotation processor configured |
| Null test fails | `nullValueMappingStrategy` not configured | Add `nullValueMappingStrategy = RETURN_NULL` to `@Mapper`; for nested properties use `nullValuePropertyMappingStrategy` |
| Bidirectional asymmetry | `@Mapping` field names mismatch | Map both directions explicitly; use `unmappedTargetPolicy = ReportingPolicy.ERROR` |
| Nested object mapping fails | nested Mapper not registered | Add `uses = NestedMapper.class` |
| Expression test fails | expression syntax or method signature error | Check classes and methods referenced in expression are accessible |

## Constraints

- MapStruct generates code at compile time — compile before testing
- `@Mapping(expression=...)` NOT verified at compile time — must be explicitly tested
- MapStruct cannot handle circular dependencies between Mappers
- Immutable collection mapping may require additional configuration
- Cross-timezone Date/Time mapping needs correctness verification
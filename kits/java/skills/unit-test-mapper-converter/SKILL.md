---
name: unit-test-mapper-converter
description: "Unit testing mappers and converters with MapStruct: DO-to-DTO transformation, custom converter coverage, and mapping logic validation. Use when writing tests for object mapping or ensuring correct data transformation between DTOs and Data Objects."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Unit Testing Mappers and Converters

## Overview

Provides patterns for unit testing MapStruct mappers and custom converter classes. Covers field mapping accuracy, null handling, type conversions, nested object transformations, bidirectional mapping, enum mapping, and partial updates.

## When to use this skill

- Writing mapping tests for MapStruct mapper implementations
- Testing custom DO-to-DTO converters and bean mappings
- Validating nested object mapping and collection transformations

## Instructions

### 1. Validate Generated Mapper Classes
Before testing, verify generated mapper classes exist:
```bash
# Maven
ls target/generated-sources/

# Gradle
ls build/generated/sources/
```

### 2. Test Null Handling
```java
assertThat(mapper.toDto(null)).isNull();
```
Configure `nullValueMappingStrategy` in mapper if null should return empty/default.

### 3. Test Bidirectional Mapping
```java
User restored = mapper.toDO(mapper.toDto(original));
assertThat(restored).usingRecursiveComparison().isEqualTo(original);
```

### 4. Test Nested Object Mapping
```java
assertThat(dto.getNested()).usingRecursiveComparison().isEqualTo(expected);
```

### 5. Test Custom Expressions
Custom expressions in `@Mapping(target = "field", expression = "java(...)")` are not compile-time validated — test them explicitly.

### 6. Test Enum Mappings
Use `@ValueMapping` for enum-to-enum translations. Test all enum values exhaustively.

### 7. Test Each Public Mapper Method
Test each public mapper method with at least: valid input, null input, and round-trip.

## Best Practices

- Test bidirectional mapping catches asymmetries between DO-to-DTO and DTO-to-DO

## Constraints and Warnings

- **Compile-time generation**: MapStruct generates code at compile time—verify generated classes exist before running tests
- **Null handling**: Configure `nullValueMappingStrategy` and `nullValuePropertyMappingStrategy` appropriately
- **Expression validation**: Expressions in `@Mapping` are not validated at compile time—test them explicitly
- **Circular dependencies**: MapStruct cannot handle circular dependencies between mappers
- **Collection immutability**: Mapping immutable collections may require special configuration
- **Date/Time**: Verify date/time objects map correctly across timezones

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Generated classes missing | Run `mvn compile` / `./gradlew compileJava`; verify MapStruct annotation processor is configured; check `@Mapper` interfaces in compiled source set |
| Null tests fail | Add `nullValueMappingStrategy = NullValueMappingStrategy.RETURN_NULL` to `@Mapper`; use `nullValuePropertyMappingStrategy` for nested property handling |
| Bidirectional tests fail | Check `@Mapping` for field name mismatches; verify both directions mapped explicitly; use `unmappedTargetPolicy = ReportingPolicy.ERROR` |
| Nested tests fail | Ensure nested mapper exists via `uses = NestedMapper.class`; check `elementMappingStrategy` |
| Expression tests fail | Verify expression syntax and method signatures; check imported classes accessible from expression context |

## Examples

Complete executable test with imports:
```java
package com.example.mapper;

import org.junit.jupiter.api.Test;
import org.mapstruct.factory.Mappers;
import static org.assertj.core.api.Assertions.*;

class UserMapperCompleteTest {
  private final UserMapper mapper = Mappers.getMapper(UserMapper.class);

  @Test
  void shouldMapUserToDto() {
    User user = new User(1L, "Alice", "alice@example.com", 25);
    UserDto dto = mapper.toDto(user);
    assertThat(dto)
      .isNotNull()
      .extracting(UserDto::getName, UserDto::getEmail)
      .containsExactly("Alice", "alice@example.com");
  }

  @Test
  void shouldMaintainRoundTrip() {
    User original = new User(1L, "Alice", "alice@example.com", 25);
    assertThat(mapper.toDO(mapper.toDto(original)))
      .usingRecursiveComparison()
      .isEqualTo(original);
  }

  @Test
  void shouldHandleNullInput() {
    assertThat(mapper.toDto(null)).isNull();
  }
}
```

Additional examples in: `references/examples.md`

## Related Skills

- `unit-test-service-layer` — Mockito patterns for testing service layer mappers

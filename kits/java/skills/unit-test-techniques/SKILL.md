---
name: unit-test-techniques
description: "General Java/JUnit 5 testing techniques: parameterized testing, boundary value analysis, utility method testing. Use when writing parameterized tests, boundary condition tests, and utility/static method tests."
version: "1.0.0"
---

# Unit Test Techniques

General Java/JUnit 5 testing techniques covering three core patterns: parameterized testing, boundary value analysis, and utility/static method testing.

## When to use this skill

- Write data-driven JUnit tests that need to test multiple input combinations
- Test boundary conditions: null, empty, extreme values, overflow, floating-point precision
- Test utility classes, static methods, and pure functions for null handling and boundary behavior
- Test enum coverage, off-by-one scenarios, and collection state boundaries

## Instructions

1. Choose source: `@ValueSource` for simple values, `@CsvSource` for tabular, `@MethodSource` for complex objects
2. Cover both sides of each boundary: below, at, above — for numbers, strings (null/empty/whitespace), collections (0/1/many)
3. NOT compare floats with `==` — use `isCloseTo(expected, within(tolerance))` or `BigDecimal`
4. NOT mock pure utility methods — only mock I/O dependencies like Clock
5. NOT mix null-return and throw for the same input type — pick one strategy per input
6. Use `Math.addExact()` / `Math.subtractExact()` to detect overflow
7. Name tests descriptively: `shouldCapitalizeFirstLetter`, NOT `test1`

---

## Section 1: Parameterized Testing

Use `@ParameterizedTest` to run the same logic across multiple inputs, eliminating duplicate tests.

Requires: `spring-boot-starter-test` (includes JUnit 5, AssertJ, Mockito).

### `@ValueSource` — Simple Values

```java
@ParameterizedTest
@ValueSource(strings = {"hello", "world", "test"})
void shouldCapitalizeAllStrings(String input) {
  assertThat(StringUtils.capitalize(input)).isNotEmpty();
}

@ParameterizedTest
@ValueSource(ints = {Integer.MIN_VALUE, -1, 0, 1, Integer.MAX_VALUE})
void shouldHandleBoundaryValues(int value) {
  assertThat(Math.incrementExact(value)).isGreaterThan(value);
}
```

### `@CsvSource` — Tabular Data

```java
@ParameterizedTest
@CsvSource({
  "alice@example.com, true",
  "invalid-email,     false",
  "user@,             false"
})
void shouldValidateEmailAddresses(String email, boolean expected) {
  assertThat(UserValidator.isValidEmail(email)).isEqualTo(expected);
}
```

### `@MethodSource` — Complex Objects

```java
@ParameterizedTest
@MethodSource("additionTestCases")
void shouldAddNumbersCorrectly(int a, int b, int expected) {
  assertThat(Calculator.add(a, b)).isEqualTo(expected);
}

static Stream<Arguments> additionTestCases() {
  return Stream.of(
    Arguments.of(1, 2, 3), Arguments.of(0, 0, 0), Arguments.of(-1, 1, 0)
  );
}
```

### `@EnumSource` — Enum Coverage

```java
@ParameterizedTest
@EnumSource(Status.class)
void shouldHandleAllStatuses(Status status) { assertThat(status).isNotNull(); }

@ParameterizedTest
@EnumSource(value = Status.class, names = {"ACTIVE", "INACTIVE"})
void shouldHandleSpecificStatuses(Status status) {
  assertThat(status).isIn(Status.ACTIVE, Status.INACTIVE);
}
```

### Null and Empty Sources

`@ValueSource` does not support null. Use `@NullAndEmptySource` or `@MethodSource`:

```java
@ParameterizedTest
@NullAndEmptySource
void shouldThrowForNullAndEmpty(String input) {
  assertThatThrownBy(() -> Parser.parse(input)).isInstanceOf(IllegalArgumentException.class);
}
```

### Custom Display Names & ArgumentsProvider

```java
@ParameterizedTest(name = "Discount {0}% calculated correctly")
@ValueSource(ints = {5, 10, 15, 20})
void shouldApplyDiscount(int pct) {
  assertThat(DiscountCalculator.apply(100.0, pct))
    .isCloseTo(100.0 * (1 - pct / 100.0), within(0.01));
}
```

---

## Section 2: Boundary Value Analysis

Systematic testing of boundary conditions, extreme values, and corner cases.

### Integer Boundaries

```java
@ParameterizedTest
@ValueSource(ints = {Integer.MIN_VALUE, Integer.MIN_VALUE + 1, 0,
                     Integer.MAX_VALUE - 1, Integer.MAX_VALUE})
void shouldHandleIntegerBoundaries(int value) { assertThat(value).isNotNull(); }

@Test
void shouldDetectOverflow() {
  assertThatThrownBy(() -> Math.addExact(Integer.MAX_VALUE, 1))
    .isInstanceOf(ArithmeticException.class);
}
```

### String Boundaries

```java
@ParameterizedTest
@ValueSource(strings = {"", " ", "  ", "\t", "\n"})
void shouldRejectEmptyAndWhitespace(String input) {
  assertThat(StringUtils.hasText(input)).isFalse();
}

@Test
void shouldHandleNullString() { assertThat(StringUtils.trimWhitespace(null)).isNull(); }
```

### Collection Boundaries (0-1-Many)

```java
@Test
void shouldHandleEmptyList() {
  assertThat(CollectionUtils.first(List.of())).isNull();
}

@Test
void shouldHandleSingleElement() {
  assertThat(CollectionUtils.first(List.of("only"))).isEqualTo("only");
}
```

### Floating-Point Precision

```java
@Test
void shouldHandleFloatingPointPrecision() {
  assertThat(0.1 + 0.2).isCloseTo(0.3, within(0.0001));
}

@Test
void shouldHandleBigDecimalExact() {
  assertThat(MathUtils.add(new BigDecimal("0.1"), new BigDecimal("0.2")))
    .isEqualTo(new BigDecimal("0.3"));
}
```

| Operation | Assert | Note |
|-----------|---------|------|
| Addition/Multiplication | `isCloseTo(delta)` | Never use `==` for float |
| Exact decimal | `isEqualTo()` | Use `BigDecimal` for financial |
| Percentage | Tolerance-based | `isCloseTo(expected, within(0.01))` |

### Off-By-One & Date/Time

```java
@ParameterizedTest
@CsvSource({"-1, false", "0, true", "1, true", "99, true", "100, false"})
void shouldValidateRangeBoundaries(int value, boolean expected) {
  assertThat(value >= 0 && value <= 100).isEqualTo(expected);
}

@Test
void shouldRejectNonLeapFeb29() {
  assertThatThrownBy(() -> LocalDate.of(2023, 2, 29)).isInstanceOf(DateTimeException.class);
}
```

---

## Section 3: Utility & Static Method Testing

Testing utility classes, static methods, and pure functions. Pure functions need no mocking.

### Basic Static Utility

```java
class StringUtilsTest {
  @Test void shouldCapitalizeFirstLetter() {
    assertThat(StringUtils.capitalize("hello")).isEqualTo("Hello");
  }
  @Test void shouldReturnNullForNullInput() {
    assertThat(StringUtils.capitalize(null)).isNull();
  }
  @Test void shouldHandleEmptyString() {
    assertThat(StringUtils.capitalize("")).isEmpty();
  }
}
```

### Null-Safe Defaults & Math Utility

```java
@Test void shouldReturnDefaultWhenNull() {
  assertThat(NullSafeUtils.getOrDefault(null, "default")).isEqualTo("default");
}

@Test void shouldCalculatePercentage() {
  assertThat(MathUtils.percentage(25, 100)).isEqualTo(25.0);
}

@Test void shouldHandleZeroDivisor() {
  assertThat(MathUtils.percentage(50, 0)).isZero();
}
```

### Validation Utility

```java
@ParameterizedTest
@CsvSource({"user@example.com, true", "invalid, false", "', false"})
void shouldValidateEmails(String email, boolean expected) {
  assertThat(ValidatorUtils.isValidEmail(email)).isEqualTo(expected);
}
```

### Utility with Clock Dependency (Rare)

```java
@ExtendWith(MockitoExtension.class)
class DateUtilsTest {
  @Mock private Clock clock;

  @Test void shouldGetDateFromClock() {
    when(clock.instant()).thenReturn(Instant.parse("2024-01-15T10:00:00Z"));
    assertThat(DateUtils.today(clock)).isEqualTo(LocalDate.of(2024, 1, 15));
  }
}
```

## Constraints and Warnings

- Parameter count in data source must match test method signature
- `@ValueSource` only supports primitives, strings, and enums — NOT null or objects
- Strings with commas in `@CsvSource` must use single-quote escaping
- Static utility methods must be thread-safe; see [concurrent-testing](references/concurrent-testing.md)

## References

- [references/parameterized-testing.md](references/parameterized-testing.md) — full parameterized testing examples
- [references/boundary-values.md](references/boundary-values.md) — boundary values and edge cases reference
- [references/concurrent-testing.md](references/concurrent-testing.md) — concurrent safety testing patterns

## Related Skills

- `spring-boot-tdd`
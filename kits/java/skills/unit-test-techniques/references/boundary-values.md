# Boundary Values and Edge Cases Reference

Supplementary examples and extended boundary conditions beyond SKILL.md.

## Numeric — Zero Divisor & Large Numbers

```java
@Test
void shouldHandleZeroDivisor() {
    assertThat(MathUtils.divide(0, 5)).isZero();
    assertThatThrownBy(() -> MathUtils.divide(5, 0))
        .isInstanceOf(ArithmeticException.class);
}

@Test
void shouldHandleLargeNumbers() {
    BigDecimal result = MathUtils.add(
        new BigDecimal("999999999999.99"),
        new BigDecimal("0.01")
    );
    assertThat(result).isEqualTo(new BigDecimal("1000000000000.00"));
}
```

## String — Unicode, Whitespace & Very Long

```java
@Test
void shouldHandleUnicodeCharacters() {
    assertThat(StringUtils.capitalize("über")).isEqualTo("Über");
}

@Test
void shouldHandleOnlyWhitespace() {
    assertThat(StringUtils.trim("   ")).isEmpty();
}

@Test
void shouldHandleVeryLongString() {
    String longString = "x".repeat(1000000);
    assertThat(StringUtils.hasText(longString)).isTrue();
}
```

## Collection — Null Input & No Matches

```java
@Test
void shouldReturnEmptyForNullInput() {
    assertThat(CollectionUtils.filter(null, n -> true)).isEmpty();
}

@Test
void shouldReturnEmptyForNoMatches() {
    assertThat(CollectionUtils.filter(List.of(1, 3, 5), n -> n % 2 == 0)).isEmpty();
}

@Test
void shouldHandleEmptyCollection() {
    assertThat(CollectionUtils.join(List.of(), "-")).isEmpty();
}

@Test
void shouldHandleSingleElement() {
    assertThat(CollectionUtils.join(List.of("a"), "-")).isEqualTo("a");
}
```

## Validation — Null/Empty/Long/Special Characters

```java
@Test
void shouldRejectEmptyEmail() {
    assertThat(ValidatorUtils.isValidEmail("")).isFalse();
}

@Test
void shouldRejectNullEmail() {
    assertThat(ValidatorUtils.isValidEmail(null)).isFalse();
}

@Test
void shouldHandleLongStrings() {
    assertThat(StringUtils.truncate("a".repeat(10000), 100)).hasSize(100);
}

@Test
void shouldHandleSpecialCharactersInUrls() {
    assertThat(ValidatorUtils.isValidUrl("https://example.com/path?query=value")).isTrue();
}
```

## Floating Point Precision Rules

| Operation | Use | Example |
|-----------|-----|---------|
| Addition | `isCloseTo(delta)` | `isCloseTo(0.3, within(0.001))` |
| Comparison | `isEqualTo()` | Use `BigDecimal` for exact decimals |
| Percentage | Tolerance-based | `isCloseTo(expected, within(0.01))` |

## Date/Time — MIN/MAX & Leap Year

```java
@Test
void shouldHandleMinAndMaxDates() {
    assertThat(LocalDate.MIN).isBefore(LocalDate.MAX);
}

@Test
void shouldRejectInvalidDateInNonLeapYear() {
    assertThatThrownBy(() -> LocalDate.of(2023, 2, 29))
        .isInstanceOf(DateTimeException.class);
}
```

## Array — Out of Bounds & Empty

```java
@Test
void shouldThrowOnOutOfBoundsIndex() {
    assertThatThrownBy(() -> new int[]{1, 2, 3}[10])
        .isInstanceOf(ArrayIndexOutOfBoundsException.class);
}

@Test
void shouldHandleEmptyArray() {
    assertThatThrownBy(() -> new int[]{}[0])
        .isInstanceOf(ArrayIndexOutOfBoundsException.class);
}
```
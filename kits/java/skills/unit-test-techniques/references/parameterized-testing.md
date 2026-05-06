# Parameterized Testing Reference

Supplementary examples beyond SKILL.md.

## CsvSource — String Boundaries

```java
@ParameterizedTest
@CsvSource({
    "null,            false",
    "'',              false",
    "'   ',           false",
    "a,               true",
    "abc,             true"
})
void shouldValidateStringBoundaries(String input, boolean expected) {
    assertThat(StringValidator.isValid(input)).isEqualTo(expected);
}
```

## MethodSource — Transformation & Named Edge Cases

```java
static Stream<Arguments> stringTransformationCases() {
    return Stream.of(
        Arguments.of("hello", "hello-world", "hello-world"),
        Arguments.of("Hello World", "hello_world", "hello_world"),
        Arguments.of("Test@123", "test123", "test123")
    );
}

@ParameterizedTest
@MethodSource("stringTransformationCases")
void shouldTransformStringsCorrectly(String input, String sep, String expected) {
    assertThat(StringUtils.toSlug(input, sep)).isEqualTo(expected);
}

static Stream<Arguments> edgeCaseProvider() {
    return Stream.of(
      Arguments.of(Integer.MIN_VALUE, "min"),
      Arguments.of(-1, "negative"),
      Arguments.of(0, "zero"),
      Arguments.of(1, "positive"),
      Arguments.of(Integer.MAX_VALUE, "max")
    );
}

@ParameterizedTest
@MethodSource("edgeCaseProvider")
void shouldTestAllEdgeCases(int value, String description) {
    assertThat(value).isNotNull();
}
```

## NullSource & EmptySource (Separate)

```java
@ParameterizedTest @NullSource @EmptySource
void shouldHandleNullAndEmpty(String input) {
    assertThat(StringUtils.isBlank(input)).isTrue();
}

@ParameterizedTest @NullAndEmptySource
void shouldHandleNullEmptyAndBlank(String input) {
    assertThat(StringUtils.isBlank(input)).isTrue();
}
```

## Off-By-One Range Testing

```java
@ParameterizedTest
@CsvSource({"-1, false", "0, true", "1, true", "99, true", "100, false", "101, false"})
void shouldValidateRangeBoundaries(int value, boolean expected) {
    assertThat(value >= 0 && value <= 100).isEqualTo(expected);
}

@Test
void shouldHandleArrayIndexOffByOne() {
    int[] array = {1, 2, 3};
    assertThat(array[0]).isEqualTo(1);
    assertThat(array[array.length - 1]).isEqualTo(3);
}
```
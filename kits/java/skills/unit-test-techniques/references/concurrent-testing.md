# Concurrent Testing Reference

Thread safety patterns for testing concurrent boundary conditions.

## NOT Patterns

- NOT use `HashMap` in concurrent contexts — use `ConcurrentHashMap`
- NOT iterate and modify `ArrayList` concurrently — use `CopyOnWriteArrayList`
- NOT rely on `++` for shared counters — use `AtomicInteger`

## Null and Race Conditions

```java
class ConcurrentBoundaryTest {

  @Test
  void shouldHandleNullInConcurrentMap() {
    ConcurrentHashMap<String, String> map = new ConcurrentHashMap<>();
    assertThat(map.get("nonexistent")).isNull();
  }

  @Test
  void shouldHandleConcurrentModification() {
    List<Integer> list = new CopyOnWriteArrayList<>(List.of(1, 2, 3, 4, 5));
    for (int num : list) {
      if (num == 3) { list.add(6); }
    }
    assertThat(list).hasSize(6);
  }

  @Test
  void shouldHandleEmptyBlockingQueue() {
    BlockingQueue<String> queue = new LinkedBlockingQueue<>();
    assertThat(queue.poll()).isNull();
  }
}
```

## Thread Safety Patterns

```java
class ThreadSafetyBoundaryTest {

  @Test
  void shouldHandleAtomicOperations() {
    AtomicInteger counter = new AtomicInteger(0);
    counter.incrementAndGet();
    counter.addAndGet(Integer.MAX_VALUE);
    assertThat(counter.get()).isGreaterThan(0);
  }
}
```
---
name: frontend-testing
description: "Defines frontend testing with Vitest, Testing Library, integration flow tests, Server Action tests, and Playwright E2E. Use when adding test coverage, testing React components, or validating user flows."
version: "1.0.0"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Frontend Testing

Test the right things at the right level. Follow the testing pyramid: many fast unit tests, fewer integration tests, few E2E tests.

## When to Use This Skill

- Setting up Vitest + Testing Library for component tests
- Writing integration tests for user flows
- Testing Server Actions directly
- Setting up Playwright E2E tests for critical journeys
- Avoiding testing anti-patterns (implementation details)

## Testing Pyramid

```
         ╱  E2E  ╲          Few, slow, high confidence
        ╱─────────╲         Playwright: critical journeys only
       ╱ Integration ╲      Some, medium speed, medium confidence
      ╱───────────────╲     Vitest + Testing Library: user-facing behavior
     ╱    Unit Tests    ╲   Many, fast, focused confidence
    ╱────────────────────╲  Vitest: pure functions, hooks, utilities
```

| Level | Tool | Scope | Speed | Count |
|---|---|---|---|---|
| Unit | Vitest | Pure functions, custom hooks, utility functions | Fast (< 10ms) | Many |
| Component/Integration | Vitest + Testing Library | Component rendering, user interactions, form submissions | Medium (< 100ms) | Some |
| Server Action | Vitest | Direct invocation of Server Actions with mock DB | Medium (< 100ms) | Some |
| E2E | Playwright | Critical user journeys across multiple pages | Slow (> 1s) | Few |

## What to Test at Each Level

### Unit (Vitest alone)
- Utility functions (formatters, validators, parsers)
- Custom hooks (without DOM rendering - `renderHook`)
- Pure business logic (calculations, transformations)
- Zod schemas (validation rules, edge cases)

### Component/Integration (Vitest + Testing Library)
- Component renders expected content
- User interactions produce expected behavior (click, type, submit)
- Form validation shows errors near inputs
- Loading and error states render correctly
- Accessibility (keyboard navigation, ARIA attributes)

### Server Action (Vitest)
- Validation rejects invalid input (Zod)
- Successful input produces correct result
- Redirects work correctly
- Revalidation calls are correct
- Error handling returns proper Result types

### E2E (Playwright)
- Authentication flow (login, logout, session persistence)
- Core business flow (create product, complete order)
- Critical path (checkout, payment)
- Cross-page navigation
- Responsive behavior on mobile viewport

## Anti-pattern: Testing Implementation Details

**Never test things the user cannot see or interact with.**

```tsx
// BAD: testing implementation details
test("component sets isLoading state", () => {
  const { result } = renderHook(() => useProducts());
  expect(result.current.isLoading).toBe(true); // internal state
});

test("renders with className 'product-card'", () => {
  render(<ProductCard product={mockProduct} />);
  expect(screen.getByTestId("card")).toHaveClass("product-card"); // CSS class
});

test("calls fetchProducts on mount", () => {
  render(<ProductList />);
  expect(fetchProducts).toHaveBeenCalled(); // internal call
});

// GOOD: testing user-facing behavior
test("shows loading skeleton while fetching products", () => {
  render(<ProductList />);
  expect(screen.getByRole("status")).toBeInTheDocument(); // visible loading indicator
});

test("displays product name and price", () => {
  render(<ProductCard product={mockProduct} />);
  expect(screen.getByText(mockProduct.name)).toBeInTheDocument();
  expect(screen.getByText(`$${mockProduct.price}`)).toBeInTheDocument();
});

test("shows validation error when submitting empty form", async () => {
  render(<CreateProductForm />);
  await user.click(screen.getByRole("button", { name: "Create" }));
  expect(screen.getByText("Name is required")).toBeInTheDocument(); // user sees the error
});
```

**Key principles**:
- Query by role, text, and label (what the user sees/hears)
- Do not query by test ID, class name, or component internals
- Test behavior, not state
- Test what the component does, not how it does it

## Related Skills

- **frontend-debugging**: Debugging failing tests
- **forms-and-validation**: Testing form validation and submission
- **react-composition**: Testing compound components

## References

- [vitest-testing-library](references/vitest-testing-library.md) - Setup, component testing, custom render, accessibility assertions
- [server-action-testing](references/server-action-testing.md) - Direct invocation, mock DB, validation testing
- [playwright-e2e](references/playwright-e2e.md) - Critical journeys, auth, API mocking, page objects

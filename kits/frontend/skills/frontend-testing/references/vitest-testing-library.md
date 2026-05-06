# Vitest + Testing Library

Setup, component testing, custom render helpers, accessibility assertions with axe, and snapshot guidelines.

## Setup

### Install

```bash
npm install -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom
```

### vitest.config.ts

```tsx
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./vitest.setup.ts"],
    include: ["**/*.{test,spec}.{ts,tsx}"],
    css: true, // process CSS for visual tests
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

### vitest.setup.ts

```tsx
import "@testing-library/jest-dom/vitest";

// Extend Vitest matchers with jest-dom
// This adds: toBeInTheDocument, toHaveTextContent, toBeVisible, etc.
```

### package.json scripts

```json
{
  "scripts": {
    "test": "vitest",
    "test:run": "vitest run",
    "test:coverage": "vitest run --coverage",
    "test:watch": "vitest watch"
  }
}
```

## Component Testing

### Basic test

```tsx
import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { ProductCard } from "./ProductCard";

const mockProduct = {
  id: "1",
  name: "Wireless Headphones",
  price: 99.99,
  inStock: true,
};

describe("ProductCard", () => {
  it("displays product name and price", () => {
    render(<ProductCard product={mockProduct} />);
    expect(screen.getByText("Wireless Headphones")).toBeInTheDocument();
    expect(screen.getByText("$99.99")).toBeInTheDocument();
  });

  it("shows in-stock indicator when product is available", () => {
    render(<ProductCard product={mockProduct} />);
    expect(screen.getByText("In Stock")).toBeInTheDocument();
  });

  it("shows out-of-stock indicator when product is unavailable", () => {
    render(<ProductCard product={{ ...mockProduct, inStock: false }} />);
    expect(screen.getByText("Out of Stock")).toBeInTheDocument();
  });
});
```

### User interaction testing

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi } from "vitest";
import { CreateProductForm } from "./CreateProductForm";

describe("CreateProductForm", () => {
  it("shows validation errors when submitting empty form", async () => {
    const user = userEvent.setup();
    render(<CreateProductForm />);

    await user.click(screen.getByRole("button", { name: "Create" }));

    expect(screen.getByText("Name is required")).toBeInTheDocument();
    expect(screen.getByText("Price must be positive")).toBeInTheDocument();
  });

  it("calls onSubmit with valid data", async () => {
    const onSubmit = vi.fn();
    const user = userEvent.setup();
    render(<CreateProductForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText("Name"), "New Product");
    await user.type(screen.getByLabelText("Price"), "99");
    await user.click(screen.getByRole("button", { name: "Create" }));

    expect(onSubmit).toHaveBeenCalledWith({
      name: "New Product",
      price: 99,
    });
  });

  it("clears form after successful submission", async () => {
    const user = userEvent.setup();
    render(<CreateProductForm onSubmit={vi.fn()} />);

    await user.type(screen.getByLabelText("Name"), "Product");
    await user.type(screen.getByLabelText("Price"), "10");
    await user.click(screen.getByRole("button", { name: "Create" }));

    expect(screen.getByLabelText("Name")).toHaveValue("");
    expect(screen.getByLabelText("Price")).toHaveValue("");
  });
});
```

**Important**: Always use `userEvent.setup()` for realistic user interactions. It simulates real browser events (focus, click, type, keyboard) in the correct order. Do not use `fireEvent` (it fires synthetic events, not real ones).

## Custom Render Helpers

Wrap `render` with providers that components need (QueryClient, NuqsAdapter, theme).

```tsx
// test-utils.tsx
import { render, type RenderOptions } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { NuqsAdapter } from "nuqs/adapters/next";
import { type ReactNode } from "react";

function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,        // don't retry in tests
        gcTime: 0,          // don't cache in tests
        staleTime: 0,       // always refetch in tests
      },
      mutations: {
        retry: false,
      },
    },
  });
}

type CustomRenderOptions = RenderOptions & {
  queryClient?: QueryClient;
};

function customRender(ui: ReactNode, options: CustomRenderOptions = {}) {
  const queryClient = options.queryClient ?? createTestQueryClient();

  return render(ui, {
    wrapper: ({ children }) => (
      <QueryClientProvider client={queryClient}>
        <NuqsAdapter>{children}</NuqsAdapter>
      </QueryClientProvider>
    ),
    ...options,
  });
}

export { customRender as render, screen, waitFor, within };
export { userEvent } from "@testing-library/user-event";
```

**Usage**:

```tsx
import { render, screen, userEvent } from "@/test-utils";
// Uses custom render with all providers set up
```

## Accessibility Assertions (axe)

### Install axe-core

```bash
npm install -D axe-core @vitest/browser
```

### Accessibility test helper

```tsx
// test-utils.ts
import axe from "axe-core";

export async function checkAccessibility(container: HTMLElement) {
  const results = await axe.run(container, {
    rules: {
      // Skip color-contrast in jsdom (no real CSS)
      "color-contrast": { enabled: false },
    },
  });

  const violations = results.violations;
  if (violations.length > 0) {
    const formatted = violations.map((v) => {
      const nodes = v.nodes.map((n) => n.html).join("\n");
      return `${v.id}: ${v.description}\n  ${nodes}`;
    }).join("\n\n");
    throw new Error(`Accessibility violations:\n${formatted}`);
  }
}
```

### Usage

```tsx
describe("ProductCard accessibility", () => {
  it("has no axe violations", async () => {
    const { container } = render(<ProductCard product={mockProduct} />);
    await checkAccessibility(container);
  });
});

describe("LoginForm accessibility", () => {
  it("has no axe violations", async () => {
    const { container } = render(<LoginForm />);
    await checkAccessibility(container);
  });

  it("has proper form labels", () => {
    render(<LoginForm />);
    expect(screen.getByLabelText("Email")).toBeInTheDocument();
    expect(screen.getByLabelText("Password")).toBeInTheDocument();
  });
});
```

## Testing Async Components

### Testing loading states

```tsx
import { render, screen, waitFor } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";

describe("ProductList", () => {
  it("shows loading state then products", async () => {
    // Mock the query to resolve after a delay
    vi.spyOn(api, "fetchProducts").mockImplementation(
      () => new Promise((resolve) => setTimeout(() => resolve(mockProducts), 100))
    );

    render(<ProductList />);

    // Initially shows loading
    expect(screen.getByRole("status")).toBeInTheDocument(); // loading skeleton

    // After data loads, shows products
    await waitFor(() => {
      expect(screen.getByText("Wireless Headphones")).toBeInTheDocument();
    });
  });
});
```

### Testing error states

```tsx
it("shows error message when fetch fails", async () => {
  vi.spyOn(api, "fetchProducts").mockRejectedValue(new Error("Network error"));

  render(<ProductList />);

  await waitFor(() => {
    expect(screen.getByText("Network error")).toBeInTheDocument();
  });
});
```

### Testing with mock TanStack Query

```tsx
import { render, screen } from "@/test-utils";

it("shows products from query cache", async () => {
  const queryClient = createTestQueryClient();
  // Pre-populate cache
  queryClient.setQueryData(["products"], mockProducts);

  render(<ProductList />, { queryClient });

  expect(screen.getByText("Wireless Headphones")).toBeInTheDocument();
});
```

## Snapshot Guidelines

### When to use snapshots

- Visual layout components (cards, modals) where the HTML structure matters
- Email templates, generated HTML content
- Configuration objects with many fields

### When NOT to use snapshots

- Components with dynamic content (lists, dates)
- Anything that changes frequently (you'll just update the snapshot)
- When a specific assertion is clearer

```tsx
// Good: specific assertions (preferred)
it("renders product name", () => {
  render(<ProductCard product={mockProduct} />);
  expect(screen.getByText(mockProduct.name)).toBeInTheDocument();
});

// Acceptable: snapshot for complex layout components
it("renders expected layout", () => {
  const { container } = render(<ProductCard product={mockProduct} />);
  // Only snapshot the specific component, not the entire DOM
  expect(container.firstChild).toMatchSnapshot();
});

// Bad: snapshotting everything
it("works", () => {
  const { container } = render(<ProductCard product={mockProduct} />);
  expect(container).toMatchSnapshot(); // too broad, fragile
});
```

### Snapshot best practices

1. Use `toMatchSnapshot()` sparingly. Prefer specific assertions.
2. Snapshot small, specific pieces (not the entire DOM).
3. Name snapshots descriptively: `expect(card).toMatchSnapshot("product-card-layout")`.
4. Review snapshot diffs carefully before updating. Never blindly update.
5. Remove unused snapshots with `vitest --update` and manual cleanup.

## Mocking Patterns

### Mock modules

```tsx
// Mock a module
vi.mock("@/lib/api", () => ({
  fetchProducts: vi.fn().mockResolvedValue(mockProducts),
}));

// Mock with factory
vi.mock("@/lib/schemas", async (importOriginal) => {
  const actual = await importOriginal();
  return {
    ...actual,
    ProductSchema: actual.ProductSchema.extend({ id: z.string().default("test-id") }),
  };
});
```

### Mock Server Actions

```tsx
vi.mock("@/actions/create-product", () => ({
  createProduct: vi.fn().mockResolvedValue({ ok: true, data: mockProduct }),
}));
```

### Mock next/navigation

```tsx
vi.mock("next/navigation", () => ({
  redirect: vi.fn(),
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    refresh: vi.fn(),
    prefetch: vi.fn(),
    back: vi.fn(),
  }),
  usePathname: () => "/products",
  useSearchParams: () => new URLSearchParams(),
}));
```

### Mock next/cache

```tsx
vi.mock("next/cache", () => ({
  revalidateTag: vi.fn(),
  revalidatePath: vi.fn(),
}));
```
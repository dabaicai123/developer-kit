# Server Action Testing

Direct invocation, mock databases, validation testing, redirect testing, and revalidation testing.

## Direct Invocation

Server Actions are just async functions. Test them directly without browser rendering.

```tsx
import { describe, it, expect, vi, beforeEach } from "vitest";
import { createProduct } from "@/actions/create-product";
import { CreateProductSchema } from "@/lib/schemas";

// Mock the database
vi.mock("@/lib/db", () => ({
  db: {
    product: {
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
      findMany: vi.fn(),
      findUnique: vi.fn(),
    },
  },
}));

// Mock Next.js server utilities
vi.mock("next/cache", () => ({
  revalidateTag: vi.fn(),
  revalidatePath: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  redirect: vi.fn(),
}));

import { db } from "@/lib/db";
import { revalidateTag } from "next/cache";
import { redirect } from "next/navigation";

describe("createProduct", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("creates a product with valid input", async () => {
    const input = {
      name: "Wireless Headphones",
      price: 99.99,
      description: "High-quality wireless headphones",
      category: "electronics",
      inStock: true,
    };

    const mockProduct = { id: "prod-1", ...input, createdAt: new Date().toISOString() };
    vi.mocked(db.product.create).mockResolvedValue(mockProduct);

    const result = await createProduct(input);

    expect(result).toEqual({ ok: true, data: mockProduct });
    expect(db.product.create).toHaveBeenCalledWith({ data: input });
    expect(revalidateTag).toHaveBeenCalledWith("products");
  });

  it("rejects invalid input with validation errors", async () => {
    const invalidInput = {
      name: "",           // empty name
      price: -10,         // negative price
    };

    const result = await createProduct(invalidInput);

    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.fieldErrors).toBeDefined();
      expect(result.error.fieldErrors?.name).toContain("Product name is required");
      expect(result.error.fieldErrors?.price).toContain("Price must be positive");
    }
    expect(db.product.create).not.toHaveBeenCalled();
  });
});
```

## Validation Testing

Test Zod schemas separately for thorough edge case coverage.

```tsx
import { describe, it, expect } from "vitest";
import { CreateProductSchema, UpdateProductSchema } from "@/lib/schemas";

describe("CreateProductSchema", () => {
  it("validates a valid product input", () => {
    const input = {
      name: "Widget",
      price: 10,
      category: "general",
    };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(true);
  });

  it("rejects empty name", () => {
    const input = { name: "", price: 10, category: "general" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(false);
    if (!result.success) {
      const nameError = result.error.issues.find((i) => i.path.includes("name"));
      expect(nameError?.message).toBe("Product name is required");
    }
  });

  it("rejects negative price", () => {
    const input = { name: "Widget", price: -5, category: "general" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(false);
  });

  it("rejects zero price", () => {
    const input = { name: "Widget", price: 0, category: "general" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(false);
  });

  it("coerces string price to number", () => {
    const input = { name: "Widget", price: "10.99", category: "general" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.price).toBe(10.99); // coerced from string
    }
  });

  it("rejects non-numeric price string", () => {
    const input = { name: "Widget", price: "abc", category: "general" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(false);
  });

  it("allows optional description", () => {
    const input = { name: "Widget", price: 10, category: "general" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.description).toBeUndefined();
    }
  });

  it("rejects description exceeding max length", () => {
    const input = {
      name: "Widget",
      price: 10,
      category: "general",
      description: "a".repeat(501),
    };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(false);
  });

  it("rejects empty category", () => {
    const input = { name: "Widget", price: 10, category: "" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(false);
  });

  // Edge case: extra fields are stripped
  it("strips unknown fields", () => {
    const input = { name: "Widget", price: 10, category: "general", hack: "evil" };
    const result = CreateProductSchema.safeParse(input);
    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data).not.toHaveProperty("hack");
    }
  });
});
```

## Redirect Testing

Next.js `redirect()` throws a special error. Test that it's called correctly.

```tsx
import { describe, it, expect, vi } from "vitest";
import { deleteProduct } from "@/actions/delete-product";

vi.mock("next/cache", () => ({
  revalidatePath: vi.fn(),
  revalidateTag: vi.fn(),
}));

// redirect throws a NEXT_REDIRECT error, catch it in tests
vi.mock("next/navigation", () => ({
  redirect: vi.fn().mockImplementation((url: string) => {
    // Simulate Next.js redirect behavior (throws a special error)
    throw new Error(`NEXT_REDIRECT: ${url}`);
  }),
}));

import { redirect } from "next/navigation";

describe("deleteProduct", () => {
  it("redirects to products list after deletion", async () => {
    vi.mocked(db.product.delete).mockResolvedValue(mockProduct);

    try {
      await deleteProduct("prod-1");
    } catch (e) {
      // redirect throws, which is expected
    }

    expect(redirect).toHaveBeenCalledWith("/products");
    expect(revalidateTag).toHaveBeenCalledWith("products");
  });
});
```

**Alternative**: Use a test-friendly Server Action wrapper that returns the redirect URL instead of calling `redirect()`:

```tsx
// actions/delete-product.ts
export async function deleteProduct(id: string): Promise<Result<Product, string>> {
  await db.product.delete({ where: { id } });
  revalidateTag("products");
  // In tests, we return the result instead of redirecting
  // In production, the caller handles redirect
  return ok({ id, redirectTo: "/products" });
}
```

## Database Mock Patterns

### Mock Prisma

```tsx
vi.mock("@/lib/db", () => {
  return {
    db: {
      product: {
        create: vi.fn(),
        findMany: vi.fn(),
        findUnique: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      user: {
        create: vi.fn(),
        findUnique: vi.fn(),
      },
    },
  };
});

import { db } from "@/lib/db";

// Set up mock responses
beforeEach(() => {
  vi.mocked(db.product.create).mockResolvedValue(mockProduct);
  vi.mocked(db.product.findMany).mockResolvedValue([mockProduct]);
  vi.mocked(db.product.findUnique).mockResolvedValue(mockProduct);
});
```

### Mock Drizzle

```tsx
vi.mock("@/lib/db", () => ({
  db: vi.fn(),
  products: { id: "id", name: "name", price: "price" },
}));

// For Drizzle, mock the query builder chain
const mockDb = {
  select: vi.fn().mockReturnThis(),
  from: vi.fn().mockReturnThis(),
  where: vi.fn().mockReturnThis(),
  execute: vi.fn().mockResolvedValue([mockProduct]),
};
vi.mocked(db).mockReturnValue(mockDb as any);
```

### In-memory database (for integration tests)

For more realistic testing, use an in-memory SQLite database with the same schema:

```tsx
import { describe, it, expect, beforeAll, afterAll, beforeEach } from "vitest";
import { betterSqlite3 } from "drizzle-orm/better-sqlite3";
import { drizzle } from "drizzle-orm/better-sqlite3";
import * as schema from "@/db/schema";

let testDb: ReturnType<typeof drizzle>;

beforeAll(() => {
  const sqlite = betterSqlite3(":memory:");
  testDb = drizzle(sqlite, { schema });
  // Run migrations
  sqlite.exec(migrationSQL);
});

afterAll(() => {
  sqlite.close();
});

beforeEach(() => {
  // Clear all tables between tests
  testDb.delete(schema.products).execute();
});
```

## Revalidation Testing

```tsx
import { revalidateTag, revalidatePath } from "next/cache";

describe("updateProduct", () => {
  it("revalidates products tag after update", async () => {
    vi.mocked(db.product.update).mockResolvedValue(updatedProduct);

    const result = await updateProduct("prod-1", { name: "Updated Widget" });

    expect(revalidateTag).toHaveBeenCalledWith("products");
    expect(revalidatePath).toHaveBeenCalledWith("/products/prod-1");
  });

  it("revalidates correct tags for different mutations", async () => {
    // Each mutation should revalidate only the relevant tags
    await deleteProduct("prod-1");
    expect(revalidateTag).toHaveBeenCalledWith("products");
    expect(revalidatePath).toHaveBeenCalledWith("/products");

    vi.clearAllMocks();

    await updateUserProfile("user-1", { name: "New Name" });
    expect(revalidateTag).toHaveBeenCalledWith("user");
    expect(revalidatePath).toHaveBeenCalledWith("/profile");
  });
});
```

## Testing FormData Input

Server Actions that accept `FormData` need special handling in tests.

```tsx
describe("createProduct with FormData", () => {
  it("parses FormData correctly", async () => {
    const formData = new FormData();
    formData.set("name", "Widget");
    formData.set("price", "99.99");
    formData.set("description", "A fine widget");
    formData.set("category", "general");

    vi.mocked(db.product.create).mockResolvedValue({
      id: "prod-1",
      name: "Widget",
      price: 99.99,
      description: "A fine widget",
      category: "general",
      inStock: true,
      createdAt: new Date().toISOString(),
    });

    const result = await createProduct(formData);

    expect(result.ok).toBe(true);
    expect(db.product.create).toHaveBeenCalledWith({
      data: {
        name: "Widget",
        price: 99.99, // coerced from string
        description: "A fine widget",
        category: "general",
      },
    });
  });

  it("rejects invalid FormData", async () => {
    const formData = new FormData();
    formData.set("name", ""); // empty
    formData.set("price", "abc"); // not a number

    const result = await createProduct(formData);

    expect(result.ok).toBe(false);
    expect(db.product.create).not.toHaveBeenCalled();
  });
});
```

## Common Patterns

### Testing error handling

```tsx
it("handles database errors gracefully", async () => {
  vi.mocked(db.product.create).mockRejectedValue(new Error("Connection refused"));

  const result = await createProduct(validInput);

  expect(result.ok).toBe(false);
  if (!result.ok) {
    expect(result.error.message).toBe("Failed to create product");
  }
  // Should still revalidate even on error? Depends on your design.
  // Usually NOT: expect(revalidateTag).not.toHaveBeenCalled();
});
```

### Testing unique constraint errors

```tsx
it("handles duplicate product name", async () => {
  vi.mocked(db.product.create).mockRejectedValue(
    new PrismaError("Unique constraint failed", { code: "P2002" })
  );

  const result = await createProduct({ name: "Existing Product", ... });

  expect(result.ok).toBe(false);
  if (!result.ok) {
    expect(result.error.fieldErrors?.name).toContain("Product name already exists");
  }
});
```
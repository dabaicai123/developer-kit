# Typed API Patterns

Zod response validation, Result<T,E> type definition, typed fetch wrapper, and discriminated union responses.

## Zod Response Validation

### Define schemas for every API response

```tsx
import { z } from "zod";

// Single resource
export const ProductSchema = z.object({
  id: z.string(),
  name: z.string().min(1),
  price: z.number().positive(),
  description: z.string().optional(),
  inStock: z.boolean(),
  createdAt: z.string().datetime(),
});

// List response with pagination metadata
export const ProductListSchema = z.object({
  items: ProductSchema.array(),
  total: z.number(),
  page: z.number(),
  pageSize: z.number(),
});

// Create input (different from response)
export const CreateProductSchema = z.object({
  name: z.string().min(1),
  price: z.number().positive(),
  description: z.string().optional(),
});

// Update input (partial)
export const UpdateProductSchema = z.object({
  name: z.string().min(1).optional(),
  price: z.number().positive().optional(),
  description: z.string().optional(),
});

// Derive TypeScript types from schemas
export type Product = z.infer<typeof ProductSchema>;
export type ProductList = z.infer<typeof ProductListSchema>;
export type CreateProductInput = z.infer<typeof CreateProductSchema>;
export type UpdateProductInput = z.infer<typeof UpdateProductSchema>;
```

### Validate at the boundary

Always validate at the point where data enters your application (the fetch call). Never trust data that crosses a boundary.

```tsx
// Server Component
export default async function ProductsPage() {
  const res = await fetch("/api/products");
  if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);

  // Validate RIGHT AFTER parsing JSON, before any component uses it
  const data = ProductListSchema.parse(await res.json());
  return <ProductGrid products={data.items} />;
}

// Client Component (TanStack Query)
function useProducts(filters: ProductFilters) {
  return useQuery({
    queryKey: ["products", filters],
    queryFn: async () => {
      const res = await fetch(`/api/products?${toSearchParams(filters)}`);
      if (!res.ok) throw new Error(`Fetch failed: ${res.status}`);
      return ProductListSchema.parse(await res.json());
    },
  });
}
```

### safeParse for non-throwing validation

```tsx
// When you want to handle validation errors without throwing
const result = ProductSchema.safeParse(await res.json());

if (result.success) {
  // result.data is typed as Product
  return result.data;
} else {
  // result.error is a ZodError with detailed path info
  console.error("Validation failed:", result.error.flatten());
  throw new Error(`Invalid product data: ${result.error.message}`);
}
```

## Result<T,E> Type

A discriminated union for type-safe success/error handling without throwing.

### Definition

```tsx
// lib/result.ts
export type Result<T, E = string> =
  | { ok: true; data: T }
  | { ok: false; error: E };

export function ok<T>(data: T): Result<T> {
  return { ok: true, data };
}

export function err<E>(error: E): Result<never, E> {
  return { ok: false, error };
}
```

### Usage in Server Actions

```tsx
"use server";
import { Result, ok, err } from "@/lib/result";
import { ProductCreateSchema } from "@/lib/schemas";

export async function createProduct(
  input: unknown
): Promise<Result<Product, string>> {
  // Validate input
  const parsed = ProductCreateSchema.safeParse(input);
  if (!parsed.success) {
    return err(parsed.error.message);
  }

  try {
    const product = await db.product.create({ data: parsed.data });
    revalidateTag("products");
    return ok(product);
  } catch (e) {
    return err("Failed to create product");
  }
}
```

### Usage in Client Components

```tsx
function CreateProductForm() {
  const [result, setResult] = useState<Result<Product, string> | null>(null);

  const handleSubmit = async (formData: FormData) => {
    const res = await createProduct({
      name: formData.get("name"),
      price: Number(formData.get("price")),
    });
    setResult(res);
  };

  return (
    <form action={handleSubmit} className="flex flex-col gap-4">
      <input name="name" required />
      <input name="price" type="number" required />
      {result && (
        result.ok
          ? <p className="text-green-600">Created: {result.data.name}</p>
          : <p className="text-red-600">{result.error}</p>
      )}
      <button type="submit">Create</button>
    </form>
  );
}
```

### TypeScript narrowing

The `ok` field is the discriminant. TypeScript narrows automatically:

```tsx
function handleResult(result: Result<Product, string>) {
  if (result.ok) {
    // TypeScript knows result.data is Product
    console.log(result.data.name);
  } else {
    // TypeScript knows result.error is string
    console.log(result.error);
  }
}
```

## Typed Fetch Wrapper

A wrapper that validates responses and returns Result types automatically.

```tsx
// lib/api.ts
import { ZodSchema } from "zod";
import { Result, ok, err } from "@/lib/result";

type FetchOptions = {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  body?: unknown;
  headers?: Record<string, string>;
  cache?: RequestCache;
  next?: { revalidate?: number; tags?: string[] };
};

export async function typedFetch<T>(
  url: string,
  schema: ZodSchema<T>,
  options: FetchOptions = {}
): Promise<Result<T, string>> {
  try {
    const res = await fetch(url, {
      method: options.method ?? "GET",
      headers: {
        "Content-Type": "application/json",
        ...options.headers,
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
      cache: options.cache,
      next: options.next,
    });

    if (!res.ok) {
      return err(`HTTP ${res.status}: ${res.statusText}`);
    }

    const json = await res.json();
    const parsed = schema.safeParse(json);

    if (!parsed.success) {
      return err(`Validation error: ${parsed.error.message}`);
    }

    return ok(parsed.data);
  } catch (e) {
    return err(e instanceof Error ? e.message : "Unknown error");
  }
}
```

### Usage in Server Components

```tsx
// app/products/page.tsx
export default async function ProductsPage() {
  const result = await typedFetch("/api/products", ProductListSchema);

  if (!result.ok) {
    throw new Error(result.error); // throws to error.tsx boundary
  }

  return <ProductGrid products={result.data.items} />;
}
```

### Usage in TanStack Query

```tsx
function useProducts(filters: ProductFilters) {
  return useQuery({
    queryKey: ["products", filters],
    queryFn: async () => {
      const result = await typedFetch(
        `/api/products?${toSearchParams(filters)}`,
        ProductListSchema
      );
      if (!result.ok) throw new Error(result.error);
      return result.data;
    },
  });
}
```

## Discriminated Union Responses

Some APIs return different shapes based on status. Handle them with Zod discriminated unions.

```tsx
// API returns different shapes for success vs error
const ApiResponseSchema = z.discriminatedUnion("status", [
  z.object({
    status: z.literal("success"),
    data: ProductSchema,
  }),
  z.object({
    status: z.literal("error"),
    message: z.string(),
    code: z.number(),
  }),
]);

// Using it
function useProduct(id: string) {
  return useQuery({
    queryKey: ["product", id],
    queryFn: async () => {
      const res = await fetch(`/api/products/${id}`);
      const json = await res.json();
      const result = ApiResponseSchema.parse(json);

      if (result.status === "success") {
        return result.data;
      }
      throw new Error(result.message);
    },
  });
}
```

### Multiple response variants

```tsx
// API that returns different data for different query types
const SearchResponseSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("products"),
    results: ProductSchema.array(),
    total: z.number(),
  }),
  z.object({
    type: z.literal("categories"),
    results: CategorySchema.array(),
    total: z.number(),
  }),
  z.object({
    type: z.literal("empty"),
    results: z.array(z.never()),
    total: z.literal(0),
  }),
]);
```

## Error Response Schema

Define a schema for error responses too, not just success:

```tsx
const ErrorResponseSchema = z.object({
  error: z.string(),
  code: z.string(),
  details: z.array(z.object({
    field: z.string(),
    message: z.string(),
  })).optional(),
});

// Wrapper that validates both success and error responses
async function validatedFetch<T>(
  url: string,
  successSchema: ZodSchema<T>,
  options?: FetchOptions
): Promise<Result<T, AppError>> {
  const res = await fetch(url, options);

  if (!res.ok) {
    const json = await res.json();
    const parsed = ErrorResponseSchema.safeParse(json);
    if (parsed.success) {
      return err(parsed.data);
    }
    return err({ error: `HTTP ${res.status}`, code: "HTTP_ERROR" });
  }

  const json = await res.json();
  const parsed = successSchema.safeParse(json);
  if (!parsed.success) {
    return err({ error: parsed.error.message, code: "VALIDATION_ERROR" });
  }
  return ok(parsed.data);
}
```

## Best Practices

1. **Validate at every boundary**: Server fetch, client fetch, form input, Server Action input
2. **Use z.infer for types**: Never manually define types that duplicate the schema
3. **Separate input/output schemas**: `CreateProductSchema` (input) vs `ProductSchema` (output)
4. **Result<T,E> for Server Actions**: Avoid throwing in Server Actions; return Result so the client can handle both cases explicitly
5. **Always handle both Result branches**: Never ignore the `ok: false` case
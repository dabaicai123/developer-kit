# Server-Side Fetching

RSC fetch, React.cache() deduplication, Suspense streaming, generateStaticParams, ISR revalidate, and Server Actions for mutations.

## RSC fetch

Server Components can fetch data directly without client JS. No loading state needed in the component itself; Suspense handles it.

```tsx
// app/products/page.tsx (Server Component)
import { ProductSchema } from "@/lib/schemas";

export default async function ProductsPage() {
  const res = await fetch("https://api.example.com/products", {
    next: { revalidate: 300 }, // ISR: revalidate every 5 minutes
  });

  if (!res.ok) {
    throw new Error(`Failed to fetch products: ${res.status}`);
  }

  const data = ProductSchema.array().parse(await res.json());

  return (
    <div className="grid grid-cols-3 gap-6">
      {data.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}
```

### fetch options for caching

```tsx
// Default: cache indefinitely (static)
fetch("https://api.example.com/data");

// ISR: revalidate at interval
fetch("https://api.example.com/data", { next: { revalidate: 300 } });

// No cache: always fresh (dynamic)
fetch("https://api.example.com/data", { cache: "no-store" });

// On-demand revalidation: revalidate by tag
fetch("https://api.example.com/data", { next: { tags: ["products"] } });
// Then in a Server Action: revalidateTag("products");
```

## React.cache() Deduplication

`React.cache()` deduplicates identical fetch calls within a single render pass. Multiple components requesting the same data make only one network request.

```tsx
// lib/data.ts
import { cache } from "react";
import { ProductSchema } from "@/lib/schemas";

export const getProduct = cache(async (id: string) => {
  const res = await fetch(`https://api.example.com/products/${id}`);
  if (!res.ok) throw new Error(`Product not found: ${id}`);
  return ProductSchema.parse(await res.json());
});

// Even if ProductHeader and ProductDetails both call getProduct("123"),
// only one fetch request is made per render pass.
export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return (
    <>
      <ProductHeader id={id} />   // calls getProduct(id)
      <ProductDetails id={id} />  // calls getProduct(id) - deduplicated
    </>
  );
}
```

**Important**: `cache()` deduplicates per render pass only. If you need cross-request caching, use `fetch()` with `next.revalidate` or TanStack Query.

## Suspense Streaming

Wrap async Server Components in Suspense for progressive rendering. The rest of the page renders immediately; the slow component streams in when ready.

```tsx
// app/page.tsx
import { Suspense } from "react";

export default function Dashboard() {
  return (
    <div className="grid grid-cols-2 gap-6">
      {/* Fast component renders immediately */}
      <QuickStats />

      {/* Slow component streams in via Suspense */}
      <Suspense fallback={<ProductSkeleton />}>
        <ProductList />
      </Suspense>

      {/* Another independent stream */}
      <Suspense fallback={<ActivitySkeleton />}>
        <RecentActivity />
      </Suspense>
    </div>
  );
}
```

**Benefits**:
- TTFB is fast (shell renders immediately)
- Slow data does not block the entire page
- Each Suspense boundary streams independently
- Works with Next.js streaming SSR

### Suspense boundary placement

```tsx
// Good: fine-grained boundaries, individual sections stream independently
<div>
  <Suspense fallback={<Skeleton />}><Header /></Suspense>
  <Suspense fallback={<Skeleton />}><Content /></Suspense>
  <Suspense fallback={<Skeleton />}><Footer /></Suspense>
</div>

// Bad: single boundary, entire page waits for the slowest component
<Suspense fallback={<PageSkeleton />}>
  <Header />
  <Content />  // slow
  <Footer />
</Suspense>
```

## generateStaticParams

Pre-render pages at build time for dynamic routes where all possible params are known.

```tsx
// app/products/[id]/page.tsx
export async function generateStaticParams() {
  const res = await fetch("https://api.example.com/products");
  const products = ProductSchema.array().parse(await res.json());

  return products.map((product) => ({
    id: product.id,
  }));
}

export default async function ProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const product = await getProduct(id);
  return <ProductDetail product={product} />;
}
```

**Combine with ISR**: Use `generateStaticParams` for the known pages and `dynamicParams = true` with `revalidate` for pages that might be added later.

```tsx
export const dynamicParams = true; // allow new pages not in generateStaticParams
export const revalidate = 300;     // ISR for pages not pre-rendered
```

## ISR Revalidate

Incremental Static Regeneration: serve cached pages, revalidate in the background.

### Time-based revalidation

```tsx
// Every 5 minutes, serve the cached version, then regenerate in background
export const revalidate = 300;

export default async function Page() {
  const data = await fetch("https://api.example.com/data", {
    next: { revalidate: 300 },
  });
}
```

### On-demand revalidation

```tsx
// Server Action triggers revalidation
"use server";
import { revalidateTag, revalidatePath } from "next/cache";

export async function updateProduct(formData: FormData) {
  // ... update product in database
  revalidateTag("products");       // revalidate all fetches with this tag
  revalidatePath("/products");     // revalidate the entire path
  revalidatePath(`/products/${id}`, "page"); // revalidate specific page
}
```

## Server Actions for Mutations

Server Actions handle form submissions and mutations on the server. They work with progressive enhancement (work without JS).

### Basic Server Action

```tsx
"use server";
import { revalidatePath } from "next/cache";
import { ProductCreateSchema } from "@/lib/schemas";
import { redirect } from "next/navigation";

export async function createProduct(formData: FormData) {
  // Validate input
  const input = ProductCreateSchema.parse({
    name: formData.get("name"),
    price: Number(formData.get("price")),
    description: formData.get("description"),
  });

  // Mutate data
  const product = await db.product.create({ data: input });

  // Revalidate cache
  revalidatePath("/products");

  // Redirect
  redirect(`/products/${product.id}`);
}
```

### Server Action with Result type

```tsx
"use server";
import { Result } from "@/lib/result";

export async function updateProduct(id: string, data: UpdateProductInput): Promise<Result<Product, string>> {
  const parsed = UpdateProductSchema.safeParse(data);
  if (!parsed.success) {
    return { ok: false, error: parsed.error.message };
  }

  try {
    const product = await db.product.update({ where: { id }, data: parsed.data });
    revalidateTag("products");
    return { ok: true, data: product };
  } catch (e) {
    return { ok: false, error: "Failed to update product" };
  }
}
```

### Server Action with form action prop

```tsx
// Progressive enhancement: works without JS
function CreateProductForm() {
  return (
    <form action={createProduct} className="flex flex-col gap-4">
      <input name="name" required className="border border-gray-200 rounded-md px-3 py-2" />
      <input name="price" type="number" required className="border border-gray-200 rounded-md px-3 py-2" />
      <textarea name="description" className="border border-gray-200 rounded-md px-3 py-2" />
      <button type="submit" className="bg-blue-500 text-white px-4 py-2 rounded-md">
        Create Product
      </button>
    </form>
  );
}
```

### useActionState for Server Action feedback

```tsx
"use client";
import { useActionState } from "react";

function UpdateProductForm({ productId }: { productId: string }) {
  const [state, formAction, isPending] = useActionState(
    async (prev: FormState, formData: FormData) => {
      const result = await updateProductAction(productId, formData);
      if (result.ok) return { success: true, message: "Product updated" };
      return { success: false, message: result.error };
    },
    { success: false, message: "" }
  );

  return (
    <form action={formAction} className="flex flex-col gap-4">
      <input name="name" required className="border border-gray-200 rounded-md px-3 py-2" />
      {state.message && (
        <div className={state.success ? "text-green-600" : "text-red-600"}>
          {state.message}
        </div>
      )}
      <button type="submit" disabled={isPending} className="bg-blue-500 text-white px-4 py-2 rounded-md">
        {isPending ? "Updating..." : "Update"}
      </button>
    </form>
  );
}
```

## Common Patterns

### Parallel fetching in RSC

```tsx
export default async function DashboardPage() {
  // Fetches run in parallel (no await between them)
  const productsPromise = getProductList();
  const statsPromise = getDashboardStats();
  const activityPromise = getRecentActivity();

  // Await all at once
  const [products, stats, activity] = await Promise.all([
    productsPromise,
    statsPromise,
    activityPromise,
  ]);

  return (
    <Dashboard products={products} stats={stats} activity={activity} />
  );
}
```

### Waterfall avoidance

```tsx
// BAD: sequential waterfall
export default async function Page() {
  const user = await getUser();       // wait...
  const orders = await getOrders(user.id); // wait again...
  const details = await getOrderDetails(orders[0].id); // wait again...
}

// GOOD: parallel if data is independent
export default async function Page() {
  const [user, products] = await Promise.all([
    getUser(),
    getProducts(), // independent, fetch together
  ]);
  const orders = await getOrders(user.id); // dependent on user, can't parallelize
}
```

### Error handling in RSC

```tsx
// app/products/page.tsx
export default async function ProductsPage() {
  try {
    const products = await getProductList();
    return <ProductGrid products={products} />;
  } catch (error) {
    // This throws to the nearest error.tsx boundary
    throw error;
  }
}

// app/products/error.tsx
"use client";
export default function ProductsError({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div className="flex flex-col items-center gap-4 py-12">
      <h2 className="text-xl font-semibold text-red-600">Something went wrong</h2>
      <p className="text-gray-500">{error.message}</p>
      <button onClick={reset} className="bg-blue-500 text-white px-4 py-2 rounded-md">
        Try again
      </button>
    </div>
  );
}
```
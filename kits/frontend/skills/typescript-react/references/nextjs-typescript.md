# Next.js TypeScript

Type patterns for Next.js App Router specifics: async params, Server Actions, route handlers, middleware, Edge runtime, and useOptimistic.

## Async Params (Next.js 15+)

In Next.js 15+, `params` and `searchParams` are Promise objects. Type and await them accordingly.

```tsx
// Page with async params
interface PageProps {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ page?: string; sort?: string }>;
}

export default async function ProductPage({ params, searchParams }: PageProps) {
  const { slug } = await params;
  const { page = '1', sort = 'date' } = await searchParams;

  const product = await getProduct(slug);
  const reviews = await getReviews(slug, { page: Number(page), sort });

  return (
    <div>
      <ProductDetail product={product} />
      <ReviewList reviews={reviews} currentPage={Number(page)} />
    </div>
  );
}
```

### generateMetadata typing

```tsx
import { type Metadata } from 'next';

interface PageProps {
  params: Promise<{ slug: string }>;
}

export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const product = await getProduct(slug);

  return {
    title: product.name,
    description: product.description,
    openGraph: {
      title: product.name,
      description: product.description,
      images: [{ url: product.imageUrl }],
    },
  };
}
```

### Dynamic route with multiple segments

```tsx
// app/shop/[category]/[productId]/page.tsx
interface ProductPageProps {
  params: Promise<{ category: string; productId: string }>;
}

export default async function ProductPage({ params }: ProductPageProps) {
  const { category, productId } = await params;

  const product = await getProduct(category, productId);
  return <ProductDetail product={product} />;
}

// generateStaticParams — returns all possible param combinations
export async function generateStaticParams() {
  const products = await getAllProducts();
  return products.map(p => ({
    category: p.categorySlug,
    productId: p.id,
  }));
}
```

### Catch-all routes

```tsx
// app/docs/[...slug]/page.tsx
interface DocsPageProps {
  params: Promise<{ slug: string[] }>; // array of segments
}

export default async function DocsPage({ params }: DocsPageProps) {
  const { slug } = await params;
  // slug = ['getting-started', 'installation'] for /docs/getting-started/installation
  const doc = await getDoc(slug.join('/'));
  return <DocContent doc={doc} />;
}
```

## Server Actions Typing

Server Actions are async server functions called from client components. Type them with explicit input/output types.

### FormData-based Server Action

```tsx
// actions/create-product.ts
'use server';

import { revalidateTag } from 'next/cache';
import { z } from 'zod';

const CreateProductSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  price: z.coerce.number().positive('Price must be positive'),
  category: z.string().min(1, 'Category is required'),
  description: z.string().optional(),
});

type CreateProductInput = z.infer<typeof CreateProductSchema>;

type CreateProductResult =
  | { success: true; productId: string }
  | { success: false; errors: Record<string, string[]> };

export async function createProduct(formData: FormData): Promise<CreateProductResult> {
  const raw = {
    name: formData.get('name'),
    price: formData.get('price'),
    category: formData.get('category'),
    description: formData.get('description'),
  };

  const parsed = CreateProductSchema.safeParse(raw);
  if (!parsed.success) {
    return { success: false, errors: parsed.error.flatten().fieldErrors };
  }

  const product = await db.insertProduct(parsed.data);
  revalidateTag('products');

  return { success: true, productId: product.id };
}
```

### Typed-args Server Action (preferred for complex inputs)

```tsx
// actions/update-product.ts
'use server';

import { revalidatePath } from 'next/cache';

interface UpdateProductInput {
  id: string;
  name: string;
  price: number;
}

type UpdateProductResult =
  | { success: true }
  | { success: false; error: string };

export async function updateProduct(input: UpdateProductInput): Promise<UpdateProductResult> {
  try {
    await db.updateProduct(input.id, { name: input.name, price: input.price });
    revalidatePath(`/products/${input.id}`);
    return { success: true };
  } catch (err) {
    return { success: false, error: err instanceof Error ? err.message : 'Unknown error' };
  }
}
```

### Client-side usage with type-safe result

```tsx
'use client';

import { type CreateProductResult } from '@/actions/create-product';

function ProductForm() {
  const [result, setResult] = useState<CreateProductResult | null>(null);

  async function handleSubmit(formData: FormData) {
    const res = await createProduct(formData);
    setResult(res);
    if (res.success) {
      router.push(`/products/${res.productId}`);
    }
  }

  return (
    <form action={handleSubmit}>
      <input name="name" required />
      <input name="price" type="number" required />
      <select name="category" required>
        <option value="electronics">Electronics</option>
        <option value="clothing">Clothing</option>
      </select>
      <button type="submit">Create Product</button>
      {result && !result.success && (
        <div className="text-red-600 text-sm mt-2">
          {Object.entries(result.errors).map(([field, msgs]) => (
            <p key={field}>{field}: {msgs.join(', ')}</p>
          ))}
        </div>
      )}
    </form>
  );
}
```

## Route Handlers Typing

Route Handlers are API endpoints in the `app/api/` directory.

### GET handler

```tsx
// app/api/products/route.ts
import { type NextRequest, type NextResponse } from 'next/server';

export async function GET(request: NextRequest): Promise<NextResponse> {
  const searchParams = request.nextUrl.searchParams;
  const category = searchParams.get('category');
  const page = Number(searchParams.get('page') ?? '1');

  const products = await getProducts({ category, page });

  return NextResponse.json({ products, total: products.length, page });
}

// GET single product
// app/api/products/[id]/route.ts
interface RouteContext {
  params: Promise<{ id: string }>;
}

export async function GET(request: NextRequest, context: RouteContext): Promise<NextResponse> {
  const { id } = await context.params;
  const product = await getProduct(id);

  if (!product) {
    return NextResponse.json({ error: 'Product not found' }, { status: 404 });
  }

  return NextResponse.json(product);
}
```

### POST handler with typed body

```tsx
// app/api/orders/route.ts
import { type NextRequest } from 'next/server';
import { z } from 'zod';

const CreateOrderSchema = z.object({
  productId: z.string(),
  quantity: z.number().int().positive(),
  shippingAddress: z.string().min(1),
});

export async function POST(request: NextRequest): Promise<NextResponse> {
  const body = await request.json();
  const parsed = CreateOrderSchema.safeParse(body);

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Invalid input', details: parsed.error.flatten() },
      { status: 400 }
    );
  }

  const order = await db.createOrder(parsed.data);
  return NextResponse.json(order, { status: 201 });
}
```

## Edge Runtime Constraints

Route Handlers and Middleware can run on the Edge runtime, which has limitations.

```tsx
// Edge runtime route handler
// app/api/health/route.ts
export const runtime = 'edge';

export async function GET(): Promise<NextResponse> {
  // Edge runtime — NO Node.js APIs available:
  // - No fs, path, crypto (use Web Crypto API instead)
  // - No Buffer (use Uint8Array or TextEncoder/TextDecoder)
  // - No process.env (use NextRequest.env or environment variables configured in next.config)
  // - No setTimeout with long delays
  // - No native modules (sqlite, bcrypt, etc.)

  return NextResponse.json({ status: 'ok', timestamp: Date.now() });
}
```

**What works on Edge**:
- `fetch`, `Request`, `Response`, `URL`, `URLSearchParams`
- Web Crypto API (`crypto.subtle`)
- `TextEncoder`, `TextDecoder`
- `ReadableStream`, `WritableStream`
- `console`, `setTimeout`, `setInterval` (short delays)
- Environment variables configured in `next.config.js`

**What does NOT work on Edge**:
- `fs`, `path`, `os`, `child_process` — any Node.js fs/module system
- `Buffer` — use `Uint8Array` or `TextEncoder`
- `crypto.createHash` — use `crypto.subtle.digest`
- `process.env` — use NextRequest context env
- Prisma (use Drizzle or @prisma/adapter-vercel)
- Large npm packages with Node.js dependencies

### Middleware typing

```tsx
// middleware.ts
import { type NextRequest, type NextResponse } from 'next/server';

export function middleware(request: NextRequest): NextResponse {
  const token = request.cookies.get('auth-token')?.value;

  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*', '/settings/:path*'],
};
```

Middleware runs on the Edge runtime by default. If the project targets a Next.js version that supports Node.js middleware runtime, set `runtime: 'nodejs'` before using Node.js APIs.

## useOptimistic Typing

`useOptimistic` provides optimistic state updates for Server Actions.

```tsx
'use client';

import { useOptimistic } from 'react';

interface Message {
  id: string;
  text: string;
  sending: boolean; // optimistic flag
}

interface OptimisticUpdate {
  id: string; // temporary client-generated ID
  text: string;
}

function MessageList({ initialMessages }: { initialMessages: Message[] }) {
  const [messages, addOptimisticMessage] = useOptimistic<Message[], OptimisticUpdate>(
    initialMessages,
    (currentMessages, newMessage) => [
      ...currentMessages,
      {
        id: newMessage.id,
        text: newMessage.text,
        sending: true, // optimistic — will be replaced when server confirms
      },
    ]
  );

  async function handleSubmit(formData: FormData) {
    const text = formData.get('text') as string;
    const tempId = `temp-${Date.now()}`;

    addOptimisticMessage({ id: tempId, text });

    try {
      const result = await sendMessage(text);
      // Server Action revalidation replaces the optimistic message with the real one
    } catch {
      // Error — optimistic message stays until revalidation removes it
    }
  }

  return (
    <div>
      <ul className="space-y-2">
        {messages.map(msg => (
          <li key={msg.id} className={msg.sending ? 'opacity-50' : ''}>
            {msg.text}
            {msg.sending && <span className="text-xs text-gray-400 ml-2">Sending...</span>}
          </li>
        ))}
      </ul>
      <form action={handleSubmit}>
        <input name="text" required className="border px-2 py-1 rounded" />
        <button type="submit">Send</button>
      </form>
    </div>
  );
}
```

### useOptimistic with update function

```tsx
// Optimistic counter with decrement/increment
interface CounterState {
  count: number;
  isUpdating: boolean;
}

type CounterAction = 'increment' | 'decrement';

function OptimisticCounter({ initialCount }: { initialCount: number }) {
  const [state, optimisticUpdate] = useOptimistic<CounterState, CounterAction>(
    { count: initialCount, isUpdating: false },
    (currentState, action) => ({
      count: action === 'increment' ? currentState.count + 1 : currentState.count - 1,
      isUpdating: true,
    })
  );

  async function handleIncrement() {
    optimisticUpdate('increment');
    await updateCount(state.count + 1);
  }

  return (
    <div className="flex items-center gap-4">
      <button onClick={handleIncrement} disabled={state.isUpdating}>
        +1
      </button>
      <span className="text-lg font-bold">{state.count}</span>
      {state.isUpdating && <span className="text-xs text-gray-400">Updating...</span>}
    </div>
  );
}
```

## Quick Reference Table

| Pattern | Key type | Notes |
|---|---|---|
| Page async params | `params: Promise<{ slug: string }>` | Always await in Next.js 15+ |
| Page searchParams | `searchParams: Promise<{ q?: string }>` | Await, same as params |
| generateMetadata | `Promise<Metadata>` | Async params same as page |
| Server Action (FormData) | `FormData → Promise<Result>` | Use Zod to parse FormData |
| Server Action (typed args) | `Input → Promise<Result>` | Prefer for complex inputs |
| Route Handler GET | `NextRequest → Promise<NextResponse>` | Access searchParams via request.nextUrl |
| Route Handler POST | `NextRequest → Promise<NextResponse>` | Parse JSON body with Zod |
| Route Handler params | `Promise<{ id: string }>` | Await context.params |
| Middleware | `NextRequest → NextResponse` | Always Edge runtime |
| Edge runtime | `export const runtime = 'edge'` | No Node.js APIs |
| useOptimistic | `useOptimistic<State, Update>(initial, reducer)` | State, optimistic update type |

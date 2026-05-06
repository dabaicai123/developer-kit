# Server Actions and Forms

action prop, useActionState, server-side revalidation, progressive enhancement, and error handling.

## Form action Prop

Next.js Server Actions can be used as form actions for progressive enhancement. The form works even without JavaScript.

```tsx
// actions/create-product.ts
"use server";
import { revalidateTag } from "next/cache";
import { redirect } from "next/navigation";
import { CreateProductSchema } from "@/lib/schemas";

export async function createProduct(formData: FormData) {
  // Validate on server
  const input = CreateProductSchema.parse({
    name: formData.get("name"),
    price: Number(formData.get("price")),
    description: formData.get("description"),
  });

  const product = await db.product.create({ data: input });

  revalidateTag("products");
  redirect(`/products/${product.id}`);
}

// components/CreateProductForm.tsx (can be Server Component)
import { createProduct } from "@/actions/create-product";

function CreateProductForm() {
  return (
    <form action={createProduct} className="flex flex-col gap-4 max-w-md">
      <div>
        <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
          Name
        </label>
        <input
          id="name"
          name="name"
          required
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500"
        />
      </div>

      <div>
        <label htmlFor="price" className="block text-sm font-medium text-gray-700 mb-1">
          Price
        </label>
        <input
          id="price"
          name="price"
          type="number"
          required
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500"
        />
      </div>

      <button
        type="submit"
        className="bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600"
      >
        Create Product
      </button>
    </form>
  );
}
```

**Progressive enhancement**: Without JS, the form submits via normal HTML POST. With JS, Next.js intercepts the submission and calls the Server Action without a full page reload.

## useActionState

For forms that need client-side feedback (loading state, success/error messages), use `useActionState`.

```tsx
"use client";
import { useActionState } from "react";
import { createProductAction } from "@/actions/create-product";

type FormState = {
  success: boolean;
  message: string;
  errors?: Record<string, string>;
};

const initialState: FormState = {
  success: false,
  message: "",
  errors: {},
};

function CreateProductForm() {
  const [state, formAction, isPending] = useActionState(
    async (prev: FormState, formData: FormData) => {
      const result = await createProductAction(formData);

      if (result.ok) {
        return { success: true, message: "Product created successfully", errors: {} };
      }

      return {
        success: false,
        message: result.error.message ?? "Failed to create product",
        errors: result.error.fieldErrors ?? {},
      };
    },
    initialState
  );

  return (
    <form action={formAction} className="flex flex-col gap-4 max-w-md">
      <div>
        <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
          Name
        </label>
        <input
          id="name"
          name="name"
          required
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500"
        />
        {state.errors?.name && (
          <p className="text-red-500 text-sm mt-1" role="alert">{state.errors.name}</p>
        )}
      </div>

      <div>
        <label htmlFor="price" className="block text-sm font-medium text-gray-700 mb-1">
          Price
        </label>
        <input
          id="price"
          name="price"
          type="number"
          required
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500"
        />
        {state.errors?.price && (
          <p className="text-red-500 text-sm mt-1" role="alert">{state.errors.price}</p>
        )}
      </div>

      {state.message && (
        <div
          role="status"
          aria-live="polite"
          className={[
            "p-3 rounded-lg text-sm",
            state.success ? "bg-green-50 text-green-700" : "bg-red-50 text-red-700",
          ].join(" ")}
        >
          {state.message}
        </div>
      )}

      <button
        type="submit"
        disabled={isPending}
        className="bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600 disabled:opacity-50"
      >
        {isPending ? "Creating..." : "Create Product"}
      </button>
    </form>
  );
}
```

## Server-Side Revalidation

After mutations, revalidate cached data so the UI shows fresh results.

### revalidateTag (by fetch tag)

```tsx
"use server";
import { revalidateTag } from "next/cache";

export async function updateProduct(id: string, data: UpdateProductInput) {
  await db.product.update({ where: { id }, data });

  // Revalidate all fetches tagged "products"
  revalidateTag("products");
}
```

### revalidatePath (by URL path)

```tsx
"use server";
import { revalidatePath } from "next/cache";

export async function deleteProduct(id: string) {
  await db.product.delete({ where: { id } });

  // Revalidate the products list page and the specific product page
  revalidatePath("/products");          // list page
  revalidatePath(`/products/${id}`);    // detail page
  revalidatePath("/", "layout");        // all pages using this layout
}
```

### When to use each

| Method | Scope | Use When |
|---|---|---|
| `revalidateTag("products")` | All fetches with `next: { tags: ["products"] }` | Mutation affects many pages showing the same data type |
| `revalidatePath("/products")` | All data on the `/products` route | Mutation only affects one page |
| `revalidatePath("/", "layout")` | All pages in the layout | Mutation affects global data (e.g., user profile) |

## Progressive Enhancement

Server Actions with form `action` work without client JavaScript. This means:

1. **Form submission works without JS**: HTML form POST fallback
2. **Validation works without JS**: Server-side Zod validation still runs
3. **Redirect works without JS**: Server `redirect()` still works

```tsx
// This form works without JS:
<form action={createProduct}>
  <input name="name" required />
  <button type="submit">Create</button>
</form>

// For enhanced UX (loading state, inline errors), add useActionState:
"use client";
const [state, formAction, isPending] = useActionState(createProductFormAction, initialState);
<form action={formAction}>
  <input name="name" required />
  <button disabled={isPending}>{isPending ? "Creating..." : "Create"}</button>
</form>
```

**Recommendation**: Start with the simple `action` prop for progressive enhancement. Add `useActionState` only when you need client-side feedback.

## Error Handling

### Server Action returning Result

```tsx
"use server";
import { Result, ok, err } from "@/lib/result";
import { CreateProductSchema, type ProductCreateInput } from "@/lib/schemas";

type FieldErrors = Record<string, string[]>;

type CreateProductResult = Result<
  Product,
  { message: string; fieldErrors?: FieldErrors }
>;

export async function createProduct(
  input: unknown
): Promise<CreateProductResult> {
  // Always validate on server
  const parsed = CreateProductSchema.safeParse(input);

  if (!parsed.success) {
    // Map Zod errors to field-level errors
    const fieldErrors: FieldErrors = {};
    for (const issue of parsed.error.issues) {
      const field = issue.path.join(".");
      if (!fieldErrors[field]) fieldErrors[field] = [];
      fieldErrors[field].push(issue.message);
    }

    return err({
      message: "Validation failed",
      fieldErrors,
    });
  }

  try {
    const product = await db.product.create({ data: parsed.data });
    revalidateTag("products");
    return ok(product);
  } catch (e) {
    return err({ message: "Failed to create product" });
  }
}
```

### Client handling server errors

```tsx
"use client";
function CreateProductForm() {
  const [state, formAction, isPending] = useActionState(
    async (prev: FormState, formData: FormData) => {
      const input = {
        name: formData.get("name") as string,
        price: Number(formData.get("price")),
      };

      const result = await createProduct(input);

      if (result.ok) {
        return { success: true, message: "Product created", errors: {} };
      }

      return {
        success: false,
        message: result.error.message,
        errors: result.error.fieldErrors ?? {},
      };
    },
    { success: false, message: "", errors: {} }
  );

  // Map server field errors to form inputs
  return (
    <form action={formAction}>
      <input name="name" />
      {state.errors?.name && <p className="text-red-500 text-sm">{state.errors.name[0]}</p>}
      <button disabled={isPending}>Submit</button>
    </form>
  );
}
```

## Common Patterns

### Combining React Hook Form with Server Actions

```tsx
"use client";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";

function CreateProductForm() {
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
    reset,
  } = useForm<ProductCreateInput>({
    resolver: zodResolver(ProductCreateSchema),
  });

  const onSubmit = async (data: ProductCreateInput) => {
    const result = await createProduct(data);

    if (result.ok) {
      reset(); // clear form on success
      toast.success("Product created");
    } else {
      // Map server errors to form fields
      if (result.error.fieldErrors) {
        for (const [field, messages] of Object.entries(result.error.fieldErrors)) {
          setError(field as keyof ProductCreateInput, {
            type: "server",
            message: messages[0],
          });
        }
      } else {
        setError("root.serverError", { message: result.error.message });
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {/* fields with register */}
      {errors.root?.serverError && (
        <p className="text-red-500">{errors.root.serverError.message}</p>
      )}
    </form>
  );
}
```

### Optimistic update with useOptimistic

```tsx
"use client";
import { useOptimistic } from "react";

function ProductList({ products }: { products: Product[] }) {
  const [optimisticProducts, addOptimisticProduct] = useOptimistic(
    products,
    (state, newProduct: Product) => [...state, newProduct]
  );

  const handleCreate = async (formData: FormData) => {
    const name = formData.get("name") as string;
    // Show optimistic product immediately
    addOptimisticProduct({ id: "temp", name, price: 0, inStock: true });

    // Server action confirms (or rejects)
    const result = await createProductAction(formData);
    // On success, the actual product replaces the optimistic one after revalidation
  };

  return (
    <div>
      <form action={handleCreate}>
        <input name="name" />
        <button type="submit">Add</button>
      </form>
      <ul>
        {optimisticProducts.map((p) => (
          <li key={p.id} className={p.id === "temp" ? "opacity-50" : ""}>
            {p.name}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

## Anti-patterns

### Client-only validation without server re-validation

```tsx
// WRONG: only validate on client
const onSubmit = async (data: ProductCreateInput) => {
  await fetch("/api/products", { method: "POST", body: JSON.stringify(data) });
  // No server-side Zod validation!
};

// RIGHT: Server Action validates on server
"use server";
export async function createProduct(input: unknown) {
  const parsed = CreateProductSchema.safeParse(input);
  if (!parsed.success) return err(parsed.error);
  await db.product.create({ data: parsed.data });
}
```

### Not revalidating after mutation

```tsx
// WRONG: mutation succeeds but stale data is still shown
export async function updateProduct(id: string, data: UpdateProductInput) {
  await db.product.update({ where: { id }, data });
  // No revalidation! UI still shows old data.
}

// RIGHT: revalidate after mutation
export async function updateProduct(id: string, data: UpdateProductInput) {
  await db.product.update({ where: { id }, data });
  revalidateTag("products");
  revalidatePath(`/products/${id}`);
}
```
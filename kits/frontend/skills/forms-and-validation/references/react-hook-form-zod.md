# React Hook Form + Zod

useForm setup with zodResolver, schema definition, z.infer for types, field arrays, and conditional validation.

## Basic Setup

### Install

```bash
npm install react-hook-form @hookform/resolvers zod
```

### Schema and type derivation

```tsx
import { z } from "zod";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";

// 1. Define Zod schema (validation rules + TypeScript type in one place)
const ProductCreateSchema = z.object({
  name: z.string().min(1, "Product name is required").max(100, "Name too long"),
  price: z.coerce.number().positive("Price must be positive"),
  description: z.string().max(500, "Description too long").optional(),
  category: z.string().min(1, "Category is required"),
  inStock: z.boolean().default(true),
});

// 2. Derive type from schema (never manually define)
type ProductCreateInput = z.infer<typeof ProductCreateSchema>;

// 3. useForm with zodResolver
function CreateProductForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ProductCreateInput>({
    resolver: zodResolver(ProductCreateSchema),
    defaultValues: {
      name: "",
      price: 0,
      description: "",
      category: "",
      inStock: true,
    },
  });

  const onSubmit = async (data: ProductCreateInput) => {
    // data is fully validated and typed
    await createProductAction(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4 max-w-md">
      <div>
        <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
          Product Name
        </label>
        <input
          id="name"
          {...register("name")}
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
        />
        {errors.name && (
          <p className="text-red-500 text-sm mt-1" role="alert">{errors.name.message}</p>
        )}
      </div>

      <div>
        <label htmlFor="price" className="block text-sm font-medium text-gray-700 mb-1">
          Price
        </label>
        <input
          id="price"
          type="number"
          {...register("price")}
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
        />
        {errors.price && (
          <p className="text-red-500 text-sm mt-1" role="alert">{errors.price.message}</p>
        )}
      </div>

      <div>
        <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">
          Description (optional)
        </label>
        <textarea
          id="description"
          {...register("description")}
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
        />
        {errors.description && (
          <p className="text-red-500 text-sm mt-1" role="alert">{errors.description.message}</p>
        )}
      </div>

      <div>
        <label htmlFor="category" className="block text-sm font-medium text-gray-700 mb-1">
          Category
        </label>
        <select
          id="category"
          {...register("category")}
          className="w-full border border-gray-200 rounded-lg px-3 py-2 focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
        >
          <option value="">Select category</option>
          <option value="electronics">Electronics</option>
          <option value="clothing">Clothing</option>
          <option value="books">Books</option>
        </select>
        {errors.category && (
          <p className="text-red-500 text-sm mt-1" role="alert">{errors.category.message}</p>
        )}
      </div>

      <button
        type="submit"
        disabled={isSubmitting}
        className="bg-blue-500 text-white px-4 py-2 rounded-lg disabled:opacity-50 hover:bg-blue-600"
      >
        {isSubmitting ? "Creating..." : "Create Product"}
      </button>
    </form>
  );
}
```

## z.coerce for Number Inputs

HTML inputs always return strings. Use `z.coerce.number()` to convert before validation.

```tsx
// WRONG: z.number() fails because the input is a string
const schema = z.object({
  price: z.number().positive(), // validation error: "Expected number, received string"
});

// RIGHT: coerce converts the string to number first
const schema = z.object({
  price: z.coerce.number().positive("Price must be a positive number"),
  quantity: z.coerce.number().int().min(1, "Quantity must be at least 1"),
});
```

## Field Arrays

Dynamic lists of inputs (e.g., adding multiple variants, tags, or line items).

```tsx
import { useFieldArray } from "react-hook-form";

const OrderSchema = z.object({
  customerName: z.string().min(1),
  items: z.array(
    z.object({
      productName: z.string().min(1, "Item name required"),
      quantity: z.coerce.number().int().min(1, "Min 1 item"),
      price: z.coerce.number().positive(),
    })
  ).min(1, "At least one item required"),
});

type OrderInput = z.infer<typeof OrderSchema>;

function OrderForm() {
  const { register, control, handleSubmit, formState: { errors } } = useForm<OrderInput>({
    resolver: zodResolver(OrderSchema),
    defaultValues: {
      customerName: "",
      items: [{ productName: "", quantity: 1, price: 0 }],
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: "items",
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
      <div>
        <label>Customer Name</label>
        <input {...register("customerName")} />
        {errors.customerName && <p className="text-red-500 text-sm">{errors.customerName.message}</p>}
      </div>

      {/* Field array errors */}
      {errors.items && typeof errors.items.message === "string" && (
        <p className="text-red-500 text-sm">{errors.items.message}</p>
      )}

      <div className="flex flex-col gap-4">
        {fields.map((field, index) => (
          <div key={field.id} className="flex gap-3 items-start p-4 bg-gray-50 rounded-lg">
            <div className="flex-1">
              <input {...register(`items.${index}.productName`)} placeholder="Product name" className="w-full border border-gray-200 rounded-md px-3 py-2" />
              {errors.items?.[index]?.productName && (
                <p className="text-red-500 text-sm mt-1">{errors.items[index].productName?.message}</p>
              )}
            </div>
            <div className="w-24">
              <input {...register(`items.${index}.quantity`)} type="number" placeholder="Qty" className="w-full border border-gray-200 rounded-md px-3 py-2" />
            </div>
            <div className="w-24">
              <input {...register(`items.${index}.price`)} type="number" placeholder="Price" className="w-full border border-gray-200 rounded-md px-3 py-2" />
            </div>
            <button
              type="button"
              onClick={() => remove(index)}
              className="text-red-500 hover:text-red-700 px-2"
            >
              Remove
            </button>
          </div>
        ))}
      </div>

      <button
        type="button"
        onClick={() => append({ productName: "", quantity: 1, price: 0 })}
        className="text-blue-500 hover:text-blue-700 text-sm"
      >
        + Add Item
      </button>

      <button type="submit" className="bg-blue-500 text-white px-4 py-2 rounded-lg">
        Submit Order
      </button>
    </form>
  );
}
```

## Conditional Validation

Show different validation rules based on form state.

### Method 1: Zod .refine (single-field conditional)

```tsx
const PaymentSchema = z.object({
  method: z.enum(["card", "bank"]),
  cardNumber: z.string().optional(),
  bankAccount: z.string().optional(),
}).refine(
  (data) => {
    if (data.method === "card") return data.cardNumber?.length === 16;
    if (data.method === "bank") return data.bankAccount?.length >= 8;
    return false;
  },
  {
    message: "Please provide complete payment details",
    path: ["method"], // error shows on the method field
  }
);
```

### Method 2: Zod discriminatedUnion (different schemas per mode)

```tsx
const PaymentSchema = z.discriminatedUnion("method", [
  z.object({
    method: z.literal("card"),
    cardNumber: z.string().length(16, "Card number must be 16 digits"),
    expiry: z.string().regex(/^\d{2}\/\d{2}$/, "Invalid expiry format"),
  }),
  z.object({
    method: z.literal("bank"),
    bankAccount: z.string().min(8, "Account number too short"),
    bankName: z.string().min(1, "Bank name required"),
  }),
]);

// Form toggles between schemas based on method
function PaymentForm() {
  const { register, handleSubmit, watch, formState: { errors } } = useForm({
    resolver: zodResolver(PaymentSchema),
  });

  const method = watch("method");

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <select {...register("method")}>
        <option value="card">Credit Card</option>
        <option value="bank">Bank Transfer</option>
      </select>

      {method === "card" && (
        <>
          <input {...register("cardNumber")} placeholder="Card number" />
          <input {...register("expiry")} placeholder="MM/YY" />
        </>
      )}

      {method === "bank" && (
        <>
          <input {...register("bankAccount")} placeholder="Account number" />
          <input {...register("bankName")} placeholder="Bank name" />
        </>
      )}
    </form>
  );
}
```

## Controlled vs Uncontrolled

### Uncontrolled (default with register)

```tsx
// register creates uncontrolled inputs (ref-based, no React state per keystroke)
const { register } = useForm();
<input {...register("name")} /> // efficient, no re-render per keystroke
```

**When to use**: Most form inputs. More performant (no re-render per keystroke).

### Controlled (Controller)

```tsx
import { Controller } from "react-hook-form";

// Controller for inputs that need controlled value access
<Controller
  name="startDate"
  control={control}
  render={({ field }) => (
    <DatePicker
      selected={field.value}
      onChange={field.onChange}
    />
  )}
/>
```

**When to use**: Third-party components that require `value` + `onChange` props (date pickers, rich text editors, custom selects). Inputs where you need to transform the value on every keystroke.

## Common Patterns

### Form with loading state

```tsx
function useCreateProduct() {
  const [result, setResult] = useState<Result<Product, string> | null>(null);

  const {
    register,
    handleSubmit,
    formState: { isSubmitting },
    reset,
  } = useForm<ProductCreateInput>({
    resolver: zodResolver(ProductCreateSchema),
  });

  const onSubmit = async (data: ProductCreateInput) => {
    const res = await createProductAction(data);
    setResult(res);
    if (res.ok) reset(); // clear form on success
  };

  return { register, handleSubmit, isSubmitting, result, onSubmit };
}
```

### Form with server-side validation errors

```tsx
function CreateProductForm() {
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<ProductCreateInput>({
    resolver: zodResolver(ProductCreateSchema),
  });

  const onSubmit = async (data: ProductCreateInput) => {
    const result = await createProductAction(data);
    if (!result.ok) {
      // Map server validation errors back to form fields
      if (typeof result.error === "object") {
        for (const [field, message] of Object.entries(result.error.fieldErrors ?? {})) {
          setError(field as keyof ProductCreateInput, { message: message?.[0] ?? "Validation error" });
        }
      } else {
        setError("root", { message: result.error });
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {/* ... fields ... */}
      {errors.root && <p className="text-red-500">{errors.root.message}</p>}
    </form>
  );
}
```
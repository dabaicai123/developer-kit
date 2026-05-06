# Zod Schema Patterns

.extend/.merge for combining schemas, .transform for data transformation, .refine/.superRefine for custom validation, z.discriminatedUnion for variant schemas, and error customization.

## .extend - Adding Fields to a Schema

Use `.extend()` when you need to add fields to an existing schema (e.g., create form extends base schema with extra fields).

```tsx
// Base product schema (shared between create and update)
const BaseProductSchema = z.object({
  name: z.string().min(1, "Name is required"),
  description: z.string().max(500).optional(),
});

// Create form: extends base + adds price and category
const CreateProductSchema = BaseProductSchema.extend({
  price: z.coerce.number().positive("Price must be positive"),
  category: z.string().min(1, "Category is required"),
});

// Update form: extends base but makes fields optional
const UpdateProductSchema = BaseProductSchema.extend({
  name: z.string().min(1).optional(), // can update just the name
  description: z.string().max(500).optional(),
});

type CreateProductInput = z.infer<typeof CreateProductSchema>;
// { name: string; description?: string; price: number; category: string }

type UpdateProductInput = z.infer<typeof UpdateProductSchema>;
// { name?: string; description?: string }
```

**Note**: `.extend()` overrides fields with the same key. The new field definition replaces the old one entirely.

## .merge - Combining Two Schemas

Use `.merge()` to combine two distinct schemas. Unlike `.extend()`, merge preserves all fields from both schemas without overriding.

```tsx
const AddressSchema = z.object({
  street: z.string().min(1),
  city: z.string().min(1),
  zip: z.string().regex(/^\d{5}$/, "Invalid ZIP code"),
  country: z.string().min(1),
});

const ContactSchema = z.object({
  email: z.string().email(),
  phone: z.string().optional(),
});

// Combined: user must provide both address and contact
const RegistrationSchema = AddressSchema.merge(ContactSchema);

type RegistrationInput = z.infer<typeof RegistrationSchema>;
// { street: string; city: string; zip: string; country: string; email: string; phone?: string }
```

**Difference from .extend()**: `.merge(A)` adds all of A's fields. `.extend({ ...A.shape })` is more explicit but equivalent. Use `.merge()` when combining two named schemas; use `.extend()` when adding specific fields.

## .transform - Data Transformation

Transform data after validation. Common uses: coerce strings, normalize formats, derive computed fields.

### String to number coercion

```tsx
// HTML inputs always return strings. Transform before validation.
const schema = z.object({
  price: z.string().transform((val) => Number(val)).pipe(z.number().positive()),
  // Or simpler:
  price: z.coerce.number().positive(), // built-in coercion
});
```

### Normalizing input

```tsx
const SearchSchema = z.object({
  query: z.string().transform((val) => val.trim().toLowerCase()),
  tags: z.string().transform((val) =>
    val.split(",").map((t) => t.trim().toLowerCase()).filter(Boolean)
  ),
});

// Input: { query: "  Hello World  ", tags: "react,vue,  angular " }
// Output: { query: "hello world", tags: ["react", "vue", "angular"] }
```

### Deriving computed fields

```tsx
const OrderSchema = z.object({
  items: z.array(z.object({
    name: z.string(),
    price: z.number(),
    quantity: z.number().int().min(1),
  })),
}).transform((data) => ({
  ...data,
  total: data.items.reduce((sum, item) => sum + item.price * item.quantity, 0),
}));

// Input: { items: [{ name: "Widget", price: 10, quantity: 3 }] }
// Output: { items: [...], total: 30 }
```

**Important**: After `.transform()`, the output type differs from the input type. Use `z.input<typeof schema>` for input type and `z.output<typeof schema>` for output type.

```tsx
type OrderInput = z.input<typeof OrderSchema>;  // without total
type OrderOutput = z.output<typeof OrderSchema>; // with total
```

## .refine - Custom Validation

Add validation rules that Zod's built-in validators can't express.

### Single-field refine

```tsx
const PasswordSchema = z.string()
  .min(8, "At least 8 characters")
  .refine((val) => /[A-Z]/.test(val), "Must contain an uppercase letter")
  .refine((val) => /[0-9]/.test(val), "Must contain a number")
  .refine((val) => /[^A-Za-z0-9]/.test(val), "Must contain a special character");
```

### Cross-field refine

```tsx
const SignupSchema = z.object({
  password: z.string().min(8),
  confirmPassword: z.string().min(8),
}).refine(
  (data) => data.password === data.confirmPassword,
  {
    message: "Passwords don't match",
    path: ["confirmPassword"], // error shows on confirmPassword field
  }
);
```

**The `path` option**: Controls which field the error appears on. Without `path`, the error appears at the root level.

### Multiple cross-field validations

```tsx
const ShippingSchema = z.object({
  method: z.enum(["standard", "express", "pickup"]),
  address: z.object({
    street: z.string(),
    city: z.string(),
    zip: z.string(),
  }).optional(),
  pickupLocation: z.string().optional(),
}).refine(
  (data) => {
    // Address required for delivery methods
    if (data.method === "standard" || data.method === "express") {
      return data.address !== undefined;
    }
    return true;
  },
  { message: "Address required for delivery", path: ["address"] }
).refine(
  (data) => {
    // Pickup location required for pickup method
    if (data.method === "pickup") {
      return data.pickupLocation !== undefined;
    }
    return true;
  },
  { message: "Pickup location required", path: ["pickupLocation"] }
);
```

## .superRefine - Advanced Custom Validation

Use `.superRefine()` when you need to add multiple errors or conditional validation with fine-grained error paths.

```tsx
const AddressSchema = z.object({
  country: z.string(),
  zip: z.string(),
}).superRefine((data, ctx) => {
  // US ZIP: 5 digits or 5+4
  if (data.country === "US" && !/^\d{5}(-\d{4})?$/.test(data.zip)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "US ZIP must be 5 digits or 5+4 format",
      path: ["zip"],
    });
  }

  // UK postcode: specific format
  if (data.country === "UK" && !/^[A-Z]{1,2}\d[A-Z\d]? \d[A-Z]{2}$/.test(data.zip)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Invalid UK postcode format",
      path: ["zip"],
    });
  }

  // Canada: alphanumeric
  if (data.country === "CA" && !/^[A-Z]\d[A-Z] \d[A-Z]\d$/.test(data.zip)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "Invalid Canadian postal code format",
      path: ["zip"],
    });
  }
});
```

**Difference from `.refine()`**: `.superRefine()` can add multiple issues via `ctx.addIssue()`. `.refine()` can only produce one error per call.

## z.discriminatedUnion - Variant Schemas

When different "modes" have completely different field requirements, use `z.discriminatedUnion`.

```tsx
const NotificationSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("email"),
    email: z.string().email("Valid email required"),
    subject: z.string().min(1, "Subject required"),
  }),
  z.object({
    type: z.literal("sms"),
    phone: z.string().regex(/^\+?\d{10,15}$/, "Valid phone number required"),
    message: z.string().min(1, "Message required").max(160, "SMS max 160 chars"),
  }),
  z.object({
    type: z.literal("push"),
    deviceId: z.string().min(1, "Device ID required"),
    title: z.string().min(1, "Title required"),
    body: z.string().optional(),
  }),
]);

type NotificationInput = z.infer<typeof NotificationSchema>;
// TypeScript narrows based on type:
// { type: "email"; email: string; subject: string }
// | { type: "sms"; phone: string; message: string }
// | { type: "push"; deviceId: string; title: string; body?: string }

// Form conditional rendering
function NotificationForm() {
  const { register, watch } = useForm<NotificationInput>({
    resolver: zodResolver(NotificationSchema),
  });

  const type = watch("type");

  return (
    <form>
      <select {...register("type")}>
        <option value="email">Email</option>
        <option value="sms">SMS</option>
        <option value="push">Push</option>
      </select>

      {type === "email" && <EmailFields register={register} />}
      {type === "sms" && <SmsFields register={register} />}
      {type === "push" && <PushFields register={register} />}
    </form>
  );
}
```

**Advantage over `.refine()`**: Each variant has its own complete schema. TypeScript narrows correctly. Error messages are specific to the variant, not generic cross-field errors.

## Error Customization

### Custom error messages

```tsx
const schema = z.object({
  name: z.string({
    required_error: "Please enter a product name",
    invalid_type_error: "Name must be a string",
  }).min(2, "Name must be at least 2 characters")
    .max(100, "Name cannot exceed 100 characters"),

  email: z.string({
    required_error: "Email is required",
  }).email("Please enter a valid email address"),

  age: z.number({
    required_error: "Age is required",
    invalid_type_error: "Age must be a number",
  }).int("Age must be a whole number")
    .min(18, "You must be at least 18 years old")
    .max(120, "Age seems unrealistic"),
});
```

### Custom error map (global)

```tsx
const customErrorMap: z.ZodErrorMap = (issue, ctx) => {
  if (issue.code === z.ZodIssueCode.invalid_type) {
    if (issue.received === "undefined") {
      return { message: "This field is required" };
    }
    return { message: `Expected ${issue.expected}, got ${issue.received}` };
  }
  if (issue.code === z.ZodIssueCode.too_small) {
    return { message: `Must be at least ${issue.minimum} characters` };
  }
  // Fall back to default
  return { message: ctx.defaultError };
};

z.setErrorMap(customErrorMap);
```

### Flattening errors for form display

```tsx
const result = CreateProductSchema.safeParse(input);

if (!result.success) {
  // Flatten: { formErrors: string[], fieldErrors: Record<string, string[]> }
  const flat = result.error.flatten();

  // Form-level errors
  console.log(flat.formErrors); // ["Validation failed"]

  // Field-level errors
  console.log(flat.fieldErrors); // { name: ["Name too short"], price: ["Price must be positive"] }
}
```

### Error formatting for UI

```tsx
function formatFieldErrors(zodError: z.ZodError): Record<string, string> {
  const errors: Record<string, string> = {};
  for (const issue of zodError.issues) {
    const field = issue.path.join(".");
    // Show only the first error per field
    if (!errors[field]) {
      errors[field] = issue.message;
    }
  }
  return errors;
}

// Usage in Server Action
export async function createProduct(input: unknown): Promise<Result<Product, FormError>> {
  const parsed = CreateProductSchema.safeParse(input);
  if (!parsed.success) {
    return err({
      message: "Validation failed",
      fieldErrors: formatFieldErrors(parsed.error),
    });
  }
  return ok(await db.product.create({ data: parsed.data }));
}
```
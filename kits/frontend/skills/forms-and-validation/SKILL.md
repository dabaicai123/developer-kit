---
name: forms-and-validation
description: "Builds forms with React Hook Form, Zod schemas, Server Actions, error display patterns, and controlled/uncontrolled inputs. Use when creating forms, validation schemas, mutations, or server-side form handling."
version: "1.0.0"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Forms and Validation

Build robust forms with React Hook Form + Zod. Handle validation, errors, and Server Actions correctly.

## When to Use This Skill

- Creating form components with validation
- Setting up React Hook Form with Zod resolver
- Handling form submissions via Server Actions
- Displaying validation errors near inputs
- Implementing controlled vs uncontrolled form patterns
- Creating Zod schemas for form validation

## Core Architecture

```
Zod Schema (validation rules)
    │
    ▼ z.infer<InputSchema>
TypeScript Types (from schema, never manual)
    │
    ▼ zodResolver(schema)
React Hook Form (useForm + resolver)
    │
    ▼ handleSubmit → Server Action
Server Action (validate again on server)
    │
    ▼ Result<T,E> response
UI (field errors near inputs, form-level errors as summary)
```

## [HARD RULE] Always Use a Zod Schema

Every form must have a Zod schema. No manual type definitions for form data. No validation logic in the component.

```tsx
// WRONG: manual validation
function handleSubmit(data: unknown) {
  if (!data.name || data.name.length < 2) return "Name too short";
  if (!data.email.includes("@")) return "Invalid email";
}

// RIGHT: Zod schema
const CreateProductSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Invalid email address"),
});

type CreateProductInput = z.infer<typeof CreateProductSchema>; // derive type from schema
```

**Why**: Zod provides runtime validation, TypeScript types, and error messages in one place. No duplication between type definitions and validation logic.

## [HARD RULE] Use z.infer for Types

Never manually define form input types. Always derive them from the Zod schema.

```tsx
// WRONG: manual type that doesn't match schema
type FormInput = { name: string; price: number };
const schema = z.object({ name: z.string(), price: z.string() }); // price is string in schema!

// RIGHT: derive from schema
const schema = z.object({
  name: z.string(),
  price: z.coerce.number(), // coerce string input to number
});
type FormInput = z.infer<typeof schema>; // { name: string; price: number }
```

## [HARD RULE] Field Errors Near the Input

Validation errors must appear directly below or beside the relevant input. Never show errors only in a distant summary.

```tsx
// WRONG: errors only in a top banner
<ErrorBanner errors={formErrors} /> // far from the inputs
<input name="email" /> // user can't see which field has the error

// RIGHT: errors below each input
<div>
  <label>Email</label>
  <input {...register("email")} />
  {errors.email && <p className="text-red-500 text-sm mt-1">{errors.email.message}</p>}
</div>
```

## [HARD RULE] Validate on Server

Server Actions must re-validate input with Zod on the server, even if the client already validated. Client validation is for UX; server validation is for security.

```tsx
"use server";
export async function createProduct(input: unknown) {
  // Re-validate on server - client validation is not trusted
  const parsed = CreateProductSchema.safeParse(input);
  if (!parsed.success) {
    return { ok: false, error: parsed.error.flatten() };
  }
  // ... proceed with validated data
}
```

## Related Skills

- **typescript-react**: z.infer, discriminated unions, Result<T,E>
- **data-fetching**: Server Actions, typed API patterns
- **design-to-code**: Form layout and styling patterns
- **state-management**: Form draft state, URL state for filters

## References

- [react-hook-form-zod](references/react-hook-form-zod.md) - useForm setup, schemas, field arrays, conditional validation
- [server-actions-forms](references/server-actions-forms.md) - action prop, useActionState, revalidation, progressive enhancement
- [zod-schema-patterns](references/zod-schema-patterns.md) - .extend/.merge, .transform, .refine, discriminated unions
- [form-error-display](references/form-error-display.md) - Field-level errors, ARIA live, toast notifications, Zod issue mapping

# Form Error Display

Field-level errors, form summary, ARIA live regions, toast notifications, and Zod issue mapping.

## Principles

1. **Errors near the input**: Every field error appears directly below or beside the relevant input
2. **Errors are accessible**: Use `role="alert"` and `aria-describedby` so screen readers announce errors
3. **Form-level errors**: Use a summary for multi-field errors (passwords don't match, cross-field validation)
4. **Timely feedback**: Show errors on submit (not on every keystroke), show inline validation on blur for important fields

## Field-Level Errors

### React Hook Form pattern

```tsx
function FormField({ label, error, id, ...inputProps }: FormFieldProps) {
  const errorId = `${id}-error`;

  return (
    <div>
      <label htmlFor={id} className="block text-sm font-medium text-gray-700 mb-1">
        {label}
      </label>
      <input
        id={id}
        aria-invalid={error ? true : undefined}
        aria-describedby={error ? errorId : undefined}
        className={[
          "w-full border rounded-lg px-3 py-2",
          error ? "border-red-500 focus-visible:ring-red-500" : "border-gray-200 focus-visible:ring-blue-500",
          "focus-visible:ring-2 focus-visible:ring-offset-2",
        ].join(" ")}
        {...inputProps}
      />
      {error && (
        <p id={errorId} className="text-red-500 text-sm mt-1" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}

// Usage
<FormField
  id="email"
  label="Email"
  error={errors.email?.message}
  {...register("email")}
/>
```

**Key accessibility features**:
- `aria-invalid={true}` when there's an error (screen readers announce the field is invalid)
- `aria-describedby` links the error message to the input (screen readers read the error when the field is focused)
- `role="alert"` on the error text (screen readers announce new errors immediately)
- Red border on the input when invalid (visual indication)
- `id` attributes link label, input, and error message

### Reusable field wrapper component

```tsx
type FieldWrapperProps = {
  label: string;
  error?: string;
  id: string;
  children: ReactNode;
  hint?: string;
};

function FieldWrapper({ label, error, id, children, hint }: FieldWrapperProps) {
  const errorId = `${id}-error`;
  const hintId = `${id}-hint`;
  const describedBy = [
    error ? errorId : null,
    hint ? hintId : null,
  ].filter(Boolean).join(" ") || undefined;

  return (
    <div>
      <label htmlFor={id} className="block text-sm font-medium text-gray-700 mb-1">
        {label}
      </label>
      {/* Clone child to inject aria props */}
      {children}
      {hint && !error && (
        <p id={hintId} className="text-gray-400 text-sm mt-1">{hint}</p>
      )}
      {error && (
        <p id={errorId} className="text-red-500 text-sm mt-1" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
```

## Form Error Summary

For multi-field validation failures, show a summary at the top of the form that lists all errors.

```tsx
function FormErrorSummary({ errors }: { errors: Record<string, string> }) {
  const errorEntries = Object.entries(errors).filter(([, msg]) => msg);

  if (errorEntries.length === 0) return null;

  return (
    <div
      role="alert"
      aria-live="polite"
      className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4"
    >
      <h3 className="text-red-700 font-medium mb-2">
        Please fix the following errors:
      </h3>
      <ul className="list-disc list-inside text-red-600 text-sm space-y-1">
        {errorEntries.map(([field, message]) => (
          <li key={field}>
            <a
              href={`#${field}`}
              className="underline hover:text-red-800"
              onClick={(e) => {
                e.preventDefault();
                document.getElementById(field)?.focus();
              }}
            >
              {message}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}

// Usage
<form onSubmit={handleSubmit(onSubmit)}>
  <FormErrorSummary errors={fieldErrorsFromRHF(errors)} />
  {/* ... fields ... */}
</form>
```

**When to show summary**: On submit validation failure. Not on blur (too noisy). Not when only one field has an error (the field-level error is sufficient).

## ARIA Live Regions

### aria-live="polite" (for non-urgent updates)

```tsx
// Search results count, form success message, toast
<div aria-live="polite" role="status">
  {searchResultCount > 0 && `${searchResultCount} results found`}
</div>
```

Screen readers announce the update after the user finishes their current action.

### aria-live="assertive" (for urgent updates)

```tsx
// Critical errors, form submission failures
<div aria-live="assertive" role="alert">
  {criticalError && criticalError}
</div>
```

Screen readers interrupt immediately.

### When to use each

| Situation | Use |
|---|---|
| Field validation error | `role="alert"` on the error message (near the field) |
| Form-level error summary | `role="alert"` + `aria-live="polite"` |
| Success toast notification | `aria-live="polite"` + `role="status"` |
| Critical system error | `aria-live="assertive"` + `role="alert"` |
| Search results count | `aria-live="polite"` + `role="status"` |

## Toast Notifications

Use toast for form-level success/error feedback that should not block the workflow.

```tsx
// Simple toast component
function Toast({ message, type }: { message: string; type: "success" | "error" }) {
  return (
    <div
      role="status"
      aria-live="polite"
      className={[
        "fixed bottom-4 right-4 px-4 py-3 rounded-lg shadow-md text-sm z-50",
        "animate-in fade-in slide-in-from-bottom-4 duration-300",
        type === "success" ? "bg-green-50 text-green-700 border border-green-200" : "bg-red-50 text-red-700 border border-red-200",
      ].join(" ")}
    >
      {message}
    </div>
  );
}

// Usage in form
function CreateProductForm() {
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);

  const onSubmit = async (data: ProductCreateInput) => {
    const result = await createProduct(data);
    if (result.ok) {
      setToast({ message: "Product created successfully", type: "success" });
      reset();
    } else {
      setToast({ message: result.error, type: "error" });
    }

    // Auto-dismiss after 5s
    setTimeout(() => setToast(null), 5000);
  };

  return (
    <>
      <form onSubmit={handleSubmit(onSubmit)}> {/* ... */ } </form>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
```

## Zod Issue Mapping

Map Zod validation issues to user-friendly form errors.

### Basic mapping

```tsx
function mapZodErrors(zodError: z.ZodError): Record<string, string> {
  const fieldErrors: Record<string, string> = {};

  for (const issue of zodError.issues) {
    const fieldPath = issue.path.join(".");
    // Show first error per field only (avoid overwhelming the user)
    if (!fieldErrors[fieldPath]) {
      fieldErrors[fieldPath] = issue.message;
    }
  }

  return fieldErrors;
}
```

### Nested field mapping

```tsx
// For schemas with nested objects
const schema = z.object({
  shipping: z.object({
    address: z.string().min(1),
    city: z.string().min(1),
  }),
  items: z.array(z.object({
    name: z.string().min(1),
    qty: z.number().min(1),
  })),
});

// Zod issue path for shipping.address: ["shipping", "address"]
// Zod issue path for items[2].name: ["items", 2, "name"]

function mapNestedZodErrors(zodError: z.ZodError): Record<string, string> {
  const errors: Record<string, string> = {};

  for (const issue of zodError.issues) {
    const key = issue.path.join(".");
    if (!errors[key]) {
      errors[key] = issue.message;
    }
  }

  return errors;
  // Example output:
  // { "shipping.address": "Required", "items.2.name": "Required" }
}
```

### Mapping server errors to React Hook Form fields

```tsx
function setServerErrors(
  setError: UseFormSetError<FormInput>,
  zodError: z.ZodError
) {
  for (const issue of zodError.issues) {
    const fieldPath = issue.path.join(".");
    // RHF supports nested field paths with dot notation
    setError(fieldPath as Path<FormInput>, {
      type: "server",
      message: issue.message,
    });
  }
}

// Usage
const result = await createProductAction(data);
if (!result.ok && result.error instanceof z.ZodError) {
  setServerErrors(setError, result.error);
}
```

## Error Display Timing

| Timing | Use When | How |
|---|---|---|
| **On submit** | Most forms (default) | `formState.errors` after `handleSubmit` |
| **On blur** | Critical fields (email, password) | `mode: "onBlur"` in useForm config |
| **On change** | Real-time validation (password strength) | `mode: "onChange"` for specific fields |
| **On server response** | Server Actions | Map server errors to form fields after response |

```tsx
// Default: validate on submit (least noisy)
const form = useForm({ resolver: zodResolver(schema) }); // mode: "onSubmit" by default

// Validate on blur (for important fields)
const form = useForm({ resolver: zodResolver(schema), mode: "onBlur" });

// Validate on change + blur (for password fields that need real-time feedback)
const form = useForm({ resolver: zodResolver(schema), mode: "onChange" });
```

## Anti-patterns

### Error only in a banner far from inputs

```tsx
// BAD: user can't tell which field has the error
<ErrorBanner>Validation failed. Please check your inputs.</ErrorBanner>
<input name="email" /> <!-- no indication this field has the error -->
<input name="name" /> <!-- same -->

// GOOD: errors directly on each field
<input name="email" aria-invalid={!!errors.email} />
{errors.email && <p className="text-red-500 text-sm" role="alert">{errors.email.message}</p>}
```

### Showing all errors on every keystroke

```tsx
// BAD: red errors flashing as user types
const form = useForm({ mode: "onChange" }); // shows errors before user finishes typing

// GOOD: validate on submit, show on blur for important fields only
const form = useForm({ mode: "onSubmit" }); // errors shown after user finishes and submits
```

### Not clearing errors when user fixes them

```tsx
// BAD: error stays after user corrects the field
// RHF should auto-clear on re-validation, but custom error handling can leave stale errors

// GOOD: clear field error when user modifies the field
<input
  {...register("email", {
    onChange: () => clearErrors("email"), // clear error as soon as user starts fixing
  })}
/>
```
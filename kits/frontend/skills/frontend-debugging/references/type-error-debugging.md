# Type Error Debugging

Systematic flowchart for resolving TypeScript type errors in React applications.

## Debugging Flowchart

```
START: You see a TypeScript error
  |
  v
[Step 1] READ THE ERROR
  - What type does TypeScript expect?
  - What type did it receive?
  - Where exactly (file, line, variable)?
  |
  v
[Step 2] IDENTIFY THE CONSTRAINT
  - Is it a property missing? (X does not have property Y)
  - Is it a type mismatch? (Type A is not assignable to Type B)
  - Is it a union narrowing issue? (Type A | B cannot be used as Type A)
  - Is it a generic inference failure? (Type T inferred as unknown)
  |
  v
[Step 3] CHECK INFERENCE
  - Hover over the variable in your editor
  - Is the inferred type what you expected?
  - If not: which step in the chain lost the type?
  |
  v
[Step 4] ADD EXPLICIT ANNOTATION
  - Add type annotation where inference fails
  - Use `satisfies` to check type without overriding inference
  - Prefer annotation over `as` casting
  |
  v
[Step 5] VERIFY FIX
  - Does the error disappear?
  - Does runtime behavior still match?
  - No new errors introduced?
  |
  v
  DONE
```

## Common Error Patterns and Fixes

### Pattern 1: Missing Property

```
Type '{ name: string }' is not assignable to type '{ name: string; id: string }'.
  Property 'id' is missing in type '{ name: string }'.
```

**Fix**: Add the missing property or make it optional in the interface.

```tsx
// Option A: Add the missing property
const data: Product = { name: "Widget", id: "1" };

// Option B: Make property optional in type
type Product = { name: string; id?: string };

// Option C: Use partial type for input
type ProductInput = Partial<Product>;
```

### Pattern 2: Type Mismatch (string vs number)

```
Type 'string' is not assignable to type 'number'.
```

**Fix**: Convert the value or fix the source type.

```tsx
// Problem: HTML input returns string, but type expects number
<input type="number" onChange={(e) => setValue(Number(e.target.value))} />

// Or use z.coerce.number() in Zod schema
const schema = z.object({ price: z.coerce.number() });
```

### Pattern 3: Union Narrowing

```
Property 'name' does not exist on type 'string | undefined'.
  Property 'name' does not exist on type 'undefined'.
```

**Fix**: Narrow the type before accessing properties.

```tsx
// Option A: Optional chaining
const name = user?.name;

// Option B: Null check
if (user) {
  const name = user.name;
}

// Option C: Default value
const name = user?.name ?? "Unknown";

// Option D: Discriminated union
if (result.ok) {
  const data = result.data; // TypeScript knows data is not undefined
}
```

### Pattern 4: Generic Inference Failure

```
Type 'unknown' is not assignable to type 'Product[]'.
```

**Fix**: Provide explicit generic type or validate with Zod.

```tsx
// Problem: JSON.parse returns unknown
const data: Product[] = JSON.parse(text); // unsafe - use as
const data = JSON.parse(text) as Product[]; // still unsafe at runtime

// Fix: Validate with Zod
const data = ProductSchema.array().parse(JSON.parse(text)); // safe
```

### Pattern 5: Event Handler Type

```
Type '(event: MouseEvent) => void' is not assignable to type '(event: MouseEvent<HTMLDivElement>) => void'.
```

**Fix**: Use React's typed event handlers.

```tsx
// Problem: generic event type
const handleClick = (event: MouseEvent) => { ... };

// Fix: React-specific event type
const handleClick = (event: MouseEvent<HTMLDivElement>) => { ... };

// Or inline:
<div onClick={(e) => { /* e is correctly typed */ }} />
```

### Pattern 6: Object Literal As Type

```
Type '{ a: 1 }' is not assignable to type '{ a: number }'.
```

**Fix**: Use `satisfies` to check type while preserving literal types.

```tsx
// Problem: literal types get widened
const config: Config = { a: 1 }; // a is typed as number, not 1

// Fix: satisfies preserves literal types
const config = { a: 1 } satisfies Config; // a is still typed as 1, but validated against Config
```

### Pattern 7: React Component Props Type Error

```
Type '() => JSX.Element' is not assignable to type 'ReactNode'.
```

**Fix**: Don't pass a function as children. Call it or use `children: ReactNode`.

```tsx
// Problem: passing function as children
<Wrapper>{() => <Content />}</Wrapper> // function, not ReactNode

// Fix 1: Call the function
<Wrapper><Content /></Wrapper>

// Fix 2: If you need render prop, type it correctly
type WrapperProps = { children: (data: SomeData) => ReactNode };
```

### Pattern 8: useState Type Inference

```
Type 'null' is not assignable to type 'Product'.
```

**Fix**: Include null in the state type or use the generic parameter.

```tsx
// Problem: initial value is null but state type is Product
const [product, setProduct] = useState(null); // inferred as null, can't assign Product

// Fix: explicit type with null
const [product, setProduct] = useState<Product | null>(null);

// Fix: provide initial value that matches type
const [product, setProduct] = useState<Product>(defaultProduct);
```

### Pattern 9: useEffect Dependency Type Error

```
Parameter 'deps' implicitly has an 'any' type.
```

**Fix**: This is usually not a type error but an ESLint warning. Ensure `react-hooks/exhaustive-deps` rule is configured.

```tsx
useEffect(() => {
  doSomething(userId);
}, [userId]); // explicit dependency array
```

### Pattern 10: Keyof / Index Signature

```
Element implicitly has an 'any' type because expression of type 'string' can't be used to index type 'Record<string, Product>'.
```

**Fix**: Use `keyof` to type the index properly.

```tsx
// Problem: string index on Record
const product = products[someKey]; // someKey is string, not keyof products

// Fix 1: Type the key
const product = products[someKey as keyof typeof products];

// Fix 2: Use a Map or explicit key type
type ProductMap = Record<string, Product>;
const product: Product | undefined = products[someKey];
```

## Diagnostic Tools

### Hover to check inferred type

Hover over any variable in VS Code / your editor to see its inferred type. This is the fastest way to diagnose type errors.

### satisfies operator

```tsx
// satisfies checks the type without widening
const themes = {
  light: { bg: "#fff", text: "#000" },
  dark: { bg: "#000", text: "#fff" },
} satisfies Record<string, { bg: string; text: string }>;

// themes.light.bg is still "#fff" (literal), not string
// But the structure is validated against the type
```

### Type narrowing in conditional

```tsx
// Before narrowing
const value: string | number = getValue();
value.toUpperCase(); // Error: toUpperCase doesn't exist on number

// After narrowing
if (typeof value === "string") {
  value.toUpperCase(); // OK: TypeScript knows value is string
}
```

### Discriminated union narrowing

```tsx
type Result<T> = { ok: true; data: T } | { ok: false; error: string };

function handle(result: Result<Product>) {
  if (result.ok) {
    result.data; // TypeScript knows data is Product
    result.error; // Error: property doesn't exist on this branch
  } else {
    result.error; // TypeScript knows error is string
    result.data; // Error: property doesn't exist on this branch
  }
}
```

## Anti-patterns

### Using `as` to silence errors

```tsx
// BAD: as doesn't validate at runtime
const product = data as Product; // if data shape is wrong, runtime crash

// GOOD: validate with Zod
const product = ProductSchema.parse(data); // runtime validation

// GOOD: satisfies for type checking
const product = data satisfies Product; // compile-time check, preserves inference
```

### Using `@ts-ignore` or `@ts-expect-error`

```tsx
// BAD: suppresses the error without fixing it
// @ts-ignore
product.nonExistentProperty;

// Acceptable: only when you've verified the error is a known TypeScript bug
// @ts-expect-error - TypeScript 5.x inference bug, tracked in #12345
product.tempProperty;
```

### Over-typing

```tsx
// BAD: redundant type annotation where inference is correct
const name: string = "Widget"; // inferred as string anyway

// GOOD: annotate only where inference fails or is ambiguous
const [product, setProduct] = useState<Product | null>(null); // inference would be null without annotation
```
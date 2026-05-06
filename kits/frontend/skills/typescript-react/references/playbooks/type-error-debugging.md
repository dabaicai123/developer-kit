# Type Error Debugging Playbook

Systematic flowchart for debugging React TypeScript errors, with common error patterns and fixes.

## Debugging Flowchart

```
START: You see a TypeScript error
  |
  v
[Step 1] READ THE ERROR MESSAGE
  - What type does TypeScript expect? (the "to" type)
  - What type did it receive? (the "from" type)
  - Where exactly? (file, line, variable name)
  - Is there a constraint mentioned? (extends, implements, satisfies)
  |
  v
[Step 2] IDENTIFY THE ERROR CATEGORY
  |
  "Type X is not assignable to type Y"
  → Prop mismatch, type widening, missing field
  → Go to Category A
  |
  "Object is possibly null/undefined"
  → Missing null check, useRef type issue
  → Go to Category B
  |
  "Property X does not exist on type Y"
  → Wrong union branch, missing type field
  → Go to Category C
  |
  "Cannot find name X" / "Parameter implicitly has any"
  → Missing import, untyped parameter
  → Go to Category D
  |
  Generic inference failure (Type inferred as unknown/any)
  → Missing type parameter, inference chain broken
  → Go to Category E
  |
  v
[Step 3] CHECK INFERENCE CHAIN
  - Hover over the failing variable in your editor
  - Is the inferred type narrower or wider than expected?
  - Trace backward: where in the chain did the type widen?
  - Common widening points:
    * JSON.parse → unknown
    * Object.entries → [string, T][]
    * Array.find → T | undefined
    * Event.target → EventTarget (not HTMLInputElement)
  |
  v
[Step 4] ADD EXPLICIT TYPE ANNOTATION
  - At the narrowest point in the chain
  - Prefer annotation over `as` casting
  - Use `satisfies` to validate without widening
  |
  Annotation didn't fix it? → Check if the annotation is correct
  Annotation fixed it but feels heavy? → Consider `satisfies` or narrowing
  |
  v
[Step 5] USE satisfies WHERE APPROPRIATE
  - `satisfies` validates shape without changing inferred type
  - Preserves literal types and exact property names
  - Use for: config objects, variant maps, Zod schema shapes
  |
  v
[Step 6] USE z.infer FOR FORM/API DATA
  - Don't manually type form or API response shapes
  - Define a Zod schema, then use z.infer<typeof Schema>
  - Runtime validation + type derivation in one step
  - No risk of schema/type mismatch
  |
  v
[Step 7] VERIFY THE FIX
  - Error disappears?
  - No new errors introduced?
  - Runtime behavior still matches?
  - If new errors: go back to Step 1 with the new error
  |
  v
DONE
```

## Category A: "Type X is not assignable to type Y" in Props

The most common React TypeScript error. Usually caused by type widening or missing required props.

### Case A1: String literal widened to string

```
Type 'string' is not assignable to type '"primary" | "secondary" | "ghost"'
```

**Cause**: TypeScript infers `string` from a variable, but the type expects a specific literal union.

**Fix**: Add `as const` or use explicit type annotation.

```tsx
// PROBLEM: variant inferred as string, not the literal union
const variant = 'primary'; // type: string
<Button variant={variant} />; // Error: string not assignable to 'primary' | 'secondary' | 'ghost'

// FIX 1: as const on the value
const variant = 'primary' as const; // type: 'primary'
<Button variant={variant} />; // OK

// FIX 2: explicit type annotation
const variant: ButtonVariant = 'primary'; // type: 'primary' | 'secondary' | 'ghost'
<Button variant={variant} />; // OK

// FIX 3: inline (simplest)
<Button variant="primary" />; // OK — inline string literal is narrowed
```

### Case A2: Missing required prop

```
Type '{ name: string }' is not assignable to type '{ name: string; id: string }'.
  Property 'id' is missing.
```

**Cause**: Component requires a prop that you didn't pass.

**Fix**: Add the prop or make it optional in the interface.

```tsx
// PROBLEM: missing id
<UserCard name="Alice" />; // Error: id is required

// FIX 1: pass the missing prop
<UserCard name="Alice" id="user-1" />;

// FIX 2: make it optional in the interface
interface UserCardProps {
  name: string;
  id?: string; // optional
}

// FIX 3: provide default in destructuring
function UserCard({ name, id = 'unknown' }: UserCardProps) {
  return <div>{name}</div>;
}
```

### Case A3: Extra prop not in interface

```
Type '{ name: string; role: string }' is not assignable to type '{ name: string }'.
  Object literal may only specify known properties, and 'role' does not exist.
```

**Cause**: Passing a prop the component doesn't accept.

```tsx
// PROBLEM: role not in UserCardProps
<UserCard name="Alice" role="admin" />; // Error: unknown prop

// FIX 1: add role to the interface
interface UserCardProps {
  name: string;
  role?: 'admin' | 'user';
}

// FIX 2: extend with ...rest if you're wrapping
interface UserCardProps extends ComponentPropsWithoutRef<'div'> {
  name: string;
}
// Now all div props are accepted
```

### Case A4: ReactNode type mismatch

```
Type '() => JSX.Element' is not assignable to type 'ReactNode'
```

**Cause**: Passing a function as children instead of calling it.

```tsx
// PROBLEM: function passed as children
<Wrapper>{() => <Content />}</Wrapper>; // function, not ReactNode

// FIX 1: call the function
<Wrapper><Content /></Wrapper>;

// FIX 2: if render prop is intentional, type children as function
interface WrapperProps {
  children: (data: SomeData) => React.ReactNode;
}
```

## Category B: "Object is possibly null/undefined"

### Case B1: useRef null access

```
Object is possibly 'null'. ts(2531)
```

```tsx
// PROBLEM: useRef current can be null
const inputRef = useRef<HTMLInputElement>(null);
inputRef.current.focus(); // Error: current is HTMLInputElement | null

// FIX 1: optional chaining (most common)
inputRef.current?.focus();

// FIX 2: null guard
if (inputRef.current) {
  inputRef.current.focus(); // narrowed to HTMLInputElement
}

// FIX 3: non-null assertion (use only when you're certain it's set)
inputRef.current!.focus(); // risky — crashes at runtime if null
```

### Case B2: useState nullable state

```
Object is possibly 'null'.
```

```tsx
// PROBLEM: accessing properties on nullable state
const [user, setUser] = useState<User | null>(null);
user.name; // Error: user could be null

// FIX 1: null check
if (user) {
  user.name; // OK — narrowed to User
}

// FIX 2: optional chaining
user?.name; // OK — returns string | undefined

// FIX 3: default value
const name = user?.name ?? 'Unknown';
```

### Case B3: Array.find returns T | undefined

```
Object is possibly 'undefined'.
```

```tsx
// PROBLEM: find returns undefined when element not found
const user = users.find(u => u.id === id);
user.name; // Error: user is User | undefined

// FIX: null check before access
const user = users.find(u => u.id === id);
if (user) {
  user.name; // OK
} else {
  handleNotFound(id);
}
```

## Category C: "Property X does not exist on type Y"

### Case C1: Wrong union branch

```
Property 'data' does not exist on type '{ status: "idle" } | { status: "loading" } | ...
```

**Cause**: Accessing a property that only exists on one union branch without narrowing.

```tsx
// PROBLEM: data only exists on the 'success' branch
type State = { status: 'idle' } | { status: 'success'; data: User[] };
state.data; // Error: data not on 'idle' branch

// FIX: narrow before accessing
if (state.status === 'success') {
  state.data; // OK — narrowed to { status: 'success'; data: User[] }
}
```

### Case C2: Event target property mismatch

```
Property 'value' does not exist on type 'EventTarget'.
```

**Cause**: `e.target` in React events is typed as `EventTarget`, not the specific HTML element.

```tsx
// PROBLEM: generic event handler
function handleChange(e: React.ChangeEvent) {
  e.target.value; // Error: EventTarget has no 'value'
}

// FIX: type the event with the specific element
function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
  e.target.value; // OK — target is HTMLInputElement which has value
}
```

### Case C3: keyof access with dynamic key

```
Element implicitly has an 'any' type because expression of type 'string' can't be used to index type.
```

```tsx
// PROBLEM: dynamic key with string type
const field = 'name'; // type: string
const value = config[field]; // Error: string can't index Config

// FIX 1: const assertion
const field = 'name' as const; // type: 'name'
const value = config[field]; // OK

// FIX 2: keyof type
const field: keyof Config = 'name';
const value = config[field]; // OK
```

## Category D: Missing Import / Implicit Any

### Case D1: "Cannot find name"

```
Cannot find name 'UserCardProps'.
```

**Fix**: Add the import.

```tsx
// PROBLEM: type used without import
function render(props: UserCardProps) { ... } // Error: UserCardProps not imported

// FIX: import the type
import { type UserCardProps } from './types';
function render(props: UserCardProps) { ... }
```

### Case D2: "Parameter implicitly has 'any' type"

```
Parameter 'e' implicitly has an 'any' type.
```

**Fix**: Add explicit type annotation.

```tsx
// PROBLEM: untyped event handler parameter
function handleClick(e) { ... } // Error: implicit any

// FIX: explicit React event type
function handleClick(e: React.MouseEvent<HTMLButtonElement>) { ... }
```

## Category E: Generic Inference Failure

### Case E1: Generic not inferred from usage

```
Type 'unknown' is not assignable to type 'Product[]'.
```

```tsx
// PROBLEM: JSON.parse returns unknown
const data = JSON.parse(responseText); // type: unknown
data.map(p => p.name); // Error: unknown has no map

// FIX 1: validate with Zod (best)
const data = ProductSchema.array().parse(JSON.parse(responseText)); // type: Product[]

// FIX 2: explicit generic (risky at runtime)
const data: Product[] = JSON.parse(responseText); // no runtime validation

// FIX 3: use as (also risky)
const data = JSON.parse(responseText) as Product[]; // no runtime validation
```

### Case E2: useState initial value determines wrong type

```
Type 'null' is not assignable to type 'Product'.
```

```tsx
// PROBLEM: useState infers from initial value
const [product, setProduct] = useState(null); // type: null
setProduct({ name: 'Widget' }); // Error: Product not assignable to null

// FIX: explicit generic with union
const [product, setProduct] = useState<Product | null>(null);
setProduct({ name: 'Widget' }); // OK
```

### Case E3: Generic component inference breaks

```tsx
// PROBLEM: T not inferred when generic props are not connected
interface ListProps<T> {
  items: T[];
  onSelect: (item: T) => void;
}

// If items is passed but onSelect isn't, T may not be inferred
<List items={products} onSelect={(item) => ...} /> // T inferred as Product — OK
<List items={[]} onSelect={(item) => ...} /> // T inferred as never — bad

// FIX: connect generic params through inference
// Always pass items first so T is inferred from items
<List items={products as Product[]} onSelect={(item) => handleSelect(item)} />
```

## satisfies vs Type Annotation Decision Guide

```
When to use what?
  |
  v
Need to validate shape AND preserve literal types?
  → satisfies (e.g., theme config, variant maps)
  |
  Need the variable to be exactly type T (no extras)?
  → : T annotation (e.g., function params, API response types)
  |
  Need runtime validation too?
  → Zod parse (e.g., form data, API responses)
  |
  Need both validation and literal preservation?
  → as const satisfies T
```

## Anti-patterns Checklist

- `as` type assertion to silence errors — fix the source type instead
- `@ts-ignore` or `@ts-expect-error` without a documented reason — fix the error instead
- `any` for event handler parameters — use explicit React event types
- `any` for third-party callback parameters — use `unknown` + narrowing
- Manual type duplication for Zod-validated data — use `z.infer<typeof Schema>`
- Over-annotation where inference is correct — annotate only where inference fails
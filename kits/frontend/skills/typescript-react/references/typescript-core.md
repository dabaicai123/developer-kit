# TypeScript Core Patterns

Type narrowing, union/intersection types, generics with constraints, utility types, `as const`, and `satisfies`.

## Type Narrowing

Narrowing converts a broad type to a specific type within a branch. TypeScript supports several narrowing constructs.

### typeof narrowing

Use `typeof` for primitive types. Works for `string`, `number`, `boolean`, `symbol`, `undefined`, `object`, `function`.

```typescript
function formatValue(value: string | number): string {
  if (typeof value === 'string') {
    return value.trim();  // narrowed to string
  }
  return value.toFixed(2);  // narrowed to number
}
```

Caveat: `typeof null === 'object'`. Always check for `null` explicitly before `typeof` on potentially null objects.

```typescript
function processNullable(obj: { name: string } | null) {
  if (obj === null) return 'empty';  // explicit null check first
  return obj.name;  // narrowed to { name: string }
}
```

### instanceof narrowing

Use `instanceof` for class-based types. Works with built-in classes (`Error`, `Date`, `Array`, `HTMLElement`) and custom classes.

```typescript
function handleError(err: Error | string): string {
  if (err instanceof Error) {
    return err.message;  // narrowed to Error
  }
  return err;  // narrowed to string
}

function processElement(el: HTMLInputElement | HTMLTextAreaElement) {
  if (el instanceof HTMLInputElement) {
    return el.value;  // narrowed — has input-specific properties
  }
  return el.value;  // narrowed to HTMLTextAreaElement
}
```

### in operator narrowing

Use the `in` operator to check for property existence. Best for differentiating object shapes without a class hierarchy.

```typescript
interface ApiResponse {
  type: 'success' | 'error';
}

type SuccessResponse = ApiResponse & { type: 'success'; data: User[] };
type ErrorResponse = ApiResponse & { type: 'error'; message: string };

function handleResponse(res: SuccessResponse | ErrorResponse) {
  if ('data' in res) {
    return res.data;  // narrowed to SuccessResponse
  }
  return res.message;  // narrowed to ErrorResponse
}
```

### Discriminated union narrowing

The most powerful narrowing pattern for React state modeling. A discriminant field (conventionally named `status`, `type`, `kind`, or `variant`) with literal values enables exhaustive type narrowing.

```typescript
type AsyncState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };

function renderState(state: AsyncState<User>) {
  switch (state.status) {
    case 'idle':
      return <Placeholder />;
    case 'loading':
      return <Spinner />;
    case 'success':
      // TypeScript knows state.data exists here — no optional chaining needed
      return <UserCard user={state.data} />;
    case 'error':
      // TypeScript knows state.error exists here
      return <ErrorBanner error={state.error} />;
  }
}
```

Exhaustiveness check with `never`:

```typescript
function renderState(state: AsyncState<User>) {
  switch (state.status) {
    case 'idle':
      return <Placeholder />;
    case 'loading':
      return <Spinner />;
    case 'success':
      return <UserCard user={state.data} />;
    case 'error':
      return <ErrorBanner error={state.error} />;
    default:
      // If a new status is added to AsyncState but not handled above,
      // TypeScript will error here because 'state' is not 'never'
      const _exhaustive: never = state;
      return _exhaustive;
  }
}
```

## Union and Intersection Types

### Union types (`A | B`)

A value matching `A | B` can be either `A` or `B`. You must narrow before accessing type-specific properties.

```typescript
// Literal union — finite set of known values
type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';

// Mixed union — different shapes
type ModalContent = string | JSX.Element | { title: string; body: string };
```

### Intersection types (`A & B`)

A value matching `A & B` must satisfy both `A` and `B`. Use for composing types.

```typescript
interface BaseProps {
  className?: string;
  id?: string;
}

interface ActionProps {
  onClick: () => void;
  disabled?: boolean;
}

type ButtonProps = BaseProps & ActionProps & {
  variant: ButtonVariant;
};
```

Prefer `interface` + `extends` for object shapes (supports declaration merging). Use `type` + `&` when mixing unions with objects or when you need computed types.

```typescript
// Prefer extends for pure object composition
interface ButtonProps extends BaseProps, ActionProps {
  variant: ButtonVariant;
}

// Use & when unions are involved
type Clickable = { onClick: () => void };
type Hoverable = { onMouseEnter: () => void };
type Interactive = Clickable & Hoverable;
```

## Generics with Constraints

### Basic generic functions

```typescript
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const user = { name: 'Alice', age: 30 };
getProperty(user, 'name');  // returns string
getProperty(user, 'age');   // returns number
getProperty(user, 'email'); // ❌ Error: 'email' not in keyof typeof user
```

### Generic constraints with `extends`

```typescript
// Constrain T to objects with an 'id' property
function findById<T extends { id: string }>(items: T[], id: string): T | undefined {
  return items.find(item => item.id === id);
}

// Constrain to a specific interface
interface HasTimestamp {
  createdAt: Date;
}

function sortByDate<T extends HasTimestamp>(items: T[]): T[] {
  return [...items].sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
}
```

### Generic React components

```typescript
// Generic list component
interface ListProps<T> {
  items: T[];
  renderItem: (item: T) => JSX.Element;
  keyExtractor: (item: T) => string;
}

function List<T>({ items, renderItem, keyExtractor }: ListProps<T>) {
  return (
    <ul>
      {items.map(item => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}

// Usage — T is inferred from items
<List
  items={users}
  renderItem={(user) => <UserCard user={user} />}
  keyExtractor={(user) => user.id}
/>
```

See [component-patterns.md](component-patterns.md) for advanced generic component patterns.

## Utility Types

### Partial<T> and Required<T>

`Partial<T>` makes all properties optional. `Required<T>` makes all properties required.

```typescript
interface UserUpdate {
  name: string;
  email: string;
  avatarUrl: string;
}

// Partial — for update payloads where all fields are optional
type UserUpdatePayload = Partial<UserUpdate>;

// Only send changed fields
const payload: UserUpdatePayload = { name: 'New Name' };  // valid — other fields omitted

// Required — ensure all fields are present at runtime
type CompleteUser = Required<UserUpdate>;
```

### Pick<T, K> and Omit<T, K>

`Pick<T, K>` selects specific properties. `Omit<T, K>` removes specific properties.

```typescript
interface FullUser {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  createdAt: Date;
  updatedAt: Date;
}

// Pick — expose only safe fields in API responses
type PublicUser = Pick<FullUser, 'id' | 'name' | 'email' | 'createdAt'>;

// Omit — exclude sensitive fields
type SafeUser = Omit<FullUser, 'passwordHash'>;

// Omit — remove native props we override
interface CustomButtonProps extends Omit<ComponentPropsWithoutRef<'button'>, 'style'> {
  variant: ButtonVariant;
}
```

### Record<K, V>

`Record<K, V>` creates an object type with keys `K` and values `V`.

```typescript
// Route configuration map
type RouteConfig = Record<string, { component: JSX.Element; isProtected: boolean }>;

const routes: RouteConfig = {
  '/': { component: <HomePage />, isProtected: false },
  '/dashboard': { component: <Dashboard />, isProtected: true },
};

// Translation map
type TranslationMap = Record<string, string>;
const en: TranslationMap = { 'greeting': 'Hello', 'farewell': 'Goodbye' };
```

### Exclude<T, U> and Extract<T, U>

`Exclude<T, U>` removes types from `T` that are assignable to `U`. `Extract<T, U>` selects types from `T` assignable to `U`.

```typescript
type Status = 'idle' | 'loading' | 'success' | 'error';

// Exclude — remove error from status for optimistic UI
type OptimisticStatus = Exclude<Status, 'error'>;  // 'idle' | 'loading' | 'success'

// Extract — get only terminal states
type TerminalStatus = Extract<Status, 'success' | 'error'>;  // 'success' | 'error'

// Exclude — remove specific native props
type DivWithoutAlign = Exclude<keyof HTMLDivElement, 'align'>;
```

### Practical combination patterns

```typescript
// Create a variant map where each variant maps to its props
type VariantMap = {
  primary: { color: 'blue'; isBold: true };
  secondary: { color: 'gray'; isBold: false };
  danger: { color: 'red'; isBold: true };
};

// Extract variant names
type Variant = keyof VariantMap;  // 'primary' | 'secondary' | 'danger'

// Get props for a specific variant
type VariantProps<V extends Variant> = VariantMap[V];

// Create component props using Pick + discriminated union
type ButtonProps =
  | ({ variant: 'primary' } & VariantMap['primary'])
  | ({ variant: 'secondary' } & VariantMap['secondary'])
  | ({ variant: 'danger' } & VariantMap['danger']);
```

## as const

`as const` asserts that a value has its most specific literal type — string literals, numeric literals, `true`/`false` (not widened `string`, `number`, `boolean`).

```typescript
// Without as const — types are widened
const directions = ['up', 'down', 'left', 'right'];
// type: string[] — each element is just 'string'

// With as const — types are literal
const directions = ['up', 'down', 'left', 'right'] as const;
// type: readonly ['up', 'down', 'left', 'right']

type Direction = typeof directions[number];  // 'up' | 'down' | 'left' | 'right'
```

Common patterns:

```typescript
// Status enum alternative
const STATUS = {
  idle: 'idle',
  loading: 'loading',
  success: 'success',
  error: 'error',
} as const;

type StatusKey = keyof typeof STATUS;       // 'idle' | 'loading' | 'success' | 'error'
type StatusValue = typeof STATUS[StatusKey]; // 'idle' | 'loading' | 'success' | 'error'

// Route configuration
const ROUTES = {
  home: { path: '/', isProtected: false },
  dashboard: { path: '/dashboard', isProtected: true },
  settings: { path: '/settings', isProtected: true },
} as const;
```

Combine `as const` with `satisfies` for validation + literal preservation:

```typescript
const theme = {
  colors: { primary: '#3b82f6', danger: '#ef4444' },
  spacing: { sm: 4, md: 8, lg: 16 },
} as const satisfies ThemeConfig;

// 'primary' is still '#3b82f6' (literal), validated against ThemeConfig
```

## satisfies

`satisfies` validates that an expression matches a type without changing the expression's inferred type. This preserves literal types, property names, and union breadth.

```typescript
type ColorMap = Record<string, string>;

// With satisfies — validation passes, exact keys preserved
const colors = {
  primary: '#3b82f6',
  danger: '#ef4444',
  success: '#22c55e',
} satisfies ColorMap;

// You can access exact keys — TypeScript knows 'primary' exists
colors.primary;  // '#3b82f6'

// Without satisfies (using type annotation) — keys widened to string
const colors: ColorMap = {
  primary: '#3b82f6',
  danger: '#ef4444',
  // typo like 'primar' still satisfies Record<string, string>
};
colors.primary;  // string — compiler doesn't know exact keys
```

When to use `satisfies` vs type annotation:

| Scenario | Use | Reason |
|---|---|---|
| Config/theme objects where you need exact key names | `satisfies` | Preserves literal keys |
| Variable where the type must be exactly T | `: T` annotation | Narrows to T |
| Validating shape while keeping inferred literals | `satisfies` | Validates + preserves |
| Function parameters | `: T` annotation | Explicit contract |
| Return types | `: T` annotation | Public API contract |

```typescript
// satisfies + as const — full power
const VARIANTS = {
  primary: { bg: 'bg-blue-500', text: 'text-white' },
  secondary: { bg: 'bg-gray-200', text: 'text-gray-800' },
  danger: { bg: 'bg-red-500', text: 'text-white' },
} as const satisfies Record<string, { bg: string; text: string }>;

type Variant = keyof typeof VARIANTS;  // 'primary' | 'secondary' | 'danger'
```

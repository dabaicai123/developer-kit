---
name: typescript-react
description: "TypeScript patterns for React and Next.js: interface vs type, discriminated unions for state, explicit event handler types, useRef generics, useOptimistic typing, satisfies validation, and SSR/CSR type safety. Use when writing typed React/Next.js components, debugging type errors, or resolving hydration mismatches."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# TypeScript for React and Next.js

TypeScript patterns for our Next.js + Tailwind v4 + TypeScript stack. No prebuilt UI control libraries for ordinary UI - we write our own components.

Project UI policy: do NOT use prebuilt UI control libraries for ordinary UI unless explicitly requested. Write project-owned components with semantic HTML and project-owned CSS/Tailwind styling.

## Rule Taxonomy

Every rule in this skill follows a three-tier taxonomy:

- **[HARD RULE]** - Always enforce. Violations cause type errors, runtime bugs, or hydration failures. No exceptions.
- **[DEFAULT]** - Recommended for most cases. Override when you have a documented reason.
- **[SITUATIONAL]** - Context-dependent. Apply when the specific scenario matches.

When in doubt, follow [HARD RULE] first, then [DEFAULT], then consider [SITUATIONAL].

## When to use this skill

- Writing typed React components, hooks, or event handlers
- Choosing between `interface` and `type` for props and state
- Modeling component state with discriminated unions instead of boolean flags
- Typing `useRef`, `useState`, `useReducer`, `useContext` correctly
- Debugging TypeScript errors in React or Next.js code
- Resolving SSR/CSR hydration mismatches
- Typing Next.js App Router specifics: async params, Server Actions, route handlers
- Implementing polymorphic or compound components with TypeScript
- Understanding useEffect dependency bugs from a type perspective

## Instructions

### 1. Use `interface` for props, `type` for unions

[HARD RULE] Use `interface` for component props and state shapes. Use `type` for unions, intersections, and derived types.

`interface` supports declaration merging and is the conventional way to define object shapes in React. `type` handles everything `interface` cannot - unions, intersections, mapped types, conditional types.

```typescript
// Props - always interface
interface UserCardProps {
  name: string;
  avatarUrl: string;
  isActive: boolean;
}

// Union state - always type
type RequestState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };

// Intersection - always type
type ButtonProps = BaseProps & VariantProps;
```

```typescript
// WRONG - type for props (unusual, breaks declaration merging convention)
type UserCardProps = {
  name: string;
  avatarUrl: string;
};

// WRONG - interface for union (interfaces cannot express unions)
interface RequestState {
  status: 'idle' | 'loading' | 'success' | 'error';
  data?: unknown;     // loses the discriminated union narrowing
  error?: Error;      // all fields optional, no type safety
}
```

### 2. Never use React.FC

[HARD RULE] Do not use `React.FC` or `React.FunctionComponent`. Plain function signatures keep props, generics, return inference, and `children` explicit without adding a wrapper type.

```typescript
// Correct - plain function, explicit props
function UserCard({ name, avatarUrl }: UserCardProps) {
  return <div>{name}</div>;
}

// Arrow function variant (equally valid)
const UserCard = ({ name, avatarUrl }: UserCardProps) => {
  return <div>{name}</div>;
};
```

```typescript
// WRONG - React.FC adds a wrapper type without improving the component signature
const UserCard: React.FC<UserCardProps> = ({ name }) => {
  return <div>{name}</div>;
};
```

### 3. Discriminated unions for state

[HARD RULE] Model component state with discriminated unions. Never use multiple boolean flags (`isLoading`, `isError`, `isSuccess`).

Discriminated unions enforce that each state variant carries exactly the right data. The `status` discriminant enables exhaustive narrowing - the compiler catches missing branches.

```typescript
type FetchState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; error: Error };

function DataDisplay({ state }: { state: FetchState<User> }) {
  switch (state.status) {
    case 'idle':
      return <p>No data loaded yet.</p>;
    case 'loading':
      return <p>Loading...</p>;
    case 'success':
      return <UserProfile user={state.data} />;
    case 'error':
      return <ErrorMessage error={state.error} />;
    // No default needed - compiler catches missing cases
  }
}
```

```typescript
// WRONG - boolean flags allow impossible states (loading + error simultaneously)
interface BadState {
  isLoading: boolean;
  isError: boolean;
  isSuccess: boolean;
  data?: User;    // optional everywhere, no guarantee when success
  error?: Error;  // optional everywhere, no guarantee when error
}
```

### 4. Explicit event handler types

[HARD RULE] Use explicit React event types for handlers. Never rely on inference from inline handlers when extracting callbacks.

```typescript
import { type ChangeEvent, type FormEvent, type KeyboardEvent } from 'react';

// Input change handler
function handleSearchChange(e: ChangeEvent<HTMLInputElement>) {
  setSearchQuery(e.target.value);  // e.target is HTMLInputElement, not generic EventTarget
}

// Form submit handler
function handleSubmit(e: FormEvent<HTMLFormElement>) {
  e.preventDefault();
  submitForm(formData);
}

// Keyboard handler
function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
  if (e.key === 'Enter') {
    e.preventDefault();
    handleSearch();
  }
}

// Focus handler
function handleFocus(e: FocusEvent<HTMLInputElement>) {
  setIsFocused(true);
}
```

```typescript
// WRONG - implicit any when extracting handlers without types
function handleChange(e) {  // 鉂?Parameter 'e' implicitly has an 'any' type
  setSearch(e.target.value); // e.target is untyped
}
```

### 5. useRef with specific element types

[HARD RULE] Always provide a specific element type to `useRef`. Never use `useRef<HTMLElement>` or `useRef<any>`.

```typescript
// Specific element type - correct
const inputRef = useRef<HTMLInputElement>(null);
const canvasRef = useRef<HTMLCanvasElement>(null);
const dialogRef = useRef<HTMLDialogElement>(null);
const scrollRef = useRef<HTMLDivElement>(null);

// Access DOM methods safely
inputRef.current?.focus();
inputRef.current?.setCustomValidity('Invalid email');
dialogRef.current?.showModal();
```

```typescript
// WRONG - generic HTMLElement loses element-specific methods
const inputRef = useRef<HTMLElement>(null);
inputRef.current?.focus();      // works - HTMLElement has focus
inputRef.current?.setCustomValidity('...');  // 鉂?HTMLElement lacks this method

// WRONG - any disables all type checking
const inputRef = useRef<any>(null);
```

### 6. Destructure props with defaults

[DEFAULT] Destructure props in the function signature and provide defaults inline. This makes the component API self-documenting and avoids `undefined` checks in the body.

```typescript
interface BadgeProps {
  label: string;
  variant?: 'info' | 'success' | 'warning' | 'error';
  size?: 'sm' | 'md' | 'lg';
  isDismissible?: boolean;
}

function Badge({
  label,
  variant = 'info',
  size = 'md',
  isDismissible = false,
}: BadgeProps) {
  return (
    <span className={`badge badge-${variant} badge-${size}`}>
      {label}
      {isDismissible && <button onClick={() => dismiss()}>x</button>}
    </span>
  );
}
```

### 7. Use `satisfies` for type validation

[DEFAULT] Use `satisfies` to validate that an expression matches a type without widening or narrowing the inferred type. This preserves literal types and exact property names.

```typescript
type ThemeConfig = {
  colors: Record<string, string>;
  spacing: Record<string, number>;
};

const theme = {
  colors: {
    primary: '#3b82f6',
    secondary: '#8b5cf6',
    danger: '#ef4444',
  },
  spacing: {
    sm: 4,
    md: 8,
    lg: 16,
  },
} satisfies ThemeConfig;

// 'primary' is preserved as a literal string key, not widened to string
theme.colors.primary;  // string - type is validated, literals preserved
```

```typescript
// Without satisfies - type is widened, no validation
const theme: ThemeConfig = {
  colors: {
    primary: '#3b82f6',  // compiler only knows Record<string, string>
    // typo like 'primar' would still satisfy Record<string, string>
  },
  spacing: {
    sm: 4,  // compiler only knows Record<string, number>
  },
};
```

Use `satisfies` for:
- Style/theme configuration objects
- Route definitions where you need exact key names
- Component variant maps
- Zod schema shape validation

### 8. ComponentPropsWithoutRef over ComponentProps

[DEFAULT] Use `ComponentPropsWithoutRef<'element'>` when extending native element props. `ComponentPropsWithRef` includes the `ref` prop which conflicts with `forwardRef` composition.

```typescript
import { type ComponentPropsWithoutRef } from 'react';

// Extend button props without pulling in ref
interface ButtonProps extends ComponentPropsWithoutRef<'button'> {
  variant?: 'primary' | 'secondary' | 'ghost';
  isLoading?: boolean;
}

function Button({ variant = 'primary', isLoading, children, ...rest }: ButtonProps) {
  return (
    <button
      className={`btn btn-${variant}`}
      disabled={isLoading}
      {...rest}
    >
      {isLoading ? <Spinner /> : children}
    </button>
  );
}
```

### 9. Async event handlers

[SITUATIONAL] Wrap async operations in a void-returning handler. React event handlers must return `void`, not `Promise<void>`.

```typescript
// Correct - void wrapper for async logic
function handleSubmit(e: FormEvent<HTMLFormElement>) {
  e.preventDefault();
  void submitOrder();  // explicitly fire-and-forget the promise
}

async function submitOrder() {
  try {
    const result = await api.createOrder(formData);
    navigate(`/orders/${result.id}`);
  } catch (err) {
    if (err instanceof Error) {
      setError(err.message);
    }
  }
}
```

```typescript
// WRONG - async handler returns Promise<void>, React does not handle this
async function handleSubmit(e: FormEvent<HTMLFormElement>) {
  e.preventDefault();
  await submitOrder();  // if submitOrder throws, the promise is unhandled
}
```

### 10. Typing Next.js async params

[SITUATIONAL] In Next.js App Router (15+), `params` and `searchParams` are `Promise` objects. Type them accordingly.

```typescript
// App Router page with async params
interface PageProps {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ page?: string }>;
}

export default async function ProductPage({ params, searchParams }: PageProps) {
  const { slug } = await params;
  const { page = '1' } = await searchParams;

  const product = await getProduct(slug);
  return <ProductDetail product={product} currentPage={Number(page)} />;
}

// Generate metadata
export async function generateMetadata({ params }: PageProps): Promise<Metadata> {
  const { slug } = await params;
  const product = await getProduct(slug);
  return {
    title: product.name,
    description: product.description,
  };
}
```

## Best Practices

- Use `interface` for props and object shapes - supports extending and declaration merging
- Use `type` for unions, intersections, and derived types - these cannot be expressed with `interface`
- Discriminated unions with a `status` (or `type`, `kind`, `variant`) field enforce exhaustive matching
- Always type `useRef` with the specific HTML element (`HTMLInputElement`, not `HTMLElement`)
- Destructure props with defaults in the signature - self-documenting, no `undefined` checks
- Use `satisfies` to validate config objects without widening literal types
- Use `ComponentPropsWithoutRef<'element'>` to extend native element props
- Void-returning wrappers for async event handlers - React handlers must return `void`
- `as const` for literal type inference in arrays and objects
- Extract event handler types (`ChangeEvent<HTMLInputElement>`) explicitly, never rely on inference alone
- Use `keyof` and mapped types for variant-based component APIs -> see `references/component-patterns.md`
- Type Server Actions with explicit input/output types -> see `references/nextjs-typescript.md`

## Anti-patterns

| # | Anti-pattern | Root cause | Fix |
|---|---|---|---|
| 1 | `React.FC<Props>` typing | Wrapper type obscures the component signature and makes generics less natural | Plain function with explicit props |
| 2 | Boolean flags for state (`isLoading`, `isError`) | Impossible states, optional data | Discriminated union with `status` field |
| 3 | `useRef<HTMLElement>` or `useRef<any>` | Loses element-specific DOM methods | Specific element type (`HTMLInputElement`) |
| 4 | Untyped event handlers (`(e) => ...`) | Implicit `any`, lost `target.value` type | Explicit `ChangeEvent<HTMLInputElement>` |
| 5 | `interface` for unions | Interfaces cannot express unions | `type` with `\|` syntax |
| 6 | `type` for component props | Loses declaration merging, breaks convention | `interface` for props |
| 7 | `ComponentPropsWithRef<'button'>` | `ref` prop conflicts with `forwardRef` | `ComponentPropsWithoutRef<'button'>` |
| 8 | Async event handler returns Promise | Unhandled promise rejection on throw | Void wrapper + separate async function |
| 9 | Inline `as` type assertions in JSX | Masks real type mismatches | Fix the source type, use `satisfies` |
| 10 | `children: ReactNode` on every component | Over-approximation, allows invalid children | `children: React.ReactNode` only when actually used |
| 11 | Broad `Record<string, any>` config | No validation, any key accepted | `satisfies ThemeConfig` preserves literals |
| 12 | `any` for third-party lib callback params | Defeats type safety | `unknown` + narrowing, or library-specific types |

## Quick Diagnosis

| Symptom | Likely cause | Reference |
|---|---|---|
| "Object is possibly null" on ref access | `useRef(null)` without element type or missing null check | `references/hooks-and-events.md` - useRef section |
| "Property does not exist on type '{}'" | Untyped event handler - `e.target` is generic | `references/hooks-and-events.md` - event handlers |
| Hydration mismatch warning | SSR renders different output than CSR | `references/playbooks/hydration-issues.md` |
| Infinite re-render loop | Unstable dep in useEffect or setState in render | `references/playbooks/effect-dependency-bugs.md` |
| Type error on `params` in App Router page | `params` is now `Promise`, not plain object | `references/nextjs-typescript.md` |
| "Cannot read property of undefined" on state | Boolean flags allow invalid state combinations | Instructions section - discriminated unions |
| Switch statement misses a case | Non-exhaustive matching on union | `references/typescript-core.md` - discriminated unions |
| `as const` not working on object | Object not typed with `satisfies`, literals widened | Instructions section - satisfies |
| "Type 'string' is not assignable to type ..." | Over-wide inference, needs explicit annotation or `as const` | `references/playbooks/type-error-debugging.md` |
| Event handler `e.target.value` typed as `any` | Handler parameter untyped | `references/hooks-and-events.md` - event handlers |

## References

- `references/typescript-core.md` - narrowing, union/intersection types, generics with constraints, utility types, `as const`, `satisfies`
- `references/react-typescript-patterns.md` - props typing, hook typing, forwardRef, context, polymorphic components
- `references/nextjs-typescript.md` - App Router async params, Server Actions, route handlers, middleware, Edge runtime, useOptimistic
- `references/component-patterns.md` - discriminated props, compound components, render props, display name, generic components
- `references/hooks-and-events.md` - useState, useReducer, useEffect, custom hooks, event handler types, async handlers
- `references/playbooks/type-error-debugging.md` - systematic flowchart for diagnosing and fixing type errors
- `references/playbooks/hydration-issues.md` - SSR/CSR mismatch diagnosis and resolution
- `references/playbooks/effect-dependency-bugs.md` - infinite loops, stale closures, missing cleanup

## Related Skills

- `react-best-practices` - component structure, composition patterns, rendering optimization
- `nextjs-app-router` - routing, layouts, server/client boundaries, streaming
- `forms-and-validation` - Zod schemas, form state management, validation integration
- `state-management` - context patterns, external stores, server state (React Query/SWR)

## Keywords

typescript-react, discriminated union, React.FC, interface vs type, useRef, event handler types, useState typing, useReducer actions, satisfies, ComponentPropsWithoutRef, Next.js params, Server Actions, hydration, SSR mismatch, forwardRef, polymorphic components, compound components, as const

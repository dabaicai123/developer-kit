---
paths:
  - "**/*.tsx"
---

# Rule: TypeScript React Conventions

Enforce consistent TypeScript patterns for React components. For detailed patterns, use `typescript-react` skill.

## Guidelines

1. **Use `interface` for props, `type` for unions** - `interface ButtonProps { variant: ... }` for object shapes; `type Status = 'idle' | 'loading' | 'error'` for unions, intersections, and computed types. This follows TypeScript convention: interfaces are extendable, types are composable.

2. **Never use `React.FC`** - declare component functions with explicit props parameter: `function Button(props: ButtonProps)`. Plain function signatures keep props, generics, return inference, and `children` explicit without a wrapper type.

3. **Use explicit event handler types** - `onClick: (event: MouseEvent<HTMLButtonElement>) => void`, `onChange: (event: ChangeEvent<HTMLInputElement>) => void`. Never use implicit `any` for event parameters.

4. **Use discriminated unions, not boolean flags** - `type State = { status: 'idle' } | { status: 'loading' } | { status: 'error'; error: Error }` instead of `{ isLoading: boolean; isError: boolean; error?: Error }`. Discriminated unions guarantee type narrowing and eliminate impossible states.

5. **Use `useRef` with specific element types** - `useRef<HTMLDivElement>(null)`, `useRef<HTMLInputElement>(null)`. Never use generic `useRef<HTMLElement>` when the actual element type is known.

6. **Use Zod validation at untrusted boundaries** - validate incoming data from external APIs, forms, URL params, and cross-process/network boundaries with Zod schemas. Derive TypeScript types from schemas: `type User = z.infer<typeof userSchema>`. Never define separate TypeScript interfaces that duplicate Zod schema fields.

7. **Use `satisfies` for type validation** - `const config = { theme: 'dark' } satisfies AppConfig` to validate shape without widening types. Prefer `satisfies` over type assertions (`as`) and explicit type annotations when you need both validation and inference.

## Anti-Patterns

- `React.FC` or `React.FunctionComponent` - declare functions with explicit props parameter
- Implicit `any` event types - always specify `MouseEvent<HTMLButtonElement>` etc.
- Boolean flags for state (`isLoading`, `isError`) - use discriminated unions
- Generic `useRef<HTMLElement>` - use specific element types (`HTMLDivElement`, etc.)
- Duplicate TypeScript interfaces alongside Zod schemas - derive types via `z.infer`
- Unvalidated external or untrusted fetch/API response consumption - validate boundaries with Zod
- `as` type assertions instead of `satisfies` - use `satisfies` for validation with inference

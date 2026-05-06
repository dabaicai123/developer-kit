# Component Variants with tailwind-variants (tv())

Patterns for using `tv()` from the `tailwind-variants` library to compose component-level variants in Next.js + TypeScript projects.

## Installation

```bash
npm install tailwind-variants
```

**Lite import** (smaller bundle, no conflict resolution):

```ts
import { tv } from "tailwind-variants/lite";
```

**Full import** (with tailwind-merge conflict resolution):

```ts
import { tv } from "tailwind-variants";
```

Use the full import when you need automatic class conflict resolution (e.g., extending components where base and variant classes might overlap). Use lite when you control all class inputs and want the smallest runtime cost.

## Basic Usage

Define variants that map to different class combinations. Call the returned function with variant selections to get the merged class string.

```tsx
import { tv } from "tailwind-variants";

const button = tv({
  base: "font-medium rounded-md transition-colors inline-flex items-center justify-center",
  variants: {
    variant: {
      primary: "bg-primary text-surface-elevated hover:bg-primary-hover",
      secondary: "bg-secondary text-surface-elevated hover:bg-secondary-hover",
      outline: "border border-border text-text hover:bg-surface",
      ghost: "text-text hover:bg-surface",
      destructive: "bg-error text-surface-elevated hover:bg-error/90",
    },
    size: {
      sm: "text-sm px-3 py-1.5 h-8",
      md: "text-base px-4 py-2 h-10",
      lg: "text-lg px-6 py-3 h-12",
    },
    fullWidth: {
      true: "w-full",
    },
  },
  defaultVariants: {
    variant: "primary",
    size: "md",
  },
});

// Usage in component
interface ButtonProps {
  variant?: "primary" | "secondary" | "outline" | "ghost" | "destructive";
  size?: "sm" | "md" | "lg";
  fullWidth?: boolean;
  className?: string;
  children: React.ReactNode;
}

export function Button({ variant, size, fullWidth, className, children }: ButtonProps) {
  return (
    <button className={button({ variant, size, fullWidth, className })}>
      {children}
    </button>
  );
}
```

**Passing extra classes** — the `className` prop merges with the `tv()` output:

```tsx
<Button className="mt-4" variant="outline" size="sm">
  Cancel
</Button>
// Output: "font-medium rounded-md transition-colors ... border border-border ... text-sm px-3 py-1.5 ... mt-4"
```

## Slots

Slots let you define styles for multiple parts of a component simultaneously. Each slot gets its own class string.

```tsx
import { tv } from "tailwind-variants";

const card = tv({
  slots: {
    base: "rounded-lg shadow-md overflow-hidden bg-surface",
    header: "px-4 py-3 border-b border-border",
    title: "text-xl font-weight-semibold text-text",
    body: "px-4 py-4 text-base text-text-secondary",
    footer: "px-4 py-3 border-t border-border flex justify-end gap-2",
  },
  variants: {
    variant: {
      elevated: {
        base: "shadow-lg border border-border/50",
        header: "bg-surface-elevated",
      },
      flat: {
        base: "shadow-sm border border-border",
        header: "bg-surface",
      },
      outlined: {
        base: "border-2 border-border",
      },
    },
    padding: {
      compact: {
        header: "px-3 py-2",
        body: "px-3 py-2",
        footer: "px-3 py-2",
      },
      comfortable: {
        header: "px-6 py-4",
        body: "px-6 py-6",
        footer: "px-6 py-4",
      },
    },
  },
  defaultVariants: {
    variant: "elevated",
    padding: "comfortable",
  },
});

// Usage
interface CardProps {
  variant?: "elevated" | "flat" | "outlined";
  padding?: "compact" | "comfortable";
  title: string;
  children: React.ReactNode;
  actions?: React.ReactNode;
}

export function Card({ variant, padding, title, children, actions }: CardProps) {
  const { base, header, title: titleSlot, body, footer } = card({ variant, padding });

  return (
    <section className={base()}>
      <div className={header()}>
        <h3 className={titleSlot()}>{title}</h3>
      </div>
      <div className={body()}>{children}</div>
      {actions && <div className={footer()}>{actions}</div>}
    </section>
  );
}
```

### Compound slots

Apply classes to multiple slots at once to avoid repetition:

```tsx
const list = tv({
  slots: {
    base: "flex flex-col divide-y divide-border",
    item: "flex items-center gap-2",
    icon: "shrink-0",
    label: "text-sm text-text-secondary",
  },
  compoundSlots: [
    {
      slots: ["item", "icon", "label"],
      class: "px-4 py-3", // applied to all three slots
    },
    {
      slots: ["item", "icon", "label"],
      size: "sm",
      class: "px-3 py-2 text-xs", // applied when size="sm"
    },
  ],
});
```

## Compound Variants

Styles that apply only when multiple variants are active simultaneously:

```tsx
const button = tv({
  base: "rounded-md font-medium transition-colors",
  variants: {
    variant: {
      primary: "bg-primary text-surface-elevated",
      outline: "border border-border text-text",
    },
    size: {
      sm: "text-sm px-3 py-1.5",
      lg: "text-lg px-6 py-3",
    },
  },
  compoundVariants: [
    {
      variant: "primary",
      size: "lg",
      class: "shadow-md hover:shadow-lg", // large primary buttons get shadow
    },
    {
      variant: "outline",
      size: "sm",
      class: "border-width-1", // small outline buttons get thinner border
    },
    {
      variant: ["primary", "outline"], // matches either variant
      size: "lg",
      class: "tracking-wide", // all large buttons get wider letter spacing
    },
  ],
});
```

## Responsive Variants

Apply variant classes at specific breakpoints using responsive prefixes in the variant definition:

```tsx
const layout = tv({
  base: "flex",
  variants: {
    direction: {
      horizontal: "flex-row",
      vertical: "flex-col",
      responsive: "flex-col md:flex-row", // stacked on mobile, side-by-side on tablet+
    },
  },
});

// Or use responsive variants with tv() alongside Tailwind responsive classes:
const grid = tv({
  base: "grid gap-4",
  variants: {
    columns: {
      auto: "grid-cols-1 md:grid-cols-2 lg:grid-cols-3",
      fixed2: "grid-cols-2",
      fixed3: "grid-cols-3",
    },
  },
});
```

## Extending Components

Use `extend` to inherit base, variants, slots, defaultVariants, and compoundVariants from another `tv()` definition:

```tsx
const baseInput = tv({
  base: "w-full rounded-md border border-border bg-surface px-3 py-2 text-base text-text transition-colors",
  variants: {
    state: {
      default: "border-border",
      focus: "border-primary ring-2 ring-primary/20",
      error: "border-error ring-2 ring-error/20",
      disabled: "opacity-50 cursor-not-allowed",
    },
    size: {
      sm: "text-sm px-2 py-1",
      md: "text-base px-3 py-2",
      lg: "text-lg px-4 py-3",
    },
  },
  defaultVariants: {
    state: "default",
    size: "md",
  },
});

// Extend for a specific use case (search input)
const searchInput = tv({
  extend: baseInput,
  base: "pl-10", // adds left padding for search icon
  variants: {
    state: {
      focus: "border-primary ring-2 ring-primary/20 shadow-md", // overrides focus style
    },
  },
});
```

**Composing with result strings** (not type-safe, but simple):

```tsx
const baseButton = tv({
  base: "font-medium text-sm px-3 py-1 bg-primary text-surface-elevated rounded-md",
});

const dangerButton = tv({
  base: [baseButton(), "bg-error hover:bg-error/90"], // merges base styles, overrides color
});
```

Put the base styles first so variant styles can override them.

## Utility Functions

### cn — Merge with conflict resolution

```ts
import { cn } from "tailwind-variants";

cn("bg-primary", "bg-secondary"); // => "bg-secondary" (second wins)
cn("px-2", "px-4", "py-2"); // => "px-4 py-2" (px-4 overrides px-2)
```

### cx — Simple concatenation (no conflict resolution)

```ts
import { cx } from "tailwind-variants";

cx("px-2", "px-4"); // => "px-2 px-4" (both kept, no merging)
```

Use `cx` when you want simple concatenation. Use `cn` when conflicting Tailwind classes need automatic resolution (last one wins per property group).

### cnMerge — Custom merge configuration

```ts
import { cnMerge } from "tailwind-variants";

cnMerge("px-2", "px-4")({ twMerge: true }); // => "px-4" (merge enabled)
cnMerge("px-2", "px-4")({ twMerge: false }); // => "px-2 px-4" (merge disabled)
```

## When to Use tv() vs Conditional Classes

| Situation | Approach | Example |
|---|---|---|
| 3+ variant combos (variant + size + state) | `tv()` with variants | Button with primary/outline/ghost + sm/md/lg |
| Component with multiple styled parts | `tv()` with slots | Card with base/header/body/footer |
| Shared base across many variants | `tv()` with base | All inputs share border/radius/focus styles |
| 1-2 simple variants | Conditional classes via `clsx`/ternary | `className={isActive ? "bg-primary" : "bg-surface"}` |
| One-off conditional style | Ternary in className | `className={hasError ? "border-error" : "border-border"}` |
| Extending another component's styles | `tv()` with extend | SearchInput extends BaseInput |
| Props-driven single variant | `tv()` if reused; ternary if one-off | Badge color: `tv()` if used in many places |

**Decision heuristic:** If you find yourself writing more than 2 ternaries in a className string, switch to `tv()`.

## Anti-patterns

| Pattern | Problem | Fix |
|---|---|---|
| `tv()` for a component with 1 variant | Over-engineering, runtime overhead for no benefit | Use a ternary or `clsx` |
| Slots for a component with 1 styled part | Unnecessary destructuring complexity | Use `base` only |
| Overriding every inherited variant in extend | You're not extending, you're rewriting | Define a new `tv()` from scratch |
| Mixing `tv()` variants with raw Tailwind responsive classes | Confusion about what drives responsive behavior | Use responsive variants in `tv()` or responsive classes on the element |
| Using `tv()` for layout-only wrappers | No variants needed; utility classes suffice | Use plain Tailwind classes on the wrapper element |

## Organizing tv() Definitions

Place `tv()` definitions in the same file as the component, or in a dedicated `variants.ts` file when the definition is large or reused:

```
components/
  button/
    button.tsx       // component implementation
    variants.ts      // tv() definition + types
    index.ts         // re-export
```

```ts
// components/button/variants.ts
import { tv, type VariantProps } from "tailwind-variants";

export const button = tv({
  base: "font-medium rounded-md transition-colors inline-flex items-center justify-center",
  variants: {
    variant: { ... },
    size: { ... },
  },
  defaultVariants: { ... },
});

export type ButtonVariantProps = VariantProps<typeof button>;
```

```tsx
// components/button/button.tsx
import { button, type ButtonVariantProps } from "./variants";

interface ButtonProps extends ButtonVariantProps {
  className?: string;
  children: React.ReactNode;
  onClick?: () => void;
}

export function Button({ variant, size, className, children, onClick }: ButtonProps) {
  return (
    <button className={button({ variant, size, className })} onClick={onClick}>
      {children}
    </button>
  );
}
```
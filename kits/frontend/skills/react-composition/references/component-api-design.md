# Component API Design

Composition vs configuration decision framework, progressive disclosure, and props design guidelines.

## Composition vs Configuration Decision Framework

### What is Configuration?

Configuration means passing props to control behavior and appearance. The component owns its structure; the consumer tweaks it through parameters.

```tsx
// Configuration API
<Alert
  title="Warning"
  description="Disk space is low"
  variant="warning"
  icon={<WarningIcon />}
  dismissible
  onDismiss={handleDismiss}
/>
```

### What is Composition?

Composition means the consumer controls structure by nesting sub-components or passing render functions. The component provides the container; the consumer fills it.

```tsx
// Composition API
<Alert variant="warning" dismissible onDismiss={handleDismiss}>
  <AlertIcon><WarningIcon /></AlertIcon>
  <AlertTitle>Warning</AlertTitle>
  <AlertDescription>Disk space is low</AlertDescription>
</Alert>
```

### Decision Matrix

| Factor | Prefer Configuration | Prefer Composition |
|---|---|---|
| **Structure variability** | Fixed, predictable structure | Variable, consumer-defined structure |
| **Number of sections** | 1-3 optional sections | More than 3 optional sections |
| **Customization depth** | Simple toggles (show/hide, variant) | Custom rendering, custom layout |
| **API stability** | Stable, unlikely to grow | Likely to add new sections over time |
| **Consumer expertise** | Quick, simple usage expected | Advanced consumers need full control |
| **Performance** | Known structure, optimize internally | Consumer controls, can't optimize as much |
| **Boolean prop count** | Under 4 boolean props | Over 4 boolean props |

### Progressive Disclosure

Start with configuration for the simple case. Add composition for the complex case. Do not force composition on every consumer.

```tsx
// Simple: configuration (covers 80% of use cases)
<Avatar name="John Doe" src="/john.jpg" size="lg" />

// Advanced: composition (for the 20% that need custom rendering)
<Avatar size="lg">
  <AvatarImage src="/john.jpg" alt="John Doe" />
  <AvatarFallback>
    <CustomFallbackIcon name="John Doe" />
  </AvatarFallback>
</Avatar>
```

**How to implement both**:

```tsx
type AvatarProps =
  | {
      // Configuration mode
      name: string;
      src?: string;
      size?: "sm" | "md" | "lg";
    }
  | {
      // Composition mode
      size?: "sm" | "md" | "lg";
      children: ReactNode;
    };

function Avatar(props: AvatarProps) {
  const size = props.size ?? "md";
  if ("children" in props) {
    // Composition mode: consumer provides content
    return (
      <div className={sizeClasses[size]}>
        {props.children}
      </div>
    );
  }
  // Configuration mode: component handles rendering
  return (
    <div className={sizeClasses[size]}>
      {props.src ? (
        <img src={props.src} alt={props.name} className="rounded-full object-cover" />
      ) : (
        <span className="bg-gray-200 text-gray-600">{props.name.charAt(0)}</span>
      )}
    </div>
  );
}
```

## Props Design Guidelines

### 1. Use discriminated unions for mutually exclusive props

```tsx
// Bad: both props optional, confusing API
type ButtonProps = {
  href?: string;
  onClick?: () => void;
};

// Good: discriminated union, one or the other
type ButtonProps =
  | { variant: "button"; onClick: () => void; href?: never }
  | { variant: "link"; href: string; onClick?: never };
```

### 2. Group related props into objects

```tsx
// Bad: flat props that are always used together
type TableProps = {
  page: number;
  pageSize: number;
  totalItems: number;
  onPageChange: (page: number) => void;
  // ... 20 more props
};

// Good: grouped into sub-objects
type TableProps = {
  data: Row[];
  pagination: {
    page: number;
    pageSize: number;
    totalItems: number;
    onPageChange: (page: number) => void;
  };
  sorting: {
    sortBy: string;
    direction: "asc" | "desc";
    onSortChange: (sortBy: string, direction: "asc" | "desc") => void;
  };
};
```

### 3. Provide sensible defaults

```tsx
// Good: every optional prop has a default
type ModalProps = {
  open: boolean;
  onClose: () => void;
  size?: "sm" | "md" | "lg";      // default: "md"
  closeOnOverlayClick?: boolean;    // default: true
  closeOnEscape?: boolean;          // default: true
  animation?: "fade" | "slide";     // default: "fade"
};

function Modal({ open, onClose, size = "md", closeOnOverlayClick = true, ... }: ModalProps) {
```

### 4. Avoid callback props that require implementation details

```tsx
// Bad: consumer must implement comparison logic
type ListProps = {
  items: any[];
  isEqual: (a: any, b: any) => boolean;
};

// Good: consumer provides a stable key
type ListProps<T> = {
  items: T[];
  keyExtractor: (item: T) => string;
};
```

### 5. Use render props for customization, not for structure

```tsx
// Good: render prop for custom item rendering
type SelectListProps<T> = {
  items: T[];
  selected: T[];
  onSelect: (item: T) => void;
  renderItem: (item: T, isSelected: boolean) => ReactNode;
};

// Bad: render prop for entire component structure (use composition instead)
type SelectListProps<T> = {
  renderList: (items: T[]) => ReactNode; // consumer shouldn't build the whole list
};
```

### 6. Keep primitive prop types when possible

```tsx
// Bad: custom type for simple prop
type IconProp = { svg: string; size: IconSize; color: string };
<Button icon={customIconObj} />

// Good: accept what React already supports
<Button icon={<MyIcon />} />  // ReactNode, compositional
```

## Naming Conventions

| Pattern | Convention | Example |
|---|---|---|
| Boolean toggle | `is*` / `has*` / `should*` | `isLoading`, `hasError`, `shouldAnimate` |
| Event handler | `on*` | `onClick`, `onChange`, `onSubmit` |
| Render delegation | `render*` | `renderItem`, `renderHeader`, `renderEmpty` |
| Slot/content | `*` (children preferred) | `header`, `footer`, `actions` |
| Variant/style | `variant` / `size` | `variant="primary"`, `size="lg"` |
| Data | Descriptive noun | `items`, `users`, `selectedRow` |
| Ref | `*Ref` | `inputRef`, `scrollRef` |

## Anti-patterns

### God Component

```tsx
// Bad: one component with 50+ props covering every scenario
type MegaTableProps = {
  data: any[];
  columns: Column[];
  sortable?: boolean;
  filterable?: boolean;
  paginated?: boolean;
  selectable?: boolean;
  expandable?: boolean;
  draggable?: boolean;
  resizable?: boolean;
  editable?: boolean;
  exportable?: boolean;
  // ... 30 more props
};

// Good: compose features
<Table data={data} columns={columns}>
  <TableSorting />
  <TableFiltering />
  <TablePagination pageSize={10} />
  <TableSelection />
</Table>
```

### Props that mirror internal state

```tsx
// Bad: exposing internal implementation
type AccordionProps = {
  activeIndex: number;        // should be "activeItem" or use composition
  animationDuration: number;  // internal concern
  transitionEasing: string;   // internal concern
};

// Good: semantic props
type AccordionProps = {
  defaultActiveItem?: string;
  activeItem?: string;
  onActiveItemChange?: (item: string) => void;
  variant?: "default" | "compact";
};
```

### Mutable ref as prop

```tsx
// Bad: passing mutable ref
<Input inputRef={myRef} />  // confusing, is it controlled?

// Good: use React's ref system
<Input ref={myRef} />  // standard forwardRef pattern
```
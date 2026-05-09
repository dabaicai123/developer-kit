# Compound Components

Parent provides context, children consume it. No prop drilling needed between parent and children.

## Pattern Overview

Compound components share implicit state through React Context. The parent manages state and provides it via context; children consume context and render accordingly.

**Key properties:**
- Children are self-selecting (they know what to render based on context)
- API is declarative and composable
- Adding new sub-components does not change the parent API
- TypeScript enforces correct usage

## Tabs / TabPanel

```tsx
import { createContext, useContext, useState, type ReactNode } from "react";

type TabsContextValue = {
  activeTab: string;
  setActiveTab: (value: string) => void;
};

const TabsContext = createContext<TabsContextValue | null>(null);

function useTabsContext() {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error("Tabs sub-components must be rendered inside <Tabs>");
  return ctx;
}

// --- Parent ---
type TabsProps = {
  children: ReactNode;
  defaultValue: string;
  value?: string;         // controlled mode
  onChange?: (value: string) => void;
};

function Tabs({ children, defaultValue, value, onChange }: TabsProps) {
  const [internalValue, setInternalValue] = useState(defaultValue);
  const activeTab = value ?? internalValue;
  const setActiveTab = onChange ?? setInternalValue;

  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="flex flex-col gap-2">{children}</div>
    </TabsContext.Provider>
  );
}

// --- Tab trigger ---
type TabProps = {
  value: string;
  children: ReactNode;
  className?: string;
};

function Tab({ value, children, className }: TabProps) {
  const { activeTab, setActiveTab } = useTabsContext();
  const isActive = activeTab === value;

  return (
    <button
      role="tab"
      aria-selected={isActive}
      className={[
        "px-4 py-2 text-sm font-medium border-b-2 transition-colors",
        isActive ? "border-blue-500 text-blue-600" : "border-transparent text-gray-500 hover:text-gray-700",
        className ?? "",
      ].join(" ")}
      onClick={() => setActiveTab(value)}
    >
      {children}
    </button>
  );
}

// --- Tab list ---
type TabListProps = {
  children: ReactNode;
  className?: string;
};

function TabList({ children, className }: TabListProps) {
  return (
    <div role="tablist" className={["flex gap-1 border-b border-gray-200", className ?? ""].join(" ")}>
      {children}
    </div>
  );
}

// --- TabPanel ---
type TabPanelProps = {
  value: string;
  children: ReactNode;
  className?: string;
};

function TabPanel({ value, children, className }: TabPanelProps) {
  const { activeTab } = useTabsContext();
  if (activeTab !== value) return null;

  return (
    <div role="tabpanel" className={className ?? "pt-4"}>
      {children}
    </div>
  );
}

// --- Usage ---
<Tabs defaultValue="profile">
  <TabList>
    <Tab value="profile">Profile</Tab>
    <Tab value="settings">Settings</Tab>
    <Tab value="notifications">Notifications</Tab>
  </TabList>
  <TabPanel value="profile"><ProfileForm /></TabPanel>
  <TabPanel value="settings"><SettingsForm /></TabPanel>
  <TabPanel value="notifications"><NotificationList /></TabPanel>
</Tabs>
```

## Select / Option

```tsx
import { createContext, useContext, useState, useRef, type ReactNode } from "react";

type SelectContextValue = {
  value: string;
  open: boolean;
  toggle: () => void;
  select: (value: string) => void;
};

const SelectContext = createContext<SelectContextValue | null>(null);

function useSelectContext() {
  const ctx = useContext(SelectContext);
  if (!ctx) throw new Error("Select sub-components must be inside <Select>");
  return ctx;
}

type SelectProps = {
  children: ReactNode;
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  placeholder?: string;
  className?: string;
};

function Select({ children, value, defaultValue = "", onChange, placeholder = "Select...", className }: SelectProps) {
  const [internalValue, setInternalValue] = useState(defaultValue);
  const [open, setOpen] = useState(false);
  const selectedValue = value ?? internalValue;

  const toggle = () => setOpen((prev) => !prev);
  const select = (v: string) => {
    if (!value) setInternalValue(v);
    onChange?.(v);
    setOpen(false);
  };

  return (
    <SelectContext.Provider value={{ value: selectedValue, open, toggle, select }}>
      <div className={["relative inline-block w-full", className ?? ""].join(" ")}>
        {children}
      </div>
    </SelectContext.Provider>
  );
}

type SelectTriggerProps = {
  children?: ReactNode;
  className?: string;
};

function SelectTrigger({ children, className }: SelectTriggerProps) {
  const { value, toggle, open } = useSelectContext();
  return (
    <button
      className={[
        "w-full px-3 py-2 text-left border border-gray-300 rounded-md bg-white",
        open ? "ring-2 ring-blue-500" : "",
        className ?? "",
      ].join(" ")}
      onClick={toggle}
    >
      {children ?? value ?? "Select..."}
      <span className="float-right">&#9662;</span>
    </button>
  );
}

type SelectOptionProps = {
  value: string;
  children: ReactNode;
  className?: string;
};

function SelectOption({ value, children, className }: SelectOptionProps) {
  const { select, value: selectedValue } = useSelectContext();
  const isSelected = selectedValue === value;

  return (
    <div
      className={[
        "px-3 py-2 cursor-pointer hover:bg-blue-50",
        isSelected ? "bg-blue-100 text-blue-700" : "text-gray-700",
        className ?? "",
      ].join(" ")}
      onClick={() => select(value)}
    >
      {children}
    </div>
  );
}

type SelectContentProps = {
  children: ReactNode;
  className?: string;
};

function SelectContent({ children, className }: SelectContentProps) {
  const { open } = useSelectContext();
  if (!open) return null;

  return (
    <div className={["absolute z-10 w-full mt-1 border border-gray-200 rounded-md bg-white shadow-lg", className ?? ""].join(" ")}>
      {children}
    </div>
  );
}

// --- Usage ---
<Select defaultValue="react" onChange={(v) => console.log(v)}>
  <SelectTrigger />
  <SelectContent>
    <SelectOption value="react">React</SelectOption>
    <SelectOption value="vue">Vue</SelectOption>
    <SelectOption value="svelte">Svelte</SelectOption>
  </SelectContent>
</Select>
```

## Card / CardHeader / CardBody

```tsx
import { createContext, useContext, type ReactNode } from "react";

type CardContextValue = {
  variant: "default" | "outlined" | "elevated";
};

const CardContext = createContext<CardContextValue>({ variant: "default" });

type CardProps = {
  children: ReactNode;
  variant?: "default" | "outlined" | "elevated";
  className?: string;
};

const variantStyles: Record<CardContextValue["variant"], string> = {
  default: "bg-white border border-gray-200 rounded-lg",
  outlined: "bg-transparent border-2 border-gray-300 rounded-lg",
  elevated: "bg-white rounded-lg shadow-md",
};

function Card({ children, variant = "default", className }: CardProps) {
  return (
    <CardContext.Provider value={{ variant }}>
      <div className={[variantStyles[variant], "p-6", className ?? ""].join(" ")}>
        {children}
      </div>
    </CardContext.Provider>
  );
}

type CardHeaderProps = {
  children: ReactNode;
  className?: string;
};

function CardHeader({ children, className }: CardHeaderProps) {
  return (
    <div className={["mb-4", className ?? ""].join(" ")}>
      {children}
    </div>
  );
}

type CardTitleProps = {
  children: ReactNode;
  className?: string;
};

function CardTitle({ children, className }: CardTitleProps) {
  return (
    <h3 className={["text-lg font-semibold text-gray-900", className ?? ""].join(" ")}>
      {children}
    </h3>
  );
}

type CardDescriptionProps = {
  children: ReactNode;
  className?: string;
};

function CardDescription({ children, className }: CardDescriptionProps) {
  return (
    <p className={["text-sm text-gray-500 mt-1", className ?? ""].join(" ")}>
      {children}
    </p>
  );
}

type CardBodyProps = {
  children: ReactNode;
  className?: string;
};

function CardBody({ children, className }: CardBodyProps) {
  return (
    <div className={["text-gray-700", className ?? ""].join(" ")}>
      {children}
    </div>
  );
}

type CardFooterProps = {
  children: ReactNode;
  className?: string;
};

function CardFooter({ children, className }: CardFooterProps) {
  return (
    <div className={["mt-4 pt-4 border-t border-gray-100 flex items-center gap-3", className ?? ""].join(" ")}>
      {children}
    </div>
  );
}

// --- Usage ---
<Card variant="elevated">
  <CardHeader>
    <CardTitle>Project Overview</CardTitle>
    <CardDescription>Q4 metrics summary</CardDescription>
  </CardHeader>
  <CardBody>
    <MetricsGrid />
  </CardBody>
  <CardFooter>
    <Button variant="primary">View Details</Button>
    <Button variant="secondary">Export</Button>
  </CardFooter>
</Card>
```

## Dialog

```tsx
import { createContext, useContext, useState, useEffect, useRef, type ReactNode } from "react";

type DialogContextValue = {
  open: boolean;
  openDialog: () => void;
  closeDialog: () => void;
};

const DialogContext = createContext<DialogContextValue | null>(null);

function useDialogContext() {
  const ctx = useContext(DialogContext);
  if (!ctx) throw new Error("Dialog sub-components must be inside <Dialog>");
  return ctx;
}

type DialogProps = {
  children: ReactNode;
  open?: boolean;
  onOpenChange?: (open: boolean) => void;
};

function Dialog({ children, open: controlledOpen, onOpenChange }: DialogProps) {
  const [internalOpen, setInternalOpen] = useState(false);
  const isOpen = controlledOpen ?? internalOpen;

  const openDialog = () => {
    if (controlledOpen === undefined) setInternalOpen(true);
    onOpenChange?.(true);
  };

  const closeDialog = () => {
    if (controlledOpen === undefined) setInternalOpen(false);
    onOpenChange?.(false);
  };

  return (
    <DialogContext.Provider value={{ open: isOpen, openDialog, closeDialog }}>
      {children}
    </DialogContext.Provider>
  );
}

// --- Trigger ---
type DialogTriggerProps = {
  children: ReactNode;
  className?: string;
};

function DialogTrigger({ children, className }: DialogTriggerProps) {
  const { openDialog } = useDialogContext();
  return (
    <button className={className ?? ""} onClick={openDialog}>
      {children}
    </button>
  );
}

// --- Overlay + Content ---
type DialogContentProps = {
  children: ReactNode;
  className?: string;
};

function DialogContent({ children, className }: DialogContentProps) {
  const { open, closeDialog } = useDialogContext();
  const contentRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeDialog();
    };
    document.addEventListener("keydown", handleEsc);
    return () => document.removeEventListener("keydown", handleEsc);
  }, [open, closeDialog]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Overlay */}
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={closeDialog}
        aria-hidden="true"
      />
      {/* Content */}
      <div
        ref={contentRef}
        role="dialog"
        aria-modal="true"
        className={[
          "relative z-10 w-full max-w-md bg-white rounded-xl shadow-xl p-6",
          className ?? "",
        ].join(" ")}
      >
        {children}
      </div>
    </div>
  );
}

type DialogHeaderProps = { children: ReactNode; className?: string };
function DialogHeader({ children, className }: DialogHeaderProps) {
  return <div className={["mb-4", className ?? ""].join(" ")}>{children}</div>;
}

type DialogTitleProps = { children: ReactNode; className?: string };
function DialogTitle({ children, className }: DialogTitleProps) {
  return <h2 className={["text-xl font-semibold text-gray-900", className ?? ""].join(" ")}>{children}</h2>;
}

type DialogBodyProps = { children: ReactNode; className?: string };
function DialogBody({ children, className }: DialogBodyProps) {
  return <div className={["text-gray-600", className ?? ""].join(" ")}>{children}</div>;
}

type DialogFooterProps = { children: ReactNode; className?: string };
function DialogFooter({ children, className }: DialogFooterProps) {
  return (
    <div className={["mt-6 flex justify-end gap-3", className ?? ""].join(" ")}>
      {children}
    </div>
  );
}

// --- Usage ---
<Dialog>
  <DialogTrigger className="px-4 py-2 bg-blue-500 text-white rounded-md">
    Open Settings
  </DialogTrigger>
  <DialogContent>
    <DialogHeader>
      <DialogTitle>Settings</DialogTitle>
    </DialogHeader>
    <DialogBody>
      <SettingsForm />
    </DialogBody>
    <DialogFooter>
      <Button onClick={closeDialog}>Cancel</Button>
      <Button variant="primary">Save</Button>
    </DialogFooter>
  </DialogContent>
</Dialog>
```

## TypeScript Patterns

### Context null-check pattern

Always type context as `T | null` and provide a `useXContext` hook that throws if used outside the parent. This gives:
- Clear runtime error messages
- Correct narrowing (no `!` assertions scattered everywhere)

```tsx
const TabsContext = createContext<TabsContextValue | null>(null);

function useTabsContext(): TabsContextValue {
  const ctx = useContext(TabsContext);
  if (ctx === null) throw new Error("useTabsContext must be used within <Tabs>");
  return ctx;
}
```

### Sub-component export pattern

Export compound components as a namespace object for clean imports:

```tsx
// Option 1: Named exports
export { Tabs, TabList, Tab, TabPanel };

// Option 2: Namespace object
const TabsComponent = Object.assign(Tabs, {
  List: TabList,
  Tab: Tab,
  Panel: TabPanel,
});
export { TabsComponent as Tabs };

// Usage: import { Tabs } from './Tabs'; <Tabs><Tabs.List>...</Tabs.List></Tabs>
```

### Controlled + uncontrolled support

Support both modes with the `value ?? internalValue` pattern:

```tsx
function Tabs({ value, defaultValue, onChange, children }: TabsProps) {
  const [internalValue, setInternalValue] = useState(defaultValue);
  const activeTab = value ?? internalValue;
  const setActiveTab = onChange ?? setInternalValue;
  // ...
}
```
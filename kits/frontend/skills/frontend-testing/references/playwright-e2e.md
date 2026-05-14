# Playwright E2E Testing

Critical journey testing, auth setup, API mocking, responsive testing, page objects, and CI integration.

## Setup

### Install

```bash
npm install -D @playwright/test
npx playwright install
```

### playwright.config.ts

```tsx
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: process.env.E2E_BASE_URL ?? "http://localhost:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
    {
      name: "mobile",
      use: { ...devices["Pixel 5"] },
    },
  ],
  webServer: {
    command: "npm run dev",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
  },
});
```

### package.json scripts

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:debug": "playwright test --debug"
  }
}
```

## Critical Journey Tests

Only test the most important user flows. Not every page and interaction.

### What qualifies as a critical journey

| Journey | Why |
|---|---|
| Authentication (login/logout) | Core functionality, session persistence |
| Core business action (create order) | Revenue-generating flow |
| Payment/checkout | Money transaction, must work perfectly |
| Data creation (create product) | Primary CRUD operation |
| Navigation to key pages | Users must find what they need |

### Example: Authentication flow

```tsx
import { test, expect } from "@playwright/test";

test.describe("Authentication", () => {
  test("user can log in with valid credentials", async ({ page }) => {
    await page.goto("/login");

    await page.getByLabel("Email").fill("user@example.com");
    await page.getByLabel("Password").fill("password123");
    await page.getByRole("button", { name: "Log in" }).click();

    // Redirected to dashboard
    await expect(page).toHaveURL("/dashboard");
    await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  });

  test("user sees error with invalid credentials", async ({ page }) => {
    await page.goto("/login");

    await page.getByLabel("Email").fill("user@example.com");
    await page.getByLabel("Password").fill("wrongpassword");
    await page.getByRole("button", { name: "Log in" }).click();

    // Error message appears
    await expect(page.getByText("Invalid credentials")).toBeVisible();
    // Still on login page
    await expect(page).toHaveURL("/login");
  });

  test("user can log out", async ({ page }) => {
    // Start from authenticated state (use auth setup)
    await page.goto("/dashboard");
    await page.getByRole("button", { name: "Logout" }).click();

    await expect(page).toHaveURL("/login");
  });
});
```

### Example: Product creation flow

```tsx
import { test, expect } from "@playwright/test";

test.describe("Product management", () => {
  test("admin can create a new product", async ({ page }) => {
    await page.goto("/products/new");

    await page.getByLabel("Name").fill("New Widget");
    await page.getByLabel("Price").fill("99.99");
    await page.getByLabel("Category").selectOption("electronics");
    await page.getByLabel("Description").fill("A brand new widget");
    await page.getByRole("button", { name: "Create Product" }).click();

    // Redirected to product detail page
    await expect(page).toHaveURL(/\/products\/[\w-]+/);
    await expect(page.getByText("New Widget")).toBeVisible();
    await expect(page.getByText("$99.99")).toBeVisible();
  });

  test("admin sees validation errors for invalid input", async ({ page }) => {
    await page.goto("/products/new");

    // Submit without filling in required fields
    await page.getByRole("button", { name: "Create Product" }).click();

    await expect(page.getByText("Name is required")).toBeVisible();
    await expect(page.getByText("Price must be positive")).toBeVisible();
  });
});
```

## Auth Setup

### Storage state pattern

Save authenticated session state to reuse across tests.

```tsx
// e2e/auth.setup.ts
import { test as setup, expect } from "@playwright/test";

const authFile = "e2e/.auth/user.json";

setup("authenticate as standard user", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill(process.env.E2E_USER_EMAIL ?? "test@example.com");
  await page.getByLabel("Password").fill(process.env.E2E_USER_PASSWORD ?? "password");
  await page.getByRole("button", { name: "Log in" }).click();

  await expect(page).toHaveURL("/dashboard");

  // Save signed-in state
  await page.context().storageState({ path: authFile });
});
```

### Use auth state in tests

```tsx
// playwright.config.ts - add setup project
projects: [
  { name: "setup", testMatch: /auth\.setup\.ts/ },
  {
    name: "authenticated",
    dependencies: ["setup"],
    use: {
      storageState: "e2e/.auth/user.json",
      ...devices["Desktop Chrome"],
    },
  },
  {
    name: "unauthenticated",
    use: { ...devices["Desktop Chrome"] },
  },
],
```

```tsx
// Tests that need authentication use the "authenticated" project
// Tests that test login flow use the "unauthenticated" project
```

## API Mocking

### Mock API responses for controlled testing

```tsx
import { test, expect } from "@playwright/test";

test("shows products from mocked API", async ({ page }) => {
  // Mock the products API
  await page.route("/api/products**", (route) => {
    route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        items: [
          { id: "1", name: "Mock Product", price: 50, inStock: true },
        ],
        total: 1,
      }),
    });
  });

  await page.goto("/products");

  await expect(page.getByText("Mock Product")).toBeVisible();
  await expect(page.getByText("$50")).toBeVisible();
});
```

### Mock API errors

```tsx
test("shows error when API fails", async ({ page }) => {
  await page.route("/api/products**", (route) => {
    route.fulfill({
      status: 500,
      contentType: "application/json",
      body: JSON.stringify({ error: "Internal server error" }),
    });
  });

  await page.goto("/products");

  await expect(page.getByText("Something went wrong")).toBeVisible();
});
```

### Intercept and modify requests

```tsx
test("submits form data to API", async ({ page }) => {
  await page.route("/api/products", (route) => {
    // Verify request body
    const request = route.request();
    const body = request.postDataJSON();

    expect(body.name).toBe("New Product");
    expect(body.price).toBe(99);

    // Respond with success
    route.fulfill({
      status: 201,
      contentType: "application/json",
      body: JSON.stringify({ id: "prod-1", ...body }),
    });
  });

  await page.goto("/products/new");
  await page.getByLabel("Name").fill("New Product");
  await page.getByLabel("Price").fill("99");
  await page.getByRole("button", { name: "Create" }).click();

  await expect(page.getByText("Product created")).toBeVisible();
});
```

## Responsive Testing

### Test at mobile viewport

```tsx
import { test, expect } from "@playwright/test";

test.describe("Mobile navigation", () => {
  test.use({ ...devices["Pixel 5"] });

  test("hamburger menu works on mobile", async ({ page }) => {
    await page.goto("/");

    // Desktop nav should be hidden
    await expect(page.getByRole("navigation", { name: "Desktop" })).not.toBeVisible();

    // Mobile hamburger visible
    await page.getByRole("button", { name: "Menu" }).click();

    // Mobile nav opens
    await expect(page.getByRole("navigation", { name: "Mobile" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Products" })).toBeVisible();
  });
});
```

### Test responsive layout breakpoints

```tsx
test("layout adapts at 768px breakpoint", async ({ page }) => {
  // Test at desktop size
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.goto("/products");

  // Grid shows 3 columns
  const grid = page.getByRole("list", { name: "Products" });
  await expect(grid).toBeVisible();

  // Resize to mobile
  await page.setViewportSize({ width: 375, height: 812 });

  // Grid shows 1 column (stacked)
  // Verify mobile-specific elements are visible
  await expect(page.getByRole("button", { name: "Menu" })).toBeVisible();
});
```

### Touch targets

```tsx
test("touch targets are at least 44x44px", async ({ page }) => {
  await page.goto("/products");

  const buttons = page.getByRole("button").all();
  for (const button of await buttons) {
    const box = await button.boundingBox();
    if (box) {
      expect(box.width).toBeGreaterThanOrEqual(44);
      expect(box.height).toBeGreaterThanOrEqual(44);
    }
  }
});
```

## Page Objects

Encapsulate page-specific logic for reuse and maintainability.

```tsx
// e2e/pages/login.page.ts
import { type Page, type Locator } from "@playwright/test";

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel("Email");
    this.passwordInput = page.getByLabel("Password");
    this.submitButton = page.getByRole("button", { name: "Log in" });
    this.errorMessage = page.getByRole("alert");
  }

  async goto() {
    await this.page.goto("/login");
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string) {
    await expect(this.errorMessage).toContainText(message);
  }

  async expectRedirect(url: string) {
    await expect(this.page).toHaveURL(url);
  }
}
```

```tsx
// e2e/pages/products.page.ts
export class ProductsPage {
  readonly page: Page;
  readonly productList: Locator;
  readonly createButton: Locator;

  constructor(page: Page) {
    this.page = page;
    this.productList = page.getByRole("list", { name: "Products" });
    this.createButton = page.getByRole("link", { name: "Create Product" });
  }

  async goto() {
    await this.page.goto("/products");
  }

  async expectProductVisible(name: string) {
    await expect(this.page.getByText(name)).toBeVisible();
  }

  async navigateToCreate() {
    await this.createButton.click();
    await expect(this.page).toHaveURL("/products/new");
  }
}
```

```tsx
// Usage in tests
import { test, expect } from "@playwright/test";
import { LoginPage } from "./pages/login.page";
import { ProductsPage } from "./pages/products.page";

test("user creates a product after login", async ({ page }) => {
  const login = new LoginPage(page);
  const products = new ProductsPage(page);

  await login.goto();
  await login.login("admin@example.com", "password");
  await login.expectRedirect("/dashboard");

  await products.goto();
  await products.expectProductVisible("Existing Product");
  await products.navigateToCreate();
  // ... fill form
});
```

## CI Integration

### GitHub Actions

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    timeout-minutes: 10
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install dependencies
        run: npm ci
      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium
      - name: Run E2E tests
        run: npx playwright test --project=chromium
        env:
          E2E_BASE_URL: http://localhost:3000
          E2E_USER_EMAIL: ci-test@example.com
          E2E_USER_PASSWORD: ci-test-password
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-traces
          path: test-results/
          retention-days: 7
```

### Tips for CI reliability

1. **Single worker in CI**: `workers: process.env.CI ? 1 : undefined` to avoid flaky tests
2. **Retries in CI**: `retries: process.env.CI ? 2 : 0` to handle intermittent failures
3. **Trace on failure**: `trace: "on-first-retry"` for debugging CI failures
4. **Screenshot on failure**: `screenshot: "only-on-failure"` for visual debugging
5. **Separate setup**: Auth setup runs first, authenticated tests use saved state
6. **Only chromium in CI**: Skip mobile/other browsers to save time; run full suite locally

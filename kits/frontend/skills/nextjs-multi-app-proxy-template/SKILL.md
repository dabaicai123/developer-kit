---
name: nextjs-multi-app-proxy-template
description: "Scaffolds a multi-app Next.js architecture where a main web gateway exposes multiple independent Next.js/Supabase child apps under one domain via reverse proxy rewrites. Use when each child project must stay independently built and deployed, but users access them through shared paths such as /app-a, /app-b, or /admin."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Next.js Multi-App Proxy Template

Use this skill to create a large frontend project where each child app is an
independent Next.js project, while one main web project provides a unified domain
and path-based entry point.

## Architecture

Recommended layout:

```text
main-web/                 # Unified entry, navigation, reverse proxy
projects/
  app-a/                  # Independent Next.js + Supabase app
  app-b/                  # Independent Next.js + Supabase app
  admin/                  # Independent Next.js + Supabase app
```

Deployment shape:

```text
https://example.com/app-a  -> https://app-a.vercel.app/app-a
https://example.com/app-b  -> https://app-b.vercel.app/app-b
https://example.com/admin  -> https://admin.vercel.app/admin
```

Each child app keeps its own:

- `package.json`
- dependencies
- environment variables
- Supabase project or Supabase configuration
- build and deployment pipeline

Do not add a workspace, shared package, or shared UI layer unless the user asks
for shared code.

## Workflow

### 1. Create the Main Web Gateway

Create a small Next.js app for `main-web`. It can contain only the landing page,
navigation, auth handoff pages if needed, and reverse proxy configuration.

Keep the gateway thin. It should not import code from child apps.

### 2. Create Child Apps Independently

For each child app, scaffold it as a normal standalone project. For Supabase
apps, use `nextjs-supabase-template` first:

```bash
npx create-next-app@latest --example with-supabase projects/app-a
npx create-next-app@latest --example with-supabase projects/app-b
```

Each child app must build successfully from its own directory:

```bash
cd projects/app-a
npm install
npm run build
```

### 3. Configure Child App Base Paths

For path-based access, each child app must know its public mount path. Configure
`basePath` in the child app's `next.config.ts`:

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  basePath: "/app-a",
};

export default nextConfig;
```

Use the matching prefix for each child app:

```text
projects/app-a  -> basePath: "/app-a"
projects/app-b  -> basePath: "/app-b"
projects/admin  -> basePath: "/admin"
```

Do not use `assetPrefix` for this. Next.js `basePath` is the correct setting for
serving an app under a sub-path, and it also prefixes framework assets such as
`/_next/static`.

### 4. Configure Main Web Rewrites

In `main-web/next.config.ts`, route each public path to the matching deployed
child app:

```ts
import type { NextConfig } from "next";

function requiredOrigin(name: string) {
  const value = process.env[name];

  if (!value) {
    throw new Error(`${name} is required for gateway rewrites`);
  }

  return value.replace(/\/$/, "");
}

const nextConfig: NextConfig = {
  async rewrites() {
    const appAOrigin = requiredOrigin("APP_A_ORIGIN");
    const appBOrigin = requiredOrigin("APP_B_ORIGIN");
    const adminOrigin = requiredOrigin("ADMIN_ORIGIN");

    return [
      {
        source: "/app-a/:path*",
        destination: `${appAOrigin}/app-a/:path*`,
      },
      {
        source: "/app-b/:path*",
        destination: `${appBOrigin}/app-b/:path*`,
      },
      {
        source: "/admin/:path*",
        destination: `${adminOrigin}/admin/:path*`,
      },
    ];
  },
};

export default nextConfig;
```

Use origin variables without trailing slashes:

```env
APP_A_ORIGIN=https://app-a.vercel.app
APP_B_ORIGIN=https://app-b.vercel.app
ADMIN_ORIGIN=https://admin.vercel.app
```

The destination keeps the same base path because each child app is built with
that `basePath`.

### 5. Deploy

Create one deployment per app:

```text
main-web      -> example.com
projects/app-a -> app-a.vercel.app
projects/app-b -> app-b.vercel.app
projects/admin -> admin.vercel.app
```

For Vercel, create separate Vercel Projects from the same repository or from
separate repositories:

```text
main-web project Root Directory: main-web
app-a project Root Directory: projects/app-a
app-b project Root Directory: projects/app-b
admin project Root Directory: projects/admin
```

Set the gateway environment variables on the `main-web` deployment. Set each
child app's Supabase variables only on that child deployment.

### 6. Configure Auth Redirects and Cookies

For Supabase Auth, configure redirect URLs with the public gateway path:

```text
https://example.com/app-a/auth/confirm
https://example.com/app-b/auth/confirm
https://example.com/admin/auth/confirm
```

Keep internal navigation and API calls relative to the child app's `basePath`.
Avoid hardcoded root-relative URLs like `/dashboard` or `/api/items` unless they
are intentionally targeting the gateway root. Prefer framework links and route
helpers that respect `basePath`.

If child apps use different Supabase projects, their auth cookies normally have
different project-specific names. If multiple child apps use the same Supabase
project under the same main domain, treat the auth session as shared unless the
app deliberately customizes cookie names and auth behavior.

### 7. Verify Routing

After deployment, verify all of these from the main domain:

```text
/app-a
/app-a/_next/static/...
/app-a/api/...        # if the child app exposes API routes
/app-b
/admin
```

Also verify direct child deployment URLs still work with their base paths:

```text
https://app-a.vercel.app/app-a
https://app-b.vercel.app/app-b
```

If a child app works directly but fails through the gateway, inspect the main
rewrite destination. If HTML loads but CSS or JavaScript fails, inspect the child
`basePath`.

## Subdomain Alternative

If the user accepts subdomains instead of paths, the child apps do not need
`basePath`:

```text
https://app-a.example.com -> app-a deployment
https://app-b.example.com -> app-b deployment
```

Use subdomains when path-prefix constraints create too much friction. Use
path-based proxying when one visible domain and paths are required.

## Completion Checklist

- [ ] Main gateway app exists and stays thin.
- [ ] Each child app has an independent `package.json`.
- [ ] Each path-based child app has the correct `basePath`.
- [ ] Main gateway rewrites point to deployed child origins.
- [ ] Gateway environment variables are documented.
- [ ] Child Supabase variables are configured only on child deployments.
- [ ] Main-domain routes and child direct routes are verified.

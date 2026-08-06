# BuurtHulp Login And Admin Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add role-based login for admin, jongeren/buurtbewoners, and hulpvragers, plus a polished admin panel for BuurtHulp.

**Architecture:** Keep the Vite app as a single-page React app. Add a small auth/domain layer for demo sessions and role routing, then build focused React components for login, admin dashboard, and user dashboards. Prepare PocketBase through a migration file without embedding real secrets in the frontend.

**Tech Stack:** React, Vite, TypeScript, Vitest, Testing Library, PocketBase-ready schema migration.

---

### Task 1: Test Harness

**Files:**
- Modify: `/Users/h/Desktop/buurthulp/website/package.json`
- Create: `/Users/h/Desktop/buurthulp/website/src/test/setup.ts`

- [ ] Add Vitest and Testing Library dependencies.
- [ ] Add `test` and `test:run` scripts.
- [ ] Verify `npm run test:run` can execute once test files exist.

### Task 2: Auth Domain Layer

**Files:**
- Create: `/Users/h/Desktop/buurthulp/website/src/domain/auth.ts`
- Test: `/Users/h/Desktop/buurthulp/website/src/domain/auth.test.ts`

- [ ] Write failing tests for successful admin login, role mismatch rejection, and invalid password rejection.
- [ ] Implement `authenticateDemoUser`, `roleLabels`, `roleHomeViews`, and safe demo users.
- [ ] Run `npm run test:run` until green.

### Task 3: Dashboard Data

**Files:**
- Create: `/Users/h/Desktop/buurthulp/website/src/domain/demoData.ts`

- [ ] Add typed mock data for hulpvragen, jongeren, hulpvragers, activity, and safety signals.
- [ ] Keep all sample data fictional and non-sensitive.

### Task 4: UI Components

**Files:**
- Create: `/Users/h/Desktop/buurthulp/website/src/components/LoginPanel.tsx`
- Create: `/Users/h/Desktop/buurthulp/website/src/components/AdminDashboard.tsx`
- Create: `/Users/h/Desktop/buurthulp/website/src/components/UserPortal.tsx`
- Modify: `/Users/h/Desktop/buurthulp/website/src/App.tsx`
- Modify: `/Users/h/Desktop/buurthulp/website/src/App.css`

- [ ] Add login entry in the homepage header and CTA.
- [ ] Build role selector and login form.
- [ ] Route admin sessions to the admin panel.
- [ ] Route jongere/buurtbewoner and hulpvrager sessions to role-specific portals.
- [ ] Add logout and return-to-home behavior.

### Task 5: PocketBase Schema Preparation

**Files:**
- Create: `/Users/h/Desktop/qawayhabase/pb_migrations/1781119200_buurthulp_schema.js`
- Create: `/Users/h/Desktop/buurthulp/website/.env.example`
- Create: `/Users/h/Desktop/buurthulp/website/src/domain/pocketbase.ts`

- [ ] Add migration definitions for BuurtHulp profiles, help requests, matches, reviews, and incident reports.
- [ ] Add a frontend environment variable for PocketBase URL.
- [ ] Do not place any admin passwords or service secrets in the website.

### Task 6: Verification

**Files:**
- Modify as needed from previous tasks.

- [ ] Run `npm run test:run`.
- [ ] Run `npm run lint`.
- [ ] Run `npm run build`.
- [ ] Start the site and verify desktop and mobile rendering in the browser.
- [ ] Verify login flows for admin, jongere/buurtbewoner, and hulpvrager.

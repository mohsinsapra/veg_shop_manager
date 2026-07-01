# GreenChain — Multi-Shop Cloud Inventory & Printing — Design Spec

**Date:** 2026-07-01
**Status:** Approved for planning
**App:** `veg_shop_manager` (Flutter, existing codebase)

## 1. Problem & Goal

A vegetable/fruit wholesale business runs multiple retail shops. Each day, staff at
each shop record which items are out of stock and how many units they need. Today this
is done on a **paper grid** (see below): items down the side, one quantity column per
shop, and a combined total column. The owner buys from the wholesale market against the
total, then distributes to each shop by truck using the per-shop quantities.

The paper form (reference):

```
VERDURAS | L | S | T | P |   VERDURAS | L S T P |   FRUTAS | L S T P |
Apio     |   |   |   |   |   ...                |   ...            |
...
```

`L, S, T, P` are **four shops** (by initial); the trailing column is the **combined total**.
The handwritten `SALE / EXPEN / Vender` figures at the bottom are daily accounting the
owner wants surfaced later as analytics.

**Goal:** Reproduce this workflow digitally — cloud-backed so shops log in from anywhere,
with admin-managed shops/catalog/members, an admin combined pivot grid, and PDF printing
in the paper format (per-shop and full).

## 2. Scope

**In scope (this build):**
- Firebase cloud backend (Auth + Firestore), runs on Android, iOS, and Web.
- Google Sign-In; admin whitelists member emails and assigns role + shops.
- Admin management of Shops, Catalog items, and Members.
- Shop-staff entry: quick-add and full-grid modes.
- Admin combined pivot-grid dashboard; mark bought; complete cycle → history.
- PDF printing: shop compact, shop full-grid, admin full grid, admin per-shop.
- Fully responsive mobile + web.

**Designed-for but NOT built now (Phase 4 / future):**
- Monthly analytics: bought-vs-sold, expenses, vendor figures.

**Explicitly out of scope:**
- Phone/SMS auth, payment processing, barcode scanning.

## 3. Approach

Evolve the existing app (Approach A). Keep clean architecture (presentation → domain →
data → core), Riverpod, and Beamer. The current `MissingItem` model already represents
"one shop's need for one item," so the admin paper grid is simply a **pivot** of these
flat rows (rows = items, columns = shops, cell = quantity, last column = total). Swap the
Hive datasource for a Firestore datasource behind the existing repository interfaces;
Firestore's offline persistence provides the offline story. Hive may remain only as an
incidental cache; Firestore is the source of truth.

**New packages:** `firebase_core`, `cloud_firestore`, `firebase_auth`,
`google_sign_in`, `pdf`, `printing`. (`url_launcher` placeholder for printing is
superseded by `printing`.)

## 4. Tech / Architecture

- **Backend:** Firebase — Firestore (data), Firebase Auth (Google provider + anonymous
  not required once Google is primary), App Check (abuse protection).
- **No Cloud Functions.** Role enforcement lives in Firestore security rules via document
  lookups, keeping cost at $0 for ~10 users/day (well within all free tiers).
- **Platforms:** single Flutter codebase → Android, iOS, Web.
- **State/routing:** Riverpod + Beamer (unchanged).
- **Layers:** repositories expose the same interfaces; only datasources change to Firestore.

## 5. Data Model (Firestore)

```
shops/{shopId}
  name: string            // "Shop 1 - Downtown"
  code: string            // "L" (short letter for grid column header)
  sortOrder: number
  active: bool

catalogItems/{itemId}
  name: string            // "Aguacate"
  category: string        // "Vegetables" | "Tomatoes" | "Fruits" | ...
  sortOrder: number
  active: bool

members/{memberId}        // memberId keyed by lowercased email (pre-provisioned)
  email: string           // Google account email, lowercased
  displayName: string
  role: "admin" | "member"
  shopIds: string[]       // shops this member may access (members can span shops)
  active: bool
  uid: string | null      // linked Firebase Auth uid on first sign-in

cycles/{cycleId}
  status: "open" | "completed"
  openedAt: timestamp
  completedAt: timestamp | null
  // Phase 4 (future): salesTotal, expensesTotal, vendorNotes

entries/{entryId}
  cycleId: string
  itemId: string
  itemName: string        // denormalized for print/history stability
  shopId: string
  quantity: number
  notes: string | null
  bought: bool
  createdBy: string       // memberId
  createdAt: timestamp
```

Rationale: `entries` are flat rows (not a nested per-day sheet). The admin grid pivots
them; history is completed cycles + their entries; and flat entries make the future
bought-vs-sold monthly analytics straightforward to query. Item name is denormalized onto
each entry so historical prints stay correct even if the catalog changes later.

**Cycle lifecycle:** at most one cycle has `status == "open"` at a time. If no open cycle
exists when a member adds the first entry, the app auto-creates one (`openedAt = now`).
All new entries attach to the current open cycle. Admin's "Complete cycle" sets it to
`completed` and stamps `completedAt`; the next entry then opens a fresh cycle.

## 6. Auth & Security

- **Sign-in:** Google Sign-In only. Firebase Auth persists the session, so members stay
  logged in (no repeated username/password).
- **Provisioning:** admin creates a `members` doc keyed by the person's lowercased Google
  email, setting `role`, `shopIds`, `active`. On first Google sign-in, the app matches the
  authenticated `token.email` to a `members` doc and links `uid`. Unknown/inactive email →
  "no access, contact admin" screen; no data granted.
- **Role/access enforced in Firestore rules** (no Cloud Function):
  - A signed-in user may read their own `members` doc where `resource.data.email ==
    request.auth.token.email`.
  - `isAdmin()` = a rules lookup of the requester's `members` doc with `role == "admin"`.
  - `shops`, `catalogItems`, `members`, `cycles`: read allowed for any active member;
    write allowed only if `isAdmin()`.
  - `entries`: a member may create/update/delete entries only for shops in their own
    `shopIds` (and only in the open cycle); admin may write any.
- **App Check** enabled to ensure only the genuine app can reach Firestore.
- **Bootstrap:** the first admin `members` doc is seeded manually (console or a one-time
  seed routine) so the owner can log in and provision everyone else.

## 7. Screens & Navigation

**Login (all):** "Sign in with Google" → resolve member → route to admin or member home;
unauthorized → no-access screen.

**Member (shop staff):**
- Shop switcher (active shop when member spans multiple shops).
- Shop home: current open cycle + this shop's entries.
- Quick-add: search catalog item, enter quantity + optional note.
- Grid entry: full catalog by category, one quantity box per row for the active shop
  (blank = not needed).
- Print (my shop): choose compact list or full-grid → PDF.

**Admin:**
- Combined grid dashboard: items × shop columns (by `code`) + Total; check off bought;
  Complete cycle → history.
- Per-shop view + print; Full-grid print (paper format).
- Management: Shops (CRUD + code), Catalog (CRUD + category), Members (whitelist email,
  role, shops, active, view history).
- History: completed cycles, view / re-print.

## 8. PDF Printing (4 templates)

1. **Shop compact** — shop + date + needed items and quantities.
2. **Shop full-grid** — full catalog, single quantity column for that shop.
3. **Admin full grid** — category columns + one column per active shop (`code`) + Total,
   sized dynamically to the number of shops; mirrors the paper form.
4. **Admin per-shop** — compact or grid for a chosen shop (for truck loaders).

All A4, generated with `pdf` + `printing` → print / save / share.

## 9. Responsive Design

Breakpoint-driven (`LayoutBuilder` / `MediaQuery`), Material 3 adaptive:
- **Phone:** single-column views, navigation drawer; the wide pivot grid is horizontally
  scrollable.
- **Tablet / web:** side navigation rail; full multi-column grid visible; wider forms.

## 10. Migration & Seeding

- Seed `catalogItems` from the existing hardcoded Spanish lists in
  `lib/core/constants/app_constants.dart` (categories preserved, `sortOrder` assigned).
- Seed initial `shops` from the existing `predefinedShops` (with letter `code`s).
- Seed one admin `members` doc for the owner (bootstrap).
- Remove the pending deletion of the legacy `veg_inventory_app/` Firebase prototype from
  the working tree as housekeeping (not part of the new app).

## 11. Build Phases

- **Phase 1 — Foundation:** Firebase wiring (Android/iOS/Web) + Google auth + security
  rules + App Check; Firestore data models and repositories; admin management screens
  (Shops, Catalog, Members); catalog/shop/admin seeding.
- **Phase 2 — Entry & grid:** quick-add + grid entry; admin pivot-grid dashboard; cycle +
  history archiving.
- **Phase 3 — Printing & polish:** the 4 PDF templates; responsive refinement.
- **Phase 4 — Future (not now):** monthly bought-vs-sold analytics.

## 12. Success Criteria

- A member signs in with Google and only sees/edits their assigned shop(s).
- Admin can create shops, catalog items, and members without a code change.
- Shop staff can record needs via quick-add and grid; admin sees the combined pivot with
  a correct Total column.
- Admin can print the full paper-format grid and per-shop lists; a shop can print its own
  list. All as A4 PDFs that print/share.
- Admin completes a cycle and it moves to history (retained for future analytics).
- Works and is usable on both phone and web.
- Monthly cost at ~10 users/day is $0.
```

# Clear / Delete History (Admin) — Design

**Date:** 2026-07-01
**Branch:** feature/cloud-inventory-printing

## Goal

Let an admin remove shopping history from the History page so it no longer
appears. Two actions:

1. **Clear all history** — hide every completed cycle at once.
2. **Per-cycle delete** — hide a single completed cycle.

Deletion is a **soft delete**: the underlying Firestore data is preserved but
marked hidden, so it disappears from the list and from printing. There is no
restore/undo UI — the requirement is simply "I don't want to see that history
again."

## Context

- The active History page is `lib/presentation/pages/admin/history_page.dart`
  (`HistoryPage`), rendered by `admin_home_page.dart` as the "History" tab.
- It lists **completed cycles** (`CycleEntity` with `status == completed`),
  most recent first, via `completedCyclesProvider`
  (`lib/presentation/providers/entry_providers.dart`).
- Each cycle card is an `ExpansionTile` (`_cycleCard`) with a trailing
  `PopupMenuButton` (`_printMenu`) offering combined / per-shop PDF print, plus a
  header "Print all history (combined)" button.
- Cycles/entries live in Firestore (`CycleRepository`, `EntryRepository`,
  `FirestoreRefs`). `CycleRepository` currently has no delete method.
- Admin status: `authControllerProvider` → `AuthSessionState.isAdmin`
  (`lib/presentation/providers/firebase_auth_provider.dart`).
- i18n: Flutter gen-l10n. Source ARBs `lib/l10n/app_en.arb` and
  `lib/l10n/app_es.arb`; accessed via `context.l10n`. Default locale is Spanish.
- The legacy `shopping_history_page.dart` is orphaned (not routed) and is **out
  of scope**, but its confirm-dialog + delete flow is a useful reference pattern.

## Data model

Add a nullable hidden marker to the cycle entity.

- `CycleEntity` (`lib/domain/entities/cycle_entity.dart`): add
  `final DateTime? hiddenAt;` (nullable, default `null`). Include it in the
  constructor and any `copyWith`/serialization helpers.
- Firestore serialization (in `CycleRepository` / cycle model mapping): read and
  write `hiddenAt` as a Firestore `Timestamp?`. Absent field → `null`
  (backward compatible with existing documents).
- Definition: a cycle is **hidden** when `hiddenAt != null`.

## Repository

`lib/data/repositories/cycle_repository.dart`:

- `Future<void> hideCycle(String cycleId)` — set `hiddenAt` on one completed
  cycle to the server timestamp.
- `Future<void> hideAllCompleted()` — query all completed, not-yet-hidden cycles
  and set `hiddenAt` on each in a single Firestore batch (mirror the existing
  batched-write pattern such as `setBoughtBatch` on `EntryRepository`). If the
  set is large, chunk into batches of ≤ 500 writes (Firestore batch limit).

Entries are **not** deleted — only the cycle is marked hidden. Hidden cycles are
excluded from reads, so their entries are never fetched.

## Provider

`completedCyclesProvider` (`entry_providers.dart`): filter results to
`status == completed && hiddenAt == null`. This single filter removes hidden
cycles from both the History list and the "Print all history" flow (which reads
the same provider).

## UI (`history_page.dart`)

Gate all delete UI on `ref.watch(authControllerProvider).isAdmin` — non-admins
see no delete affordances.

- **Per-cycle delete:** add a "Delete" item to the existing `_printMenu`
  `PopupMenuButton` on each cycle card. Selecting it opens a confirm dialog; on
  confirm, call `cycleRepository.hideCycle(cycle.id)`.
- **Clear all history:** add a header action (button/icon next to "Print all
  history"). Opens a confirm dialog warning it clears all history; on confirm,
  call `cycleRepository.hideAllCompleted()`, then show a success snackbar.
- Confirm dialogs reuse the app's existing dialog style. After a successful
  clear-all, the list becomes empty and shows the existing
  `adminHistoryEmpty` state.

## i18n

Add matching keys to `app_en.arb` and `app_es.arb`:

- `adminHistoryDeleteCycle` — per-cycle delete menu label
- `adminHistoryDeleteCycleConfirmTitle` / `adminHistoryDeleteCycleConfirmBody`
- `adminHistoryClearAll` — clear-all button label
- `adminHistoryClearAllConfirmTitle` / `adminHistoryClearAllConfirmBody`
- `adminHistoryClearAllSuccess` — success snackbar
- Reuse existing generic `commonCancel` / `commonDelete` (or add if absent).

## Testing / verification

- Manual: as admin, delete one cycle → it disappears and stays gone after
  refresh; clear all → list empties and stays empty after refresh; hidden cycles
  excluded from "Print all history". As non-admin, no delete UI appears.
- Confirm existing Firestore documents without a `hiddenAt` field still load
  (treated as not hidden).

## Out of scope (YAGNI)

- Restore / trash / view-hidden screen.
- Hard delete of Firestore documents.
- Any change to the orphaned legacy `shopping_history_page.dart`.

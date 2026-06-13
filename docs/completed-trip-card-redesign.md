# Completed Trip Card — Layout & Positioning Redesign Brief

## Goal

Redesign the **layout and positioning** of the trip cards shown in the
Transporter app's **Trips → Completed** tab so the cards look more
professional, polished, and visually balanced.

This is a **layout-only** redesign. Make the existing pieces sit better
together — spacing, alignment, grouping, ordering, and structure.

---

## Hard constraints (do NOT break these)

- **No color changes.** Keep every `AppColors.*` reference exactly as-is.
- **No font changes.** Keep all `textTheme.*` styles, `fontWeight`, `fontSize`,
  and `copyWith` text styling exactly as-is.
- **No logic changes.** Do not touch data, conditionals, callbacks, state,
  navigation, or any `if (...)` gating that decides what shows.
- **Do not add new elements.** No new icons, labels, badges, buttons, dividers,
  images, or text.
- **Do not remove elements.** Every widget that can currently appear must still
  be able to appear.
- **Only change:** spacing (`SizedBox`, `padding`, `margin`), alignment,
  ordering/position of existing widgets, grouping/nesting (`Row`/`Column`/
  `Wrap`/`Expanded`), `borderRadius` values, and container `padding` — i.e.
  pure layout/positioning.

---

## Where the code lives

- **Card widget:** `lib/widgets/trip_expansion_card.dart`
  (`TripExpansionCard`) — this is the actual card. **Edit layout here.**
- **List that renders it:** `lib/screens/tabs/trips_tab.dart`
  → `_buildTripsList(AppConstants.tripStatusCompleted, ...)` →
  `_buildTripCard(...)`. The list adds `EdgeInsets.symmetric(horizontal: 24.0)`
  around the cards.

> ⚠️ `TripExpansionCard` is **shared** by all Trips tabs (Active, Awaiting POD,
> Completed, Cancelled, Marketplace). Layout changes apply everywhere, so keep
> all conditional sections intact — just improve how they are arranged.

---

## Current structure (element inventory)

The card is a rounded `Container` (radius 16, 1px border, `bottom: 16` margin)
wrapping an `ExpansionTile`. It has a **collapsed header** and an
**expanded body**.

### Collapsed header (`ExpansionTile.title`)

`tilePadding: horizontal 16, vertical 4`

1. **Top row** (`Row`, cross-start):
   - **Left (Expanded `Column`):**
     - Title — container number, else trip ID, else `"Trip"` (`titleLarge`,
       bold, primary, max 2 lines, ellipsis)
     - Trip ID subtitle — only when both a container number and trip ID exist
       (`bodySmall`, secondary)
     - Reference — only when present (`bodySmall`, secondary, max 2 lines)
   - **Right (trailing controls, in this order):**
     - Pin / unpin `IconButton` (when `showPinButton && onPinTap != null`)
     - "Begin Trip" `FilledButton.icon` (only PLANNED + startable — **not**
       on Completed)
     - Chevron-right `IconButton` → opens detail
     - (ExpansionTile's own expand/collapse arrow)
2. **`SizedBox(height: 8)`**
3. **Badge row** (`Wrap`, spacing 8, runSpacing 8):
   - "Marketplace" pill (only marketplace booking trips)
   - "Queued"/"Queued #n" pill (only queued)
   - **Status pill** (always — for Completed this is the green "Completed" pill)
   - Trip-type label text (always)
   - Live status badge (only ACTIVE trips — **not** on Completed)

### Expanded body (`ExpansionTile.children`)

`childrenPadding: (16, 0, 16, 16)`

1. **Origin → Destination row** (when pickup and/or drop exist):
   - Origin info block (icon + "Origin" label + address) in `Expanded`
   - `arrow_forward` icon between them (only when both exist)
   - Destination info block in `Expanded`
2. **`SizedBox(height: 16)`**
3. **"Created: <date>" panel** — off-white rounded `Container` (radius 12,
   padding 12) with a calendar icon + created date text.
4. Accept / Reject button row (only Marketplace — **not** on Completed).

> **Net result for a Completed card specifically:** title block + pin + chevron
> in the header; a green "Completed" status pill and trip-type label below it;
> and when expanded, the Origin → Destination row plus the "Created" date panel.

---

## What feels off today (redesign targets)

Improve these through layout/positioning only:

1. **Header trailing controls feel cramped** — pin button, chevron, and the
   expansion arrow stack tightly on the right. Improve their spacing, vertical
   alignment, and balance against the title block.
2. **Title vs. trailing alignment** — title is `titleLarge` and tall; trailing
   icons are top-aligned (`crossAxisAlignment.start`). Consider vertical
   centering / consistent baseline so the row reads cleanly.
3. **Badge row rhythm** — the status pill, trip-type text, and other pills have
   slightly different vertical paddings (pills use `vertical: 5–6`, plain text
   has none), so they don't sit on a tidy shared line. Align them to a common
   vertical center and consistent gaps.
4. **Subtitle stack spacing** — trip ID and reference each use `SizedBox(4)`;
   confirm consistent vertical rhythm between title → trip ID → reference.
5. **Expanded body breathing room** — the Origin→Destination row sits directly
   under the header with no top gap; add/normalize spacing so the expanded
   content feels intentional and separated from the header.
6. **Origin → Destination balance** — the center `arrow_forward` uses a hard
   `top: 20` padding to fake-align with the address line. Find a cleaner
   vertical alignment between the two `Expanded` blocks and the arrow.
7. **"Created" panel placement** — make its spacing above/below consistent with
   the rest of the body so it reads as a footer detail.
8. **Overall padding harmony** — `tilePadding`, `childrenPadding`, and inner
   container paddings should feel like one consistent spacing scale.

---

## Acceptance criteria

- Looks more professional, balanced, and aligned on a typical phone width.
- Every existing widget still renders under the same conditions as before.
- No color, font, text-style, or logic diffs — only layout/positioning,
  spacing, alignment, ordering, grouping, and radius/padding values.
- Other Trips tabs (Active, Awaiting POD, Cancelled, Marketplace) still render
  correctly because the widget is shared.
- `flutter analyze` stays clean.

---

## Suggested approach (optional)

- Establish a small spacing scale (e.g. 4 / 8 / 12 / 16) and apply it
  consistently instead of mixed ad-hoc values.
- Vertically center the header `Row` controls relative to the title block.
- Give the badge `Wrap` a consistent item height so pills + label line up.
- Add a deliberate top gap to the expanded body and align the
  Origin → Destination row without the hard-coded `top: 20` offset.

# Revision plan for code_review_improvements_dry_dead_code.md

Apply the following edits to [.cursor/plans/code_review_improvements_dry_dead_code.md](.cursor/plans/code_review_improvements_dry_dead_code.md). Verified facts: `unified_waypoint_card.dart` exists; `waypoint_shared_components.dart` has no shared app bar (only FAB); shared `SectionHeader` lives in `components/adventure/section_header.dart` with inline duplicates in `adventure_card.dart` and `itinerary_select_screen.dart`.

---

## 1. Confirm or create unified_waypoint_card (Section 1.1)

**Change:** Remove ambiguity. The file **exists** at `lib/components/waypoint/unified_waypoint_card.dart`. In 1.1, replace "or use existing lib/components/waypoint/unified_waypoint_card.dart" with: "Use the existing `lib/components/waypoint/unified_waypoint_card.dart` (confirm it supports a type parameter or extend it for hotel | poi | airbnb)." So the recommendation is "use existing" with an explicit note to confirm/extend, not "create it."

---

## 2. Cross-reference prior DRY plan for WaypointAppBar (Section 1.2)

**Change:** Add one sentence after the recommendation: "Before implementing, check the existing DRY/branding plan and whether `WaypointSharedComponents` (or another shared module) already defines a shared app bar — avoid a second parallel implementation." No shared app bar exists in waypoint_shared_components today; the note ensures coordination with prior plan.

---

## 3. Elevate WaypointSpacing unification and make it concrete (Section 1.5)

**Changes:**

- **Priority:** Move 1.5 into the "High priority" list in the Summary table and state in the section that duplicate `WaypointSpacing` is a **correctness bug** (wrong spacing values), not just style.
- **Which wins:** State explicitly: **Winner: `lib/core/theme/spacing.dart`** (more complete: full scale, edge insets, component tokens, layout constants). It is already exported via `lib/core/theme/waypoint_theme.dart` and `lib/theme.dart`.
- **Tokens:** Add a short bullet list:
  - **Missing in core:** `cardPaddingInsets` (theme/waypoint_spacing uses 14px; core has `cardPadding` = 16px). Either add `cardPaddingInsets = EdgeInsets.all(14)` to core or standardize on 16px and migrate call sites.
  - **Value conflict:** `sectionGap` is 24 in core vs 32 in theme/waypoint_spacing — decide one value and use it everywhere.
- **Audit:** Add step: "Audit all imports: grep for `waypoint_spacing.dart` and `spacing.dart`; migrate every file that imports `theme/waypoint_spacing.dart` to use `theme.dart` (or core/waypoint_theme) only; then delete or re-export `lib/theme/waypoint_spacing.dart`."
- **Concrete decision:** End 1.5 with: "Decision: Pick core, add any agreed missing tokens, audit and fix imports, then remove the duplicate class (delete or deprecate `theme/waypoint_spacing.dart`)."

---

## 4. Cross-reference dark mode plan in Section 3.1

**Change:** At the start of 3.1, add: "**Coordination:** The dark mode sync plan (see that plan document) already scopes waypoint_detail_page, adventure_detail_screen, and adventure components. Implement theme fixes there to avoid duplicate or inconsistent approaches. This section summarizes scope only." Then keep the list of files/usages as a summary, not a second implementation plan.

---

## 5. Binary decision for legacy support (Section 2.3)

**Change:** Replace the vague "keep or document" with an explicit resolution option. For example:

- "**Decision (choose one):** (A) We are keeping legacy support — document in 2.3 that `route_waypoint_legacy.dart` is kept for compatibility; no removal. (B) We are dropping legacy support by [date/milestone] — add removal of `route_waypoint_legacy.dart` and related imports to the dead-code work. (C) Remove this item from the plan until product decides; track elsewhere."

So 2.3 becomes actionable: either document keep, schedule removal, or defer the item.

---

## 6. Replace 3.3 error handling with specific flows

**Change:** Replace the broad "many catch blocks only log" with: "**User-visible error handling:** Add or improve feedback for these critical flows only: (1) payment/checkout failure, (2) trip delete/fail, (3) auth/sign-in errors, (4) trip load failure (e.g. checklist, my trips), (5) save failure (e.g. waypoint edit, plan save). For each, define one approach (e.g. snackbar + retry or dialog). All other catch blocks can remain log-only; track in a separate tech-debt list if desired."

---

## 7. Remove or park 3.4 (linting)

**Change:** Replace 3.4 with: "**Linting (parked):** Enabling new lint rules in `analysis_options.yaml` will generate many warnings across unrelated files and create noise during feature work. Do not enable as part of this plan; track in a separate tech-debt or tooling ticket."

Optionally remove 3.4 from the Summary table or mark it "Parked / separate ticket."

---

## 8. Reorder document body to match priority table

**Change:** Reorder sections so implementation order matches stated priorities:

1. **First (High):** Dead code (current 2.1, 2.2, 2.3) and nav cleanup.
2. **Second (High):** WaypointSpacing unification (current 1.5) — correctness bug.
3. **Third (High):** Theme/dark mode consistency (current 3.1), with cross-reference to dark mode plan.
4. **Then:** DRY improvements (1.1, 1.2, 1.3, 1.4, 1.6, 1.7), then remaining issues (3.2, 3.3, 3.4).

The Summary table at the bottom already lists: dead screens → dead widget/export → theme → WaypointSpacing → DRY → etc. The body should follow that order (e.g. Section 2 first, then 1.5, then 3.1, then rest of 1.x, then 3.2–3.4).

---

## 9. Missing items to add

**WaypointCreamChip spacing:** Add a short bullet under a "Shared component fixes" or under 1.4/1.7: "**WaypointCreamChip:** Chips in a Wrap were touching; ensure Wrap uses consistent spacing (e.g. `spacing: 8`, `runSpacing: 8`) where chips are used (e.g. My Trips). Fix in the shared chip or in the Wrap usage so all chip rows are consistent."

**SectionHeader usage audit:** Add a bullet (e.g. under 1.6 or new 1.8): "**SectionHeader:** Audit usage of `SectionHeader` from `lib/components/adventure/section_header.dart` vs inline implementations (e.g. `SectionHeader` in `adventure_card.dart`, `_SectionHeader` in `itinerary_select_screen.dart`, `_buildSectionHeader` in `day_content_builder.dart`). Prefer the shared component and migrate or remove duplicates so section headers are consistent."

**analysis_options:** Already covered in revised 3.4 (park in separate ticket).

---

## 10. Summary table and priority wording

**Change:** In the Summary table, mark WaypointSpacing as **High** (not Medium). Optionally add a one-line note under the table: "Implementation order: follow section order (dead code → spacing unification → theme → DRY → remaining issues)."

---

## Execution checklist

- [ ] 1.1: Reword unified_waypoint_card to "use existing … confirm or extend."
- [ ] 1.2: Add cross-reference to prior DRY plan and check before implementing.
- [ ] 1.5: Elevate to High; add winner (core), missing tokens, value conflict, audit step, concrete decision.
- [ ] 3.1: Add coordination note and reference to dark mode plan.
- [ ] 2.3: Replace with binary decision (keep + document / drop by date / remove item).
- [ ] 3.3: Replace with list of 3–5 critical error flows.
- [ ] 3.4: Replace with "parked / separate ticket" and remove or park in table.
- [ ] Reorder document: 2 → 1.5 → 3.1 → 1.1, 1.2, 1.3, 1.4, 1.6, 1.7 → 3.2, 3.3, 3.4.
- [ ] Add WaypointCreamChip spacing and SectionHeader audit.
- [ ] Summary table: WaypointSpacing High; add implementation-order note if desired.

# Unified Checklist with Reusable Categories, Item Fields, and Suggestions

## Current state

- **Checklist tab** (builder and trip) contains two separate blocks:
  1. **Travel Preparation** ([`adventure_context_model.dart`](lib/models/adventure_context_model.dart)): fixed structure (`Prepare`) with dedicated models and UI for Travel Insurance, Visa, Passport, Permits (list), Vaccines, and Climate. Rendered via `_buildPrepareSection` and many `_buildPrepareInfoCard` calls in [`adventure_detail_screen.dart`](lib/presentation/adventure/adventure_detail_screen.dart) and [`builder_screen.dart`](lib/presentation/builder/builder_screen.dart).
  2. **Packing List**: generic categories and items ([`PackingCategory`](lib/models/plan_model.dart) / [`PackingItem`](lib/models/plan_model.dart)), with form state in [`sub_form_states.dart`](lib/state/sub_form_states.dart). Item fields: `id`, `name`, `description`, `quantity`; form also has `isEssential`. UI: [`_PackingCategoryCardWidgetNew`](lib/presentation/builder/builder_screen.dart) in builder_screen and equivalent in adventure_detail_screen.

- **Trip/member checklist**: [`MemberPacking`](lib/models/trip_selection_model.dart) stores `itemId -> checked` for all items from the version's packing categories; no distinction between "packing" and "documents" — all items are already checkable the same way.

## Target state

- **Single checklist**: One list of categories, each with items. Categories can be "Packing" (e.g. Food & Drinks, Clothing, Gear), "Documents" (Travel insurance, Visa, Passport, Permits), "Vaccines", or any custom name. Same data model and UI for all.
- **Item fields**: Every item gets three optional fields: **note**, **link**, **price** (in addition to existing name, description, quantity, essential). **Price**: free-text string in v1 (e.g. "€50" or "~$30"); no structured amount + currency for now.
- **Suggestions**: Builders see suggested categories and items (e.g. "Documents", "Vaccines", "Food & Drinks") they can add with one tap. **Behavior**: support both (a) "Add category + all suggested items" on first tap, and (b) **add a single suggested item to an existing category** (e.g. category "Vaccines" exists; user taps suggestion "Yellow Fever" → add only that item). Decide chip/button layout accordingly (e.g. category-level chips + per-category expandable list of item suggestions, or "Add Documents" vs "Add Yellow Fever" when Vaccines category is selected).
- **Travel Preparation removed**: The fixed Prepare cards for insurance/visa/passport/permits/vaccines are removed; that content is represented as checklist categories/items. Climate stays in Prepare (see Prepare write boundary below).

---

## Review amendments (things to watch)

### 1. Migration: use a flag, not name-matching

**Problem**: Heuristic "if no category named Documents exists, create one" can misfire if the user already created a "Documents" category with different items — we could duplicate or overwrite on every load.

**Approach**: Use a **migration flag** (or version marker) so we run Prepare → categories synthesis at most once per version.

- **Option A (recommended)**: Store a flag on the version when we first migrate (e.g. in Firestore `plan_versions` doc: `checklist_migrated_from_prepare: true`). On load: if `checklist_migrated_from_prepare == true`, skip synthesis; otherwise, if `version.prepare` has document/vaccine data, run migration and set the flag on next save.
- **Option B**: Store a hash or list of "migrated Prepare field keys" (e.g. `["travel_insurance","visa","passport","permits","vaccines"]`) and only run migration when that list is absent. Same idea: one-time migration, never re-run based on category names.

Do **not** use category name (e.g. "Documents") to decide whether to migrate.

### 2. Prepare write boundary (explicit)

When saving a version, **explicitly**:

- **Stop writing** to `prepare`: `travel_insurance`, `visa`, `passport`, `permits`, `vaccines`. (Either omit these keys or write empty/null so old clients don't see stale data if desired.)
- **Keep writing** to `prepare`: `climate` (and any other fields still in use). Existing trips that read `Prepare.climate` must keep working.

Document this in code (e.g. comment in `adventure_save_service` or wherever Prepare is serialized) and in this plan so we don't accidentally remove climate writes.

### 3. Edit dialog UX: collapsible optional fields

The edit dialog will have many fields (name, quantity, description, note, link, price). To avoid a very tall dialog:

- Group the three new fields under a **collapsible section** (e.g. "Optional details" or "Advanced") that is collapsed by default. Expand on tap so most items only show name/quantity/description unless the user needs note/link/price.

### 4. Suggestions: support adding a single item to an existing category

Decide up front so chip behavior doesn't need a redesign later:

- **Category-level**: "Add Documents", "Add Vaccines", "Add Food & Drinks" → adds the category and all suggested items if the category doesn't exist.
- **Item-level**: When the user has selected or expanded a category (or when that category already exists), show **per-item suggestions** (e.g. "Travel insurance", "Visa", "Yellow Fever") that add only that item to the selected/existing category. If no category exists for that suggestion type, create the category and add the item.

Implementation detail: e.g. a section "Suggested items" with chips like "Travel insurance", "Visa", "Yellow Fever", etc.; on tap, find or create the appropriate category (Documents / Vaccines) and append the item. Keeps UX simple and avoids "add whole category only" limitation.

### 5. Price and search/filter

- **Price**: v1 = **free-text string** only (e.g. "€50", "$30–40"). No structured amount + currency for now.
- **Search/filter**: Out of scope for v1. If the unified list grows long (Documents + Vaccines + many packing categories), consider adding search/filter in a later iteration; note this as a possible future enhancement.

---

## 1. Data model: extend item with note, link, price

- **[`lib/models/plan_model.dart`](lib/models/plan_model.dart)**
  - In `PackingItem`, add optional: `String? note`, `String? link`, `String? price` (free-text).
  - Update `fromJson` / `toJson` (e.g. `note`, `link`, `price`) with backward compatibility (omit if null).

- **[`lib/models/plan_version_model.dart`](lib/models/plan_version_model.dart)**
  - No structural change; it already uses `PackingCategory`/`PackingItem` from plan_model. Ensure serialization passes new fields if they are stored in version JSON.

- **[`lib/state/sub_form_states.dart`](lib/state/sub_form_states.dart)**
  - In `PackingItemFormState`, add optional controllers (or lazy-backed like `quantityCtrl`) for note, link, and price.
  - Update `fromModel` and `dispose` to handle the new fields.

- **Persistence**
  - [`adventure_save_service.dart`](lib/services/adventure_save_service.dart) `_composePackingCategories`: when building `PackingItem` from form state, include `note`, `link`, `price` from the new controllers.

## 2. UI: item row and edit dialog (note, link, price)

- **Builder**
  - In [`builder_screen.dart`](lib/presentation/builder/builder_screen.dart) (and equivalent in [`adventure_detail_screen.dart`](lib/presentation/adventure/adventure_detail_screen.dart)):
    - **Item chip** (`_buildItemChipNew`): show optional note/link/price (e.g. small icon or tooltip for "has note/link/price"), and make link tappable if present.
    - **Edit item dialog** (`_showEditItemDialogNew`): add optional fields **inside a collapsible "Optional details" section** (collapsed by default): Note (multiline), Link (URL), Price (free-text).
  - Same changes in adventure_detail_screen's packing category card and edit dialog if they are separate.

- **Trip / member view** (read-only checklist)
  - In [`member_packing_screen.dart`](lib/presentation/trips/member_packing_screen.dart) and trip details packing UI: when showing an item, optionally display note (e.g. expandable or tooltip) and tappable link; price can be shown next to the label if present. No model change for `MemberPacking` (still `itemId -> bool`).

## 3. Unified checklist: replace Travel Preparation with categories

- **Remove** the Travel Preparation block from the checklist tab (builder and trip):
  - Builder: [`adventure_detail_screen.dart`](lib/presentation/adventure/adventure_detail_screen.dart) `_buildBuilderPrepareTab` and [`builder_screen.dart`](lib/presentation/builder/builder_screen.dart) `_buildStep4Prepare` / `_buildPackingTab`.
  - Delete or collapse the whole "Travel Preparation" section and the `_buildPrepareSection` + `_buildPrepareInfoCard` usages for travel insurance, visa, passport, permits, vaccines (keep Climate in a small separate block or leave in Prepare).

- **Single category list**: The checklist tab shows only one list of categories (each with name + items). So "Packing" (Food & Drinks, Clothing, Gear), "Documents" (Travel insurance, Visa, Passport, Permits), "Vaccines", etc. are all entries in the same `version.packingCategories`. No separate Prepare-based cards.

- **Migration (load)** — **with flag, not name-matching**
  - When loading a version: **only if** the version does **not** have the migration flag set (e.g. `checklist_migrated_from_prepare != true`), and `version.prepare` has document/vaccine data, run **one-time** synthesis: create "Documents" / "Vaccines" categories and items from Prepare and append them to the form state's category list. Set the migration flag so the next save persists it (e.g. `checklist_migrated_from_prepare: true` on the version doc). Do not use presence or name of a "Documents" category to decide.
  - Map old fields to the unified item: e.g. Travel Insurance → one item "Travel insurance" with note = recommendation + note, link = url; Visa → "Visa" with note = requirement + note; Passport → "Passport" with note = validity + blank pages; Permits → one item per permit (name from type, note/details, price from cost); Vaccines → one item per required/recommended vaccine.

- **Migration (save)** — **explicit Prepare boundary**
  - **Stop writing** to `prepare`: `travel_insurance`, `visa`, `passport`, `permits`, `vaccines`. (Omit or clear these when writing the version doc.)
  - **Keep writing** to `prepare`: `climate` only (so existing trips that read `Prepare.climate` keep working).
  - Persist `packing_categories` as the source of truth for all checklist content including documents and vaccines. Persist the migration flag when set.

- **VersionFormState / Prepare**
  - Over time, remove the Prepare-specific controllers and `generatedPrepare` usage for insurance/visa/passport/permits/vaccines. Keep only what's needed for Climate. Document the write boundary in code.

## 4. Suggestions for categories and items

- **Define presets**
  - Add a small constant or config (e.g. `lib/data/checklist_suggestions.dart`): categories with item names, e.g. "Documents" → [Travel insurance, Visa, Passport, Permits]; "Vaccines" → [Yellow Fever, Hepatitis A, Tetanus, Typhoid, Covid-19, ...]; "Packing" → Food & Drinks, Clothing, Gear, Electronics, Toiletries.

- **Builder UI** — **category-level and item-level**
  - **Category-level**: Chips like "+ Documents", "+ Vaccines", "+ Food & Drinks". On tap: if that category does not exist, add category + all suggested items; if it already exists, do nothing (no duplicate category).
  - **Item-level**: A "Suggested items" area (or per-category "Add suggested item" dropdown/list): e.g. "Travel insurance", "Visa", "Yellow Fever", etc. On tap: find the appropriate category (Documents / Vaccines) or create it if missing, then add **only that item** to that category. This lets users add one suggested item to an existing category without re-adding the whole set.

- Keep existing "Add category" and "Add item" for fully custom content.

## 5. Files to change (summary)

| Area | Files |
|------|--------|
| Models | [`lib/models/plan_model.dart`](lib/models/plan_model.dart) (PackingItem: note, link, price) |
| Form state | [`lib/state/sub_form_states.dart`](lib/state/sub_form_states.dart) (PackingItemFormState) |
| Save | [`lib/services/adventure_save_service.dart`](lib/services/adventure_save_service.dart) (_composePackingCategories; **explicit Prepare write boundary**: stop travel_insurance/visa/passport/permits/vaccines, keep climate) |
| Load / migration | Version load path: set/read **migration flag** (e.g. `checklist_migrated_from_prepare`), run synthesis only when flag not set |
| Builder UI | [`lib/presentation/builder/builder_screen.dart`](lib/presentation/builder/builder_screen.dart) (item chip, edit dialog with **collapsible optional details**, suggestions: category + item-level) |
| Adventure checklist tab | [`lib/presentation/adventure/adventure_detail_screen.dart`](lib/presentation/adventure/adventure_detail_screen.dart) (unified list, item fields, suggestions; remove Prepare block; keep Climate) |
| Trip/member view | [`lib/presentation/trips/member_packing_screen.dart`](lib/presentation/trips/member_packing_screen.dart), [`lib/presentation/trips/trip_details_screen.dart`](lib/presentation/trips/trip_details_screen.dart) (display note, link, price; link tappable) |
| New | `lib/data/checklist_suggestions.dart` (preset categories and item names) |

## 6. Order of implementation

1. **Extend model and form state**: Add note, link, price (free-text) to `PackingItem` and `PackingItemFormState`; update save composition and JSON.
2. **Item UI**: Update builder (and adventure) item chip and edit dialog with **collapsible "Optional details"** for note, link, price; update trip/member view to show them.
3. **Suggestions data + UI**: Preset definitions; category-level chips; **item-level suggestions** (add one item to existing or new category).
4. **Unify checklist**: Remove Travel Preparation section; one category list; **migration with flag** (no name-matching); **explicit Prepare write boundary** (stop insurance/visa/passport/permits/vaccines, keep climate).
5. **Cleanup**: Remove Prepare controllers and Prepare-section UI for document/vaccine; keep Climate handling.

## 7. Optional / future

- **Climate**: Kept in Prepare; small "Climate" block on checklist tab that still reads/writes `version.generatedPrepare?.climate`. Document the Prepare write boundary in code.
- **Search/filter**: Not in v1; consider for a later iteration when the unified list is long.
- **Price**: v1 = free-text only; structured amount + currency can be added later if needed.

---

**Summary**: The plan reuses PackingCategory/PackingItem for Documents and Vaccines, adds note/link/price (price = free-text), uses a **migration flag** instead of name-matching, **explicitly** keeps writing only `prepare.climate` while stopping the rest, uses a **collapsible optional-details** section in the edit dialog, and supports **item-level suggestions** as well as category-level. Migration logic and the Prepare write boundary deserve the most careful attention during implementation.

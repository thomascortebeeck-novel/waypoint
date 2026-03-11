---
name: Back Levels Check-ins Roles Vote Shared Checklist (REVISED)
overview: Implement "Back" brand term, user/creator levels, location-based check-ins, trip member roles, waypoint voting (owner vs democracy with version lock), shared group packing (subcollection), crew term, offline/optimistic UI, push notifications, and Firestore read-cost strategy.
todos: []
isProject: false
---

# Plan: Back, Levels, Check-ins, Roles, Vote, Shared Checklist, Crew (REVISED)

This revision addresses: creator level thresholds (concrete table), check-in rank query index and scale note, waypoint voting version lock and slot snapshotting, shared checklist subcollection-only, offline/optimistic UI, push notifications, crew term decision, and Firestore read-cost strategy.

---

## Scope summary

- **a)** "Back" as **brand/copy only** — replace Buy/purchase CTAs with "Back [Creator]"; use existing salesCount for "X people have backed this"; no new data or services.
- **b)** User levels (1–5) from completed trips; **creator levels with defined thresholds and names**.
- **c)** Check-ins at waypoints — **location-based** (geolocator, 200m, day guard, manual fallback); **Firestore index and scale note**.
- **d)** Assign roles to members in trip members UI.
- **e)** **Crew** — single decided term and where it’s used.
- **f)** Waypoint decision mode (owner vs vote) with **version lock and slot snapshot** when voting opens; tie-break random.
- **g)** Shared checklist — **subcollection only** (no array-of-maps); group items add/toggle by participants.
- **New:** Offline/optimistic UI for check-ins and votes.
- **New:** Push notifications (crew check-in, vote reminder, vote resolved).
- **New:** Firestore read-cost strategy (avoid streaming all trip subcollections at once).

---

## a) "Back" as brand term (copy only, no new feature)

**"Back" is a brand/copy decision, not a new feature.** When someone buys a plan, they are already "backing" the creator. The purchase flow stays as is; only the language changes.

**What to do:**

- Replace purchase/buy CTA language with **"Back [Creator name]"** (or "Back this plan") on the plan detail screen and creator cards. The existing order/purchase flow is unchanged.
- Optionally surface **"X people have backed this"** using the existing `**salesCount`** field already on the plan — no new counter or field needed.
- **No BackService, no `users/{uid}/backs` subcollection, no `back_count` field, no Firestore changes.** This is a pure UI/copy change (on the order of an hour of work, not a full feature).

---

## b) User and creator levels

**User levels (by completed trips)** — unchanged:


| Level | Name          | Completed trips |
| ----- | ------------- | --------------- |
| 1     | First steps   | 0               |
| 2     | Explorer      | 1–2             |
| 3     | Adventurer    | 3–4             |
| 4     | Wayfinder     | 5–9             |
| 5     | Trail veteran | 10+             |


**Creator levels (by total plans sold) — defined:**


| Level | Name         | Total plans sold |
| ----- | ------------ | ---------------- |
| 1     | New creator  | 0                |
| 2     | Rising       | 1–4              |
| 3     | Local expert | 5–19             |
| 4     | Top creator  | 20–49            |
| 5     | Trail legend | 50+              |


- **Data:** Denormalized `total_plans_sold` on UserModel; updated when an order completes (OrderService or Cloud Function). Sum of `sales_count` for plans where `creator_id == userId` is the source of truth; denormalize for profile/list performance.
- **Single source of copy:** Define both ladders in one place (e.g. `lib/core/constants/level_names.dart` or l10n) so UI and copy stay in sync. Nail these names and thresholds before building level badges to avoid refactoring later.

---

## c) Check-ins at waypoints (location-based)

**Intent:** When a member is on the correct trip day and (optionally) near the waypoint, they can check in. Location is checked once when they tap "Check in"; manual fallback if permission denied or GPS unavailable. No background tracking.

**Package and radius:** Use `[geolocator](https://pub.dev/packages/geolocator)` for one-shot location. Default radius **200 m** around waypoint lat/lng (distance via `Geolocator.distanceBetween`). Day guard: check-in only when current date equals that day of the trip (`startDate + (dayNum - 1)`).

**Permission handling:** Request location on first check-in attempt. If granted → run GPS check. If denied → show manual fallback ("Check in without location"). If denied forever → prompt to open Settings. Cache permission state so the app doesn’t re-request on every waypoint.

**Check-in flow (step by step):**

1. User opens waypoint card on current trip day. If today is not that day → show greyed "Check in available on [date]". If today is that day → show active "Check in" button.
2. User taps "Check in". App gets current position (`geolocator.getCurrentPosition`, high accuracy, timeout e.g. 10s).
3. **Success:** Compute distance to waypoint. If within 200 m → confirm check-in (write doc). If outside 200 m → show "You're Xm away — check in anyway?" with [Get closer] / [Check in anyway (manual)].
4. **Timeout/error:** Show "Can't get your location. Check in anyway?" (manual).
5. Write one check-in doc per (tripId, dayNum, waypointId, userId) — idempotent (e.g. doc ID `day_{n}_{waypointId}_{userId}`). Set `method: "location"` or `"manual"`, optional `distance_m`, `accuracy_m`.
6. Show confirmation: "You're the Nth to check in here" (compute rank from check_ins for that waypoint ordered by `created_at`).

**Data model — subcollection `trips/{tripId}/check_ins`:**

Each doc: `id`, `day_num`, `waypoint_id`, `user_id`, `created_at`, `method` ("location" | "manual"), `accuracy_m` (optional), `distance_m` (optional, null if manual), optional `photo_url`, `note` for later.

**CheckInService (signatures):**

- `Future<CheckInResult> checkIn({ required tripId, dayNum, waypointId, userId, required LatLng waypointLocation, bool forceManual = false })` — day guard, optional GPS check, idempotent write, returns rank/count/method/distance.
- `Stream<List<CheckIn>> streamCheckInsForWaypoint(tripId, dayNum, waypointId)`; `Future<int> getCheckInRank(...)`; `Stream<List<CheckIn>> streamTripCheckIns(tripId)` for crew feed.

**CheckInResult:** `success`, `rank`, `totalCount`, `method`, `distanceM?`.

**LocationService helper:** `getCurrentLocation()` → `{ position, permissionStatus, error }`; `distanceTo(from, to)`; `isWithinRadius(current, target, { radiusM: 200 })`.

**UI states (waypoint card):** Future day → "Check in available on [date]" (greyed). Today, not checked in → "Check in" button. Today, checked in → "You're the Nth to check in · X total". Location denied → "Check in (manual)". After check-in → confirmation sheet with rank and optional avatars of others who checked in.

**Packages and manifests:** Add `geolocator: ^11.0.0` in `pubspec.yaml`. Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`. iOS: `NSLocationWhenInUseUsageDescription` (e.g. "Waypoint uses your location to confirm check-ins at stops on your trip."). No background location.

**Firestore index and scale:**

- **Index required:** Composite on `trips/{tripId}/check_ins`: `waypoint_id` (ASC), `created_at` (ASC). Declare in `firestore.indexes.json`.
- **Scale note:** Rank query over this subcollection is not cheap at very high check-in counts. Later options: summary doc updated by Cloud Function, or cap display ("One of the first 50"). For launch, direct query is acceptable; monitor read cost.

---

## d) Roles in member interface

Unchanged: Option B — `member_roles` map on Trip; TripService.updateMemberRole; role selector on trip members screen (Owner, Navigator, Packing lead, Member).

---

## e) Term for "crew"

**Decision:** Use **Crew** as the single term everywhere. No second option or A/B for this project.

**Where it appears:**

- Trip members screen: section title "Crew" (or "Crew (N)").
- Invite copy: "Share with your crew", "Invite your crew."
- Packing/checklist: "Crew packing progress", "Shared crew items" (for shared checklist).
- Trip feed / activity: "Crew check-ins", "Recent crew activity."
- Any notification or email: "Your crew…", "A crew member…."

**Implementation:** Single constant or l10n key (e.g. `AppStrings.crewLabel = 'Crew'`) used in all of the above so one change updates the whole app. No data model change.

---

## f) Waypoint decision mode: owner vs vote (with version lock)

**Version lock and slot stability:**

- The trip already has `planId` and `versionId`; the itinerary and waypoint options are tied to that version. **Risk:** If slot IDs are derived from the live plan (e.g. `day_1_accommodation`) and the plan is edited after the trip is created, slots could change or disappear.
- **Requirement:** When voting is used, **snapshot the voting slots at the time voting is opened**, not from the current plan document. Use the trip’s **plan version** (the version already locked to the trip) to build the list of slots and options once; store that snapshot in the voting data so slot IDs and option lists are immutable for that trip.

**Concrete approach:**

1. **When owner sets decision mode to "Members vote":**
  - Load trip’s plan + version (via trip.planId and trip.versionId).
  - From the version’s day structure, build slots: e.g. for each day, accommodation (if any), restaurant_breakfast/lunch/dinner, activity_0, activity_1, … . Each slot has a stable `slot_key` (e.g. `day_1_accommodation`) and a list of `options` (waypoint/option IDs and labels from that version).
  - Write to **subcollection** `trips/{tripId}/waypoint_votes/{slot_key}` — **one document per slot** (e.g. `day_1_accommodation`, `day_2_restaurant_lunch`). Each doc has `options`, `votes` (Map userId → optionId), `resolved_option_id`, `closed_at`. **Decision: subcollection per slot** (not a single doc with a slots map). Rationale: many members voting at once would cause write contention on one doc; per-slot docs allow concurrent writes without conflict.
  - Important: **options** are copied from the plan version at this moment; they are not read again from the plan when displaying or resolving votes. This locks the ballot.
2. **Slot keys:** Use a deterministic scheme from the locked version, e.g. `day_{n}_accommodation`, `day_{n}_restaurant_{meal}`, `day_{n}_activity_{index}`. If the plan version has no accommodation for day 2, there is no such slot — so no fragility from "missing" slots.
3. **Flow:**
  - Owner sets "Members vote" → backend/app creates vote docs with snapshot of slots and options.
  - Members see "Vote" entry point; each slot shows the snapshot options; each member submits one option per slot (overwrites previous vote).
  - Owner (or system) closes voting per slot or globally; on close: count votes, pick max; tie = random among tied options; write `resolved_option_id` and then **write the result into TripDaySelection** for that day/type so the rest of the app (itinerary, bookings) sees the same structure as owner-chosen flow.
  - ItinerarySelectScreen: if mode is vote, show read-only resolved selections after close; if voting still open, show link/button to voting UI.
4. **Data:** Trip: `waypoint_decision_mode` (`owner` | `vote`), optional `waypoint_vote_ends_at`. Votes: **subcollection** `trips/{tripId}/waypoint_votes/{slot_key}` with snapshot `options`, `votes`, `resolved_option_id`, `closed_at` per slot.

**Fleshed-out voting flow (steps):**

1. Owner opens Trip settings / Member page → "Waypoint choices: Owner decides | Members vote." Saves to Trip.
2. If "Members vote" selected for the first time: app/backend creates vote state from trip’s plan version (snapshot slots + options). If vote state already exists, skip.
3. Members open "Vote" (from trip overview or itinerary): list of slots; each slot shows option cards; tap to submit vote (overwrites). Show "Voting open" until owner closes.
4. Owner (or deadline) closes voting: for each slot, compute winner (max votes; tie = random), set `resolved_option_id`, set `closed_at`. Then for each slot, map resolved option to TripDaySelection (selectedAccommodation, selectedRestaurants, selectedActivities) and call existing TripService.updateDaySelection (or batch update). After that, itinerary shows resolved choices like owner flow.
5. ItinerarySelectScreen: when mode is vote and voting closed, load TripDaySelection and show read-only. When mode is owner, current behavior unchanged.

---

## g) Shared checklist (group items)

**Intent:** One list of group-level items that any participant or owner can add; anyone can check off. Shown alongside personal packing.

**Data — subcollection only:**

- Use **only** the subcollection approach. Do not store shared items as an array-of-maps on a single document (hits 1MB limit and causes concurrent toggle conflicts).
- **Subcollection:** `trips/{tripId}/shared_packing` with one document per item. Document fields: `id`, `label`, `added_by` (userId), `checked` (bool), `created_at`. Stable IDs (e.g. auto-ID) for add/remove/toggle.
- **Service:** addSharedItem, toggleSharedItem, removeSharedItem, streamSharedPackingItems. Only trip members (and owner) can modify.
- **UI:** Checklist / packing screen: section "Shared crew items" with list + checkboxes + "Add item"; optionally "Added by [name]".

---

## h) Offline / optimistic UI

**Check-ins:**

- On "Check in" tap, **immediately** update local state (e.g. mark this waypoint as "checked in" for current user and show "You're the Nth" with a temporary N or "…").
- Write to Firestore in the background; on success, replace with real rank/count; on failure, revert local state and show error (e.g. "Check-in failed. Retry?"). Use a simple optimistic setState or a small stream that merges local + server.

**Votes:**

- When member taps an option, **immediately** show that option as selected in the UI (optimistic).
- Write vote to Firestore; on failure, revert selection and show error. Avoid waiting for server round-trip before updating the list.

**Shared packing:**

- On add: append item to local list with a temp ID; on server confirm, replace with real ID. On toggle: flip checkbox locally; sync to Firestore; revert on failure.

**Implementation note:** Firestore persistence is already on for the app; reads will be cached. For writes, handle the success/error in the service and surface to UI so the UI can show instant feedback and roll back on error.

---

## i) Push notifications

**Suggested events (to implement when adding push):**

1. **Crew check-in:** "Sarah checked in at [Waypoint name]." Send to other trip members (and optionally owner) when a check-in is written. Payload: tripId, dayNum, waypointId, userId (or name), waypoint name.
2. **Vote reminder:** "Voting for [Trip name] waypoints ends soon." Send to trip members who haven’t voted for all slots when `waypoint_vote_ends_at` is near (e.g. 24h before), or when owner is about to close.
3. **Vote resolved:** "Voting is closed. See the chosen waypoints for [Trip name]." Send to all trip members when voting is closed and TripDaySelection has been updated.

**Implementation:** Not in scope for the initial feature set; implement when adding push. **Prerequisite:** Confirm whether FCM (Firebase Cloud Messaging) is already integrated in the app. If not, adding FCM — including registration, token handling, and backend send path — is a non-trivial prerequisite and should be planned separately before implementing these notification events. Document these events so payloads and triggers are clear when the time comes. No change to data model; use existing trip and check_ins/waypoint_votes data.

---

## j) Firestore read-cost strategy

**Problem:** Trip detail (or trip overview) could open streams for: trip doc, check_ins, waypoint_votes, shared_packing, member_packing (existing), day progress, selections. Streaming all of these on every trip open would be expensive.

**Approach:**

- **Do not** stream all four new subcollections (check_ins, waypoint_votes, shared_packing, plus existing ones) simultaneously on a single "trip detail" screen.
- **Lazy load per section:**
  - Trip header / members / config: trip doc only (and members’ profiles if needed).
  - Itinerary / waypoint cards: trip + selections + days; **check_ins** only when the user opens a day or a waypoint card that can show check-in state (e.g. stream check_ins for that trip when on itinerary tab, or per-waypoint when card is visible).
  - Voting: load **waypoint_votes** only when user opens the "Vote" screen or trip config shows vote status.
  - Checklist: load **shared_packing** only when user is on the checklist/packing screen; keep existing member_packing and packing categories load as today.
- **One-time reads where possible:** For "You're the Nth" on a single waypoint, a one-time read (or a short-lived stream) for that waypoint’s check_ins is enough; no need to stream all check_ins for the whole trip on itinerary load.
- Document in code or architecture: "Trip subcollections are loaded on demand by screen/section, not globally on trip open."

---

## Architecture overview

Same as before, with additions:

- **Levels:** Single source for user and creator level names/thresholds (e.g. level_names.dart).
- **Check-ins:** Index on check_ins (waypoint_id, created_at); scale note for rank query.
- **Votes:** Slots and options snapshot when voting opens; no live reads from plan for ballot.
- **Shared packing:** Subcollection only.
- **Reads:** Lazy load trip subcollections by screen/section.

---

## Implementation order (suggested)

1. **Back + Crew (copy/UI only):** Replace Buy/purchase CTAs with "Back [Creator name]"; optionally show "X people have backed this" using plan.salesCount; add Crew constant and use it everywhere. No new services or Firestore. (~1 hour.)
2. Levels: User + creator thresholds and names in one place; completed_trip_count, total_plans_sold; level util; UI badges.
3. Roles: Trip.memberRoles, updateMemberRole, trip members UI.
4. Check-ins: geolocator, LocationService, CheckInService (location + manual), day guard, check_ins subcollection + index, optimistic UI, waypoint card UI and confirmation sheet.
5. Shared checklist: SharedPackingItem subcollection, service, checklist section UI, optimistic add/toggle.
6. Waypoint vote: Snapshot slots/options when opening vote; waypoint_decision_mode and waypoint_votes; trip config UI; voting screens; close and resolve → TripDaySelection; ItinerarySelectScreen read-only when vote mode and closed.
7. Notifications: Document triggers (crew check-in, vote reminder, vote resolved); implement when adding push.

---

## Files and Firestore (summary)

- **Models:** UserModel (completed_trip_count, total_plans_sold), Trip (member_roles, waypoint_decision_mode, waypoint_vote_ends_at?); CheckIn, CheckInResult; SharedPackingItem; vote slot snapshot (options, votes, resolved_option_id, closed_at). No new plan fields for Back (use existing salesCount).
- **Constants:** Level names and thresholds (user + creator) in one file; Crew label constant.
- **Services:** CheckInService, LocationService; TripService (roles, shared_packing, waypoint votes with snapshot-on-open); OrderService or Cloud Function (completed_trip_count, total_plans_sold). No BackService.
- **Firestore indexes:** check_ins: (waypoint_id ASC, created_at ASC). No new collections for Back.
- **Security rules:** check-ins (trip members + day guard if desired), roles (owner only), votes (trip members; close/resolve owner or backend), shared packing (trip members). Add rules for all new collections/fields.

---

## Security and rules (reminder)

- Check-ins: trip members only; optional server-side day guard; one doc per (user, day, waypoint) via doc ID.
- Roles: only owner updates member_roles.
- Waypoint votes: only trip members submit; only owner (or backend) closes and resolves; snapshot prevents tampering with options.
- Shared packing: only trip members add/toggle/remove.
- Document ID and validation rules to avoid duplicate check-ins and to enforce slot structure for votes.

Update Firestore security rules in detail when implementing each feature.
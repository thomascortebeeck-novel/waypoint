# Push notification events

FCM (Firebase Cloud Messaging) is integrated: the app registers and stores the FCM token in Firestore (`users/{uid}.fcm_token`), and Cloud Functions send push notifications for the events below.

## Prerequisite

- Confirm whether FCM is already integrated. If not, plan FCM setup (registration, token storage, backend or Cloud Functions to send messages) separately before implementing these events.
- Data model: use existing `trips`, `check_ins`, and `waypoint_votes` data; no new fields required for these events.

---

## 1. Crew check-in

- **Trigger:** When a check-in is written to `trips/{tripId}/check_ins` (e.g. onCreate or onWrite).
- **Recipients:** Other trip members (and optionally owner). Exclude the user who checked in.
- **Payload:** `tripId`, `dayNum`, `waypointId`, `userId` (or display name), waypoint name.
- **Title/body example:** "Sarah checked in at [Waypoint name]."

---

## 2. Vote reminder

- **Trigger:** When `waypoint_vote_ends_at` on the trip is near (e.g. 24h before), or when owner is about to close voting. Can be a scheduled Cloud Function or cron.
- **Recipients:** Trip members who haven’t voted for all open slots (compare `waypoint_votes` votes map with trip `member_ids`).
- **Payload:** `tripId`, trip name, optional `waypoint_vote_ends_at`.
- **Title/body example:** "Voting for [Trip name] waypoints ends soon."

---

## 3. Vote resolved

- **Trigger:** When voting is closed (e.g. after `closeVoting` has run and `waypoint_votes` docs have `closed_at` set and TripDaySelection has been updated).
- **Recipients:** All trip members.
- **Payload:** `tripId`, trip name.
- **Title/body example:** "Voting is closed. See the chosen waypoints for [Trip name]."

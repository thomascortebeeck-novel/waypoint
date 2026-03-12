# Waypoint Cloud Functions (FCM push)

Sends push notifications when:

1. **Crew check-in** – when a document is created in `trips/{tripId}/check_ins`, other trip members get a notification (e.g. "Sarah checked in at [Waypoint name]").
2. **Vote resolved** – when a document in `trips/{tripId}/waypoint_votes` is updated with `closed_at`, all trip members get "Voting is closed. See the chosen waypoints for [Trip name]."

## Setup

- Node 18+
- Firebase CLI: `npm i -g firebase-tools` and `firebase login`

From the project root:

```bash
cd functions
npm install
```

## Deploy

From the project root (so `firebase.json` and `functions/` are found):

```bash
firebase deploy --only functions
```

If you haven’t set up Functions yet:

```bash
firebase init functions
# Choose existing project, JavaScript, ESLint if you want, install deps
# Then replace or merge the generated index.js with this implementation.
```

## Data

- FCM tokens are read from `users/{userId}.fcm_token` (set by the Flutter app via `FcmService`).
- Trip members are taken from `trips/{tripId}` (`owner_id`, `member_ids`).

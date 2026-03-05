# Stripe Integration and Builder Payouts Plan (REVISED)

## Revisions (review feedback incorporated)

- **Webhook idempotency**: Handler **must** load order first and **check order status before any write**: if status is already `completed`, return 200 and exit without updating Firestore. Prevents double-counting `sales_count` and double-adding to `purchasedPlans` on Stripe retries.
- **Connect destination guard**: **Mandatory**: Verify builder has `charges_enabled: true` before attaching `transfer_data.destination`. If not, reject with “Creator has not completed payout setup”. Block paid plan publishing until onboarding complete; free plans always publish.
- **Refunds**: Out of scope for initial implementation; document that a separate `refundOrder` (reversing application fee + transfer) will be needed later.
- **Fee formula**: **Pinned** — With destination charges, Stripe deducts its fee from the **platform** side. Builder gets **exactly 50% of gross**; platform gets 50% minus Stripe fee. `application_fee_amount` = floor(amount_cents * 0.50). Wording and code must match.
- **Pending order**: **Mandatory** (not optional): Create the pending order **server-side only** inside `createPaymentIntent`; return `clientSecret` + `orderId`; webhook updates by `orderId`. Client never creates orders.
- **Plans sold counter**: Use existing `plan.salesCount` (sum over creator’s plans) for the “Plans sold” UI; query `orders` only when revenue breakdown is needed.
- **createPaymentIntent idempotency**: Accept idempotency key from client so retries (e.g. poor connectivity) don’t risk double-charging.
- **Connect return**: Deep link for onboarding return must be set up in Flutter (Universal Links on iOS, App Links on Android) — add to implementation checklist.
- **Firestore seller read**: Rule change for orders (seller can read) is correct; explicitly test it since sellers currently cannot read their own orders.

**Latest (implementation hardening):** (1) createPaymentIntent server-side idempotency: check for existing pending order by (planId, buyerId, idempotencyKey) before creating; return existing clientSecret + orderId if found. (2) Store **orderId in PaymentIntent metadata** (`metadata: { orderId, planId, buyerId }`) so webhook can look up order. (3) **Cache charges_enabled** on user doc; createPaymentIntent reads from Firestore; **account.updated** webhook keeps cache fresh (no Stripe API call on every checkout). (4) Webhook read-check-write runs inside a **Firestore transaction** to prevent double-write under concurrent delivery. (5) FIREBASE_TOKEN deprecation noted; prefer Workload Identity Federation or service account key. (6) Local dev: backend needs local .env (or emulator secrets) with test keys; never commit. (7) GitHub Actions: use echo piped to `--data-file=-` for portability; heredoc runner note. **Latest:** Fee formula corrected for destination charges (approximately 50/50, fees shared proportionally; wording matches code). account.updated lookup: Firestore index on users.stripe_account_id or reverse lookup map. Success screen: listen to streamPurchaseStatus until order completed (loading state). Idempotency key: generate once per checkout screen lifetime; regenerate only on full navigation away. Dangling pending orders: document payment_intent.canceled/expired or TTL cleanup. --dart-define: note values are in binary; safe for STRIPE_PK only. **Round 6:** Fee wording fixed: builder gets exactly 50% of gross; platform gets 50% minus Stripe fee (destination charge: fee from platform side). Idempotency query: status IN (pending, completed); if completed found return { alreadyPurchased: true }. Success screen: 30s timeout + fallback message if webhook never fires. account.updated: filter before write (only write if charges_enabled changed). Webhook transaction: cannot return 200 inside transaction; return value from transaction, then send 200 after await. Webhook event subscription: subscribe to events when creating endpoint (payment_intent.succeeded, etc., account.updated). **Round 7 (pre-implementation):** Remove payment_intent.expired (Stripe does not fire it). Add composite Firestore index on orders (buyer_id, plan_id, idempotency_key, status). Flutter: handle alreadyPurchased: true — navigate to plan access or show “Already purchased”. createConnectAccountLink: write reverse lookup stripeAccounts/{id} → uid when storing stripe_account_id. Diagram note: Builder 50% gross; Platform 50% minus Stripe fee. GitHub Actions: show concrete conditional (main → live keys, else test). **Round 8:** Dangling orders: TTL/Cloud Scheduler is primary (Stripe doesn’t auto-cancel card PaymentIntents); payment_intent.canceled only fires when you call cancel API (e.g. on explicit dismiss). flutter_stripe: add required platform setup (iOS 13+, AppDelegate, Android SDK 21+, AppCompat, AndroidManifest) and follow setup guide before checkout. **Round 9:** createPaymentIntent: run **guard (charges_enabled) before idempotency check** so every attempt verifies builder is still eligible. flutter_stripe iOS: AppDelegate not required in v9+; follow setup guide for your version. TTL cleanup job added to implementation order and files list (cleanup.ts or scheduled in stripe.ts). Flutter: on Payment Sheet dismiss call cancelPaymentIntent callable so payment_intent.canceled is used; add cancelPaymentIntent callable to backend.

---

## Current state

- **Checkout**: [lib/presentation/checkout/checkout_screen.dart](lib/presentation/checkout/checkout_screen.dart) uses [OrderService](lib/services/order_service.dart) to create an order, simulate processing, then call `completeOrder()`. No real payment.
- **Pricing**: [Plan.basePrice](lib/models/plan_model.dart), `creatorId`. Free plans use `basePrice == 0`.
- **Builders**: [UserModel.isInfluencer](lib/models/user_model.dart). [BuilderHomeScreen](lib/presentation/builder/builder_home_screen.dart) shows grid of plans; no stats yet.
- **Orders**: [OrderModel](lib/models/order_model.dart) has `planId`, `buyerId`, `sellerId`, `amount`, `status`. Firestore: read only for **buyer** or admin; **sellers cannot read** (must fix).
- **Backend**: [functions/src/index.ts](functions/src/index.ts); no Stripe yet.

## Architecture overview

```mermaid
sequenceDiagram
  participant User
  participant App
  participant Functions
  participant Stripe
  participant Firestore

  User->>App: Buy plan
  App->>Functions: createPaymentIntent(planId, idempotencyKey)
  Functions->>Firestore: Create pending order (server-only)
  Functions->>Stripe: Create PaymentIntent (platform + Connect, 50% gross each)
  Stripe-->>Functions: clientSecret
  Functions-->>App: clientSecret, orderId
  App->>Stripe: presentPaymentSheet()
  User->>Stripe: Pay
  Stripe->>Functions: webhook payment_intent.succeeded
  Functions->>Functions: Idempotency: if order already completed, return 200 and exit
  Functions->>Firestore: complete order, increment sales_count, add purchasedPlans
  Note over Stripe: Builder: 50% gross; Platform: 50% minus Stripe fee
  Stripe->>Stripe: Payout to builder (schedule)
```

*Set up **test** environment first (keys, webhook, Connect test mode); then production.*

---

## 1. Stripe environment strategy and product setup

**Do this first so no one hardcodes keys.** Environment strategy is front-loaded here.

### 1.1 Two sets of API keys

- **Stripe Dashboard** → Developers → API keys:
  - **Test keys** (`sk_test_...`, `pk_test_...`) for **dev/staging**. Use these for local development, emulator, and any non-production builds.
  - **Live keys** (`sk_live_...`, `pk_live_...`) for **production** only.
- Never use live keys in dev; never commit any secret key.

### 1.2 Stripe Connect and test mode

- **Stripe Connect** has its own test mode. In the Dashboard, ensure you are in **Test mode** (toggle top-right) when developing.
- Builders can complete **fake Connect onboarding** (no real KYC) in test mode. Make sure the team uses the **test Connect flow** for dev/staging, not live onboarding.

### 1.3 Webhooks: two endpoints, two secrets, event subscription

- **Two separate webhook endpoints** must be registered in Stripe:
  - **Dev**: Points at your Firebase emulator/dev function URL, or use **Stripe CLI** locally: `stripe listen --forward-to localhost:5001/<project>/us-central1/stripeWebhook` (or your function URL). This endpoint gets its own signing secret.
  - **Production**: Points at your deployed Cloud Function URL (e.g. `https://us-central1-<project>.cloudfunctions.net/stripeWebhook`). This endpoint gets a different signing secret.
- Each endpoint generates its own **STRIPE_WEBHOOK_SECRET** (e.g. `whsec_...`). Use the **test** webhook secret in dev and the **live** one in production.
- **Event subscription (required):** When creating the webhook endpoint in the Stripe Dashboard, you must **explicitly select which events to listen to**. If the subscription is left empty, no events are sent. Subscribe to at minimum: **payment_intent.succeeded**, **payment_intent.payment_failed**, **payment_intent.canceled**, **account.updated** (for Connect cache). Stripe does not fire a `payment_intent.expired` webhook for standard card payments; do not subscribe to it (it does not exist). `payment_intent.canceled` is sufficient for abandoned intents. See step 0 and section 3 for handlers.

### 1.4 Product setup (Connect, split, gating)

- **Stripe account**: Enable **Stripe Connect** (Express accounts for builders).
- **Split (pinned)**: **Approximately 50/50; platform bears Stripe fee.** With destination charges, Stripe deducts its fee from the **platform** side (the application_fee is netted against the platform), not from the transfer to the builder. So: `application_fee_amount` = floor(amount_cents * 0.50) — the **builder receives exactly 50% of gross** (e.g. €5.00 on a €10 charge). The **platform receives 50% of gross minus the Stripe fee**. The builder gets the clean number; the platform bears the fee. Implementation: set `application_fee_amount` = floor(amount_cents * 0.50); transfer to Connect account = 50% of gross (builder gets that amount); Stripe fee is deducted from the platform’s side.
- **Connect**: Builders onboard via Express; Stripe handles payouts to their bank. Payout schedule: monthly (or weekly) per connected account.
- **Paid plan publishing**: **Block** until builder has completed Connect onboarding (`charges_enabled: true`). Free plans always publish. Show prominent “Add payment details to receive earnings” CTA on Builder page until then.

## 2. GitHub Actions and Firebase Functions secrets

Deployment uses GitHub Actions (e.g. `.github/workflows/deploy-functions.yml`). Stripe keys and webhook secrets must be provided per environment via **Google Cloud Secret Manager** (recommended for Firebase Functions v2), not plain env vars or deprecated `functions.config()`.

### 2.1 GitHub Secrets (Settings → Secrets and variables → Actions)

Add these repository secrets (values from Stripe Dashboard):

- `STRIPE_SECRET_KEY_TEST`
- `STRIPE_PUBLISHABLE_KEY_TEST`
- `STRIPE_WEBHOOK_SECRET_TEST`
- `STRIPE_SECRET_KEY_LIVE`
- `STRIPE_PUBLISHABLE_KEY_LIVE`
- `STRIPE_WEBHOOK_SECRET_LIVE`

Use test secrets for dev/staging workflows; use live secrets only for production deploy.

### 2.2 Firebase Functions: Secret Manager (not config)

- **Use Google Cloud Secret Manager** with Firebase Functions v2. Secrets are stored in GCP Secret Manager, not as plain environment variables.
- In `stripe.ts`, access secrets via `defineSecret` from `firebase-functions/params`:

```typescript
import { defineSecret } from "firebase-functions/params";
const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");
// Declare secrets in the function options so they are available at runtime
```

- The deploying service account (used by GitHub Actions) must have **Secret Manager Secret Accessor** IAM role on the project (or on the specific secrets). Otherwise deployment or runtime can fail when the function reads the secret.

### 2.3 GitHub Actions workflow: set secrets before deploy

In the workflow that deploys Functions, set Stripe secrets into Firebase/Secret Manager before deploying. Example pattern (adjust job name and Firebase project):

```yaml
- name: Set Stripe secrets for deployment
  run: |
    if [ "${{ github.ref }}" = "refs/heads/main" ]; then
      SECRET_KEY="${{ secrets.STRIPE_SECRET_KEY_LIVE }}"
      WEBHOOK_SECRET="${{ secrets.STRIPE_WEBHOOK_SECRET_LIVE }}"
    else
      SECRET_KEY="${{ secrets.STRIPE_SECRET_KEY_TEST }}"
      WEBHOOK_SECRET="${{ secrets.STRIPE_WEBHOOK_SECRET_TEST }}"
    fi
    echo "$SECRET_KEY" | firebase functions:secrets:set STRIPE_SECRET_KEY --data-file=-
    echo "$WEBHOOK_SECRET" | firebase functions:secrets:set STRIPE_WEBHOOK_SECRET --data-file=-
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

- Use **echo piped to `--data-file=-`** for runner portability. The conditional above ensures **live** keys are used when deploying from `main`; **test** keys otherwise. Copying only the test-key snippet would deploy test keys to production — use the conditional explicitly.
- **Authentication note:** `FIREBASE_TOKEN` is deprecated by Firebase CLI in favour of **Workload Identity Federation** (preferred) or a **service account key JSON** stored as a GitHub Secret (e.g. `GOOGLE_APPLICATION_CREDENTIALS`). It still works today but may be removed in a future CLI version; plan to migrate when possible.

Ensure the workflow does not log secret values.

### 2.4 Flutter: publishable key (environment-specific, not a secret)

The Flutter app needs the **publishable** key for `flutter_stripe` init. It is not a secret but must be environment-specific (test vs live). Use **`--dart-define`** in the build step:

- **In GitHub Actions (or CI) build step:**

```yaml
- name: Build Flutter
  run: flutter build apk --dart-define=STRIPE_PK=${{ secrets.STRIPE_PUBLISHABLE_KEY_TEST }}
```

For production builds, use `STRIPE_PUBLISHABLE_KEY_LIVE`.

- **In [lib/main.dart](lib/main.dart):**

```dart
const stripePk = String.fromEnvironment('STRIPE_PK', defaultValue: '');
// Then: Stripe.publishableKey = stripePk;
```

Provide a default for local runs (e.g. from a `.env` or a hardcoded test key only in debug, if acceptable). Never commit a live publishable key in code if it’s the only place it’s set.

Values passed via `--dart-define` are embedded in the compiled binary and can be extracted; use only for non-sensitive values. The Stripe publishable key is designed to be public — safe for STRIPE_PK. Do not pass secrets via --dart-define.

### 2.5 Local development: backend secrets

When running the Functions **emulator** locally, the Stripe webhook can be forwarded with the Stripe CLI, but the running function still needs the **secret key** and **webhook secret** to call Stripe and verify webhook signatures. Developers must provide these via a **local `.env`** (or Firebase emulator secrets config) with test keys, e.g. `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`. **Never commit this file to git** (add `.env` to `.gitignore`). Use test keys only for local dev.

## 3. Backend (Firebase Cloud Functions)

### createPaymentIntent (callable)

- Input: `planId`, `idempotencyKey` (client-generated, e.g. UUID); `buyerId` from auth.
- Validate: plan exists, not already purchased, `plan.basePrice` matches (and for paid: creator has `stripe_account_id` and cached `charges_enabled` — see section 4).
- **If free plan**: Create order server-side, complete it immediately (existing Firestore logic), return `{ completed: true, orderId }` (no Stripe).
- **If paid**:  
  - **Guard first (mandatory)**: Read creator’s **cached** `charges_enabled` from the user’s Firestore doc (see section 4); do **not** call the Stripe API on every checkout. If not `true`, return an error (e.g. “Creator has not completed payout setup”). This must run **before** the idempotency check so that every attempt verifies the builder is still eligible; otherwise, if a builder lost `charges_enabled` between a first and second attempt, the server could return an existing `clientSecret` for a PaymentIntent created when they were enabled, and the payment would go through to an account that is no longer valid. Set `transfer_data.destination` only when guard passes.  
  - **Server-side idempotency (mandatory)**: After the guard, **check whether an order already exists** for this `(planId, buyerId, idempotencyKey)` (e.g. query orders where `plan_id`, `buyer_id`, `idempotency_key` match and **`status` IN (`'pending'`, `'completed'`)**; store `idempotency_key` on the order document). **Race:** If the webhook completed the order between the client retry and this check, the order would be `completed`; a query that only looks for `pending` would find nothing and the server would create a second order even though the user already paid. So include `completed` in the query. If a **pending** order exists: retrieve the existing PaymentIntent from Stripe (using the `stripe_payment_intent_id` on that order), return its `client_secret` and the existing `orderId`. If a **completed** order exists: return early with `{ alreadyPurchased: true }` (do not return a new clientSecret or create a second order). Otherwise create the new pending order and PaymentIntent.  
  - **Mandatory**: Create **pending** order in Firestore (server-only), including `idempotency_key`; get `orderId`.  
  - Create PaymentIntent with idempotency (Stripe Idempotency-Key header from `idempotencyKey`), amount in cents, currency e.g. `eur`.  
  - **Store `orderId` in PaymentIntent metadata (critical)**: When creating the PaymentIntent in Stripe, set `metadata: { orderId, planId, buyerId }`. The webhook uses `payment_intent.metadata.orderId` to look up the order for idempotency and completion; without this, the webhook cannot find the order.  
  - **Fee formula (pinned)**: `application_fee_amount` = floor(amount_cents * 0.50). Builder gets exactly 50% of gross; platform gets 50% minus Stripe fee (destination charge: fee is deducted from platform side). See section 1.4.  
  - After creating the PaymentIntent, store `stripe_payment_intent_id` (and optionally `idempotency_key`) on the pending order in Firestore so a retry can return the same clientSecret + orderId.  
  - Return `{ clientSecret, orderId }`. Client never creates orders.

### stripeWebhook (HTTP)

- Verify signature with `STRIPE_WEBHOOK_SECRET` (from Secret Manager via `defineSecret`).
- **payment_intent.succeeded**:  
  - **Idempotency (mandatory)**: Load order by `payment_intent.metadata.orderId` (this is why createPaymentIntent must set `metadata: { orderId, planId, buyerId }` when creating the PaymentIntent). **Check order status before any write**: if status is already `completed`, return 200 and exit without updating Firestore.  
  - **Atomicity (mandatory)**: The entire read–check–write block must run inside a **Firestore transaction**. Two concurrent webhook deliveries (e.g. Stripe retries) can both read `status: pending` before either writes; without a transaction both would then write and double-count `sales_count` / double-add to `purchasedPlans`. **Implementation note:** You cannot return an HTTP response from inside a Firestore transaction callback — the transaction must run to completion and return a value. Correct pattern: run the transaction; inside it, read the order and, if status is already `completed`, have the transaction return e.g. `{ alreadyCompleted: true }` without performing writes; otherwise perform all updates and return `{ alreadyCompleted: false }`. **After** `await`ing the transaction, check the return value and send HTTP 200 (and skip further logic if `alreadyCompleted: true`).  
  - Only if order is not completed: update order to completed, set `stripe_payment_intent_id` (and optionally `stripe_charge_id`), increment `plans.sales_count`, add `users/{buyerId}/purchasedPlans` and `purchased_plan_ids`.
- **payment_intent.payment_failed**: Optional; log or update order to `failed`.
- **payment_intent.canceled**: Optional; when this event fires, update the order to `failed`. Note: for standard card PaymentIntents, Stripe **does not** auto-cancel them — they stay open until you explicitly call `stripe.paymentIntents.cancel()`. So this webhook only runs if you call the cancel API yourself (e.g. when the user **explicitly dismisses** the Payment Sheet / checkout). It does **not** catch the common case of a user just closing the app. See “Dangling pending orders” below for the primary cleanup mechanism.
- **account.updated** (Connect): When Stripe fires this, update the user’s Firestore doc with cached `charges_enabled` (and optionally `payouts_enabled`) from the Connect account. **Filter before writing:** `account.updated` fires very frequently (payout sent, bank verified, tax info updated, etc.), not only when `charges_enabled` changes. Without filtering, every event would trigger a Firestore write. **Read the current cached value from the user doc first** and only write if `charges_enabled` (or the fields you cache) has actually changed. One extra read to avoid many unnecessary writes over a builder’s lifetime. **Lookup**: the webhook receives a Connect account id (acct_...), but users are keyed by Firebase UID and store `stripe_account_id` on their doc. Firestore cannot query “users where stripe_account_id == X” without an index or reverse map. Add one of: (a) a **Firestore index** on `users.stripe_account_id` (single-field or composite as needed), or (b) a **reverse lookup** collection e.g. `stripeAccounts/{stripeAccountId}` with document `{ uid }` updated when the user’s `stripe_account_id` is set, so the webhook can resolve account id → uid and then update the user doc. Without this, the handler would need a full collection scan or would fail. See section 4.

### createConnectAccountLink (callable)

- Uses `request.auth.uid`. Check user is influencer.
- Create Stripe Connect Express account if not exists; store `stripe_account_id` on the user doc (e.g. via Admin SDK). **At the same moment**, write the **reverse lookup** document: `stripeAccounts/{stripeAccountId}` → `{ uid }` (or equivalent) so the `account.updated` webhook can resolve Connect account id → user. Without this, the webhook has no way to find the user when Stripe fires account.updated.
- Create Account Link with `return_url` / `refresh_url` pointing to app **deep link** (Universal Links / App Links).
- Return `{ url }`.

### getConnectAccountStatus (callable, optional)

- Returns onboarding status and `charges_enabled` so app can show “Complete payout setup” vs “Verified”. Used to gate paid plan publishing and show CTA.

### cancelPaymentIntent (callable, optional)

- Input: `orderId` or `paymentIntentId`. Called when the user **explicitly dismisses** the Payment Sheet (Flutter checkout screen). Verifies the order is still pending and belongs to the caller; then calls `stripe.paymentIntents.cancel()`. The `payment_intent.canceled` webhook will then run and set the order to `failed`. Without this callable, the Flutter dismiss handler has nothing to call and `payment_intent.canceled` would never fire for dismissals.

**Dangling pending orders:** If a user opens checkout (pending order + PaymentIntent created) and then abandons or closes the app without paying, that order and the PaymentIntent stay pending indefinitely (Stripe does not auto-cancel standard card PaymentIntents). **Primary mechanism:** a **TTL / cleanup job** (e.g. Cloud Scheduler) that marks or expires orders with `status === 'pending'` and `created_at` older than e.g. 24 hours (and optionally call Stripe’s cancel API on the corresponding PaymentIntent so Stripe state stays consistent). **Optional:** when the user **explicitly dismisses** the checkout (e.g. taps “Cancel” on the Payment Sheet), call `stripe.paymentIntents.cancel()` from your backend or a callable; that will fire `payment_intent.canceled` and your webhook can set the order to `failed`. That only covers explicit dismissal, not app-close or navigation away — hence TTL cleanup is the default.

## 4. Firestore and security

- **Users**: Add `stripe_account_id`. **Cache `charges_enabled`** (and optionally `payouts_enabled`) on the user document — this is the **source of truth for createPaymentIntent**: the function reads from Firestore and does **not** call the Stripe API on every checkout (avoids latency and rate limits). Keep the cache fresh by handling the **account.updated** Stripe webhook (section 3): when Stripe fires it for a Connect account, look up the user by `stripe_account_id` and update their doc. **Lookup requirement**: either create a **Firestore index** on `users.stripe_account_id` so you can query by it, or maintain a **reverse lookup** map (e.g. collection `stripeAccounts/{stripeAccountId}` → `{ uid }`) updated when a user’s `stripe_account_id` is set, so the webhook can resolve account id → uid efficiently. Only backend writes `stripe_account_id` and the cached Connect fields.
- **Orders**: Add `stripe_payment_intent_id` (optional `stripe_charge_id`) when completing; add `idempotency_key` when creating a pending order (for server-side idempotency in createPaymentIntent).  
  - **Composite index (required):** The createPaymentIntent idempotency query filters by `plan_id`, `buyer_id`, `idempotency_key`, and `status IN ('pending', 'completed')`. Firestore requires a **composite index** for this query. Without it, the query will fail in production (with a link to create the index); the emulator does not enforce composite indexes, so the failure won’t surface in local testing. Create a composite index on the `orders` collection for fields **buyer_id**, **plan_id**, **idempotency_key**, **status** (order may depend on your query; use the error link or Firebase Console to add the index).  
  - **Rule**: Allow sellers to read: `allow read: if (isSignedIn() && (request.auth.uid == resource.data.buyer_id || request.auth.uid == resource.data.seller_id)) || isAdmin();`  
  - **Test this rule** explicitly; currently sellers cannot read their own orders.

## 5. Flutter app changes

### 5.1 Dependencies and config

- Add `flutter_stripe`; init in [main.dart](lib/main.dart) with publishable key from `String.fromEnvironment('STRIPE_PK')` (set via `--dart-define=STRIPE_PK=...` in CI; see section 2.4).
- **Platform setup (required):** Follow the **flutter_stripe** setup guide for your **installed version** before wiring the checkout flow; without it, builds will fail or Payment Sheet will not work. **iOS:** minimum deployment target iOS 13+; add entitlements for Apple Pay if you use it. In **flutter_stripe v9+**, initialization is done in Dart only (`Stripe.publishableKey`); **AppDelegate changes are not required** and setting `StripeAPI.defaultPublishableKey` in AppDelegate is the old API — it can conflict on newer versions. **Android:** minimum SDK 21+; app theme must inherit from `Theme.AppCompat` (or a compat variant); add the payment sheet activity to `AndroidManifest.xml`. See the official flutter_stripe installation/setup docs for the exact snippets for your version.
- **Deep links**: Configure Universal Links (iOS) and App Links (Android) for Connect onboarding return URL so “return to app” works. Non-trivial; add to implementation checklist.

### 5.2 Checkout flow

- **Free**: Call createPaymentIntent; if response `completed: true`, redirect to success with `orderId`.
- **Paid**: Call createPaymentIntent with **idempotency key** (see lifecycle below). **If the response is `{ alreadyPurchased: true }`** (server found a completed order for this plan/buyer/idempotency key, e.g. webhook completed between retries): do not open the Payment Sheet; navigate directly to the plan access screen (or show “Already purchased” and then open the plan). Without this handling, the app would receive a response with no `clientSecret` and could crash or show a confusing error. If the response contains `clientSecret` + `orderId`, init Payment Sheet, present. On Payment Sheet success, navigate to the **success screen** — but the webhook completes the order asynchronously (can take seconds or longer), so the order may not be completed in Firestore yet. **UX requirement (explicit)**: The success screen must **listen to** `streamPurchaseStatus(userId, planId)` (or the order document) and show a **loading / “Confirming your purchase…”** state until the order flips to completed and the plan is unlocked. Only then show “You’re all set” or allow access. If the user lands on success and immediately tries to open the plan, they would see it still locked and assume payment failed; this must be avoided. **Timeout:** If the webhook never fires (Stripe outage, misconfigured endpoint, signature failure), the listener would spin forever. Add a **timeout** (e.g. 30 seconds) after which the screen shows a fallback: e.g. “Payment received — your plan will be available shortly. Check your purchases.” so the user is not stuck in an infinite loading state that looks like a crash. On Payment Sheet failure, show error; do not create order on client. **On Payment Sheet dismiss/cancel** (user taps back or cancel): call a **callable** (e.g. `cancelPaymentIntent` with `orderId` or `payment_intent_id`) that calls `stripe.paymentIntents.cancel()` on the backend; then `payment_intent.canceled` will fire and the webhook can set the order to `failed`. This is a few lines in the Flutter dismiss handler and ensures the `payment_intent.canceled` subscription is actually used; without it, that event would never fire and you rely only on TTL cleanup for abandoned intents.
- **Idempotency key lifecycle**: Generate the idempotency key **once** when the checkout screen is opened (or when the plan detail / buy flow is entered), hold it in state for the **lifetime of that screen**. Reuse the **same** key if the user dismisses the Payment Sheet and taps “Buy” again — the server will return the existing pending order + clientSecret (correct). **Only** generate a new key when the user navigates fully away (e.g. leaves the checkout or plan detail) and comes back. If a new key is generated on every “Buy” tap, each tap would create a new pending order and PaymentIntent and the previous one would dangle as pending forever.

### 5.3 Builder payout onboarding

- If influencer and not `charges_enabled`: show “Add payment details to receive earnings” CTA; on tap call createConnectAccountLink, open URL in browser. Return via deep link; refresh status.
- **Paid plan publishing**: Block (e.g. in plan publish flow or price edit) if creator has not completed payout setup; show message and link to onboarding.

### 5.4 Builder dashboard stats

- **Plans built**: Count of creator’s plans (existing stream or `createdPlanIds.length`).
- **Plans sold**: **Use sum of `plan.salesCount`** over creator’s plans for the counter UI (cheaper, already maintained). Query **orders** only when you need revenue breakdown or detailed sales list.

### 5.5 OrderService

- **No client-side order creation** for paid flow (mandatory: orders are created only in createPaymentIntent on the server). Optional: `getOrdersBySeller(sellerId)` and revenue aggregation for future “Earnings” view. Keep `hasPurchased`, `streamPurchaseStatus`, `getUserOrders`; free-plan completion can still use existing complete path from backend.

## 6. Refunds (out of scope, documented)

- Stripe refunds on destination charges require reversing both the application fee and the transfer. **Not in initial scope.** Plan for a separate **refundOrder** (or Stripe webhook `charge.refunded`) that: (1) creates refund on PaymentIntent/Charge, (2) reverses transfer to Connect account, (3) updates Firestore order status and optionally adjusts `sales_count` / purchasedPlans. To be implemented later.

## 7. Implementation order

**0. Stripe environment setup (do first):** Create Stripe account; generate **test** and **live** key pairs; register **two** webhook endpoints (dev → emulator or Stripe CLI, prod → deployed function URL); **subscribe to events** on each endpoint (at minimum: payment_intent.succeeded, payment_intent.payment_failed, payment_intent.canceled, account.updated — do not subscribe to payment_intent.expired, it does not exist; see section 1.3); store all six values in GCP Secret Manager; wire GitHub Actions to deploy with the correct secrets per environment (test for dev/staging, live for prod). Ensures no one hardcodes keys and that the webhook actually receives events.

1. Stripe + Connect product setup; fee formula (approximately 50/50, fees shared proportionally — section 1.4); Connect test mode for dev.
2. Firestore: user fields for Connect; order fields for Stripe ids; **orders rule for seller read** (and test it).
3. Functions: createPaymentIntent (**guard charges_enabled before idempotency check**); server-side idempotency; store orderId in PaymentIntent metadata; cache charges_enabled on user; store idempotency_key and stripe_payment_intent_id on order; webhook with **idempotency + Firestore transaction**; **account.updated** handler; createConnectAccountLink; getConnectAccountStatus; **TTL cleanup job** (scheduled function or Cloud Scheduler, daily: expire pending orders older than 24h, optionally cancel corresponding PaymentIntents in Stripe). Access secrets via `defineSecret`.
4. Flutter: **flutter_stripe platform setup first** (iOS/Android per section 5.1); then init with publishable key from `--dart-define=STRIPE_PK`; checkout with idempotency key; Payment Sheet; deep link config for Connect return; block paid publish until onboarding; builder CTA and stats (plans built, plans sold via salesCount).
5. Test: Stripe **test mode** end-to-end; webhook retries (verify idempotency); seller order read; Connect test onboarding return.

## 8. Decisions summary (closed)

| Topic | Decision |
|-------|----------|
| Fee split | application_fee_amount = floor(amount_cents * 0.50). Builder gets exactly 50% of gross; platform gets 50% minus Stripe fee (destination charge: fee deducted from platform side). |
| Builder without Connect | Block paid plan publishing until onboarding complete; free plans always publish. |
| Pending order creation | Server-side only in createPaymentIntent; return clientSecret + orderId; webhook updates by orderId. |
| Plans sold counter | Use sum of plan.salesCount for UI; query orders only for revenue/detail. |
| createPaymentIntent retries | Client sends idempotency key; server checks for existing order with status IN (pending, completed). If pending: return existing clientSecret + orderId. If completed: return { alreadyPurchased: true }. Otherwise create order + PaymentIntent. Prevents double-order race when webhook completed between retry and check. |
| Webhook retries | Check order status; if already completed, return 200 and skip writes. Entire read-check-write in a Firestore transaction to prevent double-write under concurrent delivery. |
| charges_enabled | Cached on user doc; updated by account.updated webhook. createPaymentIntent reads from Firestore, does not call Stripe on checkout. |
| Refunds | Out of scope; document refundOrder / charge.refunded for later. |

## 9. Files to add or touch

- **Backend**: New `functions/src/stripe.ts` (use `defineSecret` for STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET); optional **`functions/src/cleanup.ts`** (or scheduled function in stripe.ts): **TTL cleanup job** — Cloud Scheduler / `onSchedule` daily, query orders with `status === 'pending'` and `created_at` older than 24h, mark them failed (and optionally call Stripe `paymentIntents.cancel` for the corresponding PaymentIntent); extend `functions/src/index.ts`.
- **Secrets / CI**: GitHub Secrets (six Stripe keys); GCP Secret Manager; IAM Secret Accessor for deploying service account; [.github/workflows/deploy-functions.yml](.github/workflows/deploy-functions.yml) (or equivalent) to set Stripe secrets before deploy and to pass STRIPE_PK for Flutter build.
- **Firestore**: [firestore.rules](firestore.rules) (orders read for seller; test). **Composite index on `orders`**: create index on (buyer_id, plan_id, idempotency_key, status) for the createPaymentIntent idempotency query; required in production, emulator won’t fail without it. User doc: cache `charges_enabled` (and optionally `payouts_enabled`); keep fresh via account.updated webhook. **Index or reverse lookup** for account.updated: index on `users.stripe_account_id` or collection `stripeAccounts/{stripeAccountId}` → `{ uid }` (written in createConnectAccountLink when storing stripe_account_id).
- **Orders**: [lib/models/order_model.dart](lib/models/order_model.dart) (optional stripe_payment_intent_id, idempotency_key); [lib/services/order_service.dart](lib/services/order_service.dart) (getOrdersBySeller only if revenue UI needed).
- **Checkout**: [lib/presentation/checkout/checkout_screen.dart](lib/presentation/checkout/checkout_screen.dart) (idempotency key, Payment Sheet, **on dismiss/cancel call cancelPaymentIntent callable** so payment_intent.canceled fires; no client order create).
- **User**: [lib/models/user_model.dart](lib/models/user_model.dart) (optional: stripeAccountId, charges_enabled cache, onboarding status).
- **Builder**: [lib/presentation/builder/builder_home_screen.dart](lib/presentation/builder/builder_home_screen.dart) (stats via salesCount, payout CTA, block paid publish until onboarding).
- **App**: [lib/main.dart](lib/main.dart) (Stripe init with `String.fromEnvironment('STRIPE_PK')`); **platform config** — follow flutter_stripe setup guide for your version (iOS min 13+, Android min SDK 21+, AppCompat theme, payment sheet activity in AndroidManifest; AppDelegate not required in v9+); deep link config (iOS/Android); pubspec (flutter_stripe).

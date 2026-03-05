# Stripe keys and setup guide

## Which key goes where

| Key | Use | Where |
|-----|-----|--------|
| **Openbare sleutel** (Publishable key) `pk_test_...` | Flutter app only — safe in client code | Local run, CI build (`--dart-define=STRIPE_PK=...`), or default in debug |
| **Geheime sleutel** (Secret key) `sk_test_...` | Backend only — never in app or repo | Google Cloud Secret Manager + GitHub Secret |
| **Webhook signing secret** `whsec_...` | Backend webhook — to verify Stripe events | Created in Stripe when you add the webhook endpoint; store in Google Cloud + GitHub |

Rule: **Publishable** = Flutter. **Secret** and **Webhook secret** = backend only (Secret Manager / GitHub Secrets).

---

## 1. Flutter app (publishable key)

- **Local run (VS Code / terminal)**  
  Use your test publishable key when starting the app, e.g.:

  ```bash
  flutter run -d chrome --dart-define=STRIPE_PK=pk_test_51T7adIRwfVgSBVcchWhlrPjPpDyzRTIMQXfsGP3FVDZKYIJBZuzzdABt7s5GFCCseOWrwPb5YFzovV2HY9LouG3U00FWXZXebc
  ```

- **Optional default for debug**  
  In `lib/main.dart` the code uses `String.fromEnvironment('STRIPE_PK', defaultValue: '')`. You can temporarily set a non-empty default **only for local debug** (e.g. your `pk_test_...`), and remove it before committing. Never put a **live** publishable key as a default.

- **CI / GitHub Actions (Flutter build)**  
  When building the app in CI, pass the key the same way:

  ```yaml
  - run: flutter build apk --dart-define=STRIPE_PK=${{ secrets.STRIPE_PUBLISHABLE_KEY_TEST }}
  ```

  So in GitHub you need a secret like `STRIPE_PUBLISHABLE_KEY_TEST` with value = your `pk_test_...`.

---

## 2. Google Cloud (Secret Manager)

The Firebase Functions (Stripe) read **two** secrets at runtime:

- `STRIPE_SECRET_KEY` → your **Geheime sleutel** (`sk_test_...`)
- `STRIPE_WEBHOOK_SECRET` → the **webhook signing secret** (`whsec_...`) from Stripe (you get this in step 4)

**Option A – Google Cloud Console**

1. Open [Google Cloud Console](https://console.cloud.google.com/) and select your Firebase project.
2. Go to **Security → Secret Manager** (or search “Secret Manager”).
3. **Create secret** for the backend secret key:
   - Name: `STRIPE_SECRET_KEY`
   - Secret value: paste your `sk_test_51T7adIRwfVgSBVcc...` (full secret key).
4. **Create secret** for the webhook (after you have it from step 4):
   - Name: `STRIPE_WEBHOOK_SECRET`
   - Secret value: paste the `whsec_...` from Stripe.

**Option B – gcloud CLI**

```bash
# Set project
gcloud config set project YOUR_FIREBASE_PROJECT_ID

# Create secret for Stripe secret key (paste when prompted)
echo -n "sk_test_51T7adIRwfVgSBVcc..." | gcloud secrets create STRIPE_SECRET_KEY --data-file=-

# After you have the webhook signing secret from Stripe:
echo -n "whsec_..." | gcloud secrets create STRIPE_WEBHOOK_SECRET --data-file=-
```

**Permissions**

- The Firebase / Cloud Functions runtime service account must be able to **read** these secrets (e.g. role **Secret Manager Secret Accessor** on the project or on these secrets).
- If you use GitHub Actions to deploy, the service account key stored in `FIREBASE_SERVICE_ACCOUNT` also needs permission to **create/update** secret versions if you set secrets from the workflow (see below).

---

## 3. GitHub (secrets for deploy and Flutter build)

In your repo: **Settings → Secrets and variables → Actions**.

Add these **repository secrets** (use test values for now):

| Secret name | Value | Used for |
|-------------|--------|----------|
| `STRIPE_SECRET_KEY_TEST` | Your **Geheime sleutel** `sk_test_...` | Backend (set into Secret Manager or used by deploy) |
| `STRIPE_WEBHOOK_SECRET_TEST` | Webhook signing secret `whsec_...` (from step 4) | Backend webhook |
| `STRIPE_PUBLISHABLE_KEY_TEST` | Your **Openbare sleutel** `pk_test_...` | Flutter build with `--dart-define=STRIPE_PK=...` |

Later, for production, add:

- `STRIPE_SECRET_KEY_LIVE`
- `STRIPE_WEBHOOK_SECRET_LIVE`
- `STRIPE_PUBLISHABLE_KEY_LIVE`

The deploy workflow can use **test** vs **live** by branch (e.g. `main` → live, other branches → test). The workflow step below is set up to use test keys unless you change it.

---

## 4. Webhook in Stripe (get webhook URL and signing secret)

Do this **after** your Cloud Function `stripeWebhook` is deployed so you have a URL.

### 4.1 Get the webhook URL

- After deploy, the URL looks like:
  `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/stripeWebhook`
- Or in Firebase Console: **Functions** → select `stripeWebhook` → copy the trigger URL.

### 4.2 Add endpoint in Stripe

1. Log in to [Stripe Dashboard](https://dashboard.stripe.com).
2. Switch to **Test mode** (toggle top-right).
3. Go to **Developers → Webhooks**.
4. Click **Add endpoint**.
5. **Endpoint URL**: paste your `stripeWebhook` URL (e.g. `https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/stripeWebhook`).
6. **Events to send**: click “Select events” and add exactly:
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `payment_intent.canceled`
   - `account.updated`
7. Click **Add endpoint**.

### 4.3 Get the signing secret

- On the new endpoint’s page, open **Signing secret** (or “Reveal”).
- Copy the value (starts with `whsec_...`).
- This is **STRIPE_WEBHOOK_SECRET**:
  - Put it in Google Cloud Secret Manager as `STRIPE_WEBHOOK_SECRET` (see step 2).
  - Put it in GitHub as `STRIPE_WEBHOOK_SECRET_TEST` (see step 3).

---

## 5. Order of steps (summary)

1. **Google Cloud**: Create `STRIPE_SECRET_KEY` with your `sk_test_...`. Create `STRIPE_WEBHOOK_SECRET` with `whsec_...` (after step 4).
2. **GitHub**: Add `STRIPE_SECRET_KEY_TEST`, `STRIPE_PUBLISHABLE_KEY_TEST`; add `STRIPE_WEBHOOK_SECRET_TEST` after you have it from Stripe.
3. **Deploy** Cloud Functions (so `stripeWebhook` exists and has a URL).
4. **Stripe**: Add webhook endpoint (that URL), select the four events, copy signing secret, then update `STRIPE_WEBHOOK_SECRET` in Google Cloud and `STRIPE_WEBHOOK_SECRET_TEST` in GitHub if you hadn’t yet.
5. **Flutter**: Run or build with `--dart-define=STRIPE_PK=pk_test_...` (or use `STRIPE_PUBLISHABLE_KEY_TEST` in CI).

---

## 6. Set Stripe secrets from GitHub Actions (already in workflow)

The deploy workflow (`.github/workflows/deploy-functions.yml`) has a step **“Set Stripe secrets for deployment”** that runs before deploy. It reads:

- `STRIPE_SECRET_KEY_TEST` → sets `STRIPE_SECRET_KEY` in Secret Manager  
- `STRIPE_WEBHOOK_SECRET_TEST` → sets `STRIPE_WEBHOOK_SECRET` in Secret Manager  

So you **do not** have to create these two in Google Cloud by hand: add the two GitHub secrets and push; the workflow will set them. (You can still create them in Google Cloud if you prefer; then the workflow step will overwrite them with the GitHub values when it runs.)

For **production** (e.g. deploy from `main` with live keys), add GitHub secrets `STRIPE_SECRET_KEY_LIVE` and `STRIPE_WEBHOOK_SECRET_LIVE` and change the workflow step to use those when `github.ref == 'refs/heads/main'` (see the plan’s section 2.3).

---

## Quick reference – your keys (test)

- **Publishable (Flutter):** `pk_test_51T7adIRwfVgSBVcchWhlrPjPpDyzRTIMQXfsGP3FVDZKYIJBZuzzdABt7s5GFCCseOWrwPb5YFzovV2HY9LouG3U00FWXZXebc`
- **Secret (backend only):** `sk_test_51T7adIR...` → Google Cloud `STRIPE_SECRET_KEY` + GitHub `STRIPE_SECRET_KEY_TEST`
- **Webhook secret:** `whsec_...` (from Stripe after adding endpoint) → Google Cloud `STRIPE_WEBHOOK_SECRET` + GitHub `STRIPE_WEBHOOK_SECRET_TEST`

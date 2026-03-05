import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import Stripe from "stripe";

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");
const stripeWebhookSecret = defineSecret("STRIPE_WEBHOOK_SECRET");

const db = getFirestore();
const ORDERS = "orders";
const PLANS = "plans";
const USERS = "users";
const STRIPE_ACCOUNTS = "stripeAccounts";

function getStripe(secret: string): Stripe {
  return new Stripe(secret, {apiVersion: "2025-02-24.acacia"});
}

function generateOrderId(): string {
  const t = Date.now();
  const r = String(process.hrtime.bigint()).slice(-8);
  return `WP-${t}-${r}`;
}

/** createPaymentIntent: guard first (charges_enabled), then idempotency check, then create order + PI */
export const createPaymentIntent = onCall(
  {region: "us-central1", timeoutSeconds: 30, secrets: [stripeSecret]},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const uid = request.auth.uid;
    const data = request.data as Record<string, unknown> | null;
    const planId = typeof data?.planId === "string" ? data.planId : null;
    const idempotencyKey = typeof data?.idempotencyKey === "string" ? data.idempotencyKey : null;
    if (!planId || !idempotencyKey) {
      throw new HttpsError("invalid-argument", "planId and idempotencyKey required");
    }

    const planRef = db.collection(PLANS).doc(planId);
    const planSnap = await planRef.get();
    if (!planSnap.exists) {
      throw new HttpsError("not-found", "Plan not found");
    }
    const plan = planSnap.data()!;
    const basePrice = (plan.base_price as number) ?? 0;
    const creatorId = plan.creator_id as string;
    const creatorName = (plan.creator_name as string) ?? "";

    const purchasedSnap = await db.collection(USERS).doc(uid).collection("purchasedPlans").doc(planId).get();
    if (purchasedSnap.exists) {
      throw new HttpsError("failed-precondition", "Already purchased this plan");
    }

    if (basePrice === 0) {
      const orderId = generateOrderId();
      const now = new Date();
      const orderDoc = {
        id: orderId,
        plan_id: planId,
        buyer_id: uid,
        seller_id: creatorId,
        amount: 0,
        status: "completed",
        created_at: now,
        updated_at: now,
      };
      await db.collection(ORDERS).doc(orderId).set(orderDoc);

      const planData = planSnap.data()!;
      const currentSales = ((planData.sales_count as number) ?? 0) + 1;
      await planRef.update({sales_count: currentSales, updated_at: FieldValue.serverTimestamp()});

      const purchasedPlan = {
        plan_id: planId,
        order_id: orderId,
        purchased_at: now,
      };
      await db.collection(USERS).doc(uid).collection("purchasedPlans").doc(planId).set(purchasedPlan);
      await db.collection(USERS).doc(uid).update({
        purchased_plan_ids: FieldValue.arrayUnion(planId),
        updated_at: FieldValue.serverTimestamp(),
      });

      return {completed: true, orderId};
    }

    const creatorSnap = await db.collection(USERS).doc(creatorId).get();
    if (!creatorSnap.exists) {
      throw new HttpsError("failed-precondition", "Creator not found");
    }
    const creator = creatorSnap.data()!;
    const stripeAccountId = creator.stripe_account_id as string | undefined;
    const chargesEnabled = creator.charges_enabled as boolean | undefined;
    if (!stripeAccountId || chargesEnabled !== true) {
      throw new HttpsError("failed-precondition", "Creator has not completed payout setup");
    }

    const existingOrders = await db.collection(ORDERS)
      .where("buyer_id", "==", uid)
      .where("plan_id", "==", planId)
      .where("idempotency_key", "==", idempotencyKey)
      .where("status", "in", ["pending", "completed"])
      .limit(1)
      .get();

    if (!existingOrders.empty) {
      const existing = existingOrders.docs[0].data();
      const status = existing.status as string;
      if (status === "completed") {
        return {alreadyPurchased: true};
      }
      const existingOrderId = existingOrders.docs[0].id;
      const piId = existing.stripe_payment_intent_id as string | undefined;
      if (piId) {
        const stripe = getStripe(stripeSecret.value());
        const pi = await stripe.paymentIntents.retrieve(piId);
        return {clientSecret: pi.client_secret, orderId: existingOrderId};
      }
    }

    const orderId = generateOrderId();
    const amountCents = Math.round(basePrice * 100);
    const transferAmount = Math.floor(amountCents * 0.5);

    const stripe = getStripe(stripeSecret.value());
    const pi = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: "eur",
      automatic_payment_methods: {enabled: true},
      metadata: {orderId, planId, buyerId: uid},
      transfer_data: {
        destination: stripeAccountId,
        amount: transferAmount,
      },
    }, {idempotencyKey});

    const now = new Date();
    await db.collection(ORDERS).doc(orderId).set({
      id: orderId,
      plan_id: planId,
      buyer_id: uid,
      seller_id: creatorId,
      amount: basePrice,
      status: "pending",
      idempotency_key: idempotencyKey,
      stripe_payment_intent_id: pi.id,
      created_at: now,
      updated_at: now,
    });

    return {clientSecret: pi.client_secret, orderId};
  }
);

/** Stripe webhook: payment_intent.succeeded (transaction), payment_intent.canceled, account.updated */
export const stripeWebhook = onRequest(
  {region: "us-central1", timeoutSeconds: 60, secrets: [stripeWebhookSecret, stripeSecret]},
  async (req, res) => {
    const sig = req.headers["stripe-signature"] as string | undefined;
    const webhookSecret = stripeWebhookSecret.value();
    const stripe = getStripe(stripeSecret.value());
    let event: Stripe.Event;
    try {
      const rawBody = typeof req.rawBody !== "undefined" ? req.rawBody : (req as any).body;
      const body = typeof rawBody === "string" ? rawBody : JSON.stringify(rawBody ?? {});
      event = stripe.webhooks.constructEvent(body, sig ?? "", webhookSecret);
    } catch (err: any) {
      console.warn("Webhook signature verification failed:", err.message);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    switch (event.type) {
      case "payment_intent.succeeded": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const orderId = pi.metadata?.orderId as string | undefined;
        if (!orderId) {
          res.status(200).end();
          return;
        }
        const orderRef = db.collection(ORDERS).doc(orderId);
        const result = await db.runTransaction(async (tx) => {
          const orderSnap = await tx.get(orderRef);
          if (!orderSnap.exists) return {alreadyCompleted: true};
          const order = orderSnap.data()!;
          if ((order.status as string) === "completed") return {alreadyCompleted: true};

          const planRef = db.collection(PLANS).doc(order.plan_id as string);
          const planSnap = await tx.get(planRef);
          const currentSales = planSnap.exists ? ((planSnap.data()?.sales_count as number) ?? 0) + 1 : 1;

          tx.update(orderRef, {
            status: "completed",
            stripe_payment_intent_id: pi.id,
            updated_at: FieldValue.serverTimestamp(),
          });
          if (planSnap.exists) {
            tx.update(planRef, {sales_count: currentSales, updated_at: FieldValue.serverTimestamp()});
          }
          const buyerId = order.buyer_id as string;
          const purchasedPlan = {
            plan_id: order.plan_id,
            order_id: orderId,
            purchased_at: new Date(),
          };
          tx.set(db.collection(USERS).doc(buyerId).collection("purchasedPlans").doc(order.plan_id as string), purchasedPlan);
          tx.update(db.collection(USERS).doc(buyerId), {
            purchased_plan_ids: FieldValue.arrayUnion(order.plan_id),
            updated_at: FieldValue.serverTimestamp(),
          });
          return {alreadyCompleted: false};
        });
        res.status(200).end();
        return;
      }

      case "payment_intent.payment_failed": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const orderId = pi.metadata?.orderId as string | undefined;
        if (orderId) {
          await db.collection(ORDERS).doc(orderId).update({status: "failed", updated_at: FieldValue.serverTimestamp()});
        }
        res.status(200).end();
        return;
      }

      case "payment_intent.canceled": {
        const pi = event.data.object as Stripe.PaymentIntent;
        const orderId = pi.metadata?.orderId as string | undefined;
        if (orderId) {
          await db.collection(ORDERS).doc(orderId).update({status: "failed", updated_at: FieldValue.serverTimestamp()});
        } else {
          const snap = await db.collection(ORDERS).where("stripe_payment_intent_id", "==", pi.id).limit(1).get();
          if (!snap.empty) {
            await snap.docs[0].ref.update({status: "failed", updated_at: FieldValue.serverTimestamp()});
          }
        }
        res.status(200).end();
        return;
      }

      case "account.updated": {
        const account = event.data.object as Stripe.Account;
        const acctId = account.id;
        const chargesEnabled = account.charges_enabled ?? false;
        const payoutsEnabled = account.payouts_enabled ?? false;

        const stripeAccountRef = db.collection(STRIPE_ACCOUNTS).doc(acctId);
        const stripeAccountSnap = await stripeAccountRef.get();
        if (!stripeAccountSnap.exists) {
          res.status(200).end();
          return;
        }
        const uid = (stripeAccountSnap.data() as { uid?: string })?.uid;
        if (!uid) {
          res.status(200).end();
          return;
        }
        const userRef = db.collection(USERS).doc(uid);
        const userSnap = await userRef.get();
        if (!userSnap.exists) {
          res.status(200).end();
          return;
        }
        const current = userSnap.data()!;
        if (current.charges_enabled === chargesEnabled && current.payouts_enabled === payoutsEnabled) {
          res.status(200).end();
          return;
        }
        await userRef.update({
          charges_enabled: chargesEnabled,
          payouts_enabled: payoutsEnabled,
          updated_at: FieldValue.serverTimestamp(),
        });
        res.status(200).end();
        return;
      }

      default:
        res.status(200).end();
    }
  }
);

/** createConnectAccountLink: create Connect account if needed, write reverse lookup, return Account Link url */
export const createConnectAccountLink = onCall(
  {region: "us-central1", timeoutSeconds: 30, secrets: [stripeSecret]},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const uid = request.auth.uid;
    const userSnap = await db.collection(USERS).doc(uid).get();
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "User not found");
    }
    const user = userSnap.data()!;
    if (!(user.is_influencer === true || user.is_admin === true)) {
      throw new HttpsError("permission-denied", "Builder access required");
    }

    const stripe = getStripe(stripeSecret.value());
    let stripeAccountId = user.stripe_account_id as string | undefined;

    if (!stripeAccountId) {
      const account = await stripe.accounts.create({
        type: "express",
        country: "BE",
        email: (user.email as string) ?? undefined,
      });
      stripeAccountId = account.id;
      await db.collection(USERS).doc(uid).update({
        stripe_account_id: stripeAccountId,
        updated_at: FieldValue.serverTimestamp(),
      });
      await db.collection(STRIPE_ACCOUNTS).doc(stripeAccountId).set({uid});
    }

    const returnUrl = "https://waypoint.app/builder"; // TODO: use app deep link
    const refreshUrl = "https://waypoint.app/builder";
    const link = await stripe.accountLinks.create({
      account: stripeAccountId,
      type: "account_onboarding",
      refresh_url: refreshUrl,
      return_url: returnUrl,
    });
    return {url: link.url};
  }
);

/** getConnectAccountStatus: return charges_enabled (cached on user) */
export const getConnectAccountStatus = onCall(
  {region: "us-central1", timeoutSeconds: 10},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const uid = request.auth.uid;
    const userSnap = await db.collection(USERS).doc(uid).get();
    if (!userSnap.exists) {
      return {chargesEnabled: false, hasAccount: false};
    }
    const user = userSnap.data()!;
    const hasAccount = !!user.stripe_account_id;
    const chargesEnabled = user.charges_enabled === true;
    return {chargesEnabled, hasAccount};
  }
);

/** cancelPaymentIntent: when user dismisses Payment Sheet, cancel the PI so webhook can mark order failed */
export const cancelPaymentIntent = onCall(
  {region: "us-central1", timeoutSeconds: 15, secrets: [stripeSecret]},
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Must be signed in");
    }
    const uid = request.auth.uid;
    const data = request.data as Record<string, unknown> | null;
    const orderId = typeof data?.orderId === "string" ? data.orderId : null;
    if (!orderId) {
      throw new HttpsError("invalid-argument", "orderId required");
    }
    const orderSnap = await db.collection(ORDERS).doc(orderId).get();
    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found");
    }
    const order = orderSnap.data()!;
    if ((order.buyer_id as string) !== uid) {
      throw new HttpsError("permission-denied", "Not your order");
    }
    if ((order.status as string) !== "pending") {
      return {ok: true};
    }
    const piId = order.stripe_payment_intent_id as string | undefined;
    if (!piId) {
      return {ok: true};
    }
    const stripe = getStripe(stripeSecret.value());
    try {
      await stripe.paymentIntents.cancel(piId);
    } catch (e: any) {
      if (e.code === "payment_intent_unexpected_state") {
        return {ok: true};
      }
      throw new HttpsError("internal", e.message);
    }
    return {ok: true};
  }
);

/** TTL cleanup: mark pending orders older than 24h as failed */
export const cleanupPendingOrders = onSchedule(
  {schedule: "0 2 * * *", region: "us-central1", secrets: [stripeSecret]},
  async () => {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const snap = await db.collection(ORDERS)
      .where("status", "==", "pending")
      .where("created_at", "<", cutoff)
      .limit(100)
      .get();
    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.update(doc.ref, {status: "failed", updated_at: FieldValue.serverTimestamp()});
    }
    await batch.commit();
    console.log(`cleanupPendingOrders: marked ${snap.size} orders as failed`);
  }
);

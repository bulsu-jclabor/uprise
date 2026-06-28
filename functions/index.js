const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const crypto = require("crypto");

admin.initializeApp();

// ─────────────────────────────────────────────
//  PAYMONGO (GCash) CONFIGURATION
// ─────────────────────────────────────────────
// Set with:
//   firebase functions:config:set paymongo.secret_key="sk_test_xxx" paymongo.webhook_secret="whsk_xxx"
const PAYMONGO_BASE = "https://api.paymongo.com/v1";
// Update this if you deploy to a different region/project.
const FUNCTIONS_BASE_URL = "https://us-central1-uprise-5eac8.cloudfunctions.net";

function paymongoAuthHeader() {
  const secretKey = functions.config().paymongo && functions.config().paymongo.secret_key;
  if (!secretKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "PayMongo secret key is not configured. Run: firebase functions:config:set paymongo.secret_key=\"sk_test_xxx\""
    );
  }
  return "Basic " + Buffer.from(`${secretKey}:`).toString("base64");
}

async function paymongoFetch(path, method, body) {
  const resp = await fetch(`${PAYMONGO_BASE}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      Authorization: paymongoAuthHeader(),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await resp.json();
  if (!resp.ok) {
    const message = (json && json.errors && json.errors[0] && json.errors[0].detail) || "PayMongo request failed";
    throw new functions.https.HttpsError("internal", message);
  }
  return json;
}

function verifyPaymongoSignature(rawBody, signatureHeader, webhookSecret) {
  if (!signatureHeader || !webhookSecret) return false;
  const parts = {};
  signatureHeader.split(",").forEach((p) => {
    const [k, v] = p.split("=");
    if (k && v) parts[k.trim()] = v.trim();
  });
  const timestamp = parts.t;
  const expectedSig = parts.li || parts.te;
  if (!timestamp || !expectedSig) return false;
  const signedPayload = `${timestamp}.${rawBody}`;
  const computed = crypto.createHmac("sha256", webhookSecret).update(signedPayload).digest("hex");
  try {
    return crypto.timingSafeEqual(Buffer.from(computed), Buffer.from(expectedSig));
  } catch (_) {
    return false;
  }
}

// ─────────────────────────────────────────────
//  💳 CREATE GCASH PAYMENT INTENT (Callable Function)
//  Called from the student app at checkout. Writes a holding doc to
//  `gcash_payment_intents` (NOT `orders` yet) so unpaid/abandoned GCash
//  attempts never show up in the org's order management screen. The
//  real `orders` doc is only created by paymongoWebhook once PayMongo
//  confirms the payment actually succeeded.
// ─────────────────────────────────────────────
exports.createGcashPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }

  const {
    orgId, items, total, customerName, customerEmail,
    customerPhone, customerAddress, section, bundleId,
  } = data || {};

  if (!orgId || !Array.isArray(items) || items.length === 0 || !total || total <= 0) {
    throw new functions.https.HttpsError("invalid-argument", "Missing or invalid order details.");
  }

  const db = admin.firestore();
  const intentRef = db.collection("gcash_payment_intents").doc();

  await intentRef.set({
    userId: context.auth.uid,
    orgId,
    items,
    total,
    customerName: customerName || "",
    customerEmail: customerEmail || context.auth.token.email || "",
    customerPhone: customerPhone || "",
    customerAddress: customerAddress || "",
    section: section || "",
    bundleId: bundleId || "",
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    const amountCentavos = Math.round(total * 100);

    const piResp = await paymongoFetch("/payment_intents", "POST", {
      data: {
        attributes: {
          amount: amountCentavos,
          currency: "PHP",
          payment_method_allowed: ["gcash"],
          payment_method_options: { gcash: {} },
          description: `UPRISE Merchandise Order - ${customerName || context.auth.uid}`,
          metadata: { intentDocId: intentRef.id, uid: context.auth.uid },
        },
      },
    });
    const paymentIntentId = piResp.data.id;
    const clientKey = piResp.data.attributes.client_key;

    const pmResp = await paymongoFetch("/payment_methods", "POST", {
      data: {
        attributes: {
          type: "gcash",
          billing: {
            name: customerName || "",
            email: customerEmail || context.auth.token.email || "",
          },
        },
      },
    });
    const paymentMethodId = pmResp.data.id;

    const attachResp = await paymongoFetch(`/payment_intents/${paymentIntentId}/attach`, "POST", {
      data: {
        attributes: {
          payment_method: paymentMethodId,
          client_key: clientKey,
          return_url: `${FUNCTIONS_BASE_URL}/paymentRedirect`,
        },
      },
    });

    const checkoutUrl = attachResp.data.attributes.next_action &&
      attachResp.data.attributes.next_action.redirect &&
      attachResp.data.attributes.next_action.redirect.url;

    if (!checkoutUrl) {
      throw new functions.https.HttpsError("internal", "PayMongo did not return a checkout URL.");
    }

    await intentRef.update({ paymentIntentId, paymentMethodId, checkoutUrl });

    return { intentDocId: intentRef.id, checkoutUrl, paymentIntentId };
  } catch (err) {
    await intentRef.update({
      status: "failed",
      failureReason: err.message || "Failed to create payment",
    }).catch(() => {});
    if (err instanceof functions.https.HttpsError) throw err;
    console.error("createGcashPaymentIntent error", err);
    throw new functions.https.HttpsError("internal", "Failed to start GCash payment.");
  }
});

// ─────────────────────────────────────────────
//  ↩️ PAYMENT REDIRECT LANDING PAGE
//  PayMongo redirects the in-app WebView here after the user finishes
//  (or cancels) the GCash authorization. The actual pass/fail outcome
//  is determined by paymongoWebhook, not this page — the app just
//  watches for navigation to this URL to know the WebView is done.
// ─────────────────────────────────────────────
exports.paymentRedirect = functions.https.onRequest((req, res) => {
  res.set("Content-Type", "text/html");
  res.status(200).send(`
    <!DOCTYPE html>
    <html>
      <head><title>UPRISE Payment</title></head>
      <body style="font-family: sans-serif; text-align:center; padding-top:80px;">
        <h2>Thanks!</h2>
        <p>You may now close this window and return to the UPRISE app.</p>
      </body>
    </html>
  `);
});

// ─────────────────────────────────────────────
//  🔔 PAYMONGO WEBHOOK
//  Source of truth for whether a GCash payment actually succeeded.
//  On success: decrements stock, writes stock_logs, and creates the
//  real `orders` doc (mirroring the Cash-on-Pickup order shape exactly,
//  so the existing admin/org Orders screens need no changes).
// ─────────────────────────────────────────────
exports.paymongoWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const sigHeader = req.headers["paymongo-signature"];
    const webhookSecret = functions.config().paymongo && functions.config().paymongo.webhook_secret;
    if (!verifyPaymongoSignature(req.rawBody, sigHeader, webhookSecret)) {
      console.error("Invalid PayMongo webhook signature");
      return res.status(401).send("Invalid signature");
    }

    const eventType = req.body && req.body.data && req.body.data.attributes && req.body.data.attributes.type;
    const intentObj = req.body && req.body.data && req.body.data.attributes && req.body.data.attributes.data;
    const intentId = intentObj && intentObj.id;
    const metadata = (intentObj && intentObj.attributes && intentObj.attributes.metadata) || {};
    const intentDocId = metadata.intentDocId;

    if (!intentDocId) {
      console.warn("Webhook missing intentDocId metadata", eventType, intentId);
      return res.status(200).send("ignored");
    }

    const db = admin.firestore();
    const intentRef = db.collection("gcash_payment_intents").doc(intentDocId);

    if (eventType === "payment_intent.succeeded") {
      await db.runTransaction(async (txn) => {
        const intentSnap = await txn.get(intentRef);
        if (!intentSnap.exists) return;
        const intent = intentSnap.data();
        if (intent.status !== "pending") return; // already processed (idempotency)

        const items = intent.items || [];
        const productIds = [...new Set(items.map((i) => i.productId))];
        const productSnaps = {};
        for (const id of productIds) {
          productSnaps[id] = await txn.get(db.collection("products").doc(id));
        }

        const productState = {};
        for (const id of productIds) {
          const snap = productSnaps[id];
          if (!snap.exists) continue;
          const d = snap.data();
          productState[id] = {
            stock: d.stock || 0,
            status: d.status || "available",
            variants: Array.isArray(d.variants) ? d.variants.map((v) => ({ ...v })) : [],
            variantsModified: false,
          };
        }

        const orderRef = db.collection("orders").doc();
        const orderId = "ORD-" + Date.now().toString().slice(-8);

        for (const item of items) {
          const state = productState[item.productId];
          if (!state) continue; // product removed since checkout; payment still honored
          const hasVariant = !!item.variantId;
          if (hasVariant) {
            const idx = state.variants.findIndex((v) => v.id === item.variantId);
            if (idx !== -1) {
              const oldStock = state.variants[idx].stock || 0;
              const newStock = Math.max(0, oldStock - item.quantity);
              state.variants[idx].stock = newStock;
              state.variantsModified = true;
              state.stock = Math.max(0, state.stock - item.quantity);
              txn.set(db.collection("stock_logs").doc(), {
                productId: item.productId,
                productName: item.name,
                variantId: item.variantId,
                reason: "sold",
                oldStock,
                newStock,
                quantity: item.quantity,
                changedBy: "gcash-webhook",
                changedAt: admin.firestore.FieldValue.serverTimestamp(),
                orderId,
              });
            }
          } else {
            const oldStock = state.stock || 0;
            const newStock = Math.max(0, oldStock - item.quantity);
            state.stock = newStock;
            txn.set(db.collection("stock_logs").doc(), {
              productId: item.productId,
              productName: item.name,
              reason: "sold",
              oldStock,
              newStock,
              quantity: item.quantity,
              changedBy: "gcash-webhook",
              changedAt: admin.firestore.FieldValue.serverTimestamp(),
              orderId,
            });
          }
        }

        for (const [id, state] of Object.entries(productState)) {
          const update = { stock: state.stock };
          if (state.variantsModified) update.variants = state.variants;
          if (state.status !== "discontinued") {
            const effectiveStock = state.variants.length
              ? state.variants.reduce((s, v) => s + (v.stock || 0), 0)
              : state.stock;
            update.status = effectiveStock === 0 ? "out_of_stock" : "available";
          }
          txn.update(db.collection("products").doc(id), update);
        }

        txn.set(orderRef, {
          orderId,
          orgId: intent.orgId || "",
          userId: intent.userId || "",
          customerName: intent.customerName || "",
          customerEmail: intent.customerEmail || "",
          customerPhone: intent.customerPhone || "",
          customerAddress: intent.customerAddress || "",
          section: intent.section || "",
          bundleId: intent.bundleId || "",
          pickupStatus: "Pending",
          items,
          total: intent.total || 0,
          paymentMethod: "GCash",
          status: "pending",
          paymentStatus: "paid",
          paymentIntentId: intentId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        txn.update(intentRef, {
          status: "completed",
          orderId: orderRef.id,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } else if (eventType === "payment_intent.payment_failed") {
      const lastError = intentObj && intentObj.attributes && intentObj.attributes.last_payment_error;
      await intentRef.update({
        status: "failed",
        failureReason: (lastError && lastError.message) || "Payment failed",
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});
    }

    return res.status(200).send("ok");
  } catch (err) {
    console.error("paymongoWebhook error", err);
    return res.status(500).send("error");
  }
});

// ─────────────────────────────────────────────
//  EMAIL CONFIGURATION
// ─────────────────────────────────────────────
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().gmail.user,
    pass: functions.config().gmail.pass,
  },
});

// ─────────────────────────────────────────────
//  🚀 AUTO-ADD slotsLeft TO ANY NEW EVENT
//  This runs automatically when ANY event is created
//  (Even from Firebase Console!)
// ─────────────────────────────────────────────
exports.autoAddSlotsLeft = functions.firestore
    .document('events/{eventId}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const eventId = context.params.eventId;
        
        console.log(`📝 New event created: ${eventId}`);
        console.log(`📊 Data:`, data);
        
        // Check if slotsLeft is missing
        if (data.slotsLeft === undefined || data.slotsLeft === null) {
            // Use capacity, default to 0 if not set
            const capacity = data.capacity || 0;
            
            // Update the document with slotsLeft
            await snap.ref.update({
                slotsLeft: capacity
            });
            
            console.log(`✅ Added slotsLeft: ${capacity} to event ${eventId}`);
            console.log(`📊 Now showing: ${capacity}/${capacity} slots`);
        } else {
            console.log(`ℹ️ Event ${eventId} already has slotsLeft: ${data.slotsLeft}`);
        }
    });

// ─────────────────────────────────────────────
//  🔄 FIX EXISTING EVENTS (Callable Function)
//  Call this from your app to fix all existing events
// ─────────────────────────────────────────────
exports.fixExistingEvents = functions.https.onCall(async (data, context) => {
    // Security check - must be logged in
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
    }
    
    try {
        const events = await admin.firestore().collection('events').get();
        const batch = admin.firestore().batch();
        let fixedCount = 0;
        let skippedCount = 0;
        
        events.docs.forEach(doc => {
            const d = doc.data();
            // If slotsLeft is missing, add it
            if (d.slotsLeft === undefined || d.slotsLeft === null) {
                const capacity = d.capacity || 0;
                batch.update(doc.ref, { slotsLeft: capacity });
                fixedCount++;
            } else {
                skippedCount++;
            }
        });
        
        if (fixedCount > 0) {
            await batch.commit();
        }
        
        return {
            success: true,
            message: `Fixed ${fixedCount} events, ${skippedCount} already had slotsLeft`
        };
    } catch (error) {
        console.error('❌ Error fixing events:', error);
        return {
            success: false,
            error: error.message
        };
    }
});

// ─────────────────────────────────────────────
//  📊 GET EVENT STATS (Callable Function)
//  Call this to check how many events need fixing
// ─────────────────────────────────────────────
exports.getEventStats = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
    }
    
    try {
        const events = await admin.firestore().collection('events').get();
        let total = 0;
        let missingSlotsLeft = 0;
        let hasSlotsLeft = 0;
        let totalCapacity = 0;
        
        events.docs.forEach(doc => {
            const d = doc.data();
            total++;
            totalCapacity += (d.capacity || 0);
            
            if (d.slotsLeft === undefined || d.slotsLeft === null) {
                missingSlotsLeft++;
            } else {
                hasSlotsLeft++;
            }
        });
        
        return {
            success: true,
            totalEvents: total,
            eventsMissingSlotsLeft: missingSlotsLeft,
            eventsWithSlotsLeft: hasSlotsLeft,
            totalCapacity: totalCapacity
        };
    } catch (error) {
        return {
            success: false,
            error: error.message
        };
    }
});

// ─────────────────────────────────────────────
//  EXISTING EMAIL FUNCTIONS (Your original code)
// ─────────────────────────────────────────────

// Function for sending org credentials (for your existing admin screen)
exports.sendOrgCredentials = functions.https.onCall(async (data, context) => {
  // Security check - must be logged in
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }

  const { adviserEmail, orgName, username, password } = data;

  const mailOptions = {
    from: '"UPRISE System 🎓" <claudinejoysanjose@gmail.com>',
    to: adviserEmail,
    subject: `UPRISE – Login Credentials para sa ${orgName}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 500px; margin: auto;">
        <h2 style="color: #2c3e50;">Welcome to UPRISE!</h2>
        <p>Ang inyong organisasyon na <strong>${orgName}</strong> ay naka-register na sa sistema.</p>
        <hr/>
        <p><strong>Username:</strong> ${username}</p>
        <p><strong>Password:</strong> ${password}</p>
        <hr/>
        <p style="color: red;">⚠️ Palitan ang password pagkatapos mag-login.</p>
        <p>– UPRISE System, BulSU</p>
      </div>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: "Email sent!" };
  } catch (error) {
    console.error("Error sending email:", error);
    throw new functions.https.HttpsError("internal", "Failed to send email.");
  }
});

// Optional: Test function to verify everything works
exports.testEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in.");
  }
  
  const testEmail = data.testEmail || context.auth.token.email;
  
  const mailOptions = {
    from: '"UPRISE System 🎓" <claudinejoysanjose@gmail.com>',
    to: testEmail,
    subject: "✅ UPRISE Email Test",
    html: `
      <h2>Email System Test Successful!</h2>
      <p>Your UPRISE email system is working correctly.</p>
      <p>Tested at: ${new Date().toLocaleString()}</p>
      <p>You can now send credentials to users.</p>
    `
  };
  
  await transporter.sendMail(mailOptions);
  return { success: true, message: `Test email sent to ${testEmail}` };
});

// Callable function to process a single queued email
exports.processQueuedEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in.');
  }
  const docId = data.docId;
  if (!docId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing docId');
  }
  const docRef = admin.firestore().collection('email_queue').doc(docId);
  const snap = await docRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'Queue item not found');
  }
  const payload = snap.data();
  const to = payload.to_email;
  const studentId = payload.student_id;
  const password = payload.password;

  const mailOptions = {
    from: '"UPRISE System 🎓" <' + (functions.config().gmail.user || 'noreply@example.com') + '>',
    to: to,
    subject: `UPRISE – Student Credentials for ${studentId}`,
    html: `<div style="font-family: Arial, sans-serif; max-width:500px; margin:auto;">
      <h2>UPRISE – Account Created</h2>
      <p>Your account has been created.</p>
      <p><strong>Student ID:</strong> ${studentId}</p>
      <p><strong>Password:</strong> ${password}</p>
      <p>Please change your password after first login.</p>
    </div>`
  };

  try {
    await transporter.sendMail(mailOptions);
    await docRef.delete();
    return { success: true };
  } catch (err) {
    console.error('Error processing queued email', err);
    await docRef.update({ attempts: (payload.attempts || 0) + 1, lastError: err.toString(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});

// Scheduled function to process queued emails periodically
exports.processEmailQueue = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
  const q = await admin.firestore().collection('email_queue').where('attempts', '<', 5).orderBy('createdAt').limit(20).get();
  const results = { processed: 0, failed: 0 };
  for (const doc of q.docs) {
    const payload = doc.data();
    const to = payload.to_email;
    const studentId = payload.student_id;
    const password = payload.password;
    const mailOptions = {
      from: '"UPRISE System 🎓" <' + (functions.config().gmail.user || 'noreply@example.com') + '>',
      to: to,
      subject: `UPRISE – Student Credentials for ${studentId}`,
      html: `<div style="font-family: Arial, sans-serif; max-width:500px; margin:auto;">
        <h2>UPRISE – Account Created</h2>
        <p>Your account has been created.</p>
        <p><strong>Student ID:</strong> ${studentId}</p>
        <p><strong>Password:</strong> ${password}</p>
        <p>Please change your password after first login.</p>
      </div>`
    };
    try {
      await transporter.sendMail(mailOptions);
      await doc.ref.delete();
      results.processed++;
    } catch (err) {
      console.error('Queue send failed for', doc.id, err);
      await doc.ref.update({ attempts: (payload.attempts || 0) + 1, lastError: err.toString(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      results.failed++;
    }
  }
  return results;
});

// Immediate processing: when a queue doc is created, attempt to send it right away.
// This ensures user-visible credential emails are attempted immediately instead
// of waiting for the 5-minute scheduled job.
exports.onEmailQueued = functions.firestore
  .document('email_queue/{docId}')
  .onCreate(async (snap, context) => {
    const payload = snap.data();
    if (!payload) return null;
    const to = payload.to_email;
    const studentId = payload.student_id;
    const password = payload.password;
    const docRef = snap.ref;

    const mailOptions = {
      from: '"UPRISE System 🎓" <' + (functions.config().gmail.user || 'noreply@example.com') + '>',
      to: to,
      subject: `UPRISE – Student Credentials for ${studentId}`,
      html: `<div style="font-family: Arial, sans-serif; max-width:500px; margin:auto;">
        <h2>UPRISE – Account Created</h2>
        <p>Your account has been created.</p>
        <p><strong>Student ID:</strong> ${studentId}</p>
        <p><strong>Password:</strong> ${password}</p>
        <p>Please change your password after first login.</p>
      </div>`
    };

    try {
      await transporter.sendMail(mailOptions);
      await docRef.delete();
      console.log('Queued email sent and removed:', docRef.id);
      return { success: true };
    } catch (err) {
      console.error('Immediate queue send failed for', docRef.id, err);
      await docRef.update({ attempts: (payload.attempts || 0) + 1, lastError: err.toString(), updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      return null;
    }
  });
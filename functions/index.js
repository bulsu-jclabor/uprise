const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// I-setup ang Gmail transporter using functions.config()
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().gmail.user,
    pass: functions.config().gmail.pass,
  },
});

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
  return { success: true, message: "Test email sent to $testEmail" };
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
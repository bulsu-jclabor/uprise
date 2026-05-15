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
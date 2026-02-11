const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// Configure your email account (use Gmail or another SMTP)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "your-email@gmail.com",       // <-- your email
    pass: "your-email-app-password"     // <-- App password for Gmail
  }
});

// Trigger: When a new user with role 'homeowner' is created
exports.sendFamilyCodeEmail = functions.firestore
  .document("users/{userId}")
  .onCreate(async (snap, context) => {
    const userData = snap.data();

    if (!userData) return;

    if (userData.role === "homeowner") {
      const toEmail = userData.email;
      const familyCode = userData.familyCode;

      const mailOptions = {
        from: "your-email@gmail.com",
        to: toEmail,
        subject: "Your Family Code",
        text: `Hello ${userData.username},\n\nHere is your family code: ${familyCode}\n\nShare this code with your family members so they can join your family group in the app.\n\nBest,\nFamily App Team`
      };

      try {
        await transporter.sendMail(mailOptions);
        console.log(`Family code sent to ${toEmail}`);
      } catch (error) {
        console.error("Error sending email:", error);
      }
    }
  });

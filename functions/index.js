// functions/index.js

// v2-style imports
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onCall} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

exports.lockUserOnTooManyFails = onDocumentWritten(
    {region: "asia-southeast1"},
    "login_attempts/{username}",
    async (event) => {
      const username = event.params.username;
      console.log(`🔔 Trigger fired for login_attempts/${username}`);

      // avoid optional-chaining
      const beforeSnap = event.data.before;
      const afterSnap = event.data.after;
      const beforeCount = beforeSnap ? beforeSnap.data.count : 0;
      const afterCount = afterSnap ? afterSnap.data.count : 0;

      console.log(`   📊 Counts → before: ${beforeCount}, after: ${afterCount}`);

      if (!afterSnap) {
        console.log("   ⚠️ afterSnap is null (doc deleted?), exiting");
        return;
      }
      if (afterCount < 3) {
        console.log("   ℹ️ count < 3, no lock needed");
        return;
      }

      console.log(`   🚩 count ≥ 3, proceeding to lock user: ${username}`);

      const userQuery = await admin
          .firestore()
          .collection("users")
          .where("username", "==", username)
          .limit(1)
          .get();

      if (userQuery.empty) {
        console.log(`   ❌ No user found for username=${username}`);
        return;
      }
      const email = userQuery.docs[0].data().email;
      console.log(`   📧 Found email=${email}`);

      const userRecord = await admin.auth().getUserByEmail(email);
      console.log(`🔑 Auth record: uid=${userRecord.uid}`);

      if (!userRecord.disabled) {
        await admin.auth().updateUser(userRecord.uid, {disabled: true});
        console.log(`✅ Disabled user ${email} ${afterCount} failed attempts`);
      } else {
        console.log(`   ℹ️ User ${email} was already disabled`);
      }
    },
);

// 2) HTTPS Callable: re-enable a disabled user
exports.reenableUser = onCall(
    {region: "asia-southeast1"}, // optional: pick your region
    async (req) => {
      const email = req.data.email;
      if (!email) {
        throw new Error("invalid-argument: \"email\" is required");
      }

      // lookup Auth user
      const userRecord = await admin.auth().getUserByEmail(email);
      if (userRecord.disabled) {
        await admin.auth().updateUser(userRecord.uid, {disabled: false});
        console.log(`Re-enabled user ${email}`);
      }
      return {success: true};
    },
);


// /**
//  * Import function triggers from their respective submodules:
//  *
//  * const {onCall} = require("firebase-functions/v2/https");
//  * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
//  *
//  * See a full list of supported triggers at https://firebase.google.com/docs/functions
//  */

// const {setGlobalOptions} = require("firebase-functions");
// const {onRequest} = require("firebase-functions/https");
// const logger = require("firebase-functions/logger");

// // For cost control, you can set the maximum number of containers that can be
// // running at the same time. This helps mitigate the impact of unexpected
// // traffic spikes by instead downgrading performance. This limit is a
// // per-function limit. You can override the limit for each function using the
// // `maxInstances` option in the function's options, e.g.
// // `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// // NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// // functions should each use functions.runWith({ maxInstances: 10 }) instead.
// // In the v1 API, each function can only serve one request per container, so
// // this will be the maximum concurrent request count.
// setGlobalOptions({ maxInstances: 10 });

// // Create and deploy your first functions
// // https://firebase.google.com/docs/functions/get-started

// // exports.helloWorld = onRequest((request, response) => {
// //   logger.info("Hello logs!", {structuredData: true});
// //   response.send("Hello from Firebase!");
// // });

// // functions/index.js

// admin.initializeApp();

// exports.lockUserOnTooManyFails = onDocumentWritten(
//   'login_attempts/{username}',
//   async (event) => {
//     const after = event.data?.after?.data;
//     if (!after || (after.count||0) < 3) return;
//     /* …your logic, using event.params.username… */
//   }
// );

// exports.reenableUser = onCall(async (req) => {
//   const { email } = req.data;
//   if (!email) throw new Error('invalid-argument: Email is required');
//   /* …your logic… */
//   return { success: true };
// });

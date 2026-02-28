const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

function buildNotificationText(type, userName) {
  const name = userName || "Someone";
  if (type === "comment") return { title: "New Comment", body: `${name} commented on your post` };
  if (type === "reply") return { title: "New Reply", body: `${name} replied to your comment` };
  if (type === "like") return { title: "New Like", body: `${name} liked your post` };
  if (type === "laugh") return { title: "New Reaction", body: `${name} laughed at your post` };
  if (type === "support") return { title: "New Support", body: `${name} supported your post` };
  if (type === "repost") return { title: "New Repost", body: `${name} reposted your post` };
  if (type === "comment_like") return { title: "New Reaction", body: `${name} liked your comment` };
  return { title: "New Activity", body: "You have a new notification" };
}

exports.pushOnNotificationCreated = onDocumentCreated("notifications/{id}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() || {};

  const toUserId = (data.toUserId || "").toString();
  const fromUserId = (data.fromUserId || "").toString();
  
  if (!toUserId || !fromUserId) return;

  // 1. Get the target user's tokens
  const userDoc = await admin.firestore().collection("users").doc(toUserId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data() || {};
  const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens.filter((t) => typeof t === "string" && t.trim()) : [];
  if (tokens.length === 0) return;

  // 2. Get the sender's name
  let senderName = "Someone";
  try {
    const senderDoc = await admin.firestore().collection("users").doc(fromUserId).get();
    if (senderDoc.exists) {
      senderName = senderDoc.data().name || "Someone";
    }
  } catch (e) {
    console.error("Error fetching sender user:", e);
  }

  const type = (data.type || "").toString();
  const postId = (data.postId || "").toString();
  const commentId = (data.commentId || "").toString();
  const textContent = buildNotificationText(type, senderName);

  const multicast = {
    tokens,
    notification: {
      title: textContent.title,
      body: textContent.body,
    },
    data: {
      type,
      postId,
      commentId,
      screen: "post_detail",
      click_action: "FLUTTER_NOTIFICATION_CLICK"
    },
    android: {
      priority: "high",
      notification: {
        clickAction: "FLUTTER_NOTIFICATION_CLICK"
      }
    },
    apns: {
      payload: {
        aps: {
          contentAvailable: true,
        },
      },
    },
  };

  const res = await admin.messaging().sendEachForMulticast(multicast);

  const invalid = [];
  res.responses.forEach((r, idx) => {
    if (r.success) return;
    const code = r.error && r.error.code ? r.error.code : "";
    if (code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token") {
      invalid.push(tokens[idx]);
    }
  });

  if (invalid.length > 0) {
    await admin.firestore().collection("users").doc(toUserId).set(
      {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
      },
      { merge: true }
    );
  }
});

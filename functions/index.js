const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

function shortenText(value, max = 80) {
  const text = String(value || "")
    .trim()
    .replace(/\s+/g, " ");
  if (!text) return "";
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

function buildNotificationContent(type, senderName, data) {
  const name = senderName || "Someone";
  const snippet = shortenText(data?.text, 90);

  switch (type) {
    case "comment":
      return {
        title: name,
        body: snippet ? `علّق على منشورك: ${snippet}` : "علّق على منشورك",
      };

    case "reply":
      return {
        title: name,
        body: snippet ? `ردّ على تعليقك: ${snippet}` : "ردّ على تعليقك",
      };

    case "like":
      return { title: name, body: "أعجب بمنشورك" };

    case "laugh":
      return { title: name, body: "تفاعل 😂 مع منشورك" };

    case "support":
      return { title: name, body: "قدّم الدعم ❤️ لمنشورك" };

    case "repost":
      return {
        title: name,
        body: snippet ? `أعاد نشر منشورك مع: ${snippet}` : "أعاد نشر منشورك",
      };

    case "comment_like":
      return { title: name, body: "أعجب بتعليقك" };

    case "mention":
      return {
        title: name,
        body: snippet ? `ذكرك في تعليق: ${snippet}` : "ذكرك في تعليق",
      };

    case "post_pending":
      return {
        title: name,
        body: snippet
          ? `قدّم منشوراً للموافقة: ${snippet}`
          : "قدّم منشوراً للموافقة",
      };

    case "post_approved":
      return {
        title: "✅ Great news!",
        body: "Your post has been approved and is now live.",
      };

    case "chat_message":
      return {
        title: name,
        body: snippet ? snippet : "أرسل لك رسالة",
      };

    case "group_message": {
      const gName = String(data?.groupName || "").trim();
      return {
        title: gName || name,
        body: snippet ? `${name}: ${snippet}` : `${name} sent a message`,
      };
    }

    case "group_mention":
      return {
        title: name,
        body: snippet
          ? `Mentioned you: ${snippet}`
          : "Mentioned you in a group",
      };

    case "connection_request":
      return {
        title: "طلب تواصل جديد",
        body: `أرسل لك ${name} طلب تواصل.`,
      };

    case "request_accepted":
      return {
        title: "تم قبول طلبك",
        body: `قام ${name} بقبول طلب التواصل الخاص بك.`,
      };

    case "post_rejected":
      return {
        title: "⚠️ Update needed",
        body: "Your post was not approved. Click to see why.",
      };

    case "post_pending":
      return {
        title: "منشور بانتظار الموافقة",
        body: `قام ${name} بتقديم منشور جديد ينتظر موافقتك.`,
      };

    case "community_join_request": {
      const communityName = String(data?.communityName || "Community").trim();
      return {
        title: `طلب انضمام — ${communityName}`,
        body: `${name} يطلب الانضمام إلى ${communityName}`,
      };
    }

    case "schedule_uploaded":
      return {
        title: "جدول المحاضرات",
        body: "يتوفر الآن جدول محاضرات جديد.",
      };

    default:
      return {
        title: "إشعار جديد",
        body: "لديك إشعار جديد",
      };
  }
}

exports.pushOnNotificationCreated = onDocumentCreated(
  {
    document: "notifications/{id}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const notificationId = String(event.params?.id || snap.id || "");

    const toUserId = String(data.toUserId || "").trim();
    const fromUserId = String(data.fromUserId || "").trim();
    const type = String(data.type || "").trim();
    const groupId = String(data.groupId || "").trim();

    console.log(
      `[FCM] Trigger fired — notificationId=${notificationId} to=${toUserId} from=${fromUserId} type=${type}`,
    );

    if (!toUserId) return;

    // Only for group chat: do not push the message notification to the sender.
    if (
      fromUserId &&
      toUserId === fromUserId &&
      (type === "group_message" || type === "group_mention") &&
      groupId
    ) {
      console.log(`[FCM] Skip self group notification (${notificationId})`);
      return;
    }

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(toUserId)
      .get();

    if (!userDoc.exists) return;

    const userData = userDoc.data() || {};
    const tokens = (userData.fcmTokens || []).filter(
      (t) => typeof t === "string" && t.trim(),
    );

    if (!tokens.length) return;

    let senderName = "Someone";
    let senderAvatarUrl = "";

    if (fromUserId) {
      try {
        const senderDoc = await admin
          .firestore()
          .collection("users")
          .doc(fromUserId)
          .get();

        if (senderDoc.exists) {
          const senderData = senderDoc.data() || {};
          senderName = senderData.name || "Someone";
          senderAvatarUrl = String(senderData.avatarUrl || "").trim();
        }
      } catch (e) {
        console.error("Error fetching sender user:", e);
      }
    }

    const postId = String(data.postId || "");
    const commentId = String(data.commentId || "");
    const parentCommentId = String(data.parentCommentId || "");
    const conversationId = String(data.conversationId || "");
    // NOTE: fromUserId is already declared above (line ~129) from data.fromUserId
    const universityKey = String(data.universityKey || "");
    const departmentKey = String(data.departmentKey || "");
    const levelKey = String(data.levelKey || "");
    const imageUrl = String(data.imageUrl || "");

    if (type === "chat_message" && conversationId) {
      try {
        const convDoc = await admin
          .firestore()
          .collection("conversations")
          .doc(conversationId)
          .get();
        if (convDoc.exists) {
          const convData = convDoc.data() || {};
          const muteUntilObj = convData.muteUntil || {};
          const muteSeconds = muteUntilObj[toUserId]?._seconds;
          const nowSeconds = Date.now() / 1000;
          if (muteSeconds && muteSeconds > nowSeconds) {
            console.log(
              `[FCM] Skipped 1-to-1 message notification for muted user ${toUserId}`,
            );
            return;
          }
        }
      } catch (e) {
        console.error("[FCM] Error checking conversation mute status:", e);
      }
    }

    const content = buildNotificationContent(type, senderName, data);

    const multicast = {
      tokens,
      data: {
        type,
        postId,
        commentId,
        parentCommentId,
        conversationId,
        fromUserId: fromUserId || "",
        notificationId,
        universityKey,
        departmentKey,
        levelKey,
        imageUrl,
        groupId,
        senderName,
        senderAvatarUrl,
        text: String(data.text || ""),
        title: content.title,
        body: content.body,
        screen:
          type === "schedule_uploaded"
            ? "lectures"
            : type === "post_pending"
              ? "admin_dashboard"
              : type === "community_join_request"
                ? "community_admin"
                : type === "connection_request" || type === "request_accepted"
                  ? "profile"
                  : type === "chat_message"
                    ? "direct_message"
                    : type === "group_message" || type === "group_mention"
                      ? "group_chat"
                      : "post_detail",
        communityId: String(data.communityId || ""),
        communityName: String(data.communityName || ""),
        requestId: String(data.requestId || ""),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 86400000,
        restrictedPackageName: "com.natu.students",
        directBootOk: true,
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: content.title,
              body: content.body,
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
            mutableContent: true,
          },
        },
      },
    };

    const res = await admin.messaging().sendEachForMulticast(multicast);

    console.log(
      `[FCM] Sent to ${tokens.length} token(s) — success=${res.successCount} fail=${res.failureCount}`,
    );

    const invalidTokens = [];

    res.responses.forEach((r, idx) => {
      if (r.success) return;

      const code = r.error?.code || "";
      console.error(
        `[FCM] Token #${idx} failed: ${code} — ${r.error?.message || "unknown"}`,
      );

      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[idx]);
      }
    });

    if (invalidTokens.length) {
      await admin
        .firestore()
        .collection("users")
        .doc(toUserId)
        .set(
          {
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          },
          { merge: true },
        );
    }
  },
);

exports.pushOnScheduleBroadcast = onDocumentCreated(
  {
    document: "broadcasts/{id}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const topic = String(data.targetTopic || "");
    const type = String(data.type || "");

    console.log(
      `[FCM-TOPIC] Broadcast triggered for topic=${topic} type=${type}`,
    );

    if (!topic || type !== "schedule_uploaded") return;

    let senderName = "Someone";
    let senderAvatarUrl = "";

    try {
      if (data.fromUserId) {
        const senderDoc = await admin
          .firestore()
          .collection("users")
          .doc(data.fromUserId)
          .get();

        if (senderDoc.exists) {
          const senderData = senderDoc.data() || {};
          senderName = senderData.name || "Someone";
          senderAvatarUrl = String(senderData.avatarUrl || "").trim();
        }
      }
    } catch (e) {
      console.error("Error fetching sender user:", e);
    }

    const payload = {
      topic: topic,
      data: {
        type,
        universityKey: String(data.universityKey || ""),
        departmentKey: String(data.departmentKey || ""),
        levelKey: String(data.levelKey || ""),
        imageUrl: String(data.imageUrl || ""),
        senderName,
        senderAvatarUrl,
        title: "جدول المحاضرات",
        body: "يتوفر الآن جدول محاضرات جديد.",
        screen: "lectures",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 86400000,
        restrictedPackageName: "com.natu.students",
        directBootOk: true,
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: "جدول المحاضرات",
              body: "يتوفر الآن جدول محاضرات جديد.",
            },
            sound: "default",
            badge: 1,
            contentAvailable: true,
            mutableContent: true,
          },
        },
      },
    };

    try {
      const res = await admin.messaging().send(payload);
      console.log(
        `[FCM-TOPIC] Sent broadcast to ${topic} successfully. Message ID: ${res}`,
      );
    } catch (e) {
      console.error(`[FCM-TOPIC] Broadcast failed to ${topic}:`, e);
    }
  },
);

// ── Group Messages Push Notification ─────────────────────────────────────────
// Triggered when a new message is created in any group.
// Sends FCM to all group members except the sender and muted members.
exports.onGroupMessageCreated = onDocumentCreated(
  {
    document: "groups/{groupId}/messages/{msgId}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const { groupId, msgId } = event.params;

    const senderId = String(data.senderId || "").trim();
    const messageType = String(data.messageType || "text");

    // Skip system messages and deleted messages
    if (messageType === "system" || data.deletedForAll) return;
    if (!senderId) return;

    // Fetch group document
    const groupDoc = await admin
      .firestore()
      .collection("groups")
      .doc(groupId)
      .get();
    if (!groupDoc.exists) return;
    const groupData = groupDoc.data() || {};

    // Community "Announcements" channel — no member push (still unread in-app).
    if (groupData.isAnnouncementOnly === true) {
      console.log(
        `[GROUP-FCM] Skipping push — announcement channel groupId=${groupId}`,
      );
      return;
    }

    const groupName = String(groupData.name || "Group");
    const memberIds = (groupData.memberIds || [])
      .map((id) => String(id == null ? "" : id).trim())
      .filter((id) => id.length > 0);

    // Fetch sender info
    let senderName = "Someone";
    let senderAvatarUrl = "";
    try {
      const senderDoc = await admin
        .firestore()
        .collection("users")
        .doc(senderId)
        .get();
      if (senderDoc.exists) {
        const sd = senderDoc.data() || {};
        senderName = sd.name || "Someone";
        senderAvatarUrl = String(sd.avatarUrl || "").trim();
      }
    } catch (e) {
      console.error("[GROUP-FCM] Error fetching sender:", e);
    }

    const mentionedUserIds = (data.mentionedUserIds || [])
      .map((id) => String(id == null ? "" : id).trim())
      .filter((id) => id.length > 0);
    const messageText = String(data.text || "");
    const preview = shortenText(
      messageText || (data.mediaUrls?.length ? "📎 Media" : ""),
      80,
    );

    // Collect recipients (exclude sender)
    const recipientIds = memberIds.filter((id) => id !== senderId);
    if (!recipientIds.length) return;

    // Fetch user & member docs in parallel
    const [userDocs, memberDocs] = await Promise.all([
      Promise.all(
        recipientIds.map((uid) =>
          admin.firestore().collection("users").doc(uid).get(),
        ),
      ),
      Promise.all(
        recipientIds.map((uid) =>
          admin
            .firestore()
            .collection("groups")
            .doc(groupId)
            .collection("members")
            .doc(uid)
            .get(),
        ),
      ),
    ]);

    const now = Date.now();

    for (let i = 0; i < recipientIds.length; i++) {
      const uid = recipientIds[i];
      const userDoc = userDocs[i];
      const memberDoc = memberDocs[i];

      if (!userDoc.exists) continue;
      const ud = userDoc.data() || {};
      const tokens = (ud.fcmTokens || []).filter(
        (t) => typeof t === "string" && t.trim(),
      );
      if (!tokens.length) continue;

      // Check mute
      if (memberDoc.exists) {
        const md = memberDoc.data() || {};
        const muteSeconds = md.muteUntil?._seconds;
        if (muteSeconds && muteSeconds * 1000 > now) continue; // muted
      }

      const isMentioned = mentionedUserIds.includes(uid);
      const type = isMentioned ? "group_mention" : "group_message";
      const content = buildNotificationContent(type, senderName, {
        text: preview,
        groupName,
      });

      const multicast = {
        tokens,
        data: {
          type,
          groupId,
          messageId: msgId,
          groupName,
          fromUserId: senderId,
          senderName,
          senderAvatarUrl,
          text: preview,
          title: content.title,
          body: content.body,
          screen: "group_chat",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: isMentioned ? "high" : "normal",
          ttl: 86400000,
          restrictedPackageName: "com.natu.students",
          directBootOk: true,
        },
        apns: {
          headers: { "apns-priority": isMentioned ? "10" : "5" },
          payload: {
            aps: {
              alert: { title: content.title, body: content.body },
              sound: "default",
              badge: 1,
              contentAvailable: true,
              mutableContent: true,
            },
          },
        },
      };

      try {
        const res = await admin.messaging().sendEachForMulticast(multicast);
        console.log(
          `[GROUP-FCM] uid=${uid} type=${type} — success=${res.successCount} fail=${res.failureCount}`,
        );

        // Remove invalid tokens
        const invalidTokens = [];
        res.responses.forEach((r, idx) => {
          if (r.success) return;
          const code = r.error?.code || "";
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            invalidTokens.push(tokens[idx]);
          }
        });
        if (invalidTokens.length) {
          await admin
            .firestore()
            .collection("users")
            .doc(uid)
            .set(
              {
                fcmTokens: admin.firestore.FieldValue.arrayRemove(
                  ...invalidTokens,
                ),
              },
              { merge: true },
            );
        }
      } catch (e) {
        console.error(`[GROUP-FCM] Error sending to uid=${uid}:`, e);
      }
    }
  },
);

// ── Custom HTML Password Reset Email Cloud Function ──────────────────────────
const { onRequest } = require("firebase-functions/v2/https");
const nodemailer = require("nodemailer");

exports.sendCustomResetPassword = onRequest(
  {
    region: "europe-west1",
    cors: true,
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    const { email } = req.body || {};
    if (!email || typeof email !== "string") {
      res.status(400).json({ error: "Missing or invalid email parameter." });
      return;
    }

    try {
      // 1. Verify user exists in Auth
      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email.trim());
      } catch (authError) {
        if (authError.code === "auth/user-not-found") {
          res.status(404).json({ error: "No account found with this email." });
          return;
        }
        throw authError;
      }

      // 2. Fetch SMTP Configuration from Firestore
      const smtpDoc = await admin
        .firestore()
        .collection("system_config")
        .doc("smtp")
        .get();

      if (!smtpDoc.exists) {
        console.error(
          "[SMTP] smtp config document not found in system_config/smtp",
        );
        res.status(500).json({
          error:
            "SMTP server is not configured. Please create a document in Firestore at 'system_config/smtp' containing fields: host, port, secure (boolean), user, pass, senderName.",
        });
        return;
      }

      const smtpData = smtpDoc.data() || {};
      const { host, port, secure, user, pass, senderName } = smtpData;

      if (!host || !port || !user || !pass) {
        console.error("[SMTP] Incomplete SMTP config:", smtpData);
        res.status(500).json({
          error:
            "Incomplete SMTP configuration in system_config/smtp. Required fields: host, port, user, pass.",
        });
        return;
      }

      // 3. Generate Password Reset Link
      const link = await admin.auth().generatePasswordResetLink(email.trim());

      // 4. Create Nodemailer Transporter
      const transporter = nodemailer.createTransport({
        host: String(host).trim(),
        port: parseInt(port),
        secure: secure === true || secure === "true",
        auth: {
          user: String(user).trim(),
          pass: String(pass).trim(),
        },
      });

      const displaySenderName = senderName
        ? String(senderName).trim()
        : "University Connect";

      // 5. Premium Professional HTML Template
      const htmlContent = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>إعادة تعيين كلمة المرور</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&display=swap" rel="stylesheet"/>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0d1117;--card:#111827;--blue1:#3b82f6;--blue3:#1d4ed8;
  --gold:#f59e0b;--gold2:#fbbf24;--text:#f1f5f9;--muted:#94a3b8;
  --border:#1e293b;--inp:#0f172a;--success:#22c55e;--danger:#ef4444;
}
body{font-family:'Cairo',sans-serif;background:var(--bg);display:flex;align-items:flex-start;justify-content:center;min-height:100vh;padding:12px;direction:rtl}
.phone{width:100%;max-width:360px;background:var(--card);border-radius:24px;overflow:hidden;border:1px solid #1e293b;box-shadow:0 8px 40px rgba(0,0,0,0.5);}

.status-bar{background:#060d1a;padding:7px 16px 5px;display:flex;justify-content:space-between;align-items:center}
.status-bar span{font-size:11px;color:#94a3b8;font-family:monospace}

.top-bar{background:#060d1a;display:flex;align-items:center;justify-content:space-between;padding:6px 12px 9px;border-bottom:1px solid #1e293b}
.icon-btn{width:30px;height:30px;border-radius:50%;border:none;background:rgba(255,255,255,.06);color:#94a3b8;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center}
.actions{display:flex;gap:6px}

.banner{background:linear-gradient(160deg,#1e40af 0%,#2563eb 45%,#3b82f6 100%);padding:20px 18px 22px;text-align:center;position:relative;overflow:hidden}
.banner::before{content:'';position:absolute;inset:0;background:radial-gradient(circle at 20% 20%,rgba(255,255,255,.13),transparent 50%)}
.banner::after{content:'';position:absolute;bottom:-1px;left:0;right:0;height:18px;background:var(--card);border-radius:18px 18px 0 0}
.lock-wrap{width:54px;height:54px;border-radius:50%;background:rgba(255,255,255,.15);border:2px solid rgba(255,255,255,.22);display:flex;align-items:center;justify-content:center;margin:0 auto 10px;font-size:24px;}

.banner h1{font-size:17px;font-weight:900;color:#fff;line-height:1.3;position:relative;margin-bottom:4px}
.uni-badge{display:inline-flex;align-items:center;gap:5px;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.18);border-radius:20px;padding:3px 10px;font-size:10px;color:rgba(255,255,255,.88);margin-top:5px;position:relative}
.uni-dot{width:5px;height:5px;border-radius:50%;background:#4ade80}

.body{padding:14px 16px 20px}

.screen{display:none}
.screen.active{display:block;}

.steps{display:flex;gap:5px;justify-content:center;margin-bottom:14px}
.step-dot{width:7px;height:7px;border-radius:50%;background:var(--border);transition:all .3s}
.step-dot.active{background:var(--blue1);transform:scale(1.2)}
.step-dot.done{background:#22c55e}

.greet{font-size:15px;font-weight:700;color:var(--text);margin-bottom:5px}
.sub{font-size:12px;color:var(--muted);line-height:1.7;margin-bottom:12px}

.email-badge{background:var(--inp);border:1px solid #263352;border-radius:10px;padding:10px 12px;text-align:center;font-size:13px;font-weight:600;color:var(--blue1);margin-bottom:14px;direction:ltr}

.btn{width:100%;padding:12px;border:none;border-radius:12px;font-family:'Cairo',sans-serif;font-size:13px;font-weight:700;cursor:pointer;transition:all .2s;position:relative;overflow:hidden}
.btn-primary{background:linear-gradient(135deg,var(--blue1),var(--blue3));color:#fff;box-shadow:0 4px 16px rgba(37,99,235,.35);text-decoration:none;display:block;text-align:center;}
.btn-primary:hover{transform:translateY(-1px);box-shadow:0 6px 22px rgba(37,99,235,.45)}
.btn-primary:active{transform:translateY(0)}

.warn-box{background:rgba(245,158,11,.07);border:1px solid rgba(245,158,11,.22);border-radius:10px;padding:10px 12px;margin-top:12px;display:flex;gap:8px;align-items:flex-start;text-align:right;}
.warn-icon{font-size:13px;color:var(--gold2);flex-shrink:0;margin-top:2px}
.warn-text{font-size:11px;color:var(--gold2);line-height:1.6}
.warn-text strong{color:var(--gold)}

.divider{border:none;border-top:1px solid var(--border);margin:14px 0}
.footer{font-size:10px;color:#475569;text-align:center;line-height:1.9}
</style>
</head>
<body style="margin:0;padding:0;background-color:#0d1117;font-family:'Cairo',sans-serif;direction:rtl;">

<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0d1117;padding:40px 16px;">
  <tr>
    <td align="center" valign="top">

      <div class="phone" style="width:100%;max-width:360px;background:#111827;border-radius:24px;overflow:hidden;border:1px solid #1e293b;text-align:right;">
        <div class="status-bar" style="background:#060d1a;padding:7px 16px 5px;display:flex;justify-content:space-between;align-items:center;color:#94a3b8;font-size:11px;font-family:monospace;direction:ltr;">
          <span style="direction:rtl;">${displaySenderName}</span>
        </div>
        
        <div class="top-bar" style="background:#060d1a;display:flex;align-items:center;justify-content:space-between;padding:6px 12px 9px;border-bottom:1px solid #1e293b;">
          <button class="icon-btn" style="width:30px;height:30px;border-radius:50%;border:none;background:rgba(255,255,255,.06);color:#94a3b8;font-size:14px;display:flex;align-items:center;justify-content:center;">&larr;</button>
          <div class="actions" style="display:flex;gap:6px;">
          </div>
        </div>

        <div class="banner" style="background:linear-gradient(160deg,#1e40af 0%,#2563eb 45%,#3b82f6 100%);padding:20px 18px 22px;text-align:center;position:relative;overflow:hidden;">
          <div class="lock-wrap" style="width:54px;height:54px;border-radius:50%;background:rgba(255,255,255,.15);border:2px solid rgba(255,255,255,.22);display:flex;align-items:center;justify-content:center;margin:0 auto 10px;font-size:24px;">🔐</div>
          <h1 style="font-size:17px;font-weight:900;color:#fff;line-height:1.3;margin-bottom:4px;">إعادة تعيين كلمة المرور</h1>
          <div class="uni-badge" style="display:inline-flex;align-items:center;gap:5px;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.18);border-radius:20px;padding:3px 10px;font-size:10px;color:rgba(255,255,255,.88);margin-top:5px;"><span class="uni-dot" style="width:5px;height:5px;border-radius:50%;background:#4ade80;"></span>بوابتك الأكاديمية &mdash; ${displaySenderName}</div>
        </div>

        <div class="body" style="padding:14px 16px 20px;">
          <div class="steps" style="display:flex;gap:5px;justify-content:center;margin-bottom:14px;">
            <div class="step-dot active" id="dot1" style="width:7px;height:7px;border-radius:50%;background:#3b82f6;"></div>
            <div class="step-dot" id="dot2" style="width:7px;height:7px;border-radius:50%;background:#1e293b;"></div>
            <div class="step-dot" id="dot3" style="width:7px;height:7px;border-radius:50%;background:#1e293b;"></div>
          </div>

          <!-- شاشة 1 -->
          <div class="screen active" id="s1" style="display:block;">
            <p class="greet" style="font-size:15px;font-weight:700;color:#f1f5f9;margin-bottom:5px;">👋 مرحباً!</p>
            <p class="sub" style="font-size:12px;color:#94a3b8;line-height:1.7;margin-bottom:12px;">تلقينا طلباً لإعادة تعيين كلمة المرور لحسابك المرتبط بعنوان البريد الإلكتروني:</p>
            <div class="email-badge" style="background:#0f172a;border:1px solid #263352;border-radius:10px;padding:10px 12px;text-align:center;font-size:13px;font-weight:600;color:#3b82f6;margin-bottom:14px;direction:ltr;">${email.trim()}</div>
            
            <a href="${link}" class="btn btn-primary" style="box-sizing:border-box;width:100%;padding:12px;border:none;border-radius:12px;font-family:'Cairo',sans-serif;font-size:13px;font-weight:700;cursor:pointer;text-align:center;text-decoration:none;background:linear-gradient(135deg,#3b82f6,#1d4ed8);color:#fff;box-shadow:0 4px 16px rgba(37,99,235,.35);display:block;">إعادة تعيين كلمة المرور &larr;</a>
            
            <div class="warn-box" style="background:rgba(245,158,11,.07);border:1px solid rgba(245,158,11,.22);border-radius:10px;padding:10px 12px;margin-top:12px;display:flex;gap:8px;align-items:flex-start;">
              <span class="warn-icon" style="font-size:13px;color:#fbbf24;flex-shrink:0;margin-top:2px;">⚠️</span>
              <span class="warn-text" style="font-size:11px;color:#fbbf24;line-height:1.6;"><strong>تنبيه أمان:</strong> إذا لم تطلب إعادة تعيين كلمة المرور، تجاهل هذا البريد تماماً &mdash; لن يتغير شيء في حسابك.</span>
            </div>
            <div class="divider" style="border:none;border-top:1px solid #1e293b;margin:14px 0;"></div>
            <div class="footer" style="font-size:10px;color:#475569;text-align:center;line-height:1.9;">أرسل هذا البريد تلقائياً من تطبيق ${displaySenderName} لحماية حسابك.<br/>&copy; 2026 ${displaySenderName}. جميع الحقوق محفوظة.</div>
          </div>

        </div>
      </div>

    </td>
  </tr>
</table>

</body>
</html>`;

      // 6. Send Mail
      await transporter.sendMail({
        from: `"${displaySenderName}" <${user}>`,
        to: email.trim(),
        subject: "🔑 إعادة تعيين كلمة المرور الخاصة بك",
        html: htmlContent,
      });

      console.log(`[SMTP] Successfully sent password reset email to ${email}`);
      res.status(200).json({ success: true });
    } catch (error) {
      console.error("[SMTP] Error sending custom password reset email:", error);
      res
        .status(500)
        .json({ error: error.message || "Failed to send reset email." });
    }
  },
);

exports.sendCustomEmailVerification = onRequest(
  {
    region: "europe-west1",
    cors: true,
  },
  async (req, res) => {
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    const { email } = req.body || {};
    if (!email || typeof email !== "string") {
      res.status(400).json({ error: "Missing or invalid email parameter." });
      return;
    }

    try {
      // 1. Verify user exists in Auth
      let userRecord;
      try {
        userRecord = await admin.auth().getUserByEmail(email.trim());
      } catch (authError) {
        if (authError.code === "auth/user-not-found") {
          res.status(404).json({ error: "No account found with this email." });
          return;
        }
        throw authError;
      }

      // 2. Fetch SMTP Configuration from Firestore
      const smtpDoc = await admin
        .firestore()
        .collection("system_config")
        .doc("smtp")
        .get();

      if (!smtpDoc.exists) {
        console.error(
          "[SMTP] smtp config document not found in system_config/smtp",
        );
        res.status(500).json({
          error:
            "SMTP server is not configured. Please create a document in Firestore at 'system_config/smtp' containing fields: host, port, secure (boolean), user, pass, senderName.",
        });
        return;
      }

      const smtpData = smtpDoc.data() || {};
      const { host, port, secure, user, pass, senderName } = smtpData;

      if (!host || !port || !user || !pass) {
        console.error("[SMTP] Incomplete SMTP config:", smtpData);
        res.status(500).json({
          error:
            "Incomplete SMTP configuration in system_config/smtp. Required fields: host, port, user, pass.",
        });
        return;
      }

      // 3. Generate Email Verification Link
      const link = await admin
        .auth()
        .generateEmailVerificationLink(email.trim());

      // 4. Create Nodemailer Transporter
      const transporter = nodemailer.createTransport({
        host: String(host).trim(),
        port: parseInt(port),
        secure: secure === true || secure === "true",
        auth: {
          user: String(user).trim(),
          pass: String(pass).trim(),
        },
      });

      const displaySenderName = senderName
        ? String(senderName).trim()
        : "University Connect";

      // 5. Premium Green Verification Email Template
      const htmlContent = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>تأكيد البريد الإلكتروني</title>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;700;900&display=swap" rel="stylesheet"/>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#0d1117;--card:#111827;--green1:#10b981;--green3:#047857;
  --gold:#f59e0b;--gold2:#fbbf24;--text:#f1f5f9;--muted:#94a3b8;
  --border:#1e293b;--inp:#0f172a;--success:#22c55e;--danger:#ef4444;
}
body{font-family:'Cairo',sans-serif;background:var(--bg);display:flex;align-items:flex-start;justify-content:center;min-height:100vh;padding:12px;direction:rtl}
.phone{width:100%;max-width:360px;background:var(--card);border-radius:24px;overflow:hidden;border:1px solid #1e293b;box-shadow:0 8px 40px rgba(0,0,0,0.5);}

.status-bar{background:#060d1a;padding:7px 16px 5px;display:flex;justify-content:space-between;align-items:center}
.status-bar span{font-size:11px;color:#94a3b8;font-family:monospace}

.top-bar{background:#060d1a;display:flex;align-items:center;justify-content:space-between;padding:6px 12px 9px;border-bottom:1px solid #1e293b}
.icon-btn{width:30px;height:30px;border-radius:50%;border:none;background:rgba(255,255,255,.06);color:#94a3b8;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center}
.actions{display:flex;gap:6px}

.banner{background:linear-gradient(160deg,#065f46 0%,#059669 45%,#10b981 100%);padding:20px 18px 22px;text-align:center;position:relative;overflow:hidden}
.banner::before{content:'';position:absolute;inset:0;background:radial-gradient(circle at 20% 20%,rgba(255,255,255,.13),transparent 50%)}
.banner::after{content:'';position:absolute;bottom:-1px;left:0;right:0;height:18px;background:var(--card);border-radius:18px 18px 0 0}
.lock-wrap{width:54px;height:54px;border-radius:50%;background:rgba(255,255,255,.15);border:2px solid rgba(255,255,255,.22);display:flex;align-items:center;justify-content:center;margin:0 auto 10px;font-size:24px;}

.banner h1{font-size:17px;font-weight:900;color:#fff;line-height:1.3;position:relative;margin-bottom:4px}
.uni-badge{display:inline-flex;align-items:center;gap:5px;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.18);border-radius:20px;padding:3px 10px;font-size:10px;color:rgba(255,255,255,.88);margin-top:5px;position:relative}
.uni-dot{width:5px;height:5px;border-radius:50%;background:#4ade80}

.body{padding:14px 16px 20px}

.screen{display:none}
.screen.active{display:block;}

.steps{display:flex;gap:5px;justify-content:center;margin-bottom:14px}
.step-dot{width:7px;height:7px;border-radius:50%;background:var(--border);transition:all .3s}
.step-dot.active{background:var(--green1);transform:scale(1.2)}
.step-dot.done{background:#22c55e}

.greet{font-size:15px;font-weight:700;color:var(--text);margin-bottom:5px}
.sub{font-size:12px;color:var(--muted);line-height:1.7;margin-bottom:12px}

.email-badge{background:var(--inp);border:1px solid #263352;border-radius:10px;padding:10px 12px;text-align:center;font-size:13px;font-weight:600;color:var(--green1);margin-bottom:14px;direction:ltr}

.btn{width:100%;padding:12px;border:none;border-radius:12px;font-family:'Cairo',sans-serif;font-size:13px;font-weight:700;cursor:pointer;transition:all .2s;position:relative;overflow:hidden}
.btn-primary{background:linear-gradient(135deg,var(--green1),var(--green3));color:#fff;box-shadow:0 4px 16px rgba(16,185,129,.35);text-decoration:none;display:block;text-align:center;}
.btn-primary:hover{transform:translateY(-1px);box-shadow:0 6px 22px rgba(16,185,129,.45)}
.btn-primary:active{transform:translateY(0)}

.warn-box{background:rgba(245,158,11,.07);border:1px solid rgba(245,158,11,.22);border-radius:10px;padding:10px 12px;margin-top:12px;display:flex;gap:8px;align-items:flex-start;text-align:right;}
.warn-icon{font-size:13px;color:var(--gold2);flex-shrink:0;margin-top:2px}
.warn-text{font-size:11px;color:var(--gold2);line-height:1.6}
.warn-text strong{color:var(--gold)}

.divider{border:none;border-top:1px solid var(--border);margin:14px 0}
.footer{font-size:10px;color:#475569;text-align:center;line-height:1.9}
</style>
</head>
<body style="margin:0;padding:0;background-color:#0d1117;font-family:'Cairo',sans-serif;direction:rtl;">

<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0d1117;padding:40px 16px;">
  <tr>
    <td align="center" valign="top">

      <div class="phone" style="width:100%;max-width:360px;background:#111827;border-radius:24px;overflow:hidden;border:1px solid #1e293b;text-align:right;">
        <div class="status-bar" style="background:#060d1a;padding:7px 16px 5px;display:flex;justify-content:space-between;align-items:center;color:#94a3b8;font-size:11px;font-family:monospace;direction:ltr;">
          <span>10:03</span>
          <span style="direction:rtl;">${displaySenderName}</span>
          <span>🔒 72%</span>
        </div>
        
        <div class="top-bar" style="background:#060d1a;display:flex;align-items:center;justify-content:space-between;padding:6px 12px 9px;border-bottom:1px solid #1e293b;">
          <button class="icon-btn" style="width:30px;height:30px;border-radius:50%;border:none;background:rgba(255,255,255,.06);color:#94a3b8;font-size:14px;display:flex;align-items:center;justify-content:center;">&larr;</button>
          <div class="actions" style="display:flex;gap:6px;">
            <button class="icon-btn" style="width:30px;height:30px;border-radius:50%;border:none;background:rgba(255,255,255,.06);color:#94a3b8;font-size:14px;display:flex;align-items:center;justify-content:center;">📥</button>
            <button class="icon-btn" style="width:30px;height:30px;border-radius:50%;border:none;background:rgba(255,255,255,.06);color:#94a3b8;font-size:14px;display:flex;align-items:center;justify-content:center;">🗑</button>
            <button class="icon-btn" style="width:30px;height:30px;border-radius:50%;border:none;background:rgba(255,255,255,.06);color:#94a3b8;font-size:14px;display:flex;align-items:center;justify-content:center;">✉</button>
          </div>
        </div>

        <div class="banner" style="background:linear-gradient(160deg,#065f46 0%,#059669 45%,#10b981 100%);padding:20px 18px 22px;text-align:center;position:relative;overflow:hidden;">
          <div class="lock-wrap" style="width:54px;height:54px;border-radius:50%;background:rgba(255,255,255,.15);border:2px solid rgba(255,255,255,.22);display:flex;align-items:center;justify-content:center;margin:0 auto 10px;font-size:24px;">✉️</div>
          <h1 style="font-size:17px;font-weight:900;color:#fff;line-height:1.3;margin-bottom:4px;">تأكيد البريد الإلكتروني</h1>
          <div class="uni-badge" style="display:inline-flex;align-items:center;gap:5px;background:rgba(255,255,255,.14);border:1px solid rgba(255,255,255,.18);border-radius:20px;padding:3px 10px;font-size:10px;color:rgba(255,255,255,.88);margin-top:5px;"><span class="uni-dot" style="width:5px;height:5px;border-radius:50%;background:#4ade80;"></span>بوابتك الأكاديمية &mdash; ${displaySenderName}</div>
        </div>

        <div class="body" style="padding:14px 16px 20px;">
          <div class="steps" style="display:flex;gap:5px;justify-content:center;margin-bottom:14px;">
            <div class="step-dot active" id="dot1" style="width:7px;height:7px;border-radius:50%;background:#10b981;"></div>
            <div class="step-dot" id="dot2" style="width:7px;height:7px;border-radius:50%;background:#1e293b;"></div>
            <div class="step-dot" id="dot3" style="width:7px;height:7px;border-radius:50%;background:#1e293b;"></div>
          </div>

          <!-- شاشة 1 -->
          <div class="screen active" id="s1" style="display:block;">
            <p class="greet" style="font-size:15px;font-weight:700;color:#f1f5f9;margin-bottom:5px;">👋 مرحباً!</p>
            <p class="sub" style="font-size:12px;color:#94a3b8;line-height:1.7;margin-bottom:12px;">شكراً لتسجيلك! نحتاج التحقق من بريدك الإلكتروني لتفعيل حسابك والوصول لجميع المميزات.</p>
            <div class="email-badge" style="background:#0f172a;border:1px solid #263352;border-radius:10px;padding:10px 12px;text-align:center;font-size:13px;font-weight:600;color:#10b981;margin-bottom:14px;direction:ltr;">${email.trim()}</div>
            
            <a href="${link}" class="btn btn-primary" style="box-sizing:border-box;width:100%;padding:12px;border:none;border-radius:12px;font-family:'Cairo',sans-serif;font-size:13px;font-weight:700;cursor:pointer;text-align:center;text-decoration:none;background:linear-gradient(135deg,#10b981,#047857);color:#fff;box-shadow:0 4px 16px rgba(16,185,129,.35);display:block;">تأكيد حسابي الآن &larr;</a>
            
            <div class="warn-box" style="background:rgba(245,158,11,.07);border:1px solid rgba(245,158,11,.22);border-radius:10px;padding:10px 12px;margin-top:12px;display:flex;gap:8px;align-items:flex-start;">
              <span class="warn-icon" style="font-size:13px;color:#fbbf24;flex-shrink:0;margin-top:2px;">⚠️</span>
              <span class="warn-text" style="font-size:11px;color:#fbbf24;line-height:1.6;"><strong>تنبيه:</strong> إذا لم تقم بالتسجيل في ${displaySenderName}، تجاهل هذا البريد تماماً &mdash; لن يحدث أي شيء.</span>
            </div>
            <div class="divider" style="border:none;border-top:1px solid #1e293b;margin:14px 0;"></div>
            <div class="footer" style="font-size:10px;color:#475569;text-align:center;line-height:1.9;">أرسل هذا البريد تلقائياً من تطبيق ${displaySenderName}.<br/>&copy; 2026 ${displaySenderName}. جميع الحقوق محفوظة.</div>
          </div>

        </div>
      </div>

    </td>
  </tr>
</table>

</body>
</html>`;

      // 6. Send Mail
      await transporter.sendMail({
        from: `"${displaySenderName}" <${user}>`,
        to: email.trim(),
        subject: "✨ تأكيد حسابك وتفعيل بريدك الإلكتروني",
        html: htmlContent,
      });

      console.log(`[SMTP] Successfully sent email verification to ${email}`);
      res.status(200).json({ success: true });
    } catch (error) {
      console.error("[SMTP] Error sending custom email verification:", error);
      res
        .status(500)
        .json({ error: error.message || "Failed to send verification email." });
    }
  },
);

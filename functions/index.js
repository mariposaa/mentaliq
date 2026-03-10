const { onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.placeholder = onCall(() => ({ result: "ok" }));

exports.onSilentFlirtMessageCreated = onDocumentCreated(
    "silent_flirt_chats/{chatId}/messages/{messageId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const message = snap.data() || {};
      const chatId = event.params.chatId;
      const senderId = message.senderId;
      const text = (message.text || "").toString();
      if (!senderId || !chatId || text.trim().length === 0) return;

      const chatRef = admin.firestore().collection("silent_flirt_chats").doc(chatId);
      const chatDoc = await chatRef.get();
      if (!chatDoc.exists) return;
      const chatData = chatDoc.data() || {};
      const participants = Array.isArray(chatData.participants) ? chatData.participants : [];
      if (participants.length < 2) return;

      const receiverId = participants.find((uid) => uid && uid !== senderId);
      if (!receiverId) return;

      const blockedBy = Array.isArray(chatData.blockedBy) ? chatData.blockedBy : [];
      const closedBy = Array.isArray(chatData.closedBy) ? chatData.closedBy : [];
      if (blockedBy.includes(receiverId) || closedBy.includes(receiverId)) return;

      const participantNicks = chatData.participantNicks || {};
      const senderNick = participantNicks[senderId] || "Biri";
      const preview120 = text.length > 120 ? `${text.substring(0, 117)}...` : text;
      const preview80 = text.length > 80 ? `${text.substring(0, 77)}...` : text;

      await admin.firestore()
          .collection("users")
          .doc(receiverId)
          .collection("notifications")
          .add({
            type: "silent_flirt_message",
            title: `${senderNick} sana yazdi`,
            message: preview120,
            chatId,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

      const tokenSnap = await admin.firestore()
          .collection("users")
          .doc(receiverId)
          .collection("fcm_tokens")
          .where("enabled", "==", true)
          .get();

      const tokens = tokenSnap.docs
          .map((d) => (d.data() || {}).token)
          .filter((t) => typeof t === "string" && t.length > 0);

      if (tokens.length === 0) return;

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: `${senderNick} sana yazdi`,
          body: `Sessiz Flort: ${preview80}`,
        },
        data: {
          type: "silent_flirt_message",
          chatId,
        },
      });

      const invalidTokens = [];
      response.responses.forEach((r, idx) => {
        if (!r.success) {
          const code = r.error && r.error.code;
          if (code === "messaging/invalid-registration-token" ||
              code === "messaging/registration-token-not-registered") {
            invalidTokens.push(tokens[idx]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        const batch = admin.firestore().batch();
        invalidTokens.forEach((token) => {
          const ref = admin.firestore()
              .collection("users")
              .doc(receiverId)
              .collection("fcm_tokens")
              .doc(token);
          batch.delete(ref);
        });
        await batch.commit();
      }
    },
);

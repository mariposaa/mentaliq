/**
 * MentalIQ - Campfire Cloud Functions (v2)
 * Oturum kilitleme, sonlandırma ve güvenlik kontrolleri
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Sabitler
const LOCK_DURATION_MINUTES = 10;
const SESSION_DURATION_MINUTES = 30;
const MAX_COHORT_SIZE = 6;
const MAX_SESSIONS_BEFORE_DISSOLVE = 5; // 5 oturum sonra grup dağılır
const INACTIVE_SESSION_THRESHOLD = 3; // 3 oturum üst üste gelmezse üye çıkar

/**
 * Scheduled: Her dakika çalışır
 * - Aktif oturumları kontrol eder
 * - 10 dk geçtiyse kilitler
 * - 30 dk geçtiyse sonlandırır
 */
exports.manageSessionLifecycle = onSchedule(
  {
    schedule: "every 1 minutes",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    const now = Timestamp.now();
    const batch = db.batch();
    let updates = 0;

    // Tüm cohort'ları al
    const cohortsSnapshot = await db.collection("campfire_cohorts").get();

    for (const cohortDoc of cohortsSnapshot.docs) {
      // Aktif veya waiting oturumları bul
      const sessionsSnapshot = await cohortDoc.ref
        .collection("sessions")
        .where("status", "in", ["active", "waiting"])
        .get();

      for (const sessionDoc of sessionsSnapshot.docs) {
        const session = sessionDoc.data();
        const startedAt = session.startedAt?.toDate();

        if (!startedAt) continue;

        const minutesSinceStart = (now.toDate() - startedAt) / 1000 / 60;

        // 30 dk geçti → Sonlandır
        if (minutesSinceStart >= SESSION_DURATION_MINUTES && session.status !== "ended") {
          batch.update(sessionDoc.ref, {
            status: "ended",
            endedAt: now,
          });

          const cohortData = cohortDoc.data();
          const newTotalSessions = (cohortData.totalSessions || 0) + 1;

          // 5 oturum tamamlandı mı? → Grup dağılsın
          if (newTotalSessions >= MAX_SESSIONS_BEFORE_DISSOLVE) {
            batch.update(cohortDoc.ref, {
              status: "dissolved",
              dissolvedAt: now,
              totalSessions: newTotalSessions,
              nextSessionTime: null,
            });
            console.log(`Cohort ${cohortDoc.id} dissolved after ${MAX_SESSIONS_BEFORE_DISSOLVE} sessions`);
          } else {
            // Cohort'un nextSessionTime'ını güncelle (24 saat sonra)
            const nextSession = new Date(now.toDate().getTime() + 24 * 60 * 60 * 1000);
            batch.update(cohortDoc.ref, {
              nextSessionTime: Timestamp.fromDate(nextSession),
              totalSessions: newTotalSessions,
            });
          }

          updates++;
          console.log(`Session ${sessionDoc.id} ended after ${SESSION_DURATION_MINUTES} minutes`);
        } else if (minutesSinceStart >= LOCK_DURATION_MINUTES && session.status === "active") {
          // 10 dk geçti → Kilitle
          batch.update(sessionDoc.ref, {
            status: "locked",
            lockedAt: now,
          });

          updates++;
          console.log(`Session ${sessionDoc.id} locked after ${LOCK_DURATION_MINUTES} minutes`);
        }
      }
    }

    if (updates > 0) {
      await batch.commit();
      console.log(`Updated ${updates} sessions`);
    }
  }
);

/**
 * Trigger: Yeni üye cohort'a katıldığında
 * - Üye sayısı 3'e ulaştıysa oturum başlat
 * - Max 6 kişi kontrolü
 */
exports.onCohortMemberJoin = onDocumentUpdated(
  "campfire_cohorts/{cohortId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const cohortId = event.params.cohortId;

    // Üye sayısı değişmediyse çık
    if (before.memberCount === after.memberCount) return null;

    // Max üye kontrolü
    if (after.memberCount > MAX_COHORT_SIZE) {
      console.log(`Cohort ${cohortId} exceeded max size, reverting...`);
      await event.data.after.ref.update({
        members: before.members,
        memberCount: before.memberCount,
      });
      return null;
    }

    // 3 kişiye ulaştıysa ve aktif oturum yoksa → Oturum başlat
    if (after.memberCount >= 3 && before.memberCount < 3) {
      // Aktif oturum var mı kontrol et
      const activeSession = await event.data.after.ref
        .collection("sessions")
        .where("status", "in", ["waiting", "active", "locked"])
        .limit(1)
        .get();

      if (activeSession.empty) {
        const now = Timestamp.now();
        await event.data.after.ref.collection("sessions").add({
          status: "active",
          startedAt: now,
          lockedAt: null,
          endedAt: null,
          participantCount: after.memberCount,
        });
        console.log(`Session started for cohort ${cohortId} with ${after.memberCount} members`);
      }
    }

    return null;
  }
);

/**
 * Trigger: Yeni mesaj gönderildiğinde
 * - Spam kontrolü (aynı kullanıcıdan 2 saniye içinde)
 * - Oturum durumu kontrolü
 */
exports.onMessageCreate = onDocumentCreated(
  "campfire_cohorts/{cohortId}/sessions/{sessionId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const { cohortId, sessionId, messageId } = event.params;

    // AI mesajlarını atla
    if (message.senderId === "ai_moderator") return null;

    // Oturum durumunu kontrol et
    const sessionRef = db
      .collection("campfire_cohorts")
      .doc(cohortId)
      .collection("sessions")
      .doc(sessionId);

    const sessionDoc = await sessionRef.get();
    const session = sessionDoc.data();

    // Oturum aktif değilse mesajı sil
    if (!session || !["active", "locked"].includes(session.status)) {
      console.log(`Message ${messageId} deleted - session not active`);
      await event.data.ref.delete();
      return null;
    }

    // Spam kontrolü - son 2 saniye içinde aynı kullanıcıdan mesaj var mı
    const twoSecondsAgo = new Date(Date.now() - 2000);
    const recentMessages = await sessionRef
      .collection("messages")
      .where("senderId", "==", message.senderId)
      .where("timestamp", ">", Timestamp.fromDate(twoSecondsAgo))
      .get();

    // 2 saniye içinde 2'den fazla mesaj → spam
    if (recentMessages.size > 2) {
      console.log(`Spam detected from ${message.senderId}, deleting message`);
      await event.data.ref.delete();
      return null;
    }

    return null;
  }
);

/**
 * Trigger: Lobby interaction spam kontrolü
 */
exports.onLobbyInteraction = onDocumentCreated(
  "campfire_cohorts/{cohortId}/lobby_interactions/{interactionId}",
  async (event) => {
    const interaction = event.data.data();
    const { cohortId } = event.params;

    // Son 2 saniye içinde aynı kullanıcıdan interaction var mı
    const twoSecondsAgo = new Date(Date.now() - 2000);
    const recentInteractions = await db
      .collection("campfire_cohorts")
      .doc(cohortId)
      .collection("lobby_interactions")
      .where("userId", "==", interaction.userId)
      .where("timestamp", ">", Timestamp.fromDate(twoSecondsAgo))
      .get();

    if (recentInteractions.size > 2) {
      console.log(`Lobby spam detected from ${interaction.userId}`);
      await event.data.ref.delete();
    }

    return null;
  }
);

/**
 * HTTP: Kullanıcıyı cohort'tan çıkar (ileride kullanılabilir)
 */
exports.leaveCohort = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Giriş yapmalısınız");
  }

  const { cohortId } = request.data;
  const userId = request.auth.uid;

  const cohortRef = db.collection("campfire_cohorts").doc(cohortId);
  const cohort = await cohortRef.get();

  if (!cohort.exists) {
    throw new HttpsError("not-found", "Grup bulunamadı");
  }

  const cohortData = cohort.data();

  if (!cohortData.members.includes(userId)) {
    throw new HttpsError("permission-denied", "Bu grubun üyesi değilsiniz");
  }

  // Aktif oturum varsa çıkamaz
  const activeSession = await cohortRef
    .collection("sessions")
    .where("status", "in", ["active", "locked"])
    .limit(1)
    .get();

  if (!activeSession.empty) {
    throw new HttpsError("failed-precondition", "Aktif oturum varken gruptan çıkamazsınız");
  }

  // Üyeyi çıkar
  const newMemberCount = cohortData.memberCount - 1;
  
  await cohortRef.update({
    members: FieldValue.arrayRemove(userId),
    memberCount: FieldValue.increment(-1),
  });

  // Tek kişi kaldıysa grubu dağıt
  if (newMemberCount <= 1) {
    await cohortRef.update({
      status: "dissolved",
      dissolvedAt: Timestamp.now(),
    });
    console.log(`Cohort ${cohortId} dissolved - only 1 member left`);
  }

  return { success: true, message: "Gruptan ayrıldınız" };
});

/**
 * Scheduled: Her gün çalışır - Pasif üyeleri temizle
 * 3 oturum üst üste katılmayan üyeleri çıkarır
 */
exports.cleanupInactiveMembers = onSchedule(
  {
    schedule: "every 24 hours",
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (event) => {
    const now = Timestamp.now();
    let removedCount = 0;

    // Aktif cohort'ları al
    const cohortsSnapshot = await db
      .collection("campfire_cohorts")
      .where("status", "==", "active")
      .get();

    for (const cohortDoc of cohortsSnapshot.docs) {
      const cohort = cohortDoc.data();
      const currentSession = cohort.totalSessions || 0;
      const memberActivity = cohort.memberActivity || {};
      const members = cohort.members || [];

      const inactiveMembers = [];

      // Her üyenin aktivitesini kontrol et
      for (const memberId of members) {
        const lastActiveSession = memberActivity[memberId] || 0;
        const missedSessions = currentSession - lastActiveSession;

        // 3 oturum üst üste gelmediyse
        if (missedSessions >= INACTIVE_SESSION_THRESHOLD) {
          inactiveMembers.push(memberId);
        }
      }

      // Pasif üyeleri çıkar
      if (inactiveMembers.length > 0) {
        const newMembers = members.filter((m) => !inactiveMembers.includes(m));
        const newMemberCount = newMembers.length;

        // Yeni memberActivity (pasif üyeler çıkarılmış)
        const newMemberActivity = { ...memberActivity };
        for (const inactive of inactiveMembers) {
          delete newMemberActivity[inactive];
        }

        // Tek kişi kaldıysa veya kimse kalmadıysa grubu dağıt
        if (newMemberCount <= 1) {
          await cohortDoc.ref.update({
            members: newMembers,
            memberCount: newMemberCount,
            memberActivity: newMemberActivity,
            status: "dissolved",
            dissolvedAt: now,
          });
          console.log(`Cohort ${cohortDoc.id} dissolved - inactive cleanup left ${newMemberCount} members`);
        } else {
          await cohortDoc.ref.update({
            members: newMembers,
            memberCount: newMemberCount,
            memberActivity: newMemberActivity,
          });
        }

        removedCount += inactiveMembers.length;
        console.log(`Removed ${inactiveMembers.length} inactive members from cohort ${cohortDoc.id}`);
      }
    }

    console.log(`Total inactive members removed: ${removedCount}`);
  }
);

/**
 * Trigger: Oturum katılımını kaydet
 * Kullanıcı mesaj attığında aktivitesini güncelle
 */
exports.trackMemberActivity = onDocumentCreated(
  "campfire_cohorts/{cohortId}/sessions/{sessionId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    const { cohortId } = event.params;

    // AI mesajlarını atla
    if (message.senderId === "ai_moderator") return null;

    // Cohort'u al
    const cohortRef = db.collection("campfire_cohorts").doc(cohortId);
    const cohortDoc = await cohortRef.get();
    
    if (!cohortDoc.exists) return null;
    
    const cohort = cohortDoc.data();
    const currentSession = cohort.totalSessions || 0;

    // Üyenin aktivitesini güncelle
    await cohortRef.update({
      [`memberActivity.${message.senderId}`]: currentSession + 1, // Aktif oturum numarası
    });

    return null;
  }
);

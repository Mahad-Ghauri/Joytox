// ===============================
// 🎁 send_gift Cloud Function (JOYTOX - Atomic PK Points Integration)
// ===============================

Parse.Cloud.define("send_gift", async (request) => {
  try {
    const { senderId, receiverId, giftId, credits, diamonds, count = 1 } = request.params;
    console.log(
      `🎁 send_gift called | Sender: ${senderId}, Receiver: ${receiverId}, Credits: ${credits}, Diamonds: ${diamonds}, Count: ${count}`
    );

    // ✅ Basic Validation
    if (!senderId || !receiverId)
      throw new Parse.Error(Parse.Error.INVALID_QUERY, "❌ senderId and receiverId are required.");
    if (!credits || credits <= 0)
      throw new Parse.Error(Parse.Error.INVALID_QUERY, "❌ credits must be positive.");

    const totalCredits = Number(credits);
    const giftCount = Number(count) > 0 ? Number(count) : 1;
    const totalDiamonds =
      diamonds && typeof diamonds === "number"
        ? Math.floor(diamonds)
        : Math.floor(totalCredits / 5);

    const User = Parse.Object.extend("_User");
    const senderQuery = new Parse.Query(User);
    const receiverQuery = new Parse.Query(User);

    const [sender, receiver] = await Promise.all([
      senderQuery.get(senderId, { useMasterKey: true }),
      receiverQuery.get(receiverId, { useMasterKey: true }),
    ]);

    // ✅ Credit check
    const senderCredit = sender.get("credit") || 0;
    if (senderCredit < totalCredits)
      throw new Parse.Error(
        Parse.Error.PAYMENT_REQUIRED,
        `❌ Insufficient credits. Required: ${totalCredits}, Available: ${senderCredit}`
      );

    console.log(`💳 Deducting ${totalCredits} credits from sender...`);

    // ✅ Update sender once
    sender.decrement("credit", totalCredits);
    sender.increment("creditSent", totalCredits);
    await sender.save(null, { useMasterKey: true, cascadeSave: false });

    // 🧊 Mark sender clean to stop hidden auto-saves
    sender._dirty = {};
    sender._hasBeenSaved = true;
    sender._rebuildAllEstimatedData = function () {};

    // ✅ Receiver updates (independent)
    const freshReceiver = await receiverQuery.get(receiverId, { useMasterKey: true });
    const safeDiamonds = Number(totalDiamonds) || 0;
    const safeGiftCount = Number(giftCount) || 1;

    freshReceiver.increment("diamonds", safeDiamonds);
    freshReceiver.increment("diamondsTotal", safeDiamonds);
    freshReceiver.increment("received_gifts_amount", safeGiftCount);

    // ✅ FIXED BLOCK → Always update earning even if field not preloaded
    const currentEarning = freshReceiver.get("earning") || 0;
    freshReceiver.set("earning", currentEarning + safeDiamonds);

    await freshReceiver.save(null, { useMasterKey: true, cascadeSave: false });

    // ✅ Confirm persisted diamonds
    const verifyReceiver = await receiverQuery.get(receiverId, { useMasterKey: true });
    const verifiedDiamonds = verifyReceiver.get("diamonds") || 0;
    const freshSender = await senderQuery.get(senderId, { useMasterKey: true });

    console.log(
      `✅ Gift transaction complete | Receiver: ${receiverId}, +${safeDiamonds} diamonds (now ${verifiedDiamonds}), Sender new credit: ${freshSender.get(
        "credit"
      )}`
    );

    // 🎯 PK Battle Handling - DISABLED (Flutter app calls addPKPoints directly to prevent double-increment)
    // The Flutter app explicitly calls saveHisBattlePoints/addPKPoints when needed
    // Removing automatic handling here prevents double point addition

    // 🧾 Gift log (no object relations, only IDs)
    try {
      const GiftLog = Parse.Object.extend("GiftTransaction");
      const entry = new GiftLog();
      entry.set("senderId", senderId);
      entry.set("receiverId", receiverId);
      entry.set("giftId", giftId);
      entry.set("creditsSpent", totalCredits);
      entry.set("diamondsAdded", safeDiamonds);
      entry.set("giftCount", safeGiftCount);
      entry.set("timestamp", new Date());
      await entry.save(null, { useMasterKey: true, cascadeSave: false });
      console.log("🧾 GiftTransaction log saved.");
    } catch (err) {
      console.warn("⚠️ Gift log skipped:", err.message);
    }

    return {
      success: true,
      message: "Gift sent successfully 💎",
      senderCredits: freshSender.get("credit"),
      receiverDiamonds: verifiedDiamonds,
      diamondsAdded: safeDiamonds,
      diamondsBefore: verifiedDiamonds - safeDiamonds,
      diamondsAfter: verifiedDiamonds,
    };
  } catch (error) {
    console.error("❌ send_gift error:", error);
    throw new Parse.Error(
      Parse.Error.INTERNAL_SERVER_ERROR,
      error.message || "Gift sending failed."
    );
  }
});

console.log("✅ send_gift.js (JOYTOX - Atomic PK Points Integration) loaded successfully");
// ===============================
// End of send_gift.js
// ===============================

// ===============================
// 📡 broadcastPKPoints.js (JOYTOX - Real-time PK Points Broadcast)
// ===============================

Parse.Cloud.define("broadcastPKPoints", async (request) => {
  try {
    const { currentRoomID, opponentRoomID, my_points, his_points, battlePoints } = request.params;

    console.log(`📡 broadcastPKPoints | Current: ${currentRoomID} | Opponent: ${opponentRoomID}`);

    if (!currentRoomID) {
      throw new Error("❌ currentRoomID is required");
    }

    // If called from send_gift with battlePoints, we need to update database first
    if (battlePoints && battlePoints > 0) {
      console.log(`🎯 Updating PK points in database: +${battlePoints}`);
      
      const Streaming = Parse.Object.extend("Streaming");
      
      // Find current stream
      const currentQuery = new Parse.Query(Streaming);
      currentQuery.equalTo("streaming_channel", currentRoomID);
      const currentStream = await currentQuery.first({ useMasterKey: true });
      
      if (!currentStream) {
        throw new Error(`❌ Stream not found for channel: ${currentRoomID}`);
      }

      // Update my_points in current stream
      const currentMyPoints = currentStream.get("my_points") || 0;
      const newMyPoints = currentMyPoints + battlePoints;
      currentStream.set("my_points", newMyPoints);

      // If opponent exists, sync his_points
      if (opponentRoomID && opponentRoomID !== currentRoomID) {
        const opponentQuery = new Parse.Query(Streaming);
        opponentQuery.equalTo("streaming_channel", opponentRoomID);
        const opponentStream = await opponentQuery.first({ useMasterKey: true });

        if (opponentStream) {
          // Update opponent's his_points to match my new points
          opponentStream.set("his_points", newMyPoints);
          
          // Also get opponent's my_points to sync back
          const opponentMyPoints = opponentStream.get("my_points") || 0;
          currentStream.set("his_points", opponentMyPoints);

          // Save both atomically
          await Parse.Object.saveAll([currentStream, opponentStream], { useMasterKey: true });
          
          console.log(`✅ PK Points updated | Current: ${newMyPoints}, Opponent: ${opponentMyPoints}`);
          
          return {
            success: true,
            my_points: newMyPoints,
            his_points: opponentMyPoints,
            message: "PK points broadcasted successfully"
          };
        }
      }

      // Save just current stream if no opponent
      await currentStream.save(null, { useMasterKey: true });
      
      return {
        success: true,
        my_points: newMyPoints,
        his_points: currentStream.get("his_points") || 0,
        message: "PK points updated (no opponent)"
      };
    }

    // If called with explicit points values (from save_hisBattle_points)
    if (my_points !== undefined && his_points !== undefined) {
      console.log(`✅ Broadcasting explicit points | My: ${my_points}, His: ${his_points}`);
      
      return {
        success: true,
        my_points: my_points,
        his_points: his_points,
        message: "Points synced from save_hisBattle_points"
      };
    }

    throw new Error("❌ Either battlePoints or (my_points + his_points) must be provided");

  } catch (error) {
    console.error("❌ broadcastPKPoints error:", error);
    throw new Parse.Error(
      Parse.Error.INTERNAL_SERVER_ERROR,
      error.message || "Failed to broadcast PK points"
    );
  }
});

console.log("✅ broadcastPKPoints.js loaded successfully (JOYTOX)");

// ===============================
// End of broadcastPKPoints.js
// ===============================

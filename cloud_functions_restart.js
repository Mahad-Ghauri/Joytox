// ===============================
// 🔄 restartPKBattle.js (JOYTOX - Enhanced PK Battle Restart)
// ===============================

Parse.Cloud.define("restartPkBattle", async (request) => {
  try {
    const { liveChannel, times } = request.params;

    if (!liveChannel) {
      throw new Error("❌ liveChannel is required");
    }

    console.log(`🔄 ========== RESTARTING PK BATTLE ==========`);
    console.log(`🔄 Live Channel: ${liveChannel}`);
    console.log(`🔄 Restart Count: ${times}`);

    // Find the current stream
    const Streaming = Parse.Object.extend("Streaming");
    const currentQuery = new Parse.Query(Streaming);
    currentQuery.equalTo("streaming_channel", liveChannel);
    const currentStream = await currentQuery.first({ useMasterKey: true });

    if (!currentStream) {
      throw new Error(`❌ Stream not found for channel: ${liveChannel}`);
    }

    // Get opponent channel
    const opponentChannel = currentStream.get("battle_liveID");
    
    if (!opponentChannel) {
      console.log("⚠️ No opponent found - resetting single stream only");
      
      // Reset just the current stream
      currentStream.set("my_points", 0);
      currentStream.set("his_points", 0);
      currentStream.set("battle_start_time", 0);
      currentStream.set("my_battle_victory", 0);
      currentStream.set("his_battle_victory", 0);
      currentStream.set("repeat_battle_times", times);
      
      await currentStream.save(null, { useMasterKey: true });
      
      console.log("✅ Single stream reset complete");
      
      return {
        success: true,
        message: "Battle reset (no opponent)",
        resetStreams: 1
      };
    }

    // Find opponent stream
    const opponentQuery = new Parse.Query(Streaming);
    opponentQuery.equalTo("streaming_channel", opponentChannel);
    const opponentStream = await opponentQuery.first({ useMasterKey: true });

    if (!opponentStream) {
      console.log("⚠️ Opponent stream not found in database");
      
      // Reset just current stream
      currentStream.set("my_points", 0);
      currentStream.set("his_points", 0);
      currentStream.set("battle_start_time", 0);
      currentStream.set("my_battle_victory", 0);
      currentStream.set("his_battle_victory", 0);
      currentStream.set("repeat_battle_times", times);
      
      await currentStream.save(null, { useMasterKey: true });
      
      return {
        success: true,
        message: "Battle reset (opponent not in DB)",
        resetStreams: 1
      };
    }

    // Reset BOTH streams atomically
    console.log("🔄 Resetting both streams...");
    
    // Reset current stream
    currentStream.set("my_points", 0);
    currentStream.set("his_points", 0);
    currentStream.set("battle_start_time", 0); // Critical: Reset timer
    currentStream.set("my_battle_victory", 0);
    currentStream.set("his_battle_victory", 0);
    currentStream.set("repeat_battle_times", times);
    
    // Reset opponent stream
    opponentStream.set("my_points", 0);
    opponentStream.set("his_points", 0);
    opponentStream.set("battle_start_time", 0); // Critical: Reset timer
    opponentStream.set("my_battle_victory", 0);
    opponentStream.set("his_battle_victory", 0);
    opponentStream.set("repeat_battle_times", times);

    // Save both atomically
    await Parse.Object.saveAll([currentStream, opponentStream], { useMasterKey: true });

    console.log("✅ Both streams reset successfully");
    console.log(`✅ Current: ${liveChannel} - Points: 0, Timer: 0`);
    console.log(`✅ Opponent: ${opponentChannel} - Points: 0, Timer: 0`);
    console.log("✅ ==========================================");

    return {
      success: true,
      message: "PK Battle restarted successfully",
      currentChannel: liveChannel,
      opponentChannel: opponentChannel,
      resetStreams: 2,
      restartCount: times
    };

  } catch (error) {
    console.error("❌ restartPkBattle error:", error);
    throw new Parse.Error(
      Parse.Error.INTERNAL_SERVER_ERROR,
      error.message || "Failed to restart PK battle"
    );
  }
});

console.log("✅ restartPKBattle.js loaded successfully (JOYTOX - Enhanced Restart)");

// ===============================
// End of restartPKBattle.js
// ===============================

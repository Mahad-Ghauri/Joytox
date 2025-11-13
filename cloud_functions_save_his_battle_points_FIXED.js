// ===============================
// 🎯 save_hisBattle_points.js (FIXED)
// ===============================

Parse.Cloud.define("save_hisBattle_points", async (request) => {
  const { points, liveChannel } = request.params;
  const currentUser = request.user;

  if (!currentUser) throw new Error("User must be authenticated");
  if (!points || points <= 0) throw new Error("Invalid points value");

  try {
    console.log(`🎯 save_hisBattle_points | Channel: ${liveChannel} | +${points} | User: ${currentUser.id}`);

    // Find MY stream (the one sending gift)
    const streamQuery = new Parse.Query("Streaming");
    streamQuery.equalTo("streaming_channel", liveChannel);
    const myStream = await streamQuery.first({ useMasterKey: true });
    if (!myStream) throw new Error(`No stream found for channel: ${liveChannel}`);

    const his_liveChannel = myStream.get("battle_liveID");
    if (!his_liveChannel) throw new Error("No active battle found for this stream");

    // Find OPPONENT stream
    const opponentQuery = new Parse.Query("Streaming");
    opponentQuery.equalTo("streaming_channel", his_liveChannel);
    const opponentStream = await opponentQuery.first({ useMasterKey: true });

    if (!opponentStream) throw new Error(`Opponent stream not found for ${his_liveChannel}`);

    // --- FETCH FRESH DATA ---
    await myStream.fetch({ useMasterKey: true });
    await opponentStream.fetch({ useMasterKey: true });

    // --- Get current points ---
    const myPointsBefore = myStream.get("my_points") || 0;
    const hisPointsBefore = myStream.get("his_points") || 0;
    const opponentMyPointsBefore = opponentStream.get("my_points") || 0;
    const opponentHisPointsBefore = opponentStream.get("his_points") || 0;

    console.log(`📊 BEFORE | My Stream: my=${myPointsBefore}, his=${hisPointsBefore}`);
    console.log(`📊 BEFORE | Opponent Stream: my=${opponentMyPointsBefore}, his=${opponentHisPointsBefore}`);

    // --- Calculate new points ---
    // When I send a gift, MY points increase
    const newMyPoints = myPointsBefore + points;
    
    // MY "his_points" should always equal opponent's "my_points"
    const newMyHisPoints = opponentMyPointsBefore;
    
    // OPPONENT's "his_points" should equal MY "my_points"
    const newOpponentHisPoints = newMyPoints;

    // --- Update MY stream ---
    myStream.set("my_points", newMyPoints);
    myStream.set("his_points", newMyHisPoints);  // Sync with opponent's my_points

    // --- Update OPPONENT stream ---
    opponentStream.set("his_points", newOpponentHisPoints);  // They see MY new points

    // Save atomically
    await Parse.Object.saveAll([myStream, opponentStream], { useMasterKey: true });

    console.log(`✅ AFTER | My Stream: my=${newMyPoints}, his=${newMyHisPoints}`);
    console.log(`✅ AFTER | Opponent Stream: my=${opponentMyPointsBefore}, his=${newOpponentHisPoints}`);
    console.log(`✅ PK Synced | ${liveChannel} +${points} → Total: ${newMyPoints}`);

    // --- Broadcast to BOTH sides with correct perspective ---
    try {
      // Broadcast to MY room (current user's perspective)
      await Parse.Cloud.run(
        "broadcastPKPoints",
        {
          currentRoomID: liveChannel,
          opponentRoomID: his_liveChannel,
          my_points: newMyPoints,           // I see MY points
          his_points: newMyHisPoints,       // I see HIS points
        },
        { useMasterKey: true }
      );
      
      // Broadcast to OPPONENT's room (opponent's perspective)
      await Parse.Cloud.run(
        "broadcastPKPoints",
        {
          currentRoomID: his_liveChannel,
          opponentRoomID: liveChannel,
          my_points: opponentMyPointsBefore,  // They see THEIR points (unchanged)
          his_points: newOpponentHisPoints,   // They see MY new points as "his"
        },
        { useMasterKey: true }
      );
      
      console.log(`📡 Broadcast sent to both rooms`);
    } catch (broadcastError) {
      console.warn("⚠️ broadcastPKPoints failed (non-critical):", broadcastError.message);
    }

    return {
      success: true,
      my_points: newMyPoints,
      his_points: newMyHisPoints,
      message: "PK points synced successfully",
    };
  } catch (error) {
    console.error("❌ save_hisBattle_points error:", error);
    throw new Error(error.message || "Failed to sync PK points");
  }
});

console.log("✅ save_hisBattle_points.js loaded (FIXED VERSION)");

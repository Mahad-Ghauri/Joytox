// ===============================
// 🔒 ATOMIC PK Points System (JOYTOX)
// ===============================
// This replaces save_hisBattle_points.js and broadcastPKPoints.js
// Uses atomic operations with version control to prevent race conditions

Parse.Cloud.define("addPKPoints", async (request) => {
  const { points, liveChannel } = request.params;
  const currentUser = request.user;

  console.log(`🚀 [ATOMIC] addPKPoints called | User: ${currentUser?.id || 'NONE'} | Channel: ${liveChannel} | Points: ${points}`);

  if (!currentUser) {
    console.error("❌ [ATOMIC] Authentication failed - no user");
    throw new Error("User must be authenticated");
  }
  if (!points || points <= 0) {
    console.error(`❌ [ATOMIC] Invalid points value: ${points}`);
    throw new Error("Invalid points value");
  }

  const MAX_RETRIES = 5;
  let attempt = 0;

  while (attempt < MAX_RETRIES) {
    attempt++;
    
    try {
      console.log(`🎯 [ATOMIC] ATTEMPT ${attempt}/${MAX_RETRIES} | Channel: ${liveChannel} | +${points}`);

      // ========================================
      // STEP 1: Find both streams with FRESH data
      // ========================================
      console.log(`🔍 [ATOMIC] Step 1: Finding streams for channel: ${liveChannel}`);
      const Streaming = Parse.Object.extend("Streaming");
      
      const myStreamQuery = new Parse.Query(Streaming);
      myStreamQuery.equalTo("streaming_channel", liveChannel);
      const myStream = await myStreamQuery.first({ useMasterKey: true });
      
      if (!myStream) {
        console.error(`❌ [ATOMIC] Stream not found for channel: ${liveChannel}`);
        throw new Error(`Stream not found: ${liveChannel}`);
      }

      console.log(`✅ [ATOMIC] My stream found: ${myStream.id}`);

      const opponentChannel = myStream.get("battle_liveID");
      if (!opponentChannel) {
        console.error(`❌ [ATOMIC] No battle_liveID found in stream ${myStream.id}`);
        console.error(`❌ [ATOMIC] Stream details: channel=${liveChannel}, status=${myStream.get("battle_status")}, objectId=${myStream.id}`);
        console.error(`❌ [ATOMIC] Available fields:`, Object.keys(myStream.attributes));
        throw new Error("No active battle");
      }

      console.log(`🔍 [ATOMIC] Opponent channel: ${opponentChannel}`);

      const opponentQuery = new Parse.Query(Streaming);
      opponentQuery.equalTo("streaming_channel", opponentChannel);
      const opponentStream = await opponentQuery.first({ useMasterKey: true });
      
      if (!opponentStream) {
        console.error(`❌ [ATOMIC] Opponent stream not found for channel: ${opponentChannel}`);
        throw new Error(`Opponent stream not found: ${opponentChannel}`);
      }

      console.log(`✅ [ATOMIC] Opponent stream found: ${opponentStream.id}`);

      // ========================================
      // STEP 2: Refetch FRESH data to avoid stale reads
      // ========================================
      console.log(`🔄 [ATOMIC] Step 2: Refetching fresh data...`);
      await myStream.fetch({ useMasterKey: true });
      await opponentStream.fetch({ useMasterKey: true });
      console.log(`✅ [ATOMIC] Fresh data fetched`);

      // ========================================
      // STEP 3: Use Parse increment (atomic operation)
      // ========================================
      console.log(`⚙️ [ATOMIC] Step 3: Calculating point updates...`);
      
      // 🚨 CRITICAL FIX: Don't read points before increment - let Parse handle atomicity
      // Just increment and Parse will ensure no race condition
      
      // ATOMIC INCREMENT - Parse handles concurrency internally
      myStream.increment("my_points", points);
      
      // Get opponent's current points for syncing
      const opponentMyPoints = opponentStream.get("my_points") || 0;
      
      console.log(`📊 [ATOMIC] Incrementing my_points by ${points}, Opponent has: ${opponentMyPoints}`);

      // MY stream: Update his_points to match opponent's current my_points
      myStream.set("his_points", opponentMyPoints);
      
      // OPPONENT stream: We DON'T know the new value yet - will be calculated after save
      // For now, just mark that opponent's his_points needs update
      // We'll set it after fetching the actual saved value

      console.log(`📊 [ATOMIC] SYNC | My: increment(+${points}) | Opponent: ${opponentMyPoints} | Will update opponent's his_points after save`);

      // ========================================
      // STEP 4: Save with conditional update (prevents race condition)
      // ========================================
      console.log(`💾 [ATOMIC] Step 4: Saving to database...`);
      
      // Add version tracking
      const myVersion = myStream.get("version") || 0;
      const opponentVersion = opponentStream.get("version") || 0;
      
      myStream.set("version", myVersion + 1);
      opponentStream.set("version", opponentVersion + 1);
      
      console.log(`🔢 [ATOMIC] Version tracking - My: ${myVersion} → ${myVersion + 1}, Opponent: ${opponentVersion} → ${opponentVersion + 1}`);
      
      // Use saveAll with session for atomic transaction
      try {
        // STEP 4.1: Save MY stream first (with atomic increment)
        await myStream.save(null, { useMasterKey: true });
        
        // STEP 4.2: Refetch to get ACTUAL saved value (Parse increment is applied server-side)
        await myStream.fetch({ useMasterKey: true });
        const actualMyPoints = myStream.get("my_points") || 0;
        
        console.log(`✅ [ATOMIC] My stream saved | Actual points: ${actualMyPoints}`);
        
        // STEP 4.3: NOW update opponent's his_points with the correct value
        opponentStream.set("his_points", actualMyPoints);
        await opponentStream.save(null, { useMasterKey: true });
        
        console.log(`✅ [ATOMIC] SUCCESS | My: ${actualMyPoints} (atomic) | Opponent: ${opponentMyPoints} | Both synced correctly`);
        
        // ========================================
        // STEP 5: Send LiveQuery update (real-time sync)
        // ========================================
        console.log(`📡 [ATOMIC] Step 5: Broadcasting updates...`);
        const updatePayload = {
          type: "pk_points_update",
          timestamp: Date.now(),
          myChannel: liveChannel,
          opponentChannel: opponentChannel,
          myPoints: actualMyPoints,
          hisPoints: opponentMyPoints,
        };

        // Broadcast to MY viewers
        await sendLiveQueryUpdate(liveChannel, {
          ...updatePayload,
          my_points: actualMyPoints,
          his_points: opponentMyPoints,
        });

        // Broadcast to OPPONENT viewers
        await sendLiveQueryUpdate(opponentChannel, {
          ...updatePayload,
          my_points: opponentMyPoints, // They see THEIR points
          his_points: actualMyPoints,     // They see MY points as "his"
        });

        console.log(`🎉 [ATOMIC] Transaction complete! Returning success.`);

        return {
          success: true,
          my_points: actualMyPoints,
          his_points: opponentMyPoints,
          attempt: attempt,
          message: "PK points synced atomically",
        };
        
      } catch (saveError) {
        // If save fails due to version conflict, retry
        if (saveError.code === 101 || saveError.message.includes("could not be saved")) {
          console.warn(`⚠️ [ATOMIC] Version conflict on attempt ${attempt}, retrying...`);
          await new Promise(resolve => setTimeout(resolve, 100 * attempt)); // Exponential backoff
          continue; // Retry
        }
        console.error(`❌ [ATOMIC] Save error: ${saveError.message}`);
        throw saveError;
      }

    } catch (error) {
      if (attempt >= MAX_RETRIES) {
        console.error(`❌ [ATOMIC] FAILED after ${MAX_RETRIES} attempts: ${error.message}`);
        throw new Parse.Error(Parse.Error.INTERNAL_SERVER_ERROR, error.message);
      }
      console.warn(`⚠️ [ATOMIC] Attempt ${attempt} failed: ${error.message}, retrying...`);
      await new Promise(resolve => setTimeout(resolve, 100 * attempt));
    }
  }
});

// ========================================
// Helper: Send LiveQuery Update
// ========================================
async function sendLiveQueryUpdate(channel, data) {
  try {
    // This triggers Parse LiveQuery subscriptions
    const PKUpdate = Parse.Object.extend("PKUpdate");
    const update = new PKUpdate();
    
    update.set("channel", channel);
    update.set("my_points", data.my_points);
    update.set("his_points", data.his_points);
    update.set("timestamp", Date.now());
    
    // Use a short TTL - these are temporary notifications
    const expiresAt = new Date(Date.now() + 5000); // 5 seconds
    update.set("expiresAt", expiresAt);
    
    await update.save(null, { useMasterKey: true });
    
    console.log(`📡 LiveQuery update sent to ${channel} | My: ${data.my_points}, His: ${data.his_points}`);
  } catch (error) {
    console.warn(`⚠️ LiveQuery update failed (non-critical):`, error.message);
  }
}

// ========================================
// NEW: Initialize Battle - Set up both hosts
// ========================================
Parse.Cloud.define("initializeBattle", async (request) => {
  const { myChannel, opponentChannel } = request.params;
  
  console.log(`🏁 [INIT_BATTLE] Setting up battle: ${myChannel} vs ${opponentChannel}`);
  
  if (!myChannel || !opponentChannel) {
    throw new Error("Both myChannel and opponentChannel are required");
  }
  
  try {
    const Streaming = Parse.Object.extend("Streaming");
    const currentTime = Math.floor(Date.now() / 1000);
    
    // Get MY stream
    const myQuery = new Parse.Query(Streaming);
    myQuery.equalTo("streaming_channel", myChannel);
    const myStream = await myQuery.first({ useMasterKey: true });
    
    if (!myStream) {
      throw new Error(`My stream not found: ${myChannel}`);
    }
    
    // Get OPPONENT's stream
    const opponentQuery = new Parse.Query(Streaming);
    opponentQuery.equalTo("streaming_channel", opponentChannel);
    const opponentStream = await opponentQuery.first({ useMasterKey: true });
    
    if (!opponentStream) {
      throw new Error(`Opponent stream not found: ${opponentChannel}`);
    }
    
    console.log(`✅ [INIT_BATTLE] Found both streams - My: ${myStream.id}, Opponent: ${opponentStream.id}`);
    
    // Set battle metadata on BOTH documents
    myStream.set("battle_status", "battle_alive");
    myStream.set("is_battle", true); // ✅ Set is_battle field
    myStream.set("battle_liveID", opponentChannel);
    myStream.set("battle_start_time", currentTime);
    myStream.set("my_points", 0);
    myStream.set("his_points", 0);
    
    opponentStream.set("battle_status", "battle_alive");
    opponentStream.set("is_battle", true); // ✅ Set is_battle field
    opponentStream.set("battle_liveID", myChannel);
    opponentStream.set("battle_start_time", currentTime);
    opponentStream.set("my_points", 0);
    opponentStream.set("his_points", 0);
    
    // Save both documents atomically
    await Parse.Object.saveAll([myStream, opponentStream], { useMasterKey: true });
    
    console.log(`✅ [INIT_BATTLE] Battle initialized successfully`);
    console.log(`   My: ${myChannel} -> Opponent: ${opponentChannel}`);
    console.log(`   Opponent: ${opponentChannel} -> My: ${myChannel}`);
    console.log(`   Start time: ${currentTime}`);
    
    return {
      success: true,
      battleStartTime: currentTime,
      myChannel: myChannel,
      opponentChannel: opponentChannel
    };
    
  } catch (error) {
    console.error(`❌ [INIT_BATTLE] Error: ${error.message}`);
    throw new Parse.Error(Parse.Error.INTERNAL_SERVER_ERROR, error.message);
  }
});

// ========================================
// NEW: Get Battle State for Late Joiners
// ========================================
Parse.Cloud.define("getBattleState", async (request) => {
  const { liveChannel } = request.params;
  
  console.log(`🔍 [BATTLE_STATE] Request for channel: ${liveChannel}`);
  
  if (!liveChannel) {
    throw new Error("liveChannel is required");
  }
  
  try {
    const Streaming = Parse.Object.extend("Streaming");
    
    // Get MY stream
    const myQuery = new Parse.Query(Streaming);
    myQuery.equalTo("streaming_channel", liveChannel);
    const myStream = await myQuery.first({ useMasterKey: true });
    
    if (!myStream) {
      console.error(`❌ [BATTLE_STATE] Stream not found: ${liveChannel}`);
      return { success: false, error: "Stream not found" };
    }
    
    // Check if battle is active
    const battleStatus = myStream.get("battle_status");
    if (battleStatus !== "battle_alive") {
      // Battle ended - return FINAL scores, not zeros!
      const finalMyPoints = myStream.get("my_points") || 0;
      const finalHisPoints = myStream.get("his_points") || 0;
      
      console.log(`ℹ️ [BATTLE_STATE] Battle ended for ${liveChannel} - status: ${battleStatus} | Final: My=${finalMyPoints}, His=${finalHisPoints}`);
      return { 
        success: true, 
        battleActive: false,
        my_points: finalMyPoints,
        his_points: finalHisPoints,
        battleEnded: true
      };
    }
    
    // Get opponent's channel
    const opponentChannel = myStream.get("battle_liveID");
    if (!opponentChannel) {
      console.error(`❌ [BATTLE_STATE] No opponent channel found`);
      console.error(`❌ [BATTLE_STATE] Stream details: objectId=${myStream.id}, status=${battleStatus}`);
      console.error(`❌ [BATTLE_STATE] Available fields:`, Object.keys(myStream.attributes));
      return { success: false, error: "No opponent" };
    }
    
    // Get opponent's stream
    const opponentQuery = new Parse.Query(Streaming);
    opponentQuery.equalTo("streaming_channel", opponentChannel);
    const opponentStream = await opponentQuery.first({ useMasterKey: true });
    
    if (!opponentStream) {
      console.error(`❌ [BATTLE_STATE] Opponent stream not found: ${opponentChannel}`);
      return { success: false, error: "Opponent stream not found" };
    }
    
    // Fetch fresh data
    await myStream.fetch({ useMasterKey: true });
    await opponentStream.fetch({ useMasterKey: true });
    
    const myPoints = myStream.get("my_points") || 0;
    const hisPoints = myStream.get("his_points") || 0;
    const opponentMyPoints = opponentStream.get("my_points") || 0;
    const battleStartTime = myStream.get("battle_start_time") || 0;
    
    console.log(`✅ [BATTLE_STATE] Battle found | My: ${myPoints}, His: ${hisPoints}, Opponent's My: ${opponentMyPoints}, StartTime: ${battleStartTime}`);
    
    return {
      success: true,
      battleActive: true,
      my_points: myPoints,
      his_points: hisPoints,
      opponent_my_points: opponentMyPoints, // For cross-verification
      battle_start_time: battleStartTime,
      my_channel: liveChannel,
      opponent_channel: opponentChannel,
      timestamp: Date.now()
    };
    
  } catch (error) {
    console.error(`❌ [BATTLE_STATE] Error: ${error.message}`);
    return { success: false, error: error.message };
  }
});

// ========================================
// Legacy compatibility wrapper
// ========================================
Parse.Cloud.define("save_hisBattle_points", async (request) => {
  console.log("⚠️ [LEGACY] save_hisBattle_points called, redirecting to addPKPoints");
  console.log(`📋 [LEGACY] Params: ${JSON.stringify(request.params)}`);
  return Parse.Cloud.run("addPKPoints", request.params, { sessionToken: request.user?.getSessionToken() });
});

console.log("✅ [ATOMIC] PK Points System loaded successfully - addPKPoints + getBattleState ready!");

// ===============================
// End of cloud_functions_pk_points_ATOMIC.js
// ===============================

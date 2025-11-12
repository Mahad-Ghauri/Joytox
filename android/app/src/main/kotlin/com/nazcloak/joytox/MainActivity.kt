package com.nazcloak.joytox

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        
        // 🔥 Configure video player for optimal streaming
        configureVideoBuffering()
    }
    
    /**
     * Configure video player to prevent ImageReader buffer overflow
     * This fixes "Unable to acquire a buffer item" warnings
     */
    private fun configureVideoBuffering() {
        try {
            // 🔥 ExoPlayer frame dropping - aggressively drop frames to prevent buffer buildup
            System.setProperty("exoplayer.video.renderer.frame.drop.enabled", "true")
            
            // 🔥 Disable tunneling - it causes buffer issues on some devices
            System.setProperty("exoplayer.video.tunneling.enabled", "false")
            
            // 🔥 NEW: Reduce ExoPlayer's internal buffer sizes to prevent overflow
            // These properties limit how much ExoPlayer buffers ahead
            System.setProperty("exoplayer.loadcontrol.minbufferms", "2500")  // Min 2.5s (down from default 50s)
            System.setProperty("exoplayer.loadcontrol.maxbufferms", "5000")  // Max 5s (down from default 50s)
            System.setProperty("exoplayer.loadcontrol.bufferforplaybackms", "1000")  // 1s to start (down from 2.5s)
            System.setProperty("exoplayer.loadcontrol.bufferforplaybackafterrebufferms", "1500")  // 1.5s after rebuffer
            
            // 🔥 NEW: Reduce ImageReader max images (limits concurrent frame decoding)
            System.setProperty("android.media.mediacodec.video.max-output-buffers", "3")  // Down from default 4+
            
            android.util.Log.i("MainActivity", "ExoPlayer buffer configuration applied successfully")
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Failed to configure video buffering: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "high_importance_channel",
                "High Importance Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "This channel is used for important notifications from Joytox"
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ Register your custom native ad factories
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "listTile", ListTileNativeAdFactory(context)
        )

        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "gridTile", GridTileNativeAdFactory(context)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)

        // ✅ Unregister factories to avoid memory leaks
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "gridTile")
    }
}

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
            
            // 🔥 OPTIMIZED: Reduce buffers for faster initial playback (Instagram-style)
            System.setProperty("exoplayer.loadcontrol.minbufferms", "1500")  // Min 1.5s (faster start)
            System.setProperty("exoplayer.loadcontrol.maxbufferms", "4000")  // Max 4s (reduced)
            System.setProperty("exoplayer.loadcontrol.bufferforplaybackms", "500")  // 0.5s to start (very fast)
            System.setProperty("exoplayer.loadcontrol.bufferforplaybackafterrebufferms", "1000")  // 1s after rebuffer
            
            // 🔥 Reduce ImageReader max images (limits concurrent frame decoding)
            System.setProperty("android.media.mediacodec.video.max-output-buffers", "3")
            
            // 🔥 NEW: Enable fast seeking and reduce latency
            System.setProperty("exoplayer.video.enable-seek-preview", "false") // Faster seeks
            System.setProperty("exoplayer.video.max-preload-ms", "2000") // Limit preload
            
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

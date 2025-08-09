package com.trace.appsdabanda

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class GridTileNativeAdFactory(val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val nativeAdView = LayoutInflater.from(context)
            .inflate(R.layout.grid_tile_native_ad, null) as NativeAdView

        with(nativeAdView) {
            val attributionViewSmall =
                findViewById<TextView>(R.id.ad_attribution)
            //val attributionViewLarge = findViewById<TextView>(R.id.tv_list_tile_native_ad_attribution_large)

            val iconView = findViewById<ImageView>(R.id.ad_icon)
            val icon = nativeAd.icon
            if (icon != null) {
                attributionViewSmall.visibility = View.VISIBLE
                //attributionViewLarge.visibility = View.INVISIBLE
                iconView.setImageDrawable(icon.drawable)
            } else {
                attributionViewSmall.visibility = View.INVISIBLE
                //attributionViewLarge.visibility = View.VISIBLE
            }
            this.iconView = iconView

            val headlineView = findViewById<TextView>(R.id.ad_headline)
            headlineView.text = nativeAd.headline
            this.headlineView = headlineView

            val bodyView = findViewById<TextView>(R.id.ad_body)
            with(bodyView) {
                text = nativeAd.body
                visibility = if (nativeAd.body.isNullOrEmpty()) View.INVISIBLE else View.VISIBLE
            }
            this.bodyView = bodyView

            val mediaView = findViewById<MediaView>(R.id.ad_media)
            val mediaViewAd = nativeAd.mediaContent

            if (mediaViewAd != null){
                mediaView.visibility = View.VISIBLE
                with(mediaView) { setMediaContent(mediaViewAd) } // = nativeAd.callToAction
            } else {
                mediaView.visibility = View.INVISIBLE
            }

            this.mediaView = mediaView

            val callToAction = findViewById<TextView>(R.id.ad_call_to_action)
            val callToActionAd = nativeAd.callToAction

            if (callToActionAd != null){
                callToAction.visibility = View.VISIBLE
                callToAction.text = nativeAd.callToAction
            } else {
                callToAction.visibility = View.INVISIBLE
            }
            this.callToActionView = callToAction

            setNativeAd(nativeAd)
        }

        return nativeAdView
    }
}
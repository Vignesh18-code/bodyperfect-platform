package com.bodyperfect.clinicapp

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bodyperfect/external_links"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    result.success(openUrl(url))
                }
                "openDirections" -> {
                    val branch = call.argument<String>("branch")
                    val fallbackUrl = call.argument<String>("fallbackUrl")
                    result.success(openDirections(branch, fallbackUrl))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openDirections(branch: String?, fallbackUrl: String?): Boolean {
        val destination = destinationFor(branch)
        val encodedDestination = Uri.encode(destination)

        val googleMapsIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("google.navigation:q=$encodedDestination")
        ).apply {
            setPackage("com.google.android.apps.maps")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        if (startIntent(googleMapsIntent)) {
            return true
        }

        val webDirectionsUrl =
            "https://www.google.com/maps/dir/?api=1&destination=$encodedDestination"
        if (openUrl(webDirectionsUrl)) {
            return true
        }

        return openUrl(fallbackUrl)
    }

    private fun openUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) {
            return false
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return startIntent(intent)
    }

    private fun startIntent(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun destinationFor(branch: String?): String {
        val normalized = branch
            ?.uppercase()
            ?.replace(" ", "")
            ?.replace("-", "")
            ?: ""

        return when (normalized) {
            "MARINA", "DUBAIMARINA" -> "Body Perfect Clinic Marina Dubai"
            "BURJUMAN", "KARAMA", "BURDUBAI" -> "Body Perfect Clinic BurJuman Karama Dubai"
            else -> "Body Perfect Clinic Dubai"
        }
    }
}

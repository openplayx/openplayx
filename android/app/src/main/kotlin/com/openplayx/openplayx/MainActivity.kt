package com.openplayx.openplayx

import android.app.Activity
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.OrientationEventListener
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var orientationListener: OrientationEventListener? = null
    private var pendingPick: MethodChannel.Result? = null
    private val fileWorker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "openplayx/device_orientation")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    orientationListener?.disable()
                    orientationListener = object : OrientationEventListener(this@MainActivity) {
                        private var last = -1
                        override fun onOrientationChanged(angle: Int) {
                            if (angle == ORIENTATION_UNKNOWN) return
                            val quadrant = ((angle + 45) / 90) % 4
                            val distance = kotlin.math.abs(angle - quadrant * 90)
                            // Ignore diagonal readings to avoid jitter at the boundary.
                            if (kotlin.math.min(distance, 360 - distance) > 30 || quadrant == last) return
                            last = quadrant
                            events.success(listOf("portraitUp", "landscapeRight", "portraitDown", "landscapeLeft")[quadrant])
                        }
                    }.also { it.enable() }
                }
                override fun onCancel(arguments: Any?) {
                    orientationListener?.disable()
                    orientationListener = null
                }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openplayx/transfer_storage")
            .setMethodCallHandler { call, result ->
                if (call.method != "availableBytes") result.notImplemented()
                else result.success(android.os.StatFs(cacheDir.absolutePath).availableBytes)
            }
        val networkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openplayx/network_policy")
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        networkCallback?.let { connectivity.unregisterNetworkCallback(it) }
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            private fun changed() { runOnUiThread { networkChannel.invokeMethod("networkChanged", null) } }
            override fun onAvailable(network: Network) = changed()
            override fun onLost(network: Network) = changed()
            override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) = changed()
        }.also { connectivity.registerDefaultNetworkCallback(it) }
        networkChannel.setMethodCallHandler { call, result ->
                if (call.method != "usingCellular") { result.notImplemented() }
                else {
                    val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val caps = manager.getNetworkCapabilities(manager.activeNetwork)
                    if (caps == null || (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN) &&
                        !caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) &&
                        !caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) &&
                        !caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET))) {
                        result.error("network_unknown", "Unable to determine the active network", null)
                    } else { result.success(caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "openplayx/local_media")
            .setMethodCallHandler { call, result ->
                if (call.method != "pickMedia") {
                    result.notImplemented()
                } else if (pendingPick != null) {
                    result.error("busy", "A file selection is already in progress", null)
                } else {
                    pendingPick = result
                    try {
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }, PICK_MEDIA)
                    } catch (e: Exception) {
                        pendingPick = null
                        result.error("picker_unavailable", "Unable to open file picker", null)
                    }
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_MEDIA) return
        val result = pendingPick ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingPick = null
            result.success(null)
            return
        }
        // Never materialize the whole media file in a byte array or platform message.
        fileWorker.execute {
            var output: File? = null
            try {
                val name = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else null }
                    ?: "media"
                val directory = File(cacheDir, "local_media").apply { mkdirs() }
                val target = File.createTempFile("media_", ".cache", directory)
                output = target
                val input = contentResolver.openInputStream(uri)
                    ?: throw java.io.IOException("Unable to open media")
                input.use { source -> target.outputStream().use { source.copyTo(it, 64 * 1024) } }
                Handler(Looper.getMainLooper()).post {
                    pendingPick = null
                    result.success(mapOf("path" to target.absolutePath, "name" to name))
                }
            } catch (e: Exception) {
                output?.delete()
                Handler(Looper.getMainLooper()).post {
                    pendingPick = null
                    result.error("media_open_failed", "Unable to copy selected media; check available storage", null)
                }
            }
        }
    }

    override fun onDestroy() {
        networkCallback?.let { (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager).unregisterNetworkCallback(it) }
        networkCallback = null
        orientationListener?.disable()
        orientationListener = null
        super.onDestroy()
    }

    companion object {
        private const val PICK_MEDIA = 4701
    }
}

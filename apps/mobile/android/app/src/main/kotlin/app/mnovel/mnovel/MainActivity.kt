package app.mnovel.mnovel

import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "mnovel/js_runner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "evaluate") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val script = call.argument<String>("script")
                if (script.isNullOrBlank()) {
                    result.error("invalid_script", "JS 脚本不能为空", null)
                    return@setMethodCallHandler
                }
                val webView = WebView(this)
                webView.settings.javaScriptEnabled = true
                webView.webViewClient = WebViewClient()
                webView.loadDataWithBaseURL(
                    "about:blank",
                    "<html><body></body></html>",
                    "text/html",
                    "UTF-8",
                    null,
                )
                webView.evaluateJavascript(script) { value ->
                    val decoded = if (value == null || value == "null") {
                        ""
                    } else {
                        try {
                            org.json.JSONArray("[$value]").getString(0)
                        } catch (_: Exception) {
                            value
                        }
                    }
                    webView.destroy()
                    result.success(decoded)
                }
            }
    }
}

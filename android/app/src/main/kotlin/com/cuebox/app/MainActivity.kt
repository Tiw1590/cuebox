package com.cuebox.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var safChannel: SafChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "cuebox/saf",
        )
        val handler = SafChannel(this)
        handler.registerWith(channel)
        safChannel = handler
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val handled = safChannel?.onActivityResult(requestCode, resultCode, data) == true
        if (!handled) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }
}

package com.example.flutter_multitracker_example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.raybsou.flutter_multitracker.FlutterMultitrackerPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Manually register the plugin
        FlutterMultitrackerPlugin.registerWith(flutterEngine.dartExecutor.binaryMessenger)
    }
}

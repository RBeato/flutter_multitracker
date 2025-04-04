package com.raybsou.flutter_multitracker

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.BinaryMessenger
import android.util.Log

/** FlutterMultitrackerPlugin */
class FlutterMultitrackerPlugin: FlutterPlugin, MethodCallHandler {
  private val TAG = "FlutterMultitrackerPlugin"
  private lateinit var channel : MethodChannel
  private var context: android.content.Context? = null
  private var audioEngine: SimpleAudioEngine? = null

  // Companion object for static methods
  companion object {
    @JvmStatic
    fun registerWith(messenger: BinaryMessenger) {
      val plugin = FlutterMultitrackerPlugin()
      val channel = MethodChannel(messenger, "flutter_multitracker")
      channel.setMethodCallHandler(plugin)
      Log.d("FlutterMultitrackerPlugin", "Plugin manually registered with messenger")
    }
  }

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_multitracker")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    
    // Initialize the audio engine
    audioEngine = SimpleAudioEngine(flutterPluginBinding.applicationContext)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    Log.d(TAG, "Method called: ${call.method}")
    
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "initializeAudioEngine" -> {
        val sampleRate = call.argument<Int>("sampleRate") ?: 44100
        val success = audioEngine?.initialize() ?: false
        Log.i(TAG, "Initialize audio engine result: $success")
        result.success(success)
      }
      "playTestTone" -> {
        val success = audioEngine?.playTestTone() ?: false
        Log.i(TAG, "Play test tone result: $success")
        result.success(success)
      }
      "stopTestTone" -> {
        val success = audioEngine?.stopTestTone() ?: false
        Log.i(TAG, "Stop test tone result: $success")
        result.success(success)
      }
      "playNote" -> {
        val instrumentId = call.argument<Int>("instrumentId") ?: 0
        val noteNumber = call.argument<Int>("noteNumber") ?: 60
        val velocity = call.argument<Int>("velocity") ?: 64
        
        // We ignore instrumentId since we only have one instrument
        val success = audioEngine?.playNote(noteNumber, velocity) ?: false
        Log.i(TAG, "Play note result: $success (instr=$instrumentId, note=$noteNumber, vel=$velocity)")
        result.success(success)
      }
      "stopNote" -> {
        val instrumentId = call.argument<Int>("instrumentId") ?: 0
        val noteNumber = call.argument<Int>("noteNumber") ?: 60
        
        // We ignore instrumentId since we only have one instrument
        val success = audioEngine?.stopNote(noteNumber) ?: false
        Log.i(TAG, "Stop note result: $success (instr=$instrumentId, note=$noteNumber)")
        result.success(success)
      }
      "shutdown" -> {
        audioEngine?.shutdown()
        Log.i(TAG, "Audio engine shut down")
        result.success(true)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    audioEngine?.shutdown()
    audioEngine = null
    context = null
  }
} 
package com.example.flutter_multitracker

import androidx.annotation.NonNull
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterMultitrackerPlugin */
class FlutterMultitrackerPlugin: FlutterPlugin, MethodCallHandler {
  private val TAG = "FlutterMultitrackerPlugin"
  private lateinit var channel : MethodChannel
  private var audioEngine: com.example.flutter_multitracker.AudioEngine? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_multitracker")
    channel.setMethodCallHandler(this)
    
    // Create audio engine instance
    audioEngine = com.example.flutter_multitracker.AudioEngine()
    Log.i(TAG, "FlutterMultitrackerPlugin attached to engine")
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    Log.d(TAG, "Method call: ${call.method}")
    
    try {
      when (call.method) {
        "getPlatformVersion" -> {
          result.success("Android ${android.os.Build.VERSION.RELEASE}")
        }
        "initAudioEngine" -> {
          val sampleRate = call.argument<Int>("sampleRate") ?: 44100
          val success = audioEngine?.init(sampleRate) ?: false
          result.success(success)
        }
        "startAudioEngine" -> {
          val success = audioEngine?.start() ?: false
          result.success(success)
        }
        "stopAudioEngine" -> {
          val success = audioEngine?.stop() ?: false
          result.success(success)
        }
        "cleanupAudioEngine" -> {
          audioEngine?.cleanup()
          result.success(true)
        }
        "setMasterVolume" -> {
          val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
          audioEngine?.setMasterVolume(volume)
          result.success(true)
        }
        "createSineWaveInstrument" -> {
          val name = call.argument<String>("name") ?: "Sine Wave"
          val instrumentId = audioEngine?.createSineWaveInstrument(name) ?: -1
          result.success(instrumentId)
        }
        "unloadInstrument" -> {
          val instrumentId = call.argument<Int>("instrumentId") ?: -1
          val success = audioEngine?.unloadInstrument(instrumentId) ?: false
          result.success(success)
        }
        "sendNoteOn" -> {
          val instrumentId = call.argument<Int>("instrumentId") ?: -1
          val noteNumber = call.argument<Int>("noteNumber") ?: -1
          val velocity = call.argument<Int>("velocity") ?: 100
          
          val success = audioEngine?.sendNoteOn(instrumentId, noteNumber, velocity) ?: false
          result.success(success)
        }
        "sendNoteOff" -> {
          val instrumentId = call.argument<Int>("instrumentId") ?: -1
          val noteNumber = call.argument<Int>("noteNumber") ?: -1
          
          val success = audioEngine?.sendNoteOff(instrumentId, noteNumber) ?: false
          result.success(success)
        }
        "setInstrumentVolume" -> {
          val instrumentId = call.argument<Int>("instrumentId") ?: -1
          val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
          
          val success = audioEngine?.setInstrumentVolume(instrumentId, volume) ?: false
          result.success(success)
        }
        "getLoadedInstrumentIds" -> {
          val ids = audioEngine?.getLoadedInstrumentIds() ?: intArrayOf()
          result.success(ids.toList())
        }
        else -> {
          result.notImplemented()
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Exception in method call: ${e.message}")
      e.printStackTrace()
      result.error("EXCEPTION", "Exception in method call: ${e.message}", e.toString())
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    Log.i(TAG, "FlutterMultitrackerPlugin detached from engine")
    
    try {
      // Clean up resources
      audioEngine?.cleanup()
      audioEngine = null
      
      channel.setMethodCallHandler(null)
    } catch (e: Exception) {
      Log.e(TAG, "Exception in onDetachedFromEngine: ${e.message}")
      e.printStackTrace()
    }
  }
}

package com.raybsou.flutter_multitracker

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlin.math.sin

class SimpleAudioEngine(private val context: Context) {
    private val TAG = "SimpleAudioEngine"
    
    // Load native library
    companion object {
        init {
            try {
                System.loadLibrary("flutter_multitracker")
                Log.i("SimpleAudioEngine", "Native library loaded successfully")
            } catch (e: Exception) {
                Log.e("SimpleAudioEngine", "Failed to load native library: ${e.message}")
            }
        }
    }
    
    // Native method declarations
    private external fun setupAudioEngine(sampleRate: Int): Boolean
    private external fun nativePlayNote(instrumentId: Int, noteNumber: Int, velocity: Int): Boolean
    private external fun nativeStopNote(instrumentId: Int, noteNumber: Int): Boolean
    private external fun nativeCleanup(): Unit
    
    // Audio constants
    private val sampleRate = 44100
    private val bufferSize = AudioTrack.getMinBufferSize(
        sampleRate,
        AudioFormat.CHANNEL_OUT_MONO,
        AudioFormat.ENCODING_PCM_16BIT
    )
    
    // Audio track
    private var audioTrack: AudioTrack? = null
    
    // Coroutine scope for audio processing
    private val audioScope = CoroutineScope(Dispatchers.Default)
    private var audioJob: Job? = null
    
    // Sine wave parameters
    private var currentNotes = mutableMapOf<Int, NoteInfo>()
    
    // Flag to indicate if initialized
    private var isInitialized = false
    private var useNativeEngine = true // Try native engine first
    
    // Class to hold note information
    data class NoteInfo(
        val noteNumber: Int,
        val velocity: Int,
        var phase: Double = 0.0
    )
    
    // Initialize the audio engine
    fun initialize(): Boolean {
        Log.i(TAG, "Initializing SimpleAudioEngine")
        
        // Try native implementation first
        if (useNativeEngine) {
            try {
                Log.i(TAG, "Attempting to initialize native audio engine")
                
                // Try to load the library again just to be sure
                try {
                    System.loadLibrary("flutter_multitracker")
                    Log.i(TAG, "Native library loaded successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to load native library: ${e.message}")
                    Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
                    useNativeEngine = false
                    // Continue to fallback
                }
                
                if (useNativeEngine) {
                    try {
                        val nativeResult = setupAudioEngine(sampleRate)
                        Log.i(TAG, "Native setupAudioEngine result: $nativeResult")
                        
                        if (nativeResult) {
                            Log.i(TAG, "Native audio engine initialized successfully")
                            isInitialized = true
                            
                            // Test creating a note
                            try {
                                val testResult = nativePlayNote(0, 60, 100)
                                Log.i(TAG, "Test note play result: $testResult")
                                
                                if (testResult) {
                                    // Stop the test note
                                    nativeStopNote(0, 60)
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Test note failed: ${e.message}")
                                Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
                            }
                            
                            return true
                        } else {
                            Log.w(TAG, "Native audio engine failed to initialize, falling back to Java implementation")
                            useNativeEngine = false // Fall back to Java implementation
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Exception calling native setupAudioEngine: ${e.message}")
                        Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
                        Log.w(TAG, "Falling back to Java implementation")
                        useNativeEngine = false // Fall back to Java implementation
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exception initializing native audio engine: ${e.message}")
                Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
                Log.w(TAG, "Falling back to Java implementation")
                useNativeEngine = false // Fall back to Java implementation
            }
        }
        
        // If native implementation failed or not being used, use Java implementation
        try {
            // Create AudioTrack
            audioTrack = createAudioTrack()
            
            if (audioTrack == null) {
                Log.e(TAG, "Failed to create AudioTrack")
                return false
            }
            
            // Start the audio track
            audioTrack?.play()
            
            // Start audio processing
            startAudioProcessing()
            
            isInitialized = true
            Log.i(TAG, "SimpleAudioEngine initialized successfully (Java implementation)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize SimpleAudioEngine: ${e.message}")
            cleanup()
            return false
        }
    }
    
    // Create the AudioTrack
    private fun createAudioTrack(): AudioTrack? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
                
                val audioFormat = AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
                
                AudioTrack.Builder()
                    .setAudioAttributes(audioAttributes)
                    .setAudioFormat(audioFormat)
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                AudioTrack(
                    AudioManager.STREAM_MUSIC,
                    sampleRate,
                    AudioFormat.CHANNEL_OUT_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                    AudioTrack.MODE_STREAM
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create AudioTrack: ${e.message}")
            null
        }
    }
    
    // Start audio processing
    private fun startAudioProcessing() {
        audioJob = audioScope.launch {
            val buffer = ShortArray(1024)
            
            while (isInitialized) {
                // Generate audio
                generateAudio(buffer)
                
                // Write to audio track
                try {
                    audioTrack?.write(buffer, 0, buffer.size)
                } catch (e: Exception) {
                    Log.e(TAG, "Error writing to AudioTrack: ${e.message}")
                }
            }
        }
    }
    
    // Generate audio samples
    private fun generateAudio(buffer: ShortArray) {
        // Clear the buffer
        buffer.fill(0)
        
        // No notes playing? Return silence
        if (currentNotes.isEmpty()) {
            return
        }
        
        // Generate samples for each active note
        synchronized(currentNotes) {
            for (noteInfo in currentNotes.values) {
                val frequency = noteNumberToFrequency(noteInfo.noteNumber)
                val amplitude = noteInfo.velocity / 127.0 * 0.2 // Scale to avoid clipping
                
                for (i in buffer.indices) {
                    // Generate sine wave: amplitude * sin(2π * frequency * time)
                    val sample = amplitude * sin(noteInfo.phase)
                    
                    // Add sample to buffer (additive synthesis)
                    buffer[i] = (buffer[i] + (sample * Short.MAX_VALUE)).toInt().toShort()
                    
                    // Update phase for next sample
                    noteInfo.phase += 2.0 * Math.PI * frequency / sampleRate
                    
                    // Wrap phase to stay within 0 to 2π
                    if (noteInfo.phase >= 2.0 * Math.PI) {
                        noteInfo.phase -= 2.0 * Math.PI
                    }
                }
            }
        }
    }
    
    // Play a note
    fun playNote(noteNumber: Int, velocity: Int): Boolean {
        if (!isInitialized) {
            Log.e(TAG, "SimpleAudioEngine not initialized")
            return false
        }
        
        Log.i(TAG, "Playing note: $noteNumber with velocity: $velocity")
        
        try {
            // Use native implementation if available
            if (useNativeEngine) {
                return nativePlayNote(0, noteNumber, velocity)
            }
            
            // Otherwise use Java implementation
            synchronized(currentNotes) {
                currentNotes[noteNumber] = NoteInfo(noteNumber, velocity)
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play note: ${e.message}")
            return false
        }
    }
    
    // Stop a note
    fun stopNote(noteNumber: Int): Boolean {
        if (!isInitialized) {
            Log.e(TAG, "SimpleAudioEngine not initialized")
            return false
        }
        
        Log.i(TAG, "Stopping note: $noteNumber")
        
        try {
            // Use native implementation if available
            if (useNativeEngine) {
                return nativeStopNote(0, noteNumber)
            }
            
            // Otherwise use Java implementation
            synchronized(currentNotes) {
                currentNotes.remove(noteNumber)
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop note: ${e.message}")
            return false
        }
    }
    
    // Stop all notes
    fun stopAllNotes(): Boolean {
        if (!isInitialized) {
            Log.e(TAG, "SimpleAudioEngine not initialized")
            return false
        }
        
        Log.i(TAG, "Stopping all notes")
        
        try {
            synchronized(currentNotes) {
                currentNotes.clear()
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop all notes: ${e.message}")
            return false
        }
    }
    
    // Play a test tone
    fun playTestTone(): Boolean {
        return playNote(60, 100) // Middle C, medium velocity
    }
    
    // Stop the test tone
    fun stopTestTone(): Boolean {
        return stopNote(60) // Stop middle C
    }
    
    // Shutdown the audio engine
    fun shutdown() {
        Log.i(TAG, "Shutting down SimpleAudioEngine")
        
        if (useNativeEngine) {
            try {
                nativeCleanup()
                Log.i(TAG, "Native audio engine shut down")
            } catch (e: Exception) {
                Log.e(TAG, "Error shutting down native audio engine: ${e.message}")
            }
        }
        
        // Stop audio processing
        isInitialized = false
        audioJob?.cancel()
        
        // Cleanup resources
        cleanup()
    }
    
    // Clean up resources
    private fun cleanup() {
        // Stop and release AudioTrack
        try {
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup: ${e.message}")
        }
        
        // Cancel coroutine scope
        try {
            audioScope.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Error canceling audio scope: ${e.message}")
        }
        
        // Clear notes
        synchronized(currentNotes) {
            currentNotes.clear()
        }
        
        isInitialized = false
    }
    
    // Convert MIDI note number to frequency
    private fun noteNumberToFrequency(noteNumber: Int): Double {
        return 440.0 * Math.pow(2.0, (noteNumber - 69) / 12.0)
    }
} 
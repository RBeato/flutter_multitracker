package com.example.flutter_multitracker;

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * A Java-based audio engine implementation using AudioTrack.
 * This replaces the native OpenSL ES implementation for better compatibility.
 */
public class AudioEngine {
    private static final String TAG = "AudioEngine";
    private static final int DEFAULT_SAMPLE_RATE = 44100;
    private static final int DEFAULT_BUFFER_SIZE_FACTOR = 4; // Buffer size = frames per buffer * factor
    private static final int MAX_INSTRUMENTS = 32;
    private static final int MAX_NOTES = 128;

    // Audio configuration
    private int sampleRate = DEFAULT_SAMPLE_RATE;
    private int bufferSize = 0;
    private int framesPerBuffer = 0;
    private float masterVolume = 1.0f;

    // Audio objects
    private AudioTrack audioTrack;
    private short[] audioBuffer;
    private float[] floatBuffer;

    // State
    private final AtomicBoolean isInitialized = new AtomicBoolean(false);
    private final AtomicBoolean isPlaying = new AtomicBoolean(false);
    private final AtomicBoolean isRendering = new AtomicBoolean(false);

    // Instrument data
    private final Map<Integer, Instrument> instruments = new HashMap<>();
    private final Map<Integer, Set<Integer>> activeNotes = new HashMap<>();
    private final Map<Integer, Map<Integer, Integer>> noteVelocities = new HashMap<>();
    private final Map<Integer, Map<Integer, Float>> notePhases = new HashMap<>();
    private int nextInstrumentId = 1;

    // Audio thread
    private Thread audioThread;

    /**
     * Initialize the audio engine with the specified sample rate.
     */
    public boolean init(int sampleRate) {
        Log.d(TAG, "Initializing AudioEngine with sample rate: " + sampleRate);

        if (isInitialized.get()) {
            Log.w(TAG, "AudioEngine already initialized");
            return true;
        }

        // Validate sample rate
        if (sampleRate <= 0) {
            Log.w(TAG, "Invalid sample rate: " + sampleRate + ", using default: " + DEFAULT_SAMPLE_RATE);
            this.sampleRate = DEFAULT_SAMPLE_RATE;
        } else {
            this.sampleRate = sampleRate;
        }

        try {
            // Calculate buffer size
            int minBufferSize = AudioTrack.getMinBufferSize(
                    this.sampleRate,
                    AudioFormat.CHANNEL_OUT_STEREO,
                    AudioFormat.ENCODING_PCM_16BIT
            );

            if (minBufferSize == AudioTrack.ERROR || minBufferSize == AudioTrack.ERROR_BAD_VALUE) {
                Log.e(TAG, "Failed to get minimum buffer size");
                return false;
            }

            // Use a larger buffer for stability
            framesPerBuffer = minBufferSize / 4; // 2 channels * 2 bytes per sample
            bufferSize = framesPerBuffer * DEFAULT_BUFFER_SIZE_FACTOR;

            Log.d(TAG, "Using buffer size: " + bufferSize + ", frames per buffer: " + framesPerBuffer);

            // Create audio buffers
            audioBuffer = new short[framesPerBuffer * 2]; // Stereo
            floatBuffer = new float[framesPerBuffer * 2]; // Stereo

            // Create AudioTrack
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                AudioAttributes audioAttributes = new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build();

                AudioFormat audioFormat = new AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(this.sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build();

                audioTrack = new AudioTrack.Builder()
                        .setAudioAttributes(audioAttributes)
                        .setAudioFormat(audioFormat)
                        .setBufferSizeInBytes(bufferSize)
                        .setTransferMode(AudioTrack.MODE_STREAM)
                        .build();
            } else {
                audioTrack = new AudioTrack(
                        AudioManager.STREAM_MUSIC,
                        this.sampleRate,
                        AudioFormat.CHANNEL_OUT_STEREO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        bufferSize,
                        AudioTrack.MODE_STREAM
                );
            }

            // Check if AudioTrack was created successfully
            if (audioTrack.getState() != AudioTrack.STATE_INITIALIZED) {
                Log.e(TAG, "Failed to initialize AudioTrack");
                audioTrack.release();
                audioTrack = null;
                return false;
            }

            isInitialized.set(true);
            Log.i(TAG, "AudioEngine initialized successfully");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Exception in init: " + e.getMessage());
            e.printStackTrace();
            cleanup();
            return false;
        }
    }

    /**
     * Start audio playback.
     */
    public boolean start() {
        Log.d(TAG, "Starting AudioEngine");

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        if (isPlaying.get()) {
            Log.w(TAG, "AudioEngine already started");
            return true;
        }

        try {
            // Start audio thread
            audioThread = new Thread(new Runnable() {
                @Override
                public void run() {
                    try {
                        Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO);
                        Log.d(TAG, "Audio thread started");

                        audioTrack.play();
                        isPlaying.set(true);

                        while (isPlaying.get()) {
                            renderAudio();
                            
                            // Write audio data to AudioTrack
                            if (audioBuffer != null) {
                                audioTrack.write(audioBuffer, 0, audioBuffer.length);
                            }
                        }

                        Log.d(TAG, "Audio thread stopped");
                    } catch (Exception e) {
                        Log.e(TAG, "Exception in audio thread: " + e.getMessage());
                        e.printStackTrace();
                        isPlaying.set(false);
                    }
                }
            });

            audioThread.start();
            Log.i(TAG, "AudioEngine started successfully");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Exception in start: " + e.getMessage());
            e.printStackTrace();
            isPlaying.set(false);
            return false;
        }
    }

    /**
     * Stop audio playback.
     */
    public boolean stop() {
        Log.d(TAG, "Stopping AudioEngine");

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        if (!isPlaying.get()) {
            Log.w(TAG, "AudioEngine already stopped");
            return true;
        }

        try {
            // Stop audio thread
            isPlaying.set(false);
            
            if (audioThread != null) {
                try {
                    audioThread.join(1000);
                } catch (InterruptedException e) {
                    Log.w(TAG, "Interrupted while waiting for audio thread to stop");
                }
                audioThread = null;
            }

            // Stop AudioTrack
            if (audioTrack != null) {
                audioTrack.pause();
                audioTrack.flush();
                audioTrack.stop();
            }

            Log.i(TAG, "AudioEngine stopped successfully");
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Exception in stop: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Clean up resources.
     */
    public void cleanup() {
        Log.d(TAG, "Cleaning up AudioEngine");

        try {
            // Stop playback if active
            if (isPlaying.get()) {
                stop();
            }

            // Release AudioTrack
            if (audioTrack != null) {
                audioTrack.release();
                audioTrack = null;
            }

            // Clear buffers
            audioBuffer = null;
            floatBuffer = null;

            // Clear instrument data
            synchronized (instruments) {
                instruments.clear();
            }
            
            synchronized (activeNotes) {
                activeNotes.clear();
            }
            
            synchronized (noteVelocities) {
                noteVelocities.clear();
            }
            
            synchronized (notePhases) {
                notePhases.clear();
            }

            isInitialized.set(false);
            Log.i(TAG, "AudioEngine cleaned up successfully");
        } catch (Exception e) {
            Log.e(TAG, "Exception in cleanup: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Set the master volume (0.0 to 1.0).
     */
    public void setMasterVolume(float volume) {
        Log.d(TAG, "Setting master volume to " + volume);

        // Clamp volume to valid range
        masterVolume = Math.max(0.0f, Math.min(1.0f, volume));

        // Set volume on AudioTrack if available
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && audioTrack != null) {
            audioTrack.setVolume(masterVolume);
        }
    }

    /**
     * Create a sine wave instrument.
     */
    public int createSineWaveInstrument(String name) {
        Log.i(TAG, "Creating sine wave instrument: " + name);

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return -1;
        }

        synchronized (instruments) {
            // Check if we've reached the maximum number of instruments
            if (instruments.size() >= MAX_INSTRUMENTS) {
                Log.e(TAG, "Maximum number of instruments reached (" + MAX_INSTRUMENTS + ")");
                return -1;
            }

            // Create instrument
            int instrumentId = nextInstrumentId++;
            Instrument instrument = new Instrument(
                    instrumentId,
                    name,
                    InstrumentType.SINE_WAVE,
                    1.0f
            );

            instruments.put(instrumentId, instrument);
            Log.i(TAG, "Successfully created sine wave instrument '" + name + "' with ID: " + instrumentId);
            return instrumentId;
        }
    }

    /**
     * Unload an instrument.
     */
    public boolean unloadInstrument(int instrumentId) {
        Log.d(TAG, "Unloading instrument with ID: " + instrumentId);

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        synchronized (instruments) {
            if (!instruments.containsKey(instrumentId)) {
                Log.w(TAG, "Instrument with ID " + instrumentId + " not found");
                return false;
            }

            // First, clear all active notes for this instrument
            synchronized (activeNotes) {
                activeNotes.remove(instrumentId);
            }

            synchronized (noteVelocities) {
                noteVelocities.remove(instrumentId);
            }

            synchronized (notePhases) {
                notePhases.remove(instrumentId);
            }

            // Then remove the instrument
            instruments.remove(instrumentId);
            Log.d(TAG, "Successfully unloaded instrument with ID: " + instrumentId);
            return true;
        }
    }

    /**
     * Send note on event.
     */
    public boolean sendNoteOn(int instrumentId, int noteNumber, int velocity) {
        Log.i(TAG, "Note ON: instrument=" + instrumentId + ", note=" + noteNumber + ", velocity=" + velocity);

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        // Validate parameters
        if (noteNumber < 0 || noteNumber >= MAX_NOTES) {
            Log.e(TAG, "Invalid note number: " + noteNumber + " (must be 0-" + (MAX_NOTES - 1) + ")");
            return false;
        }

        int clampedVelocity = Math.max(1, Math.min(127, velocity));
        if (clampedVelocity != velocity) {
            Log.w(TAG, "Note velocity clamped to valid range: " + clampedVelocity);
        }

        synchronized (instruments) {
            if (!instruments.containsKey(instrumentId)) {
                Log.e(TAG, "Instrument with ID " + instrumentId + " not found for note on");
                return false;
            }

            // Store the velocity
            synchronized (noteVelocities) {
                Map<Integer, Integer> velocities = noteVelocities.get(instrumentId);
                if (velocities == null) {
                    velocities = new HashMap<>();
                    noteVelocities.put(instrumentId, velocities);
                }
                velocities.put(noteNumber, clampedVelocity);
            }

            // Add the note to active notes
            synchronized (activeNotes) {
                Set<Integer> notes = activeNotes.get(instrumentId);
                if (notes == null) {
                    notes = new HashSet<>();
                    activeNotes.put(instrumentId, notes);
                }
                notes.add(noteNumber);
            }

            Log.i(TAG, "Added note " + noteNumber + " to active notes for instrument " + instrumentId + " with velocity " + clampedVelocity);
            return true;
        }
    }

    /**
     * Send note off event.
     */
    public boolean sendNoteOff(int instrumentId, int noteNumber) {
        Log.i(TAG, "Note OFF: instrument=" + instrumentId + ", note=" + noteNumber);

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        // Validate parameters
        if (noteNumber < 0 || noteNumber >= MAX_NOTES) {
            Log.e(TAG, "Invalid note number: " + noteNumber + " (must be 0-" + (MAX_NOTES - 1) + ")");
            return false;
        }

        synchronized (instruments) {
            if (!instruments.containsKey(instrumentId)) {
                Log.e(TAG, "Instrument with ID " + instrumentId + " not found for note off");
                return false;
            }

            // Remove the note from active notes
            synchronized (activeNotes) {
                Set<Integer> notes = activeNotes.get(instrumentId);
                if (notes != null && notes.contains(noteNumber)) {
                    notes.remove(noteNumber);
                    Log.i(TAG, "Removed note " + noteNumber + " from active notes for instrument " + instrumentId);

                    // Clean up empty sets
                    if (notes.isEmpty()) {
                        activeNotes.remove(instrumentId);
                        Log.d(TAG, "Removed empty note set for instrument " + instrumentId);
                    }
                } else {
                    Log.w(TAG, "Note " + noteNumber + " was not active for instrument " + instrumentId);
                }
            }

            // Clean up velocity map
            synchronized (noteVelocities) {
                Map<Integer, Integer> velocities = noteVelocities.get(instrumentId);
                if (velocities != null) {
                    velocities.remove(noteNumber);

                    // Clean up empty maps
                    if (velocities.isEmpty()) {
                        noteVelocities.remove(instrumentId);
                    }
                }
            }

            return true;
        }
    }

    /**
     * Set instrument volume.
     */
    public boolean setInstrumentVolume(int instrumentId, float volume) {
        Log.d(TAG, "Setting volume for instrument " + instrumentId + " to " + volume);

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        synchronized (instruments) {
            Instrument instrument = instruments.get(instrumentId);
            if (instrument == null) {
                Log.w(TAG, "Instrument with ID " + instrumentId + " not found for volume setting");
                return false;
            }

            // Clamp volume to valid range
            float clampedVolume = Math.max(0.0f, Math.min(1.0f, volume));
            
            // Set the instrument volume
            instrument.setVolume(clampedVolume);
            
            Log.d(TAG, "Volume changed: instrument=" + instrumentId + ", volume=" + clampedVolume);
            return true;
        }
    }

    /**
     * Get loaded instrument IDs.
     */
    public int[] getLoadedInstrumentIds() {
        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return new int[0];
        }

        synchronized (instruments) {
            int[] ids = new int[instruments.size()];
            int i = 0;
            for (Integer id : instruments.keySet()) {
                ids[i++] = id;
            }
            Log.d(TAG, "Retrieved " + ids.length + " loaded instrument IDs");
            return ids;
        }
    }

    /**
     * Get the instrument by ID.
     */
    private Instrument getInstrument(int instrumentId) {
        synchronized (instruments) {
            return instruments.get(instrumentId);
        }
    }

    /**
     * Render audio data.
     */
    private void renderAudio() {
        if (!isInitialized.get() || isRendering.get()) {
            return;
        }

        isRendering.set(true);
        try {
            if (floatBuffer == null || audioBuffer == null) {
                isRendering.set(false);
                return;
            }

            // Clear buffer
            for (int i = 0; i < floatBuffer.length; i++) {
                floatBuffer[i] = 0.0f;
            }

            // Only process if we have instruments loaded
            if (instruments.isEmpty()) {
                // Convert float buffer to short buffer
                for (int i = 0; i < audioBuffer.length; i++) {
                    audioBuffer[i] = 0;
                }
                isRendering.set(false);
                return;
            }

            // Check if we have active notes
            boolean hasActiveNotes = false;

            // Process each instrument with active notes
            synchronized (activeNotes) {
                List<Integer> activeInstrumentIds = new ArrayList<>(activeNotes.keySet());
                
                for (int instrumentId : activeInstrumentIds) {
                    Set<Integer> notes = activeNotes.get(instrumentId);
                    
                    if (notes == null || notes.isEmpty()) {
                        continue;
                    }

                    hasActiveNotes = true;

                    // Get the instrument
                    Instrument instrument = getInstrument(instrumentId);
                    if (instrument == null) {
                        continue;
                    }

                    // Calculate base amplitude - reduce as more notes are active
                    float baseAmplitude = 0.15f / (float)Math.sqrt(notes.size());

                    // Apply instrument volume
                    float instrumentAmplitude = baseAmplitude * instrument.getVolume();

                    // Generate sine waves for each note
                    List<Integer> activeNotesList = new ArrayList<>(notes);
                    
                    for (int note : activeNotesList) {
                        // Calculate frequency based on MIDI note number
                        double frequency = midiNoteToFrequency(note);

                        // Get or initialize phase for this note
                        float phase = 0.0f;
                        synchronized (notePhases) {
                            Map<Integer, Float> phases = notePhases.get(instrumentId);
                            if (phases == null) {
                                phases = new HashMap<>();
                                notePhases.put(instrumentId, phases);
                            }
                            
                            Float currentPhase = phases.get(note);
                            if (currentPhase == null) {
                                phases.put(note, 0.0f);
                            } else {
                                phase = currentPhase;
                            }
                        }

                        // Apply velocity scaling if available
                        float amplitude = instrumentAmplitude;
                        synchronized (noteVelocities) {
                            Map<Integer, Integer> velocities = noteVelocities.get(instrumentId);
                            if (velocities != null && velocities.containsKey(note)) {
                                Integer velocity = velocities.get(note);
                                if (velocity != null) {
                                    amplitude *= velocity / 127.0f;
                                } else {
                                    // Default velocity if not specified
                                    amplitude *= 100 / 127.0f;
                                }
                            } else {
                                // Default velocity if not specified
                                amplitude *= 100 / 127.0f;
                            }
                        }

                        // Apply master volume
                        amplitude *= masterVolume;

                        // Generate sine wave for this note
                        for (int i = 0; i < framesPerBuffer; i++) {
                            double sample = amplitude * Math.sin(phase + i * 2.0 * Math.PI * frequency / sampleRate);

                            // Mix into output buffer (stereo)
                            floatBuffer[i * 2] += (float)sample;     // Left channel
                            floatBuffer[i * 2 + 1] += (float)sample; // Right channel
                        }

                        // Update phase
                        synchronized (notePhases) {
                            Map<Integer, Float> phases = notePhases.get(instrumentId);
                            if (phases != null) {
                                double newPhase = phase + framesPerBuffer * 2.0 * Math.PI * frequency / sampleRate;
                                // Keep phase in the range [0, 2π]
                                while (newPhase >= 2.0 * Math.PI) {
                                    newPhase -= 2.0 * Math.PI;
                                }
                                phases.put(note, (float)newPhase);
                            }
                        }
                    }
                }
            }

            // Apply soft limiting to prevent clipping
            for (int i = 0; i < floatBuffer.length; i++) {
                // Soft clipping using tanh
                floatBuffer[i] = (float)Math.tanh(floatBuffer[i]);
            }

            // Convert float buffer to short buffer
            for (int i = 0; i < floatBuffer.length; i++) {
                // Convert -1.0 to 1.0 range to short range (-32768 to 32767)
                audioBuffer[i] = (short)(floatBuffer[i] * 32767.0f);
            }

            if (hasActiveNotes) {
                Log.d(TAG, "Rendered audio frame with active notes");
            }
        } catch (Exception e) {
            Log.e(TAG, "Exception in renderAudio: " + e.getMessage());
            e.printStackTrace();

            // Clear buffer in case of exception to prevent undefined behavior
            if (audioBuffer != null) {
                for (int i = 0; i < audioBuffer.length; i++) {
                    audioBuffer[i] = 0;
                }
            }
        } finally {
            isRendering.set(false);
        }
    }

    /**
     * Convert MIDI note number to frequency.
     */
    private double midiNoteToFrequency(int note) {
        // A4 = 69 = 440Hz
        return 440.0 * Math.pow(2.0, (note - 69) / 12.0);
    }

    /**
     * Instrument type enum.
     */
    public enum InstrumentType {
        SINE_WAVE,
        UNKNOWN
    }

    /**
     * Instrument data class.
     */
    public static class Instrument {
        private final int id;
        private final String name;
        private final InstrumentType type;
        private float volume;

        public Instrument(int id, String name, InstrumentType type, float volume) {
            this.id = id;
            this.name = name;
            this.type = type;
            this.volume = volume;
        }

        public int getId() {
            return id;
        }

        public String getName() {
            return name;
        }

        public InstrumentType getType() {
            return type;
        }

        public float getVolume() {
            return volume;
        }

        public void setVolume(float volume) {
            this.volume = volume;
        }
    }
} 
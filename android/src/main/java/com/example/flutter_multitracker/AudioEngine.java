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

    // Add a map to track note envelopes
    private final Map<Integer, Map<Integer, NoteEnvelope>> noteEnvelopes = new HashMap<>();
    
    // Add a map to track note start times for accurate phase calculation
    private final Map<Integer, Map<Integer, Long>> noteStartTimes = new HashMap<>();

    // Add a map to store sample data
    private final Map<Integer, Map<Integer, short[]>> instrumentSamples = new HashMap<>();
    private final Map<Integer, Map<Integer, Integer>> sampleRates = new HashMap<>();

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
            
            synchronized (noteEnvelopes) {
                noteEnvelopes.clear();
            }
            
            synchronized (noteStartTimes) {
                noteStartTimes.clear();
            }

            // Clear sample data
            synchronized (instrumentSamples) {
                instrumentSamples.clear();
            }
            
            synchronized (sampleRates) {
                sampleRates.clear();
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
            
            // Create or reset envelope for this note
            synchronized (noteEnvelopes) {
                Map<Integer, NoteEnvelope> envelopes = noteEnvelopes.get(instrumentId);
                if (envelopes == null) {
                    envelopes = new HashMap<>();
                    noteEnvelopes.put(instrumentId, envelopes);
                }
                envelopes.put(noteNumber, new NoteEnvelope());
            }
            
            // Store note start time for accurate phase calculation
            synchronized (noteStartTimes) {
                Map<Integer, Long> startTimes = noteStartTimes.get(instrumentId);
                if (startTimes == null) {
                    startTimes = new HashMap<>();
                    noteStartTimes.put(instrumentId, startTimes);
                }
                startTimes.put(noteNumber, System.currentTimeMillis());
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

            // Start release phase for this note's envelope
            boolean noteWasActive = false;
            synchronized (noteEnvelopes) {
                Map<Integer, NoteEnvelope> envelopes = noteEnvelopes.get(instrumentId);
                if (envelopes != null) {
                    NoteEnvelope envelope = envelopes.get(noteNumber);
                    if (envelope != null) {
                        envelope.release();
                        noteWasActive = true;
                    }
                }
            }
            
            // For notes without envelopes or if we want immediate note-off
            if (!noteWasActive) {
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

                    // Get the instrument
                    Instrument instrument = getInstrument(instrumentId);
                    if (instrument == null) {
                        continue;
                    }

                    // Generate audio for each note
                    List<Integer> activeNotesList = new ArrayList<>(notes);
                    List<Integer> notesToRemove = new ArrayList<>();
                    
                    for (int note : activeNotesList) {
                        // Get envelope for this note
                        NoteEnvelope envelope = null;
                        synchronized (noteEnvelopes) {
                            Map<Integer, NoteEnvelope> envelopes = noteEnvelopes.get(instrumentId);
                            if (envelopes != null) {
                                envelope = envelopes.get(note);
                            }
                        }
                        
                        // Skip notes with completed envelopes
                        if (envelope != null && !envelope.isActive()) {
                            notesToRemove.add(note);
                            continue;
                        }
                        
                        hasActiveNotes = true;
                        
                        // Check if we have a sample for this note
                        boolean hasSample = false;
                        synchronized (instrumentSamples) {
                            Map<Integer, short[]> samples = instrumentSamples.get(instrumentId);
                            if (samples != null && samples.containsKey(note)) {
                                hasSample = true;
                            }
                        }
                        
                        if (hasSample && (instrument.getType() == InstrumentType.SAMPLE_BASED || 
                                         instrument.getType() == InstrumentType.SF2_BASED || 
                                         instrument.getType() == InstrumentType.SFZ_BASED)) {
                            // Render sample-based audio
                            renderSampleAudio(instrumentId, note, envelope, instrument);
                        } else {
                            // Render sine wave as fallback
                            renderSineWaveAudio(instrumentId, note, envelope, instrument);
                        }
                    }
                    
                    // Clean up notes with completed envelopes
                    if (!notesToRemove.isEmpty()) {
                        synchronized (activeNotes) {
                            Set<Integer> currentNotes = activeNotes.get(instrumentId);
                            if (currentNotes != null) {
                                for (int noteToRemove : notesToRemove) {
                                    currentNotes.remove(noteToRemove);
                                    Log.d(TAG, "Removed completed note " + noteToRemove + " from instrument " + instrumentId);
                                    
                                    // Clean up related data
                                    synchronized (noteVelocities) {
                                        Map<Integer, Integer> velocities = noteVelocities.get(instrumentId);
                                        if (velocities != null) {
                                            velocities.remove(noteToRemove);
                                        }
                                    }
                                    
                                    synchronized (notePhases) {
                                        Map<Integer, Float> phases = notePhases.get(instrumentId);
                                        if (phases != null) {
                                            phases.remove(noteToRemove);
                                        }
                                    }
                                    
                                    synchronized (noteEnvelopes) {
                                        Map<Integer, NoteEnvelope> envelopes = noteEnvelopes.get(instrumentId);
                                        if (envelopes != null) {
                                            envelopes.remove(noteToRemove);
                                        }
                                    }
                                    
                                    synchronized (noteStartTimes) {
                                        Map<Integer, Long> startTimes = noteStartTimes.get(instrumentId);
                                        if (startTimes != null) {
                                            startTimes.remove(noteToRemove);
                                        }
                                    }
                                }
                                
                                // Clean up empty sets
                                if (currentNotes.isEmpty()) {
                                    activeNotes.remove(instrumentId);
                                    Log.d(TAG, "Removed empty note set for instrument " + instrumentId);
                                }
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
        SAMPLE_BASED,
        SF2_BASED,
        SFZ_BASED,
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
        private float attack = 0.01f;  // Attack time in seconds
        private float decay = 0.05f;   // Decay time in seconds
        private float sustain = 0.7f;  // Sustain level (0.0 to 1.0)
        private float release = 0.3f;  // Release time in seconds

        // Map of MIDI note numbers to samples
        Map<Integer, Sample> samples = new HashMap<>();

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
        
        public float getAttack() {
            return attack;
        }
        
        public void setAttack(float attack) {
            this.attack = Math.max(0.001f, attack);
        }
        
        public float getDecay() {
            return decay;
        }
        
        public void setDecay(float decay) {
            this.decay = Math.max(0.001f, decay);
        }
        
        public float getSustain() {
            return sustain;
        }
        
        public void setSustain(float sustain) {
            this.sustain = Math.max(0.0f, Math.min(1.0f, sustain));
        }
        
        public float getRelease() {
            return release;
        }
        
        public void setRelease(float release) {
            this.release = Math.max(0.001f, release);
        }
    }
    
    /**
     * Note envelope data class to track the state of each note's envelope.
     */
    private static class NoteEnvelope {
        private static final int STATE_ATTACK = 0;
        private static final int STATE_DECAY = 1;
        private static final int STATE_SUSTAIN = 2;
        private static final int STATE_RELEASE = 3;
        private static final int STATE_OFF = 4;
        
        private int state = STATE_ATTACK;
        private float value = 0.0f;
        private float releaseStartValue = 0.0f;
        private long startTimeMs = 0;
        private long releaseStartTimeMs = 0;
        
        public NoteEnvelope() {
            startTimeMs = System.currentTimeMillis();
        }
        
        public void release() {
            if (state != STATE_OFF) {
                state = STATE_RELEASE;
                releaseStartValue = value;
                releaseStartTimeMs = System.currentTimeMillis();
            }
        }
        
        public float getValue(Instrument instrument) {
            long currentTimeMs = System.currentTimeMillis();
            float elapsedSec = (currentTimeMs - startTimeMs) / 1000.0f;
            
            switch (state) {
                case STATE_ATTACK:
                    if (instrument.getAttack() <= 0) {
                        value = 1.0f;
                        state = STATE_DECAY;
                    } else {
                        value = Math.min(1.0f, elapsedSec / instrument.getAttack());
                        if (value >= 1.0f) {
                            state = STATE_DECAY;
                        }
                    }
                    break;
                    
                case STATE_DECAY:
                    float decayElapsed = elapsedSec - instrument.getAttack();
                    if (instrument.getDecay() <= 0) {
                        value = instrument.getSustain();
                        state = STATE_SUSTAIN;
                    } else {
                        float decayProgress = Math.min(1.0f, decayElapsed / instrument.getDecay());
                        value = 1.0f - (decayProgress * (1.0f - instrument.getSustain()));
                        if (decayProgress >= 1.0f) {
                            state = STATE_SUSTAIN;
                        }
                    }
                    break;
                    
                case STATE_SUSTAIN:
                    value = instrument.getSustain();
                    break;
                    
                case STATE_RELEASE:
                    float releaseElapsedSec = (currentTimeMs - releaseStartTimeMs) / 1000.0f;
                    if (instrument.getRelease() <= 0) {
                        value = 0.0f;
                        state = STATE_OFF;
                    } else {
                        float releaseProgress = Math.min(1.0f, releaseElapsedSec / instrument.getRelease());
                        value = releaseStartValue * (1.0f - releaseProgress);
                        if (releaseProgress >= 1.0f) {
                            value = 0.0f;
                            state = STATE_OFF;
                        }
                    }
                    break;
                    
                case STATE_OFF:
                    value = 0.0f;
                    break;
            }
            
            return value;
        }
        
        public boolean isActive() {
            return state != STATE_OFF;
        }
    }

    /**
     * Set ADSR envelope parameters for an instrument.
     */
    public boolean setInstrumentEnvelope(int instrumentId, float attack, float decay, float sustain, float release) {
        Log.d(TAG, "Setting envelope for instrument " + instrumentId + 
              ": A=" + attack + ", D=" + decay + ", S=" + sustain + ", R=" + release);

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        synchronized (instruments) {
            Instrument instrument = instruments.get(instrumentId);
            if (instrument == null) {
                Log.w(TAG, "Instrument with ID " + instrumentId + " not found for envelope setting");
                return false;
            }

            // Set envelope parameters with validation
            instrument.setAttack(Math.max(0.001f, attack));
            instrument.setDecay(Math.max(0.001f, decay));
            instrument.setSustain(Math.max(0.0f, Math.min(1.0f, sustain)));
            instrument.setRelease(Math.max(0.001f, release));
            
            Log.d(TAG, "Envelope changed for instrument " + instrumentId);
            return true;
        }
    }

    /**
     * Create an instrument with the specified parameters.
     */
    public boolean createInstrument(int instrumentId, String name, String type, float volume) {
        Log.i(TAG, "Creating instrument: " + name + ", type: " + type + ", id: " + instrumentId);

        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }

        try {
            synchronized (instruments) {
                // Check if instrument with this ID already exists
                if (instruments.containsKey(instrumentId)) {
                    Log.w(TAG, "Instrument with ID " + instrumentId + " already exists");
                    return false;
                }

                // Determine instrument type
                InstrumentType instrumentType = InstrumentType.UNKNOWN;
                if (type.equalsIgnoreCase("sine") || type.equalsIgnoreCase("sine_wave")) {
                    instrumentType = InstrumentType.SINE_WAVE;
                } else if (type.equalsIgnoreCase("sf2")) {
                    instrumentType = InstrumentType.SF2_BASED;
                } else if (type.equalsIgnoreCase("sample")) {
                    instrumentType = InstrumentType.SAMPLE_BASED;
                } else if (type.equalsIgnoreCase("sfz")) {
                    instrumentType = InstrumentType.SFZ_BASED;
                }

                // Create instrument
                Instrument instrument = new Instrument(
                        instrumentId,
                        name,
                        instrumentType,
                        volume
                );

                instruments.put(instrumentId, instrument);
                Log.i(TAG, "Successfully created instrument '" + name + "' with ID: " + instrumentId);
                return true;
            }
        } catch (Exception e) {
            Log.e(TAG, "Exception in createInstrument: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }

    /**
     * Get the next available instrument ID.
     */
    public synchronized int getNextInstrumentId() {
        int id = nextInstrumentId++;
        Log.d(TAG, "Generated new instrument ID: " + id);
        return id;
    }

    /**
     * Load a sample for an instrument at a specific note.
     */
    public boolean loadSample(int instrumentId, int noteNumber, String samplePath, int sampleRate) {
        Log.i(TAG, "Loading sample for instrument " + instrumentId + ", note " + noteNumber + ": " + samplePath);
        
        if (!isInitialized.get()) {
            Log.e(TAG, "AudioEngine not initialized");
            return false;
        }
        
        synchronized (instruments) {
            Instrument instrument = instruments.get(instrumentId);
            if (instrument == null) {
                Log.e(TAG, "Instrument with ID " + instrumentId + " not found");
                return false;
            }
            
            // Update instrument type if needed
            if (instrument.getType() != InstrumentType.SAMPLE_BASED && 
                instrument.getType() != InstrumentType.SF2_BASED && 
                instrument.getType() != InstrumentType.SFZ_BASED) {
                // This is a hack - we should create a proper subclass for sample instruments
                Log.i(TAG, "Converting instrument " + instrumentId + " to sample-based");
                Instrument newInstrument = new Instrument(
                    instrument.getId(),
                    instrument.getName(),
                    InstrumentType.SAMPLE_BASED,
                    instrument.getVolume()
                );
                newInstrument.setAttack(instrument.getAttack());
                newInstrument.setDecay(instrument.getDecay());
                newInstrument.setSustain(instrument.getSustain());
                newInstrument.setRelease(instrument.getRelease());
                instruments.put(instrumentId, newInstrument);
                instrument = newInstrument;
            }
        }
        
        try {
            // Load the sample file
            java.io.File file = new java.io.File(samplePath);
            if (!file.exists()) {
                Log.e(TAG, "Sample file not found: " + samplePath);
                return false;
            }
            
            // Read the WAV file
            short[] sampleData = loadWavFile(file);
            if (sampleData == null) {
                Log.e(TAG, "Failed to load WAV file: " + samplePath);
                return false;
            }
            
            // Store the sample data
            synchronized (instrumentSamples) {
                Map<Integer, short[]> samples = instrumentSamples.get(instrumentId);
                if (samples == null) {
                    samples = new HashMap<>();
                    instrumentSamples.put(instrumentId, samples);
                }
                samples.put(noteNumber, sampleData);
            }
            
            // Store the sample rate
            synchronized (sampleRates) {
                Map<Integer, Integer> rates = sampleRates.get(instrumentId);
                if (rates == null) {
                    rates = new HashMap<>();
                    sampleRates.put(instrumentId, rates);
                }
                rates.put(noteNumber, sampleRate);
            }
            
            Log.i(TAG, "Successfully loaded sample for instrument " + instrumentId + ", note " + noteNumber);
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Exception loading sample: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
    
    /**
     * Load a WAV file and return the sample data.
     */
    private short[] loadWavFile(java.io.File file) {
        try {
            Log.i(TAG, "Loading WAV file: " + file.getAbsolutePath());
            java.io.FileInputStream fis = new java.io.FileInputStream(file);
            java.io.BufferedInputStream bis = new java.io.BufferedInputStream(fis);
            
            // Read WAV header
            byte[] header = new byte[12]; // RIFF header + chunk size + WAVE
            if (bis.read(header, 0, header.length) != header.length) {
                Log.e(TAG, "Failed to read WAV header");
                bis.close();
                return null;
            }
            
            // Verify it's a WAV file (RIFF header)
            if (header[0] != 'R' || header[1] != 'I' || header[2] != 'F' || header[3] != 'F') {
                Log.e(TAG, "Not a valid WAV file (missing RIFF header)");
                bis.close();
                return null;
            }
            
            // Check format (should be WAVE)
            if (header[8] != 'W' || header[9] != 'A' || header[10] != 'V' || header[11] != 'E') {
                Log.e(TAG, "Not a valid WAV file (missing WAVE format)");
                bis.close();
                return null;
            }
            
            // Variables to store format information
            int format = 1; // Default to PCM
            int channels = 1;
            int sampleRate = 44100;
            int bitsPerSample = 16;
            int dataSize = 0;
            
            // Read chunks until we find the data chunk
            byte[] chunkHeader = new byte[8];
            boolean foundFmt = false;
            boolean foundData = false;
            
            while (!foundData) {
                int bytesRead = bis.read(chunkHeader, 0, chunkHeader.length);
                if (bytesRead < chunkHeader.length) {
                    if (!foundFmt) {
                        Log.e(TAG, "Unexpected end of file before fmt chunk");
                        bis.close();
                        return null;
                    }
                    
                    // If we've found the fmt chunk but not the data chunk, we'll try to create
                    // a silent sample with default parameters
                    Log.w(TAG, "Reached end of file without finding data chunk, creating silent sample");
                    short[] silentSample = new short[sampleRate]; // 1 second of silence
                    bis.close();
                    return silentSample;
                }
                
                // Get chunk ID as string
                String chunkId = new String(chunkHeader, 0, 4);
                
                // Get chunk size (little endian)
                int chunkSize = ((chunkHeader[7] & 0xFF) << 24) | ((chunkHeader[6] & 0xFF) << 16) | 
                               ((chunkHeader[5] & 0xFF) << 8) | (chunkHeader[4] & 0xFF);
                
                Log.d(TAG, "Found chunk: " + chunkId + " with size: " + chunkSize);
                
                if (chunkId.equals("fmt ")) {
                    // Format chunk
                    foundFmt = true;
                    
                    // Read format chunk
                    byte[] fmtChunk = new byte[Math.min(chunkSize, 16)]; // Read at least the basic format info
                    if (bis.read(fmtChunk, 0, fmtChunk.length) != fmtChunk.length) {
                        Log.e(TAG, "Failed to read format chunk");
                        bis.close();
                        return null;
                    }
                    
                    // Get format code (little endian)
                    format = ((fmtChunk[1] & 0xFF) << 8) | (fmtChunk[0] & 0xFF);
                    
                    // Get number of channels (little endian)
                    channels = ((fmtChunk[3] & 0xFF) << 8) | (fmtChunk[2] & 0xFF);
                    
                    // Get sample rate (little endian)
                    sampleRate = ((fmtChunk[7] & 0xFF) << 24) | ((fmtChunk[6] & 0xFF) << 16) | 
                                ((fmtChunk[5] & 0xFF) << 8) | (fmtChunk[4] & 0xFF);
                    
                    // Skip to bits per sample if we read less than the full chunk
                    if (fmtChunk.length >= 16) {
                        // Get bits per sample (little endian)
                        bitsPerSample = ((fmtChunk[15] & 0xFF) << 8) | (fmtChunk[14] & 0xFF);
                    } else {
                        // Skip the rest of the chunk
                        bis.skip(chunkSize - fmtChunk.length);
                    }
                    
                    // Log format information
                    Log.i(TAG, "WAV format: " + format + ", channels: " + channels + 
                          ", sample rate: " + sampleRate + ", bits per sample: " + bitsPerSample);
                    
                    // Check if format is supported
                    // We'll support PCM (1) and also try to handle format code 26548 that appears in our WAV files
                    if (format != 1 && format != 26548) {
                        Log.w(TAG, "Unsupported WAV format (not PCM): " + format + " - will try to read anyway");
                    }
                } else if (chunkId.equals("data")) {
                    // Data chunk
                    foundData = true;
                    dataSize = chunkSize;
                    
                    // Log data size
                    Log.i(TAG, "WAV data size: " + dataSize + " bytes");
                    
                    // If we haven't found the format chunk yet, use default values
                    if (!foundFmt) {
                        Log.w(TAG, "No format chunk found before data chunk, using default values");
                    }
                    
                    // Calculate number of samples
                    int bytesPerSample = bitsPerSample / 8;
                    int samplesPerChannel = dataSize / (bytesPerSample * channels);
                    
                    // Read sample data
                    short[] sampleData;
                    
                    if (channels == 1) {
                        // Mono
                        sampleData = new short[samplesPerChannel];
                        
                        if (bitsPerSample == 16) {
                            // 16-bit samples
                            byte[] buffer = new byte[dataSize];
                            int bytesRead = bis.read(buffer, 0, buffer.length);
                            
                            if (bytesRead < buffer.length) {
                                Log.w(TAG, "Read fewer bytes than expected: " + bytesRead + " vs " + buffer.length);
                                // Adjust the number of samples
                                samplesPerChannel = bytesRead / 2;
                                sampleData = new short[samplesPerChannel];
                            }
                            
                            for (int i = 0; i < samplesPerChannel; i++) {
                                // Convert bytes to short (little endian)
                                if (i * 2 + 1 < bytesRead) {
                                    sampleData[i] = (short)(((buffer[i * 2 + 1] & 0xFF) << 8) | (buffer[i * 2] & 0xFF));
                                } else if (i * 2 < bytesRead) {
                                    // Handle odd number of bytes
                                    sampleData[i] = (short)(buffer[i * 2] & 0xFF);
                                } else {
                                    // Pad with zeros if we run out of data
                                    sampleData[i] = 0;
                                }
                            }
                        } else if (bitsPerSample == 8) {
                            // 8-bit samples
                            byte[] buffer = new byte[dataSize];
                            int bytesRead = bis.read(buffer, 0, buffer.length);
                            
                            if (bytesRead < buffer.length) {
                                Log.w(TAG, "Read fewer bytes than expected: " + bytesRead + " vs " + buffer.length);
                                // Adjust the number of samples
                                samplesPerChannel = bytesRead;
                                sampleData = new short[samplesPerChannel];
                            }
                            
                            for (int i = 0; i < samplesPerChannel; i++) {
                                if (i < bytesRead) {
                                    // Convert 8-bit unsigned to 16-bit signed
                                    sampleData[i] = (short)(((buffer[i] & 0xFF) - 128) * 256);
                                } else {
                                    // Pad with zeros if we run out of data
                                    sampleData[i] = 0;
                                }
                            }
                        } else {
                            Log.e(TAG, "Unsupported bits per sample: " + bitsPerSample);
                            bis.close();
                            return null;
                        }
                    } else if (channels == 2) {
                        // Stereo - we'll convert to mono by averaging channels
                        sampleData = new short[samplesPerChannel];
                        
                        if (bitsPerSample == 16) {
                            // 16-bit samples
                            byte[] buffer = new byte[dataSize];
                            int bytesRead = bis.read(buffer, 0, buffer.length);
                            
                            if (bytesRead < buffer.length) {
                                Log.w(TAG, "Read fewer bytes than expected: " + bytesRead + " vs " + buffer.length);
                                // Adjust the number of samples
                                samplesPerChannel = bytesRead / 4;
                                sampleData = new short[samplesPerChannel];
                            }
                            
                            for (int i = 0; i < samplesPerChannel; i++) {
                                if (i * 4 + 3 < bytesRead) {
                                    // Convert bytes to short (little endian)
                                    short left = (short)(((buffer[i * 4 + 1] & 0xFF) << 8) | (buffer[i * 4] & 0xFF));
                                    short right = (short)(((buffer[i * 4 + 3] & 0xFF) << 8) | (buffer[i * 4 + 2] & 0xFF));
                                    
                                    // Average the channels
                                    sampleData[i] = (short)((left + right) / 2);
                                } else if (i * 4 + 1 < bytesRead) {
                                    // We have at least the left channel
                                    short left = (short)(((buffer[i * 4 + 1] & 0xFF) << 8) | (buffer[i * 4] & 0xFF));
                                    sampleData[i] = left;
                                } else if (i * 4 < bytesRead) {
                                    // Handle odd number of bytes
                                    sampleData[i] = (short)(buffer[i * 4] & 0xFF);
                                } else {
                                    // Pad with zeros if we run out of data
                                    sampleData[i] = 0;
                                }
                            }
                        } else if (bitsPerSample == 8) {
                            // 8-bit samples
                            byte[] buffer = new byte[dataSize];
                            int bytesRead = bis.read(buffer, 0, buffer.length);
                            
                            if (bytesRead < buffer.length) {
                                Log.w(TAG, "Read fewer bytes than expected: " + bytesRead + " vs " + buffer.length);
                                // Adjust the number of samples
                                samplesPerChannel = bytesRead / 2;
                                sampleData = new short[samplesPerChannel];
                            }
                            
                            for (int i = 0; i < samplesPerChannel; i++) {
                                if (i * 2 + 1 < bytesRead) {
                                    // Convert 8-bit unsigned to 16-bit signed and average channels
                                    short left = (short)(((buffer[i * 2] & 0xFF) - 128) * 256);
                                    short right = (short)(((buffer[i * 2 + 1] & 0xFF) - 128) * 256);
                                    
                                    // Average the channels
                                    sampleData[i] = (short)((left + right) / 2);
                                } else if (i * 2 < bytesRead) {
                                    // We have at least the left channel
                                    short left = (short)(((buffer[i * 2] & 0xFF) - 128) * 256);
                                    sampleData[i] = left;
                                } else {
                                    // Pad with zeros if we run out of data
                                    sampleData[i] = 0;
                                }
                            }
                        } else {
                            Log.e(TAG, "Unsupported bits per sample: " + bitsPerSample);
                            bis.close();
                            return null;
                        }
                    } else {
                        // More than 2 channels - we'll convert to mono by reading only the first channel
                        Log.w(TAG, "WAV file has " + channels + " channels, will use only the first channel");
                        
                        sampleData = new short[samplesPerChannel];
                        int bytesPerFrame = bytesPerSample * channels;
                        
                        if (bitsPerSample == 16) {
                            // 16-bit samples
                            byte[] buffer = new byte[dataSize];
                            int bytesRead = bis.read(buffer, 0, buffer.length);
                            
                            for (int i = 0; i < samplesPerChannel; i++) {
                                if (i * bytesPerFrame + 1 < bytesRead) {
                                    // Convert bytes to short (little endian) - first channel only
                                    sampleData[i] = (short)(((buffer[i * bytesPerFrame + 1] & 0xFF) << 8) | 
                                                           (buffer[i * bytesPerFrame] & 0xFF));
                                } else if (i * bytesPerFrame < bytesRead) {
                                    // Handle odd number of bytes
                                    sampleData[i] = (short)(buffer[i * bytesPerFrame] & 0xFF);
                                } else {
                                    // Pad with zeros if we run out of data
                                    sampleData[i] = 0;
                                }
                            }
                        } else if (bitsPerSample == 8) {
                            // 8-bit samples
                            byte[] buffer = new byte[dataSize];
                            int bytesRead = bis.read(buffer, 0, buffer.length);
                            
                            for (int i = 0; i < samplesPerChannel; i++) {
                                if (i * bytesPerFrame < bytesRead) {
                                    // Convert 8-bit unsigned to 16-bit signed - first channel only
                                    sampleData[i] = (short)(((buffer[i * bytesPerFrame] & 0xFF) - 128) * 256);
                                } else {
                                    // Pad with zeros if we run out of data
                                    sampleData[i] = 0;
                                }
                            }
                        } else {
                            Log.e(TAG, "Unsupported bits per sample: " + bitsPerSample);
                            bis.close();
                            return null;
                        }
                    }
                    
                    bis.close();
                    Log.i(TAG, "Successfully loaded WAV file: " + file.getName() + 
                          " (format: " + format + ", channels: " + channels + ", sample rate: " + sampleRate + 
                          ", bits: " + bitsPerSample + ", samples: " + sampleData.length + ")");
                    
                    return sampleData;
                } else {
                    // Skip unknown chunk
                    Log.d(TAG, "Skipping unknown chunk: " + chunkId + " with size: " + chunkSize);
                    bis.skip(chunkSize);
                }
            }
            
            // We should never reach here if we found the data chunk
            Log.e(TAG, "Failed to find data chunk in WAV file");
            bis.close();
            return null;
        } catch (Exception e) {
            Log.e(TAG, "Exception loading WAV file: " + e.getMessage());
            e.printStackTrace();
            return null;
        }
    }
    
    /**
     * Render audio for a sample-based note.
     */
    private void renderSampleAudio(int instrumentId, int note, NoteEnvelope envelope, Instrument instrument) {
        // Get sample data
        short[] sampleData = null;
        synchronized (instrumentSamples) {
            Map<Integer, short[]> samples = instrumentSamples.get(instrumentId);
            if (samples != null) {
                sampleData = samples.get(note);
            }
        }
        
        if (sampleData == null) {
            // Fallback to sine wave if no sample data
            renderSineWaveAudio(instrumentId, note, envelope, instrument);
            return;
        }
        
        // Get sample playback position
        long noteStartTime = 0;
        synchronized (noteStartTimes) {
            Map<Integer, Long> startTimes = noteStartTimes.get(instrumentId);
            if (startTimes != null) {
                Long startTime = startTimes.get(note);
                if (startTime != null) {
                    noteStartTime = startTime;
                }
            }
        }
        
        // Get sample rate
        int sampleRate = this.sampleRate;
        synchronized (sampleRates) {
            Map<Integer, Integer> rates = sampleRates.get(instrumentId);
            if (rates != null) {
                Integer rate = rates.get(note);
                if (rate != null) {
                    sampleRate = rate;
                }
            }
        }
        
        // Calculate base amplitude - reduce as more notes are active
        float baseAmplitude = 0.15f;
        
        // Apply instrument volume
        float instrumentAmplitude = baseAmplitude * instrument.getVolume();
        
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
        
        // Apply envelope if available
        if (envelope != null) {
            amplitude *= envelope.getValue(instrument);
        }
        
        // Apply master volume
        amplitude *= masterVolume;
        
        // Calculate elapsed time and sample position
        long elapsedMs = System.currentTimeMillis() - noteStartTime;
        double elapsedSec = elapsedMs / 1000.0;
        
        // Calculate sample position
        double samplePos = elapsedSec * sampleRate;
        int samplePosInt = (int)samplePos;
        
        // Check if we've reached the end of the sample
        if (samplePosInt >= sampleData.length) {
            // Loop or stop
            if (envelope != null && envelope.isActive()) {
                // Loop the sample
                samplePosInt = samplePosInt % sampleData.length;
            } else {
                // End of sample and envelope is done
                return;
            }
        }
        
        // Calculate sample rate conversion ratio
        double sampleRateRatio = (double)sampleRate / this.sampleRate;
        
        // Render the sample
        for (int i = 0; i < framesPerBuffer; i++) {
            // Calculate sample index with rate conversion
            int sampleIndex = samplePosInt + (int)(i * sampleRateRatio);
            
            // Check bounds
            if (sampleIndex >= sampleData.length) {
                // Loop or stop
                if (envelope != null && envelope.isActive()) {
                    // Loop the sample
                    sampleIndex = sampleIndex % sampleData.length;
                } else {
                    // End of sample
                    break;
                }
            }
            
            // Get sample value and normalize to -1.0 to 1.0
            float sampleValue = sampleData[sampleIndex] / 32768.0f;
            
            // Apply amplitude
            sampleValue *= amplitude;
            
            // Mix into output buffer (stereo)
            floatBuffer[i * 2] += sampleValue;     // Left channel
            floatBuffer[i * 2 + 1] += sampleValue; // Right channel
        }
    }
    
    /**
     * Render audio for a sine wave note.
     */
    private void renderSineWaveAudio(int instrumentId, int note, NoteEnvelope envelope, Instrument instrument) {
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
        
        // Calculate base amplitude - reduce as more notes are active
        float baseAmplitude = 0.15f;
        
        // Apply instrument volume
        float instrumentAmplitude = baseAmplitude * instrument.getVolume();
        
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
        
        // Apply envelope if available
        if (envelope != null) {
            amplitude *= envelope.getValue(instrument);
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

    /**
     * Store sample data for an instrument.
     * 
     * @param instrumentId The ID of the instrument to store the sample for.
     * @param note The MIDI note number to associate with this sample.
     * @param sampleData The audio sample data as an array of shorts.
     * @param sampleRate The sample rate of the audio data.
     * @return true if the sample was stored successfully, false otherwise.
     */
    public boolean storeSampleData(int instrumentId, int note, short[] sampleData, int sampleRate) {
        if (!isInitialized()) {
            Log.e(TAG, "Audio engine not initialized");
            return false;
        }
        
        if (!instruments.containsKey(instrumentId)) {
            Log.e(TAG, "Instrument with ID " + instrumentId + " does not exist");
            return false;
        }
        
        try {
            // Get the instrument
            Instrument instrument = instruments.get(instrumentId);
            
            // Create a new sample
            Sample sample = new Sample();
            sample.sampleData = sampleData;
            sample.sampleRate = sampleRate;
            sample.numChannels = 1; // Mono
            sample.bitsPerSample = 16; // 16-bit
            
            // Store the sample in the instrument
            instrument.samples.put(note, sample);
            
            Log.i(TAG, "Stored sample data for instrument " + instrumentId + ", note " + note + 
                  " (" + sampleData.length + " samples at " + sampleRate + " Hz)");
            
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Exception in storeSampleData: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
    
    // Inner class to represent a sample
    private class Sample {
        short[] sampleData;
        int sampleRate;
        int numChannels;
        int bitsPerSample;
    }
} 
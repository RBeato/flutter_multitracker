package com.example.flutter_multitracker;

import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import java.util.Timer;
import java.util.TimerTask;
import java.io.File;

/** FlutterMultitrackerPlugin */
public class FlutterMultitrackerPlugin implements FlutterPlugin, MethodCallHandler {
  private static final String TAG = "FlutterMultitrackerPlugin";
  private MethodChannel channel;
  private AudioEngine audioEngine;
  private SequenceManager sequenceManager;
  private Timer sequenceTimer;
  
  // Timer interval for processing sequence notes (in milliseconds)
  private static final int SEQUENCE_TIMER_INTERVAL = 20;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_multitracker");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    try {
      switch (call.method) {
        case "getPlatformVersion":
          result.success("Android " + android.os.Build.VERSION.RELEASE);
          break;
        case "initialize":
          result.success(initialize());
          break;
        case "createInstrument":
          result.success(createInstrument(call, result));
          break;
        case "setInstrumentVolume":
          result.success(setInstrumentVolume(call, result));
          break;
        case "setInstrumentEnvelope":
          result.success(setInstrumentEnvelope(call, result));
          break;
        case "setMasterVolume":
          result.success(setMasterVolume(call, result));
          break;
        case "noteOn":
          result.success(sendNoteOn(call, result));
          break;
        case "noteOff":
          result.success(sendNoteOff(call, result));
          break;
        case "loadSample":
          result.success(loadSample(call, result));
          break;
        case "loadInstrumentFromSF2":
          result.success(loadInstrumentFromSF2(call, result));
          break;
        case "loadInstrumentFromSFZ":
          result.success(loadInstrumentFromSFZ(call, result));
          break;
        case "cleanup":
          result.success(cleanup());
          break;
        // Sequence methods
        case "createSequence":
          result.success(createSequence(call, result));
          break;
        case "deleteSequence":
          result.success(deleteSequence(call, result));
          break;
        case "addTrack":
          result.success(addTrack(call, result));
          break;
        case "deleteTrack":
          result.success(deleteTrack(call, result));
          break;
        case "addNote":
          result.success(addNote(call, result));
          break;
        case "deleteNote":
          result.success(deleteNote(call, result));
          break;
        case "startPlayback":
          result.success(startPlayback(call, result));
          break;
        case "stopPlayback":
          result.success(stopPlayback(call, result));
          break;
        case "setTempo":
          result.success(setTempo(call, result));
          break;
        case "setLoop":
          result.success(setLoop(call, result));
          break;
        case "unsetLoop":
          result.success(unsetLoop(call, result));
          break;
        case "setBeat":
          result.success(setBeat(call, result));
          break;
        case "setEndBeat":
          result.success(setEndBeat(call, result));
          break;
        case "getPosition":
          result.success(getPosition(call, result));
          break;
        case "getIsPlaying":
          result.success(getIsPlaying(call, result));
          break;
        // New method
        case "loadPianoInstrument":
          result.success(loadPianoInstrument(call, result));
          break;
        default:
          result.notImplemented();
          break;
      }
    } catch (Exception e) {
      Log.e(TAG, "Exception in method call: " + e.getMessage());
      e.printStackTrace();
      result.error("EXCEPTION", "Exception in method call: " + e.getMessage(), e.toString());
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
    cleanup();
  }

  private boolean initialize() {
    try {
      if (audioEngine == null) {
        audioEngine = new AudioEngine();
      }
      
      boolean success = audioEngine.init(44100);
      if (success) {
        // Start the audio engine
        success = audioEngine.start();
        if (success) {
          // Create a default sine wave instrument with ID 0
          createDefaultInstrument();
          
          // Initialize sequence manager
          if (sequenceManager == null) {
            sequenceManager = new SequenceManager(audioEngine);
            sequenceManager.init();
            
            // Start sequence timer
            startSequenceTimer();
          }
          
          Log.i(TAG, "Audio engine and sequence manager initialized successfully");
        } else {
          Log.e(TAG, "Failed to start audio engine");
        }
      } else {
        Log.e(TAG, "Failed to initialize audio engine");
      }
      
      return success;
    } catch (Exception e) {
      Log.e(TAG, "Exception in initialize: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private void startSequenceTimer() {
    if (sequenceTimer != null) {
      sequenceTimer.cancel();
    }
    
    sequenceTimer = new Timer();
    sequenceTimer.scheduleAtFixedRate(new TimerTask() {
      @Override
      public void run() {
        if (sequenceManager != null) {
          sequenceManager.processActiveNotes();
        }
      }
    }, 0, SEQUENCE_TIMER_INTERVAL);
    
    Log.d(TAG, "Sequence timer started");
  }

  private void createDefaultInstrument() {
    try {
      // Create a default sine wave instrument with ID 0
      if (audioEngine != null) {
        // Use the public methods to create an instrument
        audioEngine.createInstrument(0, "Default Sine", "sine", 0.8f);
        
        // Set default envelope parameters
        audioEngine.setInstrumentEnvelope(0, 0.01f, 0.05f, 0.7f, 0.3f);
        
        Log.i(TAG, "Created default instrument");
      }
    } catch (Exception e) {
      Log.e(TAG, "Exception creating default instrument: " + e.getMessage());
      e.printStackTrace();
    }
  }

  private int createInstrument(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return -1;
      }
      
      String name = call.argument("name");
      String type = call.argument("type");
      
      if (name == null || type == null) {
        Log.e(TAG, "Missing required parameters for createInstrument");
        return -1;
      }
      
      // Generate a new instrument ID
      int instrumentId = audioEngine.getNextInstrumentId();
      
      // Default volume if not provided
      double volume = 0.8;
      if (call.hasArgument("volume")) {
        volume = call.argument("volume");
      }
      
      boolean success = audioEngine.createInstrument(instrumentId, name, type, (float)volume);
      
      if (success) {
        return instrumentId;
      } else {
        return -1;
      }
    } catch (Exception e) {
      Log.e(TAG, "Exception in createInstrument: " + e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }

  private boolean setInstrumentVolume(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return false;
      }
      
      int instrumentId = call.argument("instrumentId");
      double volume = call.argument("volume");
      
      audioEngine.setInstrumentVolume(instrumentId, (float)volume);
      return true;
    } catch (Exception e) {
      Log.e(TAG, "Exception in setInstrumentVolume: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  private boolean setInstrumentEnvelope(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return false;
      }
      
      int instrumentId = call.argument("instrumentId");
      double attack = call.argument("attack");
      double decay = call.argument("decay");
      double sustain = call.argument("sustain");
      double release = call.argument("release");
      
      return audioEngine.setInstrumentEnvelope(instrumentId, (float)attack, (float)decay, (float)sustain, (float)release);
    } catch (Exception e) {
      Log.e(TAG, "Exception in setInstrumentEnvelope: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  private boolean setMasterVolume(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return false;
      }
      
      double volume = call.argument("volume");
      
      audioEngine.setMasterVolume((float)volume);
      return true;
    } catch (Exception e) {
      Log.e(TAG, "Exception in setMasterVolume: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  private boolean sendNoteOn(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return false;
      }
      
      int instrumentId = call.argument("instrumentId");
      int noteNumber = call.argument("noteNumber");
      int velocity = call.argument("velocity");
      
      return audioEngine.sendNoteOn(instrumentId, noteNumber, velocity);
    } catch (Exception e) {
      Log.e(TAG, "Exception in sendNoteOn: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  private boolean sendNoteOff(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return false;
      }
      
      int instrumentId = call.argument("instrumentId");
      int noteNumber = call.argument("noteNumber");
      
      return audioEngine.sendNoteOff(instrumentId, noteNumber);
    } catch (Exception e) {
      Log.e(TAG, "Exception in sendNoteOff: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  // Sequence methods
  
  private int createSequence(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return -1;
      }
      
      int tempo = call.argument("tempo");
      
      return sequenceManager.createSequence(tempo);
    } catch (Exception e) {
      Log.e(TAG, "Exception in createSequence: " + e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }
  
  private boolean deleteSequence(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      
      return sequenceManager.deleteSequence(sequenceId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in deleteSequence: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private int addTrack(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return -1;
      }
      
      int sequenceId = call.argument("sequenceId");
      int instrumentId = call.argument("instrumentId");
      
      return sequenceManager.addTrack(sequenceId, instrumentId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in addTrack: " + e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }
  
  private boolean deleteTrack(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      int trackId = call.argument("trackId");
      
      return sequenceManager.deleteTrack(sequenceId, trackId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in deleteTrack: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private int addNote(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return -1;
      }
      
      int sequenceId = call.argument("sequenceId");
      int trackId = call.argument("trackId");
      int noteNumber = call.argument("noteNumber");
      int velocity = call.argument("velocity");
      double startTime = call.argument("startTime");
      double duration = call.argument("duration");
      
      return sequenceManager.addNote(sequenceId, trackId, noteNumber, velocity, startTime, duration);
    } catch (Exception e) {
      Log.e(TAG, "Exception in addNote: " + e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }
  
  private boolean deleteNote(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      int trackId = call.argument("trackId");
      int noteId = call.argument("noteId");
      
      return sequenceManager.deleteNote(sequenceId, trackId, noteId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in deleteNote: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private boolean startPlayback(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      
      return sequenceManager.startPlayback(sequenceId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in startPlayback: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private boolean stopPlayback(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      // If sequenceId is provided, stop that specific sequence
      if (call.hasArgument("sequenceId")) {
        int sequenceId = call.argument("sequenceId");
        return sequenceManager.stopPlayback(sequenceId);
      }
      
      // Otherwise, stop all sequences (not implemented yet)
      Log.w(TAG, "Stopping all sequences not implemented yet");
      return false;
    } catch (Exception e) {
      Log.e(TAG, "Exception in stopPlayback: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private boolean setTempo(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      double tempo = call.argument("tempo");
      
      return sequenceManager.setTempo(sequenceId, tempo);
    } catch (Exception e) {
      Log.e(TAG, "Exception in setTempo: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private boolean setLoop(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      double loopStartBeat = call.argument("loopStartBeat");
      double loopEndBeat = call.argument("loopEndBeat");
      
      return sequenceManager.setLoop(sequenceId, loopStartBeat, loopEndBeat);
    } catch (Exception e) {
      Log.e(TAG, "Exception in setLoop: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private boolean unsetLoop(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      
      return sequenceManager.unsetLoop(sequenceId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in unsetLoop: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private boolean setBeat(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      double beat = call.argument("beat");
      
      return sequenceManager.setBeat(sequenceId, beat);
    } catch (Exception e) {
      Log.e(TAG, "Exception in setBeat: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private boolean setEndBeat(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      double endBeat = call.argument("endBeat");
      
      return sequenceManager.setEndBeat(sequenceId, endBeat);
    } catch (Exception e) {
      Log.e(TAG, "Exception in setEndBeat: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }
  
  private double getPosition(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return 0.0;
      }
      
      int sequenceId = call.argument("sequenceId");
      
      return sequenceManager.getPosition(sequenceId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in getPosition: " + e.getMessage());
      e.printStackTrace();
      return 0.0;
    }
  }
  
  private boolean getIsPlaying(MethodCall call, Result result) {
    try {
      if (sequenceManager == null) {
        Log.e(TAG, "Sequence manager not initialized");
        return false;
      }
      
      int sequenceId = call.argument("sequenceId");
      
      return sequenceManager.getIsPlaying(sequenceId);
    } catch (Exception e) {
      Log.e(TAG, "Exception in getIsPlaying: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  private boolean cleanup() {
    try {
      // Stop sequence timer
      if (sequenceTimer != null) {
        sequenceTimer.cancel();
        sequenceTimer = null;
      }
      
      // Clean up sequence manager
      if (sequenceManager != null) {
        sequenceManager.cleanup();
        sequenceManager = null;
      }
      
      // Clean up audio engine
      if (audioEngine != null) {
        audioEngine.cleanup();
        audioEngine = null;
        Log.i(TAG, "Audio engine cleaned up successfully");
      }
      return true;
    } catch (Exception e) {
      Log.e(TAG, "Exception in cleanup: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  // Add the loadSample method
  private boolean loadSample(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return false;
      }
      
      int instrumentId = call.argument("instrumentId");
      int noteNumber = call.argument("noteNumber");
      String samplePath = call.argument("samplePath");
      int sampleRate = call.argument("sampleRate");
      
      if (samplePath == null) {
        Log.e(TAG, "Missing required parameter 'samplePath' for loadSample");
        return false;
      }
      
      return audioEngine.loadSample(instrumentId, noteNumber, samplePath, sampleRate);
    } catch (Exception e) {
      Log.e(TAG, "Exception in loadSample: " + e.getMessage());
      e.printStackTrace();
      return false;
    }
  }

  // Add the loadInstrumentFromSF2 method
  private int loadInstrumentFromSF2(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return -1;
      }
      
      String sf2Path = call.argument("sf2Path");
      int preset = call.argument("preset") != null ? call.argument("preset") : 0;
      int bank = call.argument("bank") != null ? call.argument("bank") : 0;
      
      if (sf2Path == null) {
        Log.e(TAG, "Missing required parameter 'sf2Path' for loadInstrumentFromSF2");
        return -1;
      }
      
      // Generate a new instrument ID
      int instrumentId = audioEngine.getNextInstrumentId();
      
      // Create an instrument of type SF2_BASED
      boolean success = audioEngine.createInstrument(instrumentId, "TR-808 Drum Kit", "sf2", 0.8f);
      
      if (!success) {
        Log.e(TAG, "Failed to create SF2 instrument");
        return -1;
      }
      
      Log.i(TAG, "Creating TR-808 drum kit with ID: " + instrumentId);
      
      // Set appropriate envelope for drum sounds (very short attack and release)
      audioEngine.setInstrumentEnvelope(instrumentId, 0.001f, 0.1f, 0.3f, 0.1f);
      
      // Since we don't have actual WAV samples for the TR-808 sounds, we'll create synthetic drum sounds
      // that sound more like TR-808 drums rather than simple sine waves
      
      // Common drum note mappings in General MIDI
      int[] drumNotes = {
        36, // Bass Drum (C2)
        38, // Snare (D2)
        42, // Closed Hi-hat (F#2)
        46, // Open Hi-hat (A#2)
        49, // Crash Cymbal (C#3)
        51  // Ride Cymbal (D#3)
      };
      
      // Create synthetic drum sounds for each note
      for (int note : drumNotes) {
        // Create a synthetic drum sound based on the note
        createSyntheticDrumSound(instrumentId, note);
      }
      
      Log.i(TAG, "Successfully created TR-808 drum kit with ID: " + instrumentId);
      
      // Return the instrument ID
      return instrumentId;
    } catch (Exception e) {
      Log.e(TAG, "Exception in loadInstrumentFromSF2: " + e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }
  
  /**
   * Create a synthetic drum sound for the specified note.
   */
  private void createSyntheticDrumSound(int instrumentId, int note) {
    try {
      // Create a synthetic drum sound based on the note
      short[] sampleData = null;
      int sampleRate = 44100;
      
      switch (note) {
        case 36: // Bass Drum (C2)
          sampleData = createBassDrumSound(sampleRate);
          break;
        case 38: // Snare (D2)
          sampleData = createSnareDrumSound(sampleRate);
          break;
        case 42: // Closed Hi-hat (F#2)
          sampleData = createClosedHiHatSound(sampleRate);
          break;
        case 46: // Open Hi-hat (A#2)
          sampleData = createOpenHiHatSound(sampleRate);
          break;
        case 49: // Crash Cymbal (C#3)
          sampleData = createCrashCymbalSound(sampleRate);
          break;
        case 51: // Ride Cymbal (D#3)
          sampleData = createRideCymbalSound(sampleRate);
          break;
        default:
          // For other notes, create a generic percussion sound
          sampleData = createGenericPercussionSound(sampleRate, note);
          break;
      }
      
      if (sampleData != null) {
        // Store the sample data in the audio engine
        audioEngine.storeSampleData(instrumentId, note, sampleData, sampleRate);
        Log.i(TAG, "Created synthetic drum sound for note " + note);
      }
    } catch (Exception e) {
      Log.e(TAG, "Exception creating synthetic drum sound for note " + note + ": " + e.getMessage());
      e.printStackTrace();
    }
  }
  
  /**
   * Create a synthetic bass drum sound (similar to TR-808 kick).
   */
  private short[] createBassDrumSound(int sampleRate) {
    // Bass drum parameters
    double frequency = 60.0; // Low frequency for bass drum
    double decay = 0.6; // Longer decay for bass drum
    
    // Create a sample buffer for about 1 second
    int numSamples = (int)(sampleRate * 1.0);
    short[] sampleData = new short[numSamples];
    
    // Generate a sine wave with exponential decay and pitch drop
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      double envelope = Math.exp(-time / decay);
      
      // Pitch drop (frequency decreases over time)
      double currentFreq = frequency * (1.0 - 0.5 * Math.min(1.0, time * 4.0));
      
      // Generate sample
      double sample = Math.sin(2.0 * Math.PI * currentFreq * time) * envelope;
      
      // Add some distortion for more punch
      sample = Math.tanh(sample * 2.0) * 0.5;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
  
  /**
   * Create a synthetic snare drum sound (similar to TR-808 snare).
   */
  private short[] createSnareDrumSound(int sampleRate) {
    // Snare drum parameters
    double toneFreq = 180.0; // Mid frequency for snare tone
    double noiseAmount = 0.7; // Amount of noise in the snare
    double decay = 0.2; // Shorter decay for snare
    
    // Create a sample buffer for about 0.5 seconds
    int numSamples = (int)(sampleRate * 0.5);
    short[] sampleData = new short[numSamples];
    
    // Generate a mix of sine wave and noise with exponential decay
    java.util.Random random = new java.util.Random(1234); // Fixed seed for reproducibility
    
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      double envelope = Math.exp(-time / decay);
      
      // Generate tone component
      double tone = Math.sin(2.0 * Math.PI * toneFreq * time);
      
      // Generate noise component
      double noise = 2.0 * random.nextDouble() - 1.0;
      
      // Mix tone and noise
      double sample = ((1.0 - noiseAmount) * tone + noiseAmount * noise) * envelope;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
  
  /**
   * Create a synthetic closed hi-hat sound (similar to TR-808 closed hi-hat).
   */
  private short[] createClosedHiHatSound(int sampleRate) {
    // Closed hi-hat parameters
    double decay = 0.05; // Very short decay for closed hi-hat
    
    // Create a sample buffer for about 0.2 seconds
    int numSamples = (int)(sampleRate * 0.2);
    short[] sampleData = new short[numSamples];
    
    // Generate filtered noise with very short exponential decay
    java.util.Random random = new java.util.Random(5678); // Fixed seed for reproducibility
    
    // Simple high-pass filter state
    double filterState = 0.0;
    double filterCoeff = 0.8; // Higher values = more high frequencies
    
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      double envelope = Math.exp(-time / decay);
      
      // Generate noise
      double noise = 2.0 * random.nextDouble() - 1.0;
      
      // Apply high-pass filter (simple first-order)
      double filtered = filterCoeff * (noise - filterState);
      filterState = noise;
      
      // Apply envelope
      double sample = filtered * envelope;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
  
  /**
   * Create a synthetic open hi-hat sound (similar to TR-808 open hi-hat).
   */
  private short[] createOpenHiHatSound(int sampleRate) {
    // Open hi-hat parameters
    double decay = 0.3; // Longer decay for open hi-hat
    
    // Create a sample buffer for about 0.5 seconds
    int numSamples = (int)(sampleRate * 0.5);
    short[] sampleData = new short[numSamples];
    
    // Generate filtered noise with longer exponential decay
    java.util.Random random = new java.util.Random(9012); // Fixed seed for reproducibility
    
    // Simple high-pass filter state
    double filterState = 0.0;
    double filterCoeff = 0.85; // Higher values = more high frequencies
    
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      double envelope = Math.exp(-time / decay);
      
      // Generate noise
      double noise = 2.0 * random.nextDouble() - 1.0;
      
      // Apply high-pass filter (simple first-order)
      double filtered = filterCoeff * (noise - filterState);
      filterState = noise;
      
      // Apply envelope
      double sample = filtered * envelope;
      
      // Add some resonance for metallic character
      double resonance = Math.sin(2.0 * Math.PI * 6000.0 * time) * 0.1 * envelope;
      sample += resonance;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
  
  /**
   * Create a synthetic crash cymbal sound (similar to TR-808 crash).
   */
  private short[] createCrashCymbalSound(int sampleRate) {
    // Crash cymbal parameters
    double decay = 0.8; // Long decay for crash
    
    // Create a sample buffer for about 2 seconds
    int numSamples = (int)(sampleRate * 2.0);
    short[] sampleData = new short[numSamples];
    
    // Generate filtered noise with long exponential decay
    java.util.Random random = new java.util.Random(3456); // Fixed seed for reproducibility
    
    // Simple high-pass filter state
    double filterState = 0.0;
    double filterCoeff = 0.9; // Higher values = more high frequencies
    
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      double envelope = Math.exp(-time / decay);
      
      // Generate noise
      double noise = 2.0 * random.nextDouble() - 1.0;
      
      // Apply high-pass filter (simple first-order)
      double filtered = filterCoeff * (noise - filterState);
      filterState = noise;
      
      // Apply envelope
      double sample = filtered * envelope;
      
      // Add some resonances for metallic character
      double resonance1 = Math.sin(2.0 * Math.PI * 4000.0 * time) * 0.1 * envelope;
      double resonance2 = Math.sin(2.0 * Math.PI * 6000.0 * time) * 0.05 * envelope;
      sample += resonance1 + resonance2;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
  
  /**
   * Create a synthetic ride cymbal sound (similar to TR-808 ride).
   */
  private short[] createRideCymbalSound(int sampleRate) {
    // Ride cymbal parameters
    double decay = 0.6; // Medium-long decay for ride
    
    // Create a sample buffer for about 1.5 seconds
    int numSamples = (int)(sampleRate * 1.5);
    short[] sampleData = new short[numSamples];
    
    // Generate filtered noise with medium-long exponential decay
    java.util.Random random = new java.util.Random(7890); // Fixed seed for reproducibility
    
    // Simple high-pass filter state
    double filterState = 0.0;
    double filterCoeff = 0.88; // Higher values = more high frequencies
    
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      double envelope = Math.exp(-time / decay);
      
      // Generate noise
      double noise = 2.0 * random.nextDouble() - 1.0;
      
      // Apply high-pass filter (simple first-order)
      double filtered = filterCoeff * (noise - filterState);
      filterState = noise;
      
      // Apply envelope
      double sample = filtered * envelope;
      
      // Add some specific resonances for ride character
      double resonance1 = Math.sin(2.0 * Math.PI * 3000.0 * time) * 0.15 * envelope;
      double resonance2 = Math.sin(2.0 * Math.PI * 5000.0 * time) * 0.1 * envelope;
      sample += resonance1 + resonance2;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
  
  /**
   * Create a generic percussion sound for other notes.
   */
  private short[] createGenericPercussionSound(int sampleRate, int note) {
    // Calculate frequency based on MIDI note number
    double frequency = 440.0 * Math.pow(2.0, (note - 69) / 12.0);
    double decay = 0.3; // Medium decay
    
    // Create a sample buffer for about 0.5 seconds
    int numSamples = (int)(sampleRate * 0.5);
    short[] sampleData = new short[numSamples];
    
    // Generate a mix of sine wave and noise with exponential decay
    java.util.Random random = new java.util.Random(note); // Seed based on note for variety
    
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      double envelope = Math.exp(-time / decay);
      
      // Generate tone component
      double tone = Math.sin(2.0 * Math.PI * frequency * time);
      
      // Generate noise component
      double noise = 2.0 * random.nextDouble() - 1.0;
      
      // Mix tone and noise (more tone for higher notes, more noise for lower notes)
      double noiseAmount = 0.5 - (note - 36) * 0.01; // Adjust based on note
      noiseAmount = Math.max(0.1, Math.min(0.9, noiseAmount)); // Clamp between 0.1 and 0.9
      
      double sample = ((1.0 - noiseAmount) * tone + noiseAmount * noise) * envelope;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
  
  // Helper method to get MIDI note name
  private String getMidiNoteName(int note) {
    String[] noteNames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
    int octave = (note / 12) - 1;
    int noteIndex = note % 12;
    return noteNames[noteIndex] + octave;
  }
  
  // Add the loadInstrumentFromSFZ method
  private int loadInstrumentFromSFZ(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return -1;
      }
      
      String sfzPath = call.argument("sfzPath");
      
      if (sfzPath == null) {
        Log.e(TAG, "Missing required parameter 'sfzPath' for loadInstrumentFromSFZ");
        return -1;
      }
      
      // Generate a new instrument ID
      int instrumentId = audioEngine.getNextInstrumentId();
      
      // Create an instrument of type SFZ_BASED
      boolean success = audioEngine.createInstrument(instrumentId, "SFZ Instrument", "sfz", 0.8f);
      
      if (!success) {
        Log.e(TAG, "Failed to create SFZ instrument");
        return -1;
      }
      
      // For now, we'll load the SFZ as a sample-based instrument
      // In the future, we should implement proper SFZ loading
      Log.i(TAG, "Created SFZ instrument with ID: " + instrumentId);
      
      // Return the instrument ID
      return instrumentId;
    } catch (Exception e) {
      Log.e(TAG, "Exception in loadInstrumentFromSFZ: " + e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }

  // Add a method to load a piano instrument
  private int loadPianoInstrument(MethodCall call, Result result) {
    try {
      if (audioEngine == null) {
        Log.e(TAG, "Audio engine not initialized");
        return -1;
      }
      
      // Generate a new instrument ID
      int instrumentId = audioEngine.getNextInstrumentId();
      
      // Create an instrument of type SAMPLE_BASED
      boolean success = audioEngine.createInstrument(instrumentId, "Piano", "sample", 0.8f);
      
      if (!success) {
        Log.e(TAG, "Failed to create piano instrument");
        return -1;
      }
      
      Log.i(TAG, "Creating piano instrument with ID: " + instrumentId);
      
      // Set appropriate envelope for piano sounds
      audioEngine.setInstrumentEnvelope(instrumentId, 0.01f, 0.1f, 0.7f, 0.5f);
      
      // Create synthetic piano sounds for a range of notes
      for (int note = 36; note <= 84; note++) {
        createSyntheticPianoSound(instrumentId, note);
      }
      
      Log.i(TAG, "Successfully created piano instrument with ID: " + instrumentId);
      
      // Return the instrument ID
      return instrumentId;
    } catch (Exception e) {
      Log.e(TAG, "Exception in loadPianoInstrument: " + e.getMessage());
      e.printStackTrace();
      return -1;
    }
  }
  
  /**
   * Create a synthetic piano sound for the specified note.
   */
  private void createSyntheticPianoSound(int instrumentId, int note) {
    try {
      // Create a synthetic piano sound based on the note
      short[] sampleData = null;
      int sampleRate = 44100;
      
      // Calculate frequency based on MIDI note number
      double frequency = 440.0 * Math.pow(2.0, (note - 69) / 12.0);
      
      // Create the piano sound
      sampleData = createPianoSound(sampleRate, frequency, note);
      
      if (sampleData != null) {
        // Store the sample data in the audio engine
        audioEngine.storeSampleData(instrumentId, note, sampleData, sampleRate);
        Log.i(TAG, "Created synthetic piano sound for note " + note + " (" + getMidiNoteName(note) + ")");
      }
    } catch (Exception e) {
      Log.e(TAG, "Exception creating synthetic piano sound for note " + note + ": " + e.getMessage());
      e.printStackTrace();
    }
  }
  
  /**
   * Create a synthetic piano sound with the specified frequency.
   */
  private short[] createPianoSound(int sampleRate, double frequency, int note) {
    // Piano sound parameters
    double attack = 0.005; // Very short attack
    double decay = 0.5 + (84 - note) * 0.01; // Longer decay for lower notes
    double sustain = 0.3; // Sustain level
    double release = 0.3; // Release time
    
    // Total duration in seconds (adjust based on note range)
    double duration = Math.min(5.0, 1.0 + (84 - note) * 0.05);
    
    // Create a sample buffer
    int numSamples = (int)(sampleRate * duration);
    short[] sampleData = new short[numSamples];
    
    // Generate a piano-like sound with multiple harmonics
    java.util.Random random = new java.util.Random(note); // Fixed seed for reproducibility
    
    // Harmonic amplitudes (typical for piano)
    double[] harmonicAmps = {
      1.0,    // Fundamental
      0.6,    // 2nd harmonic
      0.4,    // 3rd harmonic
      0.25,   // 4th harmonic
      0.15,   // 5th harmonic
      0.1,    // 6th harmonic
      0.05,   // 7th harmonic
      0.025   // 8th harmonic
    };
    
    // Slight detuning for each harmonic to create more natural sound
    double[] detuning = {
      0.0,      // Fundamental
      0.0001,   // 2nd harmonic
      0.0002,   // 3rd harmonic
      0.0003,   // 4th harmonic
      0.0004,   // 5th harmonic
      0.0005,   // 6th harmonic
      0.0006,   // 7th harmonic
      0.0007    // 8th harmonic
    };
    
    // Different decay rates for each harmonic
    double[] harmonicDecays = {
      decay,          // Fundamental
      decay * 0.8,    // 2nd harmonic
      decay * 0.7,    // 3rd harmonic
      decay * 0.6,    // 4th harmonic
      decay * 0.5,    // 5th harmonic
      decay * 0.4,    // 6th harmonic
      decay * 0.3,    // 7th harmonic
      decay * 0.2     // 8th harmonic
    };
    
    // Generate each sample
    for (int i = 0; i < numSamples; i++) {
      double time = (double)i / sampleRate;
      
      // Calculate envelope
      double envelope;
      if (time < attack) {
        // Attack phase
        envelope = time / attack;
      } else if (time < attack + decay) {
        // Decay phase
        double decayTime = time - attack;
        envelope = 1.0 - (1.0 - sustain) * (decayTime / decay);
      } else {
        // Sustain and gradual release phase
        envelope = sustain * Math.exp(-(time - (attack + decay)) / release);
      }
      
      // Add some noise at the attack for hammer sound (first 50ms)
      double hammerNoise = 0;
      if (time < 0.05) {
        hammerNoise = (random.nextDouble() * 2.0 - 1.0) * 0.1 * (0.05 - time) / 0.05;
      }
      
      // Generate harmonics
      double sample = 0;
      for (int h = 0; h < harmonicAmps.length; h++) {
        int harmonicNumber = h + 1;
        double harmonicFreq = frequency * harmonicNumber * (1.0 + detuning[h]);
        
        // Calculate harmonic-specific envelope
        double harmonicEnvelope = envelope * Math.exp(-time / harmonicDecays[h]);
        
        // Add the harmonic
        sample += harmonicAmps[h] * Math.sin(2.0 * Math.PI * harmonicFreq * time) * harmonicEnvelope;
      }
      
      // Add hammer noise
      sample += hammerNoise;
      
      // Add string resonance effect
      double stringResonance = Math.sin(2.0 * Math.PI * frequency * 4.05 * time) * 0.01 * envelope;
      sample += stringResonance;
      
      // Soft limiting to prevent clipping
      sample = Math.tanh(sample * 0.8) * 0.8;
      
      // Convert to short
      sampleData[i] = (short)(sample * 32767.0);
    }
    
    return sampleData;
  }
} 
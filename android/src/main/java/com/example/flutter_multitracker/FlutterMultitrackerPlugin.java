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
} 
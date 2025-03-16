import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_multitracker_platform_interface.dart';

// Export model classes
export 'models/models.dart';

/// A Flutter plugin for multi-track audio synthesis and sequencing.
class FlutterMultitracker {
  static const MethodChannel _channel = MethodChannel('flutter_multitracker');
  
  /// Singleton instance
  static final FlutterMultitracker _instance = FlutterMultitracker._internal();
  
  /// Factory constructor to return the singleton instance
  factory FlutterMultitracker() => _instance;
  
  /// Private constructor for singleton pattern
  FlutterMultitracker._internal();
  
  /// Get platform version
  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  
  /// Initialize the audio engine
  /// 
  /// [sampleRate] - The sample rate to use (default: 44100)
  /// 
  /// Returns true if initialization was successful
  Future<bool> initAudioEngine({int sampleRate = 44100}) async {
    try {
      final bool result = await _channel.invokeMethod('initAudioEngine', {
        'sampleRate': sampleRate,
      });
      return result;
    } catch (e) {
      debugPrint('Error initializing audio engine: $e');
      return false;
    }
  }
  
  /// Start the audio engine
  /// 
  /// Returns true if the audio engine was started successfully
  Future<bool> startAudioEngine() async {
    try {
      final bool result = await _channel.invokeMethod('startAudioEngine');
      return result;
    } catch (e) {
      debugPrint('Error starting audio engine: $e');
      return false;
    }
  }
  
  /// Stop the audio engine
  /// 
  /// Returns true if the audio engine was stopped successfully
  Future<bool> stopAudioEngine() async {
    try {
      final bool result = await _channel.invokeMethod('stopAudioEngine');
      return result;
    } catch (e) {
      debugPrint('Error stopping audio engine: $e');
      return false;
    }
  }
  
  /// Clean up the audio engine resources
  /// 
  /// Returns true if cleanup was successful
  Future<bool> cleanupAudioEngine() async {
    try {
      final bool result = await _channel.invokeMethod('cleanupAudioEngine');
      return result;
    } catch (e) {
      debugPrint('Error cleaning up audio engine: $e');
      return false;
    }
  }
  
  /// Set the master volume
  /// 
  /// [volume] - Volume level between 0.0 and 1.0
  /// 
  /// Returns true if the volume was set successfully
  Future<bool> setMasterVolume(double volume) async {
    try {
      final bool result = await _channel.invokeMethod('setMasterVolume', {
        'volume': volume.clamp(0.0, 1.0),
      });
      return result;
    } catch (e) {
      debugPrint('Error setting master volume: $e');
      return false;
    }
  }
  
  /// Create a sine wave instrument
  /// 
  /// [name] - Name of the instrument
  /// 
  /// Returns the instrument ID if successful, or -1 if failed
  Future<int> createSineWaveInstrument(String name) async {
    try {
      final int result = await _channel.invokeMethod('createSineWaveInstrument', {
        'name': name,
      });
      return result;
    } catch (e) {
      debugPrint('Error creating sine wave instrument: $e');
      return -1;
    }
  }
  
  /// Unload an instrument
  /// 
  /// [instrumentId] - ID of the instrument to unload
  /// 
  /// Returns true if the instrument was unloaded successfully
  Future<bool> unloadInstrument(int instrumentId) async {
    try {
      final bool result = await _channel.invokeMethod('unloadInstrument', {
        'instrumentId': instrumentId,
      });
      return result;
    } catch (e) {
      debugPrint('Error unloading instrument: $e');
      return false;
    }
  }
  
  /// Send a note on event
  /// 
  /// [instrumentId] - ID of the instrument
  /// [noteNumber] - MIDI note number (0-127)
  /// [velocity] - Note velocity (1-127)
  /// 
  /// Returns true if the note was triggered successfully
  Future<bool> sendNoteOn(int instrumentId, int noteNumber, int velocity) async {
    try {
      final bool result = await _channel.invokeMethod('sendNoteOn', {
        'instrumentId': instrumentId,
        'noteNumber': noteNumber,
        'velocity': velocity,
      });
      return result;
    } catch (e) {
      debugPrint('Error sending note on: $e');
      return false;
    }
  }
  
  /// Send a note off event
  /// 
  /// [instrumentId] - ID of the instrument
  /// [noteNumber] - MIDI note number (0-127)
  /// 
  /// Returns true if the note was released successfully
  Future<bool> sendNoteOff(int instrumentId, int noteNumber) async {
    try {
      final bool result = await _channel.invokeMethod('sendNoteOff', {
        'instrumentId': instrumentId,
        'noteNumber': noteNumber,
      });
      return result;
    } catch (e) {
      debugPrint('Error sending note off: $e');
      return false;
    }
  }
  
  /// Set instrument volume
  /// 
  /// [instrumentId] - ID of the instrument
  /// [volume] - Volume level between 0.0 and 1.0
  /// 
  /// Returns true if the volume was set successfully
  Future<bool> setInstrumentVolume(int instrumentId, double volume) async {
    try {
      final bool result = await _channel.invokeMethod('setInstrumentVolume', {
        'instrumentId': instrumentId,
        'volume': volume.clamp(0.0, 1.0),
      });
      return result;
    } catch (e) {
      debugPrint('Error setting instrument volume: $e');
      return false;
    }
  }
  
  /// Get IDs of all loaded instruments
  /// 
  /// Returns a list of instrument IDs
  Future<List<int>> getLoadedInstrumentIds() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getLoadedInstrumentIds');
      return result.cast<int>();
    } catch (e) {
      debugPrint('Error getting loaded instrument IDs: $e');
      return [];
    }
  }

  /// Create a sequence
  static Future<int> createSequence({int tempo = 120}) async {
    try {
      final int sequenceId = await _channel.invokeMethod('createSequence', {
        'tempo': tempo,
      });
      return sequenceId;
    } catch (e) {
      print('Error creating sequence: $e');
      return -1;
    }
  }

  /// Delete a sequence
  static Future<bool> deleteSequence(int sequenceId) async {
    try {
      final bool result = await _channel.invokeMethod('deleteSequence', {
        'sequenceId': sequenceId,
      });
      return result;
    } catch (e) {
      print('Error deleting sequence: $e');
      return false;
    }
  }

  /// Add a track to a sequence
  static Future<int> addTrack(int sequenceId, int instrumentId) async {
    try {
      final int trackId = await _channel.invokeMethod('addTrack', {
        'sequenceId': sequenceId,
        'instrumentId': instrumentId,
      });
      return trackId;
    } catch (e) {
      print('Error adding track: $e');
      return -1;
    }
  }

  /// Delete a track from a sequence
  static Future<bool> deleteTrack(int sequenceId, int trackId) async {
    try {
      final bool result = await _channel.invokeMethod('deleteTrack', {
        'sequenceId': sequenceId,
        'trackId': trackId,
      });
      return result;
    } catch (e) {
      print('Error deleting track: $e');
      return false;
    }
  }

  /// Add a note to a track
  static Future<int> addNote(
    int sequenceId,
    int trackId,
    int noteNumber,
    int velocity,
    double startTime,
    double duration,
  ) async {
    try {
      final int noteId = await _channel.invokeMethod('addNote', {
        'sequenceId': sequenceId,
        'trackId': trackId,
        'noteNumber': noteNumber,
        'velocity': velocity,
        'startTime': startTime,
        'duration': duration,
      });
      return noteId;
    } catch (e) {
      print('Error adding note: $e');
      return -1;
    }
  }

  /// Delete a note from a track
  static Future<bool> deleteNote(int sequenceId, int trackId, int noteId) async {
    try {
      final bool result = await _channel.invokeMethod('deleteNote', {
        'sequenceId': sequenceId,
        'trackId': trackId,
        'noteId': noteId,
      });
      return result;
    } catch (e) {
      print('Error deleting note: $e');
      return false;
    }
  }

  /// Start playback of a sequence
  static Future<bool> startPlayback(int sequenceId) async {
    try {
      final bool result = await _channel.invokeMethod('startPlayback', {
        'sequenceId': sequenceId,
      });
      return result;
    } catch (e) {
      print('Error starting playback: $e');
      return false;
    }
  }

  /// Stop playback
  static Future<bool> stopPlayback() async {
    try {
      final bool result = await _channel.invokeMethod('stopPlayback');
      return result;
    } catch (e) {
      print('Error stopping playback: $e');
      return false;
    }
  }

  /// Release all resources and shutdown the audio engine
  /// 
  /// This should be called when the app is being closed.
  Future<bool> dispose() {
    return FlutterMultitrackerPlatform.instance.dispose();
  }
}

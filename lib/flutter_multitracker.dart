import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'flutter_multitracker_platform_interface.dart';
import 'flutter_multitracker_ffi_impl.dart';
import 'flutter_multitracker_ffi.dart';
import 'models/models.dart';

// Export model classes
export 'models/models.dart';

// Export public API
export 'flutter_multitracker_platform_interface.dart';

// Import implementation
import 'flutter_multitracker_platform_interface.dart';
import 'flutter_multitracker_method_channel.dart';

/// The main plugin class to interact with the multitracker audio engine
class FlutterMultitracker {
  static const MethodChannel _channel = MethodChannel('flutter_multitracker');
  
  /// Map of sequences by ID.
  final Map<int, Sequence> _sequences = {};
  
  /// Map of instruments by ID.
  final Map<int, Instrument> _instruments = {};
  
  /// Direct access to FFI implementation (for advanced users)
  static final MultiTrackerFFI ffi = MultiTrackerFFI();
  
  /// Singleton instance
  static final FlutterMultitracker _instance = FlutterMultitracker._internal();
  
  /// Factory constructor to return the singleton instance
  factory FlutterMultitracker() => _instance;
  
  bool _initialized = false;
  
  /// Private constructor for singleton pattern
  FlutterMultitracker._internal() {
    // We'll use method channel by default until FFI is fully working
  }
  
  /// Get platform version
  Future<String?> getPlatformVersion() {
    return FlutterMultitrackerPlatform.instance.getPlatformVersion();
  }
  
  /// Initialize the audio engine
  Future<bool> initialize({int sampleRate = 44100}) async {
    try {
      _initialized = await FlutterMultitrackerPlatform.instance.initializeAudioEngine(sampleRate: sampleRate);
      return _initialized;
    } catch (e) {
      debugPrint('FlutterMultitracker: Error initializing audio engine: $e');
      return false;
    }
  }
  
  /// Load an SFZ format instrument
  ///
  /// [filePath] is the path to the .sfz file
  /// [name] is an optional friendly name for the instrument
  /// 
  /// Returns an [Instrument] representing the loaded instrument
  Future<Instrument> loadSFZ(String filePath, {String? name}) {
    return FlutterMultitrackerPlatform.instance.loadInstrumentFromSFZ(filePath, name: name);
  }
  
  /// Load a SoundFont (SF2) format instrument
  ///
  /// [filePath] is the path to the .sf2 file
  /// [preset] is the preset number to load
  /// [bank] is the bank number to load
  /// [name] is an optional friendly name for the instrument
  /// 
  /// Returns an [Instrument] representing the loaded instrument
  Future<Instrument> loadSF2(String filePath, int preset, int bank, {String? name}) {
    return FlutterMultitrackerPlatform.instance.loadInstrumentFromSF2(filePath, preset, bank, name: name);
  }
  
  /// Create a new sequence
  ///
  /// [tempo] specifies the beats per minute
  /// [numerator] and [denominator] define the time signature (e.g., 4/4)
  /// 
  /// Returns a [Sequence] that can be used for playback
  Future<Sequence> createSequence(double tempo, {int numerator = 4, int denominator = 4}) {
    return FlutterMultitrackerPlatform.instance.createSequence(tempo, numerator: numerator, denominator: denominator);
  }
  
  /// Add a track to a sequence
  ///
  /// [sequence] is the sequence to add the track to
  /// [instrument] is the instrument to use for the track
  /// 
  /// Returns a [Track] that can be used to add notes
  Future<Track> addTrack(Sequence sequence, Instrument instrument) {
    return FlutterMultitrackerPlatform.instance.addTrack(sequence, instrument);
  }
  
  /// Add a note to a track
  ///
  /// [track] is the track to add the note to
  /// [noteNumber] is the MIDI note number (0-127)
  /// [velocity] is the velocity (0-127)
  /// [startBeat] is the beat position where the note starts
  /// [durationBeats] is the duration of the note in beats
  /// 
  /// Returns true if the note was successfully added
  Future<bool> addNote(Track track, int noteNumber, int velocity, double startBeat, double durationBeats) {
    return FlutterMultitrackerPlatform.instance.addNote(track, noteNumber, velocity, startBeat, durationBeats);
  }
  
  /// Play a sequence
  ///
  /// [sequence] is the sequence to play
  /// [loop] determines whether the sequence should loop after completion
  /// 
  /// Returns true if playback was successfully started
  Future<bool> playSequence(Sequence sequence, {bool loop = false}) {
    return FlutterMultitrackerPlatform.instance.playSequence(sequence, loop: loop);
  }
  
  /// Stop a sequence
  ///
  /// [sequence] is the sequence to stop
  /// 
  /// Returns true if playback was successfully stopped
  Future<bool> stopSequence(Sequence sequence) {
    return FlutterMultitrackerPlatform.instance.stopSequence(sequence);
  }
  
  /// Delete a sequence and free all its resources
  ///
  /// [sequence] is the sequence to delete
  /// 
  /// Returns true if the sequence was successfully deleted
  Future<bool> deleteSequence(Sequence sequence) {
    return FlutterMultitrackerPlatform.instance.deleteSequence(sequence);
  }
  
  /// Set the playback position for a sequence
  ///
  /// [sequence] is the sequence to adjust
  /// [beat] is the position in beats to set
  /// 
  /// Returns true if the position was successfully set
  Future<bool> setPlaybackPosition(Sequence sequence, double beat) {
    return FlutterMultitrackerPlatform.instance.setPlaybackPosition(sequence, beat);
  }
  
  /// Get the current playback position of a sequence
  ///
  /// [sequence] is the sequence to query
  /// 
  /// Returns the current position in beats
  Future<double> getPlaybackPosition(Sequence sequence) {
    return FlutterMultitrackerPlatform.instance.getPlaybackPosition(sequence);
  }
  
  /// Set the master volume for all audio output
  ///
  /// [volume] is a value between 0.0 and 1.0
  /// 
  /// Returns true if the volume was successfully set
  Future<bool> setMasterVolume(double volume) {
    return FlutterMultitrackerPlatform.instance.setMasterVolume(volume);
  }
  
  /// Set the volume for a track
  ///
  /// [track] is the track to adjust
  /// [volume] is a value between 0.0 and 1.0
  /// 
  /// Returns true if the volume was successfully set
  Future<bool> setTrackVolume(Track track, double volume) {
    return FlutterMultitrackerPlatform.instance.setTrackVolume(track, volume);
  }
  
  /// Play a note directly (for immediate playback)
  ///
  /// [instrument] is the instrument to use
  /// [noteNumber] is the MIDI note number (0-127)
  /// [velocity] is the velocity (0-127)
  /// 
  /// Returns true if the note was successfully started
  Future<bool> playNote(int instrumentId, int noteNumber, int velocity) {
    return FlutterMultitrackerPlatform.instance.playNote(instrumentId, noteNumber, velocity);
  }
  
  /// Stop a note that was started with playNote
  ///
  /// [instrument] is the instrument the note is playing on
  /// [noteNumber] is the MIDI note number (0-127) to stop
  /// 
  /// Returns true if the note was successfully stopped
  Future<bool> stopNote(int instrumentId, int noteNumber) {
    return FlutterMultitrackerPlatform.instance.stopNote(instrumentId, noteNumber);
  }
  
  /// Plays a test tone to verify audio is working
  Future<bool> playTestTone() {
    return FlutterMultitrackerPlatform.instance.playTestTone();
  }
  
  /// Stops the test tone
  Future<bool> stopTestTone() {
    return FlutterMultitrackerPlatform.instance.stopTestTone();
  }
  
  /// Clean up all resources and shutdown the audio engine
  ///
  /// This should be called when the plugin is no longer needed
  Future<bool> dispose() async {
    if (!_initialized) {
      return true; // Nothing to dispose
    }
    
    try {
      // Call the native implementation
      final result = await ffi.dispose();
      
      if (result) {
        _initialized = false;
        developer.log('FlutterMultitracker disposed successfully');
      }
      
      return result;
    } catch (e) {
      developer.log('Error disposing FlutterMultitracker: $e');
      return false;
    }
  }
  
  /// Get a sequence by ID
  Sequence? getSequence(int id) {
    return _sequences[id];
  }
  
  /// Get an instrument by ID
  Instrument? getInstrument(int id) {
    return _instruments[id];
  }
}

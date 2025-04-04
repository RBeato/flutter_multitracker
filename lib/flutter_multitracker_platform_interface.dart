import 'dart:async';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_multitracker/models/models.dart';

import 'flutter_multitracker_method_channel.dart';

/// The interface that implementations of flutter_multitracker must implement.
abstract class FlutterMultitrackerPlatform extends PlatformInterface {
  /// Constructs a FlutterMultitrackerPlatform.
  FlutterMultitrackerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterMultitrackerPlatform _instance = MethodChannelFlutterMultitracker();

  /// The default instance of [FlutterMultitrackerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterMultitracker].
  static FlutterMultitrackerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterMultitrackerPlatform] when
  /// they register themselves.
  static set instance(FlutterMultitrackerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }
  
  /// Initialize the audio engine
  Future<bool> initializeAudioEngine({int sampleRate = 44100}) {
    throw UnimplementedError('initializeAudioEngine() has not been implemented.');
  }

  /// Load an SFZ format instrument
  Future<Instrument> loadInstrumentFromSFZ(String filePath, {String? name}) {
    throw UnimplementedError('loadInstrumentFromSFZ() has not been implemented.');
  }

  /// Load an SF2 format instrument
  Future<Instrument> loadInstrumentFromSF2(String filePath, int preset, int bank, {String? name}) {
    throw UnimplementedError('loadInstrumentFromSF2() has not been implemented.');
  }

  /// iOS only: Load an AudioUnit instrument
  Future<int?> loadAudioUnitInstrument(String componentDescription, String? auPresetPath) {
    throw UnimplementedError('loadAudioUnitInstrument() has not been implemented.');
  }

  /// Unload an instrument and free its resources
  Future<bool> unloadInstrument(int instrumentId) {
    throw UnimplementedError('unloadInstrument() has not been implemented.');
  }

  /// Create a new sequence
  Future<Sequence> createSequence(double tempo, {int numerator = 4, int denominator = 4}) {
    throw UnimplementedError('createSequence() has not been implemented.');
  }

  /// Add a track to a sequence for a specific instrument
  Future<Track> addTrack(Sequence sequence, Instrument instrument) {
    throw UnimplementedError('addTrack() has not been implemented.');
  }

  /// Add a note to a track
  Future<bool> addNote(Track track, int noteNumber, int velocity, double startBeat, double durationBeats) {
    throw UnimplementedError('addNote() has not been implemented.');
  }

  /// Add a volume automation point to a track
  Future<bool> addVolumeAutomation(int sequenceId, int trackId, double beat, double volume) {
    throw UnimplementedError('addVolumeAutomation() has not been implemented.');
  }

  /// Play a sequence with optional looping
  Future<bool> playSequence(Sequence sequence, {bool loop = false}) {
    throw UnimplementedError('playSequence() has not been implemented.');
  }

  /// Stop a sequence
  Future<bool> stopSequence(Sequence sequence) {
    throw UnimplementedError('stopSequence() has not been implemented.');
  }

  /// Delete a sequence and all its resources
  Future<bool> deleteSequence(Sequence sequence) {
    throw UnimplementedError('deleteSequence() has not been implemented.');
  }

  /// Set the playback position for a sequence
  Future<bool> setPlaybackPosition(Sequence sequence, double beat) {
    throw UnimplementedError('setPlaybackPosition() has not been implemented.');
  }

  /// Get the current playback position for a sequence
  Future<double> getPlaybackPosition(Sequence sequence) {
    throw UnimplementedError('getPlaybackPosition() has not been implemented.');
  }

  /// Set the master volume
  Future<bool> setMasterVolume(double volume) {
    throw UnimplementedError('setMasterVolume() has not been implemented.');
  }

  /// Set the volume for a track
  Future<bool> setTrackVolume(Track track, double volume) {
    throw UnimplementedError('setTrackVolume() has not been implemented.');
  }

  /// Play a note directly (for immediate playback)
  Future<bool> playNote(int instrumentId, int noteNumber, int velocity) {
    throw UnimplementedError('playNote() has not been implemented.');
  }

  /// Stop playing a note
  Future<bool> stopNote(int instrumentId, int noteNumber) {
    throw UnimplementedError('stopNote() has not been implemented.');
  }
  
  /// Play a test tone to verify audio output is working
  Future<bool> playTestTone() {
    throw UnimplementedError('playTestTone() has not been implemented.');
  }
  
  /// Stop the test tone
  Future<bool> stopTestTone() {
    throw UnimplementedError('stopTestTone() has not been implemented.');
  }

  /// Clean up all resources
  Future<bool> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  Future<void> shutdown() {
    throw UnimplementedError('shutdown() has not been implemented.');
  }
}

/// A placeholder implementation that throws on every method.
class _PlaceholderImplementation extends FlutterMultitrackerPlatform {}

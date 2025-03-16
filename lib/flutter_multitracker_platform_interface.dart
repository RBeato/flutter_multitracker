import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_multitracker_method_channel.dart';

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
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
  
  /// Initialize the audio engine
  Future<bool> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Load a sampler instrument from an SFZ file
  Future<int?> loadInstrumentFromSFZ(String sfzPath) {
    throw UnimplementedError('loadInstrumentFromSFZ() has not been implemented.');
  }

  /// Load a sampler instrument from a SoundFont (SF2) file
  Future<int?> loadInstrumentFromSF2(String sf2Path, int preset, int bank) {
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
  Future<int?> createSequence(double bpm, int timeSignatureNumerator, int timeSignatureDenominator) {
    throw UnimplementedError('createSequence() has not been implemented.');
  }

  /// Add a track to a sequence
  Future<int?> addTrack(int sequenceId, int instrumentId) {
    throw UnimplementedError('addTrack() has not been implemented.');
  }

  /// Add a note to a track
  Future<bool> addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startBeat, double durationBeats) {
    throw UnimplementedError('addNote() has not been implemented.');
  }

  /// Add a volume automation point to a track
  Future<bool> addVolumeAutomation(int sequenceId, int trackId, double beat, double volume) {
    throw UnimplementedError('addVolumeAutomation() has not been implemented.');
  }

  /// Play a sequence
  Future<bool> playSequence(int sequenceId, bool loop) {
    throw UnimplementedError('playSequence() has not been implemented.');
  }

  /// Stop a sequence
  Future<bool> stopSequence(int sequenceId) {
    throw UnimplementedError('stopSequence() has not been implemented.');
  }

  /// Delete a sequence and free its resources
  Future<bool> deleteSequence(int sequenceId) {
    throw UnimplementedError('deleteSequence() has not been implemented.');
  }

  /// Set the current playback position of a sequence
  Future<bool> setPlaybackPosition(int sequenceId, double beat) {
    throw UnimplementedError('setPlaybackPosition() has not been implemented.');
  }

  /// Get the current playback position of a sequence
  Future<double> getPlaybackPosition(int sequenceId) {
    throw UnimplementedError('getPlaybackPosition() has not been implemented.');
  }

  /// Set the master volume
  Future<bool> setMasterVolume(double volume) {
    throw UnimplementedError('setMasterVolume() has not been implemented.');
  }

  /// Set the volume for a specific track
  Future<bool> setTrackVolume(int sequenceId, int trackId, double volume) {
    throw UnimplementedError('setTrackVolume() has not been implemented.');
  }

  /// Release all resources and shutdown the audio engine
  Future<bool> dispose() {
    throw UnimplementedError('dispose() has not been implemented.');
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_multitracker/models/models.dart';
import 'flutter_multitracker_platform_interface.dart';

/// An implementation of [FlutterMultitrackerPlatform] that uses method channels.
class MethodChannelFlutterMultitracker extends FlutterMultitrackerPlatform {
  /// The method channel used to communicate with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_multitracker');
  
  /// Whether to use fallback implementations when native methods fail
  bool _useFallback = false;
  
  /// Set whether to use fallback implementations when native methods fail
  void setUseFallback(bool useFallback) {
    _useFallback = useFallback;
  }

  @override
  Future<String?> getPlatformVersion() async {
    try {
      final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
      return version;
    } on PlatformException catch (e) {
      debugPrint('Error getting platform version: ${e.message}');
      return 'Unknown platform version';
    }
  }
  
  @override
  Future<bool> initializeAudioEngine({int sampleRate = 44100}) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'initializeAudioEngine',
        {'sampleRate': sampleRate},
      );
      debugPrint('Audio engine initialized with result: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to initialize audio engine: ${e.message}');
      if (_useFallback) {
        debugPrint('Using fallback audio implementation');
        return true; // Pretend initialization succeeded
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected error initializing audio engine: $e');
      return false;
    }
  }

  @override
  Future<Instrument> loadInstrumentFromSFZ(String sfzPath, {String? name}) async {
    // Mock a successful instrument load with ID 1
    debugPrint('Mock loading SFZ instrument from $sfzPath');
    return Instrument(
      id: 1,
      type: InstrumentType.sfz,
      path: sfzPath,
      name: name ?? sfzPath.split('/').last,
    );
  }

  @override
  Future<Instrument> loadInstrumentFromSF2(String sf2Path, int preset, int bank, {String? name}) async {
    // Mock a successful instrument load with ID 2
    debugPrint('Mock loading SF2 instrument from $sf2Path');
    return Instrument(
      id: 2,
      type: InstrumentType.sf2,
      path: sf2Path,
      preset: preset,
      bank: bank,
      name: name ?? sf2Path.split('/').last,
    );
  }

  @override
  Future<bool> unloadInstrument(int instrumentId) async {
    debugPrint('Mock unloading instrument $instrumentId');
    return true;
  }

  @override
  Future<Sequence> createSequence(double bpm, {int numerator = 4, int denominator = 4}) async {
    debugPrint('Mock creating sequence with BPM: $bpm, time signature: $numerator/$denominator');
    return Sequence(
      id: 1,
      bpm: bpm,
      timeSignatureNumerator: numerator,
      timeSignatureDenominator: denominator,
    );
  }

  @override
  Future<Track> addTrack(Sequence sequence, Instrument instrument) async {
    debugPrint('Mock adding track to sequence ${sequence.id} with instrument ${instrument.id}');
    return Track(
      id: 1,
      sequenceId: sequence.id,
      instrumentId: instrument.id,
    );
  }

  @override
  Future<bool> addNote(Track track, int noteNumber, int velocity, double startBeat, double durationBeats) async {
    debugPrint('Mock adding note to track ${track.id}');
    return true;
  }

  @override
  Future<bool> playSequence(Sequence sequence, {bool loop = false}) async {
    debugPrint('Mock playing sequence ${sequence.id}');
    return true;
  }

  @override
  Future<bool> stopSequence(Sequence sequence) async {
    debugPrint('Mock stopping sequence ${sequence.id}');
    return true;
  }

  @override
  Future<bool> deleteSequence(Sequence sequence) async {
    debugPrint('Mock deleting sequence ${sequence.id}');
    return true;
  }

  @override
  Future<bool> setPlaybackPosition(Sequence sequence, double beat) async {
    debugPrint('Mock setting playback position for sequence ${sequence.id}');
    return true;
  }

  @override
  Future<double> getPlaybackPosition(Sequence sequence) async {
    debugPrint('Mock getting playback position for sequence ${sequence.id}');
    return 0.0;
  }

  @override
  Future<bool> setMasterVolume(double volume) async {
    debugPrint('Mock setting master volume to $volume');
    return true;
  }

  @override
  Future<bool> setTrackVolume(Track track, double volume) async {
    debugPrint('Mock setting track ${track.id} volume to $volume');
    return true;
  }

  @override
  Future<bool> playNote(int instrumentId, int noteNumber, int velocity) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'playNote',
        {
          'instrumentId': instrumentId,
          'noteNumber': noteNumber,
          'velocity': velocity,
        },
      );
      debugPrint('Play note result: $result (inst=$instrumentId, note=$noteNumber, vel=$velocity)');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error playing note: ${e.message}');
      if (_useFallback) {
        debugPrint('Using fallback play note (inst=$instrumentId, note=$noteNumber)');
        return true; // Fallback will handle the real audio
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected error playing note: $e');
      return false;
    }
  }

  @override
  Future<bool> stopNote(int instrumentId, int noteNumber) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'stopNote',
        {
          'instrumentId': instrumentId,
          'noteNumber': noteNumber,
        },
      );
      debugPrint('Stop note result: $result (inst=$instrumentId, note=$noteNumber)');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error stopping note: ${e.message}');
      if (_useFallback) {
        debugPrint('Using fallback stop note (inst=$instrumentId, note=$noteNumber)');
        return true; // Fallback will handle the real audio
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected error stopping note: $e');
      return false;
    }
  }

  @override
  Future<bool> playTestTone() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('playTestTone');
      debugPrint('Play test tone result: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error playing test tone: ${e.message}');
      if (_useFallback) {
        debugPrint('Using fallback play test tone');
        return true; // Fallback will handle the real audio
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected error playing test tone: $e');
      return false;
    }
  }

  @override
  Future<bool> stopTestTone() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('stopTestTone');
      debugPrint('Stop test tone result: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error stopping test tone: ${e.message}');
      if (_useFallback) {
        debugPrint('Using fallback stop test tone');
        return true; // Fallback will handle the real audio
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected error stopping test tone: $e');
      return false;
    }
  }

  @override
  Future<bool> dispose() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('dispose');
      debugPrint('Dispose resources result: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Error disposing resources: ${e.message}');
      if (_useFallback) {
        debugPrint('Using fallback resource disposal');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Unexpected error disposing resources: $e');
      return false;
    }
  }
}

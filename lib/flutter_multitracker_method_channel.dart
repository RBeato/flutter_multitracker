import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_multitracker_platform_interface.dart';

/// An implementation of [FlutterMultitrackerPlatform] that uses method channels.
class MethodChannelFlutterMultitracker extends FlutterMultitrackerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_multitracker');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
  
  @override
  Future<bool> initialize() async {
    final result = await methodChannel.invokeMethod<bool>('initialize');
    return result ?? false;
  }

  @override
  Future<int?> loadInstrumentFromSFZ(String sfzPath) async {
    final instrumentId = await methodChannel.invokeMethod<int>('loadInstrumentFromSFZ', {
      'sfzPath': sfzPath,
    });
    return instrumentId;
  }

  @override
  Future<int?> loadInstrumentFromSF2(String sf2Path, int preset, int bank) async {
    final instrumentId = await methodChannel.invokeMethod<int>('loadInstrumentFromSF2', {
      'sf2Path': sf2Path,
      'preset': preset,
      'bank': bank,
    });
    return instrumentId;
  }

  @override
  Future<int?> loadAudioUnitInstrument(String componentDescription, String? auPresetPath) async {
    final instrumentId = await methodChannel.invokeMethod<int>('loadAudioUnitInstrument', {
      'componentDescription': componentDescription,
      'auPresetPath': auPresetPath,
    });
    return instrumentId;
  }

  @override
  Future<bool> unloadInstrument(int instrumentId) async {
    final result = await methodChannel.invokeMethod<bool>('unloadInstrument', {
      'instrumentId': instrumentId,
    });
    return result ?? false;
  }

  @override
  Future<int?> createSequence(double bpm, int timeSignatureNumerator, int timeSignatureDenominator) async {
    final sequenceId = await methodChannel.invokeMethod<int>('createSequence', {
      'bpm': bpm,
      'timeSignatureNumerator': timeSignatureNumerator,
      'timeSignatureDenominator': timeSignatureDenominator,
    });
    return sequenceId;
  }

  @override
  Future<int?> addTrack(int sequenceId, int instrumentId) async {
    final trackId = await methodChannel.invokeMethod<int>('addTrack', {
      'sequenceId': sequenceId,
      'instrumentId': instrumentId,
    });
    return trackId;
  }

  @override
  Future<bool> addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startBeat, double durationBeats) async {
    final result = await methodChannel.invokeMethod<bool>('addNote', {
      'sequenceId': sequenceId,
      'trackId': trackId,
      'noteNumber': noteNumber,
      'velocity': velocity,
      'startBeat': startBeat,
      'durationBeats': durationBeats,
    });
    return result ?? false;
  }

  @override
  Future<bool> addVolumeAutomation(int sequenceId, int trackId, double beat, double volume) async {
    final result = await methodChannel.invokeMethod<bool>('addVolumeAutomation', {
      'sequenceId': sequenceId,
      'trackId': trackId,
      'beat': beat,
      'volume': volume,
    });
    return result ?? false;
  }

  @override
  Future<bool> playSequence(int sequenceId, bool loop) async {
    final result = await methodChannel.invokeMethod<bool>('playSequence', {
      'sequenceId': sequenceId,
      'loop': loop,
    });
    return result ?? false;
  }

  @override
  Future<bool> stopSequence(int sequenceId) async {
    final result = await methodChannel.invokeMethod<bool>('stopSequence', {
      'sequenceId': sequenceId,
    });
    return result ?? false;
  }

  @override
  Future<bool> deleteSequence(int sequenceId) async {
    final result = await methodChannel.invokeMethod<bool>('deleteSequence', {
      'sequenceId': sequenceId,
    });
    return result ?? false;
  }

  @override
  Future<bool> setPlaybackPosition(int sequenceId, double beat) async {
    final result = await methodChannel.invokeMethod<bool>('setPlaybackPosition', {
      'sequenceId': sequenceId,
      'beat': beat,
    });
    return result ?? false;
  }

  @override
  Future<double> getPlaybackPosition(int sequenceId) async {
    final position = await methodChannel.invokeMethod<double>('getPlaybackPosition', {
      'sequenceId': sequenceId,
    });
    return position ?? 0.0;
  }

  @override
  Future<bool> setMasterVolume(double volume) async {
    final result = await methodChannel.invokeMethod<bool>('setMasterVolume', {
      'volume': volume,
    });
    return result ?? false;
  }

  @override
  Future<bool> setTrackVolume(int sequenceId, int trackId, double volume) async {
    final result = await methodChannel.invokeMethod<bool>('setTrackVolume', {
      'sequenceId': sequenceId,
      'trackId': trackId,
      'volume': volume,
    });
    return result ?? false;
  }

  @override
  Future<bool> dispose() async {
    final result = await methodChannel.invokeMethod<bool>('dispose');
    return result ?? false;
  }
}

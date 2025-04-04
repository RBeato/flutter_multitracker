// A web implementation of the FlutterMultitracker plugin.
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

import 'flutter_multitracker_platform_interface.dart';
import 'models/models.dart';

/// A web implementation of the FlutterMultitrackerPlatform.
class FlutterMultitrackerWeb extends FlutterMultitrackerPlatform {
  /// Constructs a FlutterMultitrackerWeb
  FlutterMultitrackerWeb();

  // This static function is optional and can be used as a
  // platform-specific implementation registration method.
  // It will be called by the platform implementation at web initialization time.
  static void registerWith(dynamic registrar) {
    FlutterMultitrackerPlatform.instance = FlutterMultitrackerWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final userAgent = html.window.navigator.userAgent;
    return 'Web - $userAgent';
  }
  
  @override
  Future<bool> initializeAudioEngine({int sampleRate = 44100}) async {
    debugPrint('Web implementation: initialize audio engine with sample rate $sampleRate');
    return true;
  }

  @override
  Future<Instrument> loadInstrumentFromSFZ(String sfzPath, {String? name}) async {
    debugPrint('Web implementation: load SFZ instrument from $sfzPath');
    return Instrument(
      id: 1,
      type: InstrumentType.sfz,
      path: sfzPath,
      name: name ?? sfzPath.split('/').last,
    );
  }

  @override
  Future<Instrument> loadInstrumentFromSF2(String sf2Path, int preset, int bank, {String? name}) async {
    debugPrint('Web implementation: load SF2 instrument from $sf2Path');
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
    debugPrint('Web implementation: unload instrument $instrumentId');
    return true;
  }

  @override
  Future<Sequence> createSequence(double bpm, {int numerator = 4, int denominator = 4}) async {
    debugPrint('Web implementation: create sequence with BPM $bpm, time signature $numerator/$denominator');
    return Sequence(
      id: 1,
      bpm: bpm,
      timeSignatureNumerator: numerator,
      timeSignatureDenominator: denominator,
    );
  }

  @override
  Future<Track> addTrack(Sequence sequence, Instrument instrument) async {
    debugPrint('Web implementation: add track to sequence ${sequence.id} with instrument ${instrument.id}');
    return Track(
      id: 1,
      sequenceId: sequence.id, 
      instrumentId: instrument.id
    );
  }

  @override
  Future<bool> addNote(Track track, int noteNumber, int velocity, double startBeat, double durationBeats) async {
    debugPrint('Web implementation: add note to track ${track.id}');
    return true;
  }

  @override
  Future<bool> playSequence(Sequence sequence, {bool loop = false}) async {
    debugPrint('Web implementation: play sequence ${sequence.id}');
    return true;
  }

  @override
  Future<bool> stopSequence(Sequence sequence) async {
    debugPrint('Web implementation: stop sequence ${sequence.id}');
    return true;
  }

  @override
  Future<bool> deleteSequence(Sequence sequence) async {
    debugPrint('Web implementation: delete sequence ${sequence.id}');
    return true;
  }

  @override
  Future<bool> setPlaybackPosition(Sequence sequence, double beat) async {
    debugPrint('Web implementation: set playback position to $beat for sequence ${sequence.id}');
    return true;
  }

  @override
  Future<double> getPlaybackPosition(Sequence sequence) async {
    debugPrint('Web implementation: get playback position for sequence ${sequence.id}');
    return 0.0;
  }

  @override
  Future<bool> setMasterVolume(double volume) async {
    debugPrint('Web implementation: set master volume to $volume');
    return true;
  }

  @override
  Future<bool> setTrackVolume(Track track, double volume) async {
    debugPrint('Web implementation: set volume to $volume for track ${track.id}');
    return true;
  }

  @override
  Future<bool> playNote(int instrumentId, int noteNumber, int velocity) async {
    debugPrint('Web implementation: play note $noteNumber with velocity $velocity on instrument $instrumentId');
    return true;
  }

  @override
  Future<bool> stopNote(int instrumentId, int noteNumber) async {
    debugPrint('Web implementation: stop note $noteNumber on instrument $instrumentId');
    return true;
  }

  @override
  Future<bool> playTestTone() async {
    debugPrint('Web implementation: play test tone');
    return true;
  }

  @override
  Future<bool> stopTestTone() async {
    debugPrint('Web implementation: stop test tone');
    return true;
  }

  @override
  Future<bool> dispose() async {
    debugPrint('Web implementation: dispose resources');
    return true;
  }
} 
import 'dart:async';
import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_multitracker/flutter_multitracker_platform_interface.dart';
import 'package:flutter_multitracker/models/models.dart';
import 'package:flutter_multitracker/flutter_multitracker_ffi.dart';
import 'dart:developer' as developer;

/// Native function signatures
typedef TestInitNative = Int8 Function();
typedef TestInitDart = int Function();

typedef RegisterDartCallbackPortNative = Pointer Function(Int64 port);
typedef RegisterDartCallbackPortDart = Pointer Function(int port);

typedef InitAudioEngineNative = Int8 Function(Int32 sampleRate);
typedef InitAudioEngineDart = int Function(int sampleRate);

typedef StartAudioEngineNative = Int8 Function();
typedef StartAudioEngineDart = int Function();

typedef StopAudioEngineNative = Int8 Function();
typedef StopAudioEngineDart = int Function();

typedef LoadInstrumentSfzNative = Int32 Function(Pointer<Utf8> sfzPath);
typedef LoadInstrumentSfzDart = int Function(Pointer<Utf8> sfzPath);

typedef LoadInstrumentSf2Native = Int32 Function(Pointer<Utf8> sf2Path, Int32 preset, Int32 bank);
typedef LoadInstrumentSf2Dart = int Function(Pointer<Utf8> sf2Path, int preset, int bank);

typedef CreateSequenceNative = Int32 Function(Float bpm, Int32 timeSignatureNumerator, Int32 timeSignatureDenominator);
typedef CreateSequenceDart = int Function(double bpm, int timeSignatureNumerator, int timeSignatureDenominator);

typedef AddTrackNative = Int32 Function(Int32 sequenceId, Int32 instrumentId);
typedef AddTrackDart = int Function(int sequenceId, int instrumentId);

typedef AddNoteNative = Int8 Function(Int32 sequenceId, Int32 trackId, Int32 noteNumber, Int32 velocity, Float startBeat, Float durationBeats);
typedef AddNoteDart = int Function(int sequenceId, int trackId, int noteNumber, int velocity, double startBeat, double durationBeats);

typedef PlaySequenceNative = Int8 Function(Int32 sequenceId, Int8 loop);
typedef PlaySequenceDart = int Function(int sequenceId, int loop);

typedef StopSequenceNative = Int8 Function(Int32 sequenceId);
typedef StopSequenceDart = int Function(int sequenceId);

typedef DeleteSequenceNative = Int8 Function(Int32 sequenceId);
typedef DeleteSequenceDart = int Function(int sequenceId);

typedef SetPlaybackPositionNative = Int8 Function(Int32 sequenceId, Float beat);
typedef SetPlaybackPositionDart = int Function(int sequenceId, double beat);

typedef GetPlaybackPositionNative = Float Function(Int32 sequenceId);
typedef GetPlaybackPositionDart = double Function(int sequenceId);

typedef SetMasterVolumeNative = Int8 Function(Float volume);
typedef SetMasterVolumeDart = int Function(double volume);

typedef SetTrackVolumeNative = Int8 Function(Int32 sequenceId, Int32 trackId, Float volume);
typedef SetTrackVolumeDart = int Function(int sequenceId, int trackId, double volume);

typedef DisposeNative = Int8 Function();
typedef DisposeDart = int Function();

/// FFI implementation of the FlutterMultitracker plugin.
class FFIFlutterMultitracker extends FlutterMultitrackerPlatform {
  /// Register this implementation as the default platform implementation.
  static void registerWith() {
    FlutterMultitrackerPlatform.instance = FFIFlutterMultitracker();
  }
  
  /// Direct access to the FFI implementation
  final _ffi = MultiTrackerFFI();
  
  /// Flag to track initialization status
  bool _isInitialized = false;
  
  /// Maps to track objects
  final _instruments = <int, Instrument>{};
  final _sequences = <int, Sequence>{};
  final _tracks = <int, Track>{};
  
  @override
  Future<String?> getPlatformVersion() async {
    return 'FFI implementation';
  }
  
  /// Logger function
  void _log(String message) {
    developer.log(message, name: 'FFIFlutterMultitracker');
  }
  
  @override
  Future<bool> initialize({int sampleRate = 44100}) async {
    _log('Initializing audio engine with sample rate: $sampleRate');
    
    if (_isInitialized) {
      _log('Already initialized');
      return true;
    }
    
    try {
      // Initialize the FFI bindings first
      final ffiInit = await _ffi.initialize(timeout: const Duration(seconds: 10));
      if (!ffiInit) {
        _log('Failed to initialize FFI bindings');
        return false;
      }
      
      // Initialize the audio engine
      final result = await _ffi.initAudioEngine(sampleRate);
      _isInitialized = result == 1;
      
      if (_isInitialized) {
        // Start the audio engine
        final startResult = await _ffi.startAudioEngine();
        if (startResult != 1) {
          _log('Warning: Audio engine initialized but failed to start');
        }
      }
      
      _log('Initialization result: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      _log('Error during initialization: $e');
      return false;
    }
  }
  
  @override
  Future<Instrument> loadInstrumentFromSFZ(String filePath, {String? name}) async {
    _log('Loading SFZ instrument from: $filePath');
    _checkInitialized();
    
    try {
      // Call FFI to load the instrument
      final id = await _ffi.loadInstrumentFromSFZ(filePath);
      if (id < 0) {
        throw Exception('Failed to load SFZ instrument from: $filePath');
      }
      
      // Create and cache the instrument
      final instrument = Instrument(
        id: id,
        name: name ?? filePath.split('/').last,
        type: InstrumentType.sfz,
        path: filePath,
      );
      
      _instruments[id] = instrument;
      _log('Loaded SFZ instrument with ID: $id');
      return instrument;
    } catch (e) {
      _log('Error loading SFZ instrument: $e');
      rethrow;
    }
  }
  
  @override
  Future<Instrument> loadInstrumentFromSF2(String filePath, int preset, int bank, {String? name}) async {
    _log('Loading SF2 instrument from: $filePath, preset: $preset, bank: $bank');
    _checkInitialized();
    
    try {
      // Call FFI to load the instrument
      final id = await _ffi.loadInstrumentFromSF2(filePath, preset, bank);
      if (id < 0) {
        throw Exception('Failed to load SF2 instrument from: $filePath');
      }
      
      // Create and cache the instrument
      final instrument = Instrument(
        id: id,
        name: name ?? '${filePath.split('/').last} P:$preset B:$bank',
        type: InstrumentType.sf2,
        path: filePath,
        preset: preset,
        bank: bank,
      );
      
      _instruments[id] = instrument;
      _log('Loaded SF2 instrument with ID: $id');
      return instrument;
    } catch (e) {
      _log('Error loading SF2 instrument: $e');
      rethrow;
    }
  }
  
  @override
  Future<Sequence> createSequence(double tempo, {int numerator = 4, int denominator = 4}) async {
    _log('Creating sequence with BPM: $tempo, time signature: $numerator/$denominator');
    _checkInitialized();
    
    try {
      // Call FFI to create the sequence
      final id = await _ffi.createSequence(tempo, numerator, denominator);
      if (id < 0) {
        throw Exception('Failed to create sequence');
      }
      
      // Create and cache the sequence
      final sequence = Sequence(
        id: id,
        bpm: tempo,
        timeSignatureNumerator: numerator,
        timeSignatureDenominator: denominator,
      );
      
      _sequences[id] = sequence;
      _log('Created sequence with ID: $id');
      return sequence;
    } catch (e) {
      _log('Error creating sequence: $e');
      rethrow;
    }
  }
  
  @override
  Future<Track> addTrack(Sequence sequence, Instrument instrument) async {
    _log('Adding track to sequence ${sequence.id} with instrument ${instrument.id}');
    _checkInitialized();
    
    try {
      // Call FFI to add the track
      final id = await _ffi.addTrack(sequence.id, instrument.id);
      if (id < 0) {
        throw Exception('Failed to add track to sequence ${sequence.id}');
      }
      
      // Create and cache the track
      final track = Track(
        id: id,
        sequenceId: sequence.id,
        instrumentId: instrument.id,
        notes: [],
      );
      
      _tracks[id] = track;
      sequence.addTrack(track);
      _log('Added track with ID: $id');
      return track;
    } catch (e) {
      _log('Error adding track: $e');
      rethrow;
    }
  }
  
  @override
  Future<bool> addNote(Track track, int noteNumber, int velocity, double startBeat, double durationBeats) async {
    _log('Adding note to track ${track.id}: note=$noteNumber, velocity=$velocity, start=$startBeat, duration=$durationBeats');
    _checkInitialized();
    
    try {
      // Call FFI to add the note
      final result = await _ffi.addNote(
        track.sequenceId,
        track.id,
        noteNumber,
        velocity,
        startBeat,
        durationBeats,
      );
      
      if (result) {
        // Create the note
        final note = Note(
          trackId: track.id,
          noteNumber: noteNumber,
          velocity: velocity,
          startBeat: startBeat,
          durationBeats: durationBeats,
        );
        
        // Add the note to the track
        track.addNote(note);
        _log('Added note successfully');
      } else {
        _log('Failed to add note to track ${track.id}');
      }
      
      return result;
    } catch (e) {
      _log('Error adding note: $e');
      return false;
    }
  }
  
  @override
  Future<bool> playSequence(Sequence sequence, {bool loop = false}) async {
    _log('Playing sequence ${sequence.id}, loop: $loop');
    _checkInitialized();
    
    try {
      // Start the audio engine if not already running
      await _ffi.startAudioEngine();
      
      // Call the native implementation
      final result = await _ffi.playSequence(sequence.id, loop ? 1 : 0);
      
      if (result == 1) {
        sequence.isPlaying = true;
        _log('Sequence ${sequence.id} playback started');
      } else {
        _log('Failed to start playback for sequence ${sequence.id}');
      }
      
      return result == 1;
    } catch (e) {
      _log('Error playing sequence: $e');
      return false;
    }
  }
  
  @override
  Future<bool> stopSequence(Sequence sequence) async {
    _log('Stopping sequence ${sequence.id}');
    _checkInitialized();
    
    try {
      // Call the native implementation
      final result = await _ffi.stopSequence(sequence.id);
      
      if (result == 1) {
        sequence.isPlaying = false;
        _log('Sequence ${sequence.id} playback stopped');
      } else {
        _log('Failed to stop playback for sequence ${sequence.id}');
      }
      
      return result == 1;
    } catch (e) {
      _log('Error stopping sequence: $e');
      return false;
    }
  }
  
  @override
  Future<bool> deleteSequence(Sequence sequence) async {
    _log('Deleting sequence ${sequence.id}');
    _checkInitialized();
    
    try {
      // Stop the sequence first if it's playing
      if (sequence.isPlaying) {
        await stopSequence(sequence);
      }
      
      // Call the native implementation
      final result = await _ffi.deleteSequence(sequence.id);
      
      if (result == 1) {
        // Remove all tracks associated with this sequence
        final trackIds = _tracks.entries
            .where((entry) => entry.value.sequenceId == sequence.id)
            .map((entry) => entry.key)
            .toList();
        
        for (final id in trackIds) {
          _tracks.remove(id);
        }
        
        // Remove the sequence
        _sequences.remove(sequence.id);
        _log('Sequence ${sequence.id} deleted');
      } else {
        _log('Failed to delete sequence ${sequence.id}');
      }
      
      return result == 1;
    } catch (e) {
      _log('Error deleting sequence: $e');
      return false;
    }
  }
  
  @override
  Future<bool> setPlaybackPosition(Sequence sequence, double beat) async {
    _log('Setting playback position for sequence ${sequence.id} to beat: $beat');
    _checkInitialized();
    
    try {
      // Call the native implementation
      final result = await _ffi.setPlaybackPosition(sequence.id, beat);
      
      if (result != 1) {
        _log('Failed to set playback position for sequence ${sequence.id}');
      }
      
      return result == 1;
    } catch (e) {
      _log('Error setting playback position: $e');
      return false;
    }
  }
  
  @override
  Future<double> getPlaybackPosition(Sequence sequence) async {
    _log('Getting playback position for sequence ${sequence.id}');
    _checkInitialized();
    
    try {
      // Call the native implementation
      final position = await _ffi.getPlaybackPosition(sequence.id);
      return position.toDouble();
    } catch (e) {
      _log('Error getting playback position: $e');
      return 0.0;
    }
  }
  
  @override
  Future<bool> setMasterVolume(double volume) async {
    _log('Setting master volume: $volume');
    _checkInitialized();
    
    // Clamp volume to valid range
    volume = volume.clamp(0.0, 1.0);
    
    try {
      // Call the native implementation
      final result = await _ffi.setMasterVolume(volume);
      
      if (result != 1) {
        _log('Failed to set master volume');
      }
      
      return result == 1;
    } catch (e) {
      _log('Error setting master volume: $e');
      return false;
    }
  }
  
  @override
  Future<bool> setTrackVolume(Track track, double volume) async {
    _log('Setting volume for track ${track.id} in sequence ${track.sequenceId}: $volume');
    _checkInitialized();
    
    // Clamp volume to valid range
    volume = volume.clamp(0.0, 1.0);
    
    try {
      // Call the native implementation
      final result = await _ffi.setTrackVolume(track.sequenceId, track.id, volume);
      
      if (result == 1) {
        track.volume = volume;
      } else {
        _log('Failed to set volume for track ${track.id}');
      }
      
      return result == 1;
    } catch (e) {
      _log('Error setting track volume: $e');
      return false;
    }
  }
  
  @override
  Future<bool> playNote(int instrumentId, int noteNumber, int velocity) async {
    _log('Playing note $noteNumber with velocity $velocity on instrument $instrumentId');
    _checkInitialized();
    
    try {
      // Call the native implementation using sendNoteOn
      final result = _ffi.sendNoteOn(instrumentId, noteNumber, velocity);
      
      if (result != 1) {
        _log('Failed to play note $noteNumber on instrument $instrumentId');
      }
      
      return result == 1;
    } catch (e) {
      _log('Error playing note: $e');
      return false;
    }
  }
  
  @override
  Future<bool> stopNote(int instrumentId, int noteNumber) async {
    _log('Stop note called for instrument $instrumentId, note: $noteNumber');
    if (!_isInitialized) {
      _log('Error: Plugin not initialized');
      return false;
    }

    try {
      final result = _ffi.sendNoteOff(instrumentId, noteNumber);
      return result == 1;
    } catch (e) {
      _log('Error stopping note: $e');
      return false;
    }
  }
  
  @override
  Future<bool> playTestTone() async {
    _log('Playing test tone to verify audio output');
    if (!_isInitialized) {
      _log('Error: Plugin not initialized');
      return false;
    }

    final result = _ffi.playTestTone();
    return result == 1;
  }

  @override
  Future<bool> stopTestTone() async {
    _log('Stopping test tone');
    if (!_isInitialized) {
      _log('Error: Plugin not initialized');
      return false;
    }

    final result = _ffi.stopTestTone();
    return result == 1;
  }
  
  @override
  Future<bool> dispose() async {
    _log('Disposing plugin resources');
    if (!_isInitialized) {
      _log('Warning: Plugin not initialized');
      return false;
    }
    
    try {
      await _ffi.dispose();
      _isInitialized = false;
      _log('Plugin resources disposed successfully');
      return true;
    } catch (e) {
      _log('Error disposing plugin resources: $e');
      return false;
    }
  }
  
  /// Check if the plugin is initialized
  void _checkInitialized() {
    if (!_isInitialized) {
      throw Exception('FlutterMultitracker not initialized. Call initialize() first.');
    }
  }
} 
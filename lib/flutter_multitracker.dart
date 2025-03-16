import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'flutter_multitracker_platform_interface.dart';
import 'models/models.dart';

// Export model classes
export 'models/models.dart';

/// The Flutter plugin for multi-track audio synthesis and sequencing.
class FlutterMultitracker {
  static const MethodChannel _channel = MethodChannel('flutter_multitracker');
  
  /// Map of sequences by ID.
  final Map<int, Sequence> _sequences = {};
  
  /// Map of instruments by ID.
  final Map<int, Instrument> _instruments = {};
  
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
      final result = await _channel.invokeMethod<bool>('initAudioEngine', {
        'sampleRate': sampleRate,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error initializing audio engine: $e');
      return false;
    }
  }
  
  /// Initialize the audio engine with default settings
  /// 
  /// Returns true if initialization was successful
  Future<bool> initialize() async {
    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      return result ?? false;
    } catch (e) {
      debugPrint('Error initializing flutter_multitracker: $e');
      return false;
    }
  }
  
  /// Start the audio engine
  /// 
  /// Returns true if the audio engine was started successfully
  Future<bool> startAudioEngine() async {
    try {
      final result = await _channel.invokeMethod<bool>('startAudioEngine');
      return result ?? false;
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
      final result = await _channel.invokeMethod<bool>('stopAudioEngine');
      return result ?? false;
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
      final result = await _channel.invokeMethod<bool>('cleanupAudioEngine');
      return result ?? false;
    } catch (e) {
      debugPrint('Error cleaning up audio engine: $e');
      return false;
    }
  }
  
  /// Clean up resources
  Future<bool> cleanup() async {
    try {
      final result = await _channel.invokeMethod<bool>('cleanup');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to cleanup: ${e.message}');
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
      final result = await _channel.invokeMethod<bool>('setMasterVolume', {
        'volume': volume.clamp(0.0, 1.0),
      });
      return result ?? false;
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
      final result = await _channel.invokeMethod<int>('createSineWaveInstrument', {
        'name': name,
      });
      return result ?? -1;
    } catch (e) {
      debugPrint('Error creating sine wave instrument: $e');
      return -1;
    }
  }
  
  /// Create a new instrument
  /// 
  /// [name] - Name of the instrument
  /// [type] - Type of the instrument (e.g., "sine", "square", "sawtooth")
  /// 
  /// Returns the created instrument if successful, or null if failed
  Future<Instrument?> createInstrument(String name, String type) async {
    try {
      final id = await _channel.invokeMethod<int>('createInstrument', {
        'name': name,
        'type': type,
      });
      
      if (id != null && id >= 0) {
        final instrument = Instrument(
          id: id,
          name: name,
          type: type,
        );
        _instruments[id] = instrument;
        return instrument;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating instrument: $e');
      return null;
    }
  }
  
  /// Gets an instrument by ID.
  Instrument? getInstrument(int id) {
    return _instruments[id];
  }
  
  /// Set the ADSR envelope for an instrument
  /// 
  /// [instrumentId] - ID of the instrument
  /// [attack] - Attack time in seconds
  /// [decay] - Decay time in seconds
  /// [sustain] - Sustain level (0.0 to 1.0)
  /// [release] - Release time in seconds
  /// 
  /// Returns true if the envelope was set successfully
  Future<bool> setInstrumentEnvelope(int instrumentId, double attack, double decay, double sustain, double release) async {
    try {
      final result = await _channel.invokeMethod<bool>('setInstrumentEnvelope', {
        'instrumentId': instrumentId,
        'attack': attack,
        'decay': decay,
        'sustain': sustain.clamp(0.0, 1.0),
        'release': release,
      });
      
      final instrument = _instruments[instrumentId];
      if (instrument != null) {
        instrument.attack = attack;
        instrument.decay = decay;
        instrument.sustain = sustain.clamp(0.0, 1.0);
        instrument.release = release;
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting instrument envelope: ${e}');
      return false;
    }
  }
  
  /// Unload an instrument
  /// 
  /// [instrumentId] - ID of the instrument to unload
  /// 
  /// Returns true if the instrument was unloaded successfully
  Future<bool> unloadInstrument(int instrumentId) async {
    try {
      final result = await _channel.invokeMethod<bool>('unloadInstrument', {
        'instrumentId': instrumentId,
      });
      
      if (result == true) {
        _instruments.remove(instrumentId);
      }
      
      return result ?? false;
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
  Future<bool> noteOn(int instrumentId, int noteNumber, int velocity) async {
    try {
      final result = await _channel.invokeMethod<bool>('noteOn', {
        'instrumentId': instrumentId,
        'noteNumber': noteNumber,
        'velocity': velocity,
      });
      return result ?? false;
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
  Future<bool> noteOff(int instrumentId, int noteNumber) async {
    try {
      final result = await _channel.invokeMethod<bool>('noteOff', {
        'instrumentId': instrumentId,
        'noteNumber': noteNumber,
      });
      return result ?? false;
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
      final result = await _channel.invokeMethod<bool>('setInstrumentVolume', {
        'instrumentId': instrumentId,
        'volume': volume,
      });
      
      final instrument = _instruments[instrumentId];
      if (instrument != null) {
        instrument.volume = volume;
      }
      
      return result ?? false;
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
      final result = await _channel.invokeMethod<List<dynamic>>('getLoadedInstrumentIds');
      return result?.cast<int>() ?? [];
    } catch (e) {
      debugPrint('Error getting loaded instrument IDs: $e');
      return [];
    }
  }

  /// Creates a new sequence.
  Future<Sequence?> createSequence(double tempo) async {
    try {
      final id = await _channel.invokeMethod<int>('createSequence', {
        'tempo': tempo,
      });
      
      if (id != null && id >= 0) {
        final sequence = Sequence(
          id: id,
          tempo: tempo,
        );
        _sequences[id] = sequence;
        return sequence;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating sequence: $e');
      return null;
    }
  }
  
  /// Deletes a sequence.
  Future<bool> deleteSequence(int sequenceId) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteSequence', {
        'sequenceId': sequenceId,
      });
      
      if (result == true) {
        _sequences.remove(sequenceId);
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error deleting sequence: $e');
      return false;
    }
  }
  
  /// Gets a sequence by ID.
  Sequence? getSequence(int id) {
    return _sequences[id];
  }
  
  /// Adds a track to a sequence.
  Future<Track?> addTrack(int sequenceId, int instrumentId, String name) async {
    try {
      final trackId = await _channel.invokeMethod<int>('addTrack', {
        'sequenceId': sequenceId,
        'instrumentId': instrumentId,
        'name': name,
      });
      
      if (trackId != null && trackId >= 0) {
        final track = Track(
          id: trackId,
          instrumentId: instrumentId,
          name: name,
        );
        
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.addTrack(track);
        }
        
        return track;
      }
      return null;
    } catch (e) {
      debugPrint('Error adding track: $e');
      return null;
    }
  }
  
  /// Deletes a track from a sequence.
  Future<bool> deleteTrack(int sequenceId, int trackId) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteTrack', {
        'sequenceId': sequenceId,
        'trackId': trackId,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          final track = sequence.getTrack(trackId);
          if (track != null) {
            sequence.removeTrack(track);
          }
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error deleting track: $e');
      return false;
    }
  }
  
  /// Adds a note to a track.
  Future<Note?> addNote(int sequenceId, int trackId, int noteNumber, int velocity, double startBeat, double durationBeats) async {
    try {
      final noteId = await _channel.invokeMethod<int>('addNote', {
        'sequenceId': sequenceId,
        'trackId': trackId,
        'noteNumber': noteNumber,
        'velocity': velocity,
        'startBeat': startBeat,
        'durationBeats': durationBeats,
      });
      
      if (noteId != null && noteId >= 0) {
        final note = Note(
          id: noteId,
          noteNumber: noteNumber,
          velocity: velocity,
          startBeat: startBeat,
          durationBeats: durationBeats,
        );
        
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          final track = sequence.getTrack(trackId);
          if (track != null) {
            track.addNote(note);
          }
        }
        
        return note;
      }
      return null;
    } catch (e) {
      debugPrint('Error adding note: $e');
      return null;
    }
  }
  
  /// Deletes a note from a track.
  Future<bool> deleteNote(int sequenceId, int trackId, int noteId) async {
    try {
      final result = await _channel.invokeMethod<bool>('deleteNote', {
        'sequenceId': sequenceId,
        'trackId': trackId,
        'noteId': noteId,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          final track = sequence.getTrack(trackId);
          if (track != null) {
            final note = track.getNote(noteId);
            if (note != null) {
              track.removeNote(note);
            }
          }
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error deleting note: $e');
      return false;
    }
  }
  
  /// Starts playback of a sequence.
  Future<bool> startPlayback(int sequenceId) async {
    try {
      final result = await _channel.invokeMethod<bool>('startPlayback', {
        'sequenceId': sequenceId,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.isPlaying = true;
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error starting playback: $e');
      return false;
    }
  }
  
  /// Stops playback of a sequence.
  Future<bool> stopPlayback(int sequenceId) async {
    try {
      final result = await _channel.invokeMethod<bool>('stopPlayback', {
        'sequenceId': sequenceId,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.isPlaying = false;
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error stopping playback: $e');
      return false;
    }
  }
  
  /// Sets the tempo for a sequence.
  Future<bool> setTempo(int sequenceId, double tempo) async {
    try {
      final result = await _channel.invokeMethod<bool>('setTempo', {
        'sequenceId': sequenceId,
        'tempo': tempo,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.tempo = tempo;
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting tempo: $e');
      return false;
    }
  }
  
  /// Sets a loop range for a sequence.
  Future<bool> setLoop(int sequenceId, double startBeat, double endBeat) async {
    try {
      final result = await _channel.invokeMethod<bool>('setLoop', {
        'sequenceId': sequenceId,
        'startBeat': startBeat,
        'endBeat': endBeat,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.loopEnabled = true;
          sequence.loopStartBeat = startBeat;
          sequence.loopEndBeat = endBeat;
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting loop: $e');
      return false;
    }
  }
  
  /// Disables looping for a sequence.
  Future<bool> unsetLoop(int sequenceId) async {
    try {
      final result = await _channel.invokeMethod<bool>('unsetLoop', {
        'sequenceId': sequenceId,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.loopEnabled = false;
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error unsetting loop: $e');
      return false;
    }
  }
  
  /// Sets the current beat position for a sequence.
  Future<bool> setBeat(int sequenceId, double beat) async {
    try {
      final result = await _channel.invokeMethod<bool>('setBeat', {
        'sequenceId': sequenceId,
        'beat': beat,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.position = beat;
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting beat: $e');
      return false;
    }
  }
  
  /// Sets the end beat for a sequence.
  Future<bool> setEndBeat(int sequenceId, double endBeat) async {
    try {
      final result = await _channel.invokeMethod<bool>('setEndBeat', {
        'sequenceId': sequenceId,
        'endBeat': endBeat,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.endBeat = endBeat;
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting end beat: $e');
      return false;
    }
  }
  
  /// Gets the current playback position of a sequence.
  Future<double> getPosition(int sequenceId) async {
    try {
      final position = await _channel.invokeMethod<double>('getPosition', {
        'sequenceId': sequenceId,
      });
      
      if (position != null) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.position = position;
        }
        return position;
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error getting position: $e');
      return 0.0;
    }
  }
  
  /// Gets whether a sequence is currently playing.
  Future<bool> getIsPlaying(int sequenceId) async {
    try {
      final isPlaying = await _channel.invokeMethod<bool>('getIsPlaying', {
        'sequenceId': sequenceId,
      });
      
      if (isPlaying != null) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          sequence.isPlaying = isPlaying;
        }
        return isPlaying;
      }
      return false;
    } catch (e) {
      debugPrint('Error getting isPlaying: $e');
      return false;
    }
  }
  
  /// Sets the volume for a track.
  Future<bool> setTrackVolume(int sequenceId, int trackId, double volume) async {
    try {
      final result = await _channel.invokeMethod<bool>('setTrackVolume', {
        'sequenceId': sequenceId,
        'trackId': trackId,
        'volume': volume,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          final track = sequence.getTrack(trackId);
          if (track != null) {
            track.volume = volume;
          }
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting track volume: $e');
      return false;
    }
  }
  
  /// Sets whether a track is muted.
  Future<bool> setTrackMuted(int sequenceId, int trackId, bool muted) async {
    try {
      final result = await _channel.invokeMethod<bool>('setTrackMuted', {
        'sequenceId': sequenceId,
        'trackId': trackId,
        'muted': muted,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          final track = sequence.getTrack(trackId);
          if (track != null) {
            track.muted = muted;
          }
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting track muted: $e');
      return false;
    }
  }
  
  /// Sets whether a track is soloed.
  Future<bool> setTrackSoloed(int sequenceId, int trackId, bool soloed) async {
    try {
      final result = await _channel.invokeMethod<bool>('setTrackSoloed', {
        'sequenceId': sequenceId,
        'trackId': trackId,
        'soloed': soloed,
      });
      
      if (result == true) {
        final sequence = _sequences[sequenceId];
        if (sequence != null) {
          final track = sequence.getTrack(trackId);
          if (track != null) {
            track.soloed = soloed;
          }
        }
      }
      
      return result ?? false;
    } catch (e) {
      debugPrint('Error setting track soloed: $e');
      return false;
    }
  }
  
  /// Release all resources and shutdown the audio engine
  /// 
  /// This should be called when the app is being closed.
  Future<bool> dispose() {
    return FlutterMultitrackerPlatform.instance.dispose();
  }

  /// Load a sample for an instrument.
  /// 
  /// [instrumentId] is the ID of the instrument.
  /// [noteNumber] is the MIDI note number (0-127).
  /// [assetPath] is the path to the asset.
  /// [sampleRate] is the sample rate of the asset (default: 44100).
  Future<bool> loadSample({
    required int instrumentId,
    required int noteNumber,
    required String assetPath,
    int sampleRate = 44100,
  }) async {
    try {
      // Extract asset to temporary file
      final String tempPath = await _extractAssetToTemp(assetPath);
      
      // Load the sample
      final bool result = await _channel.invokeMethod('loadSample', {
        'instrumentId': instrumentId,
        'noteNumber': noteNumber,
        'samplePath': tempPath,
        'sampleRate': sampleRate,
      });
      
      return result;
    } catch (e) {
      debugPrint('Error loading sample: $e');
      return false;
    }
  }
  
  /// Load a WAV file for each note in a range.
  /// 
  /// [instrumentId] is the ID of the instrument.
  /// [baseNote] is the MIDI note number of the base sample.
  /// [assetPath] is the path to the asset.
  /// [noteRange] is the range of notes to map the sample to (default: 1).
  /// [sampleRate] is the sample rate of the asset (default: 44100).
  Future<bool> loadWavSample({
    required int instrumentId,
    required int baseNote,
    required String assetPath,
    int noteRange = 1,
    int sampleRate = 44100,
  }) async {
    try {
      // Extract asset to temporary file
      final String tempPath = await _extractAssetToTemp(assetPath);
      
      // Load the sample for the base note
      final bool result = await _channel.invokeMethod('loadSample', {
        'instrumentId': instrumentId,
        'noteNumber': baseNote,
        'samplePath': tempPath,
        'sampleRate': sampleRate,
      });
      
      if (!result) {
        return false;
      }
      
      // If noteRange > 1, map the sample to additional notes
      if (noteRange > 1) {
        final int startNote = baseNote - (noteRange ~/ 2);
        final int endNote = startNote + noteRange - 1;
        
        for (int note = startNote; note <= endNote; note++) {
          if (note != baseNote && note >= 0 && note < 128) {
            // Use the same sample for this note
            await _channel.invokeMethod('loadSample', {
              'instrumentId': instrumentId,
              'noteNumber': note,
              'samplePath': tempPath,
              'sampleRate': sampleRate,
            });
          }
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error loading WAV sample: $e');
      return false;
    }
  }
  
  /// Load multiple WAV samples for an instrument.
  /// 
  /// [instrumentId] is the ID of the instrument.
  /// [sampleMap] is a map of MIDI note numbers to asset paths.
  /// [sampleRate] is the sample rate of the assets (default: 44100).
  Future<bool> loadMultipleWavSamples({
    required int instrumentId,
    required Map<int, String> sampleMap,
    int sampleRate = 44100,
  }) async {
    try {
      bool allSuccess = true;
      
      // Load each sample
      for (final MapEntry<int, String> entry in sampleMap.entries) {
        final bool success = await loadWavSample(
          instrumentId: instrumentId,
          baseNote: entry.key,
          assetPath: entry.value,
          sampleRate: sampleRate,
        );
        
        if (!success) {
          allSuccess = false;
          debugPrint('Failed to load sample for note ${entry.key}: ${entry.value}');
        }
      }
      
      return allSuccess;
    } catch (e) {
      debugPrint('Error loading multiple WAV samples: $e');
      return false;
    }
  }
  
  /// Extract an asset to a temporary file.
  Future<String> _extractAssetToTemp(String assetPath) async {
    try {
      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;
      
      // Create a unique filename based on the asset path
      final String filename = path.basename(assetPath);
      final String filePath = path.join(tempPath, filename);
      
      // Check if the file already exists
      final File file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
      
      // Load the asset
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();
      
      // Write to temporary file
      await file.writeAsBytes(bytes);
      
      return filePath;
    } catch (e) {
      debugPrint('Error extracting asset: $e');
      rethrow;
    }
  }
}

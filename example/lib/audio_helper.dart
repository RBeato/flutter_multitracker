import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A simple audio helper for playing tones using audioplayers
/// This is a fallback implementation when native audio is not available
class AudioHelper {
  static final AudioHelper _instance = AudioHelper._internal();
  factory AudioHelper() => _instance;
  
  AudioHelper._internal();
  
  bool _initialized = false;
  final Map<int, AudioPlayer> _players = {};
  
  // Predefined notes for quick access
  final _noteFrequencies = {
    60: 'C4', // Middle C - 261.63 Hz
    61: 'C#4',
    62: 'D4',
    63: 'D#4',
    64: 'E4',
    65: 'F4',
    66: 'F#4',
    67: 'G4',
    68: 'G#4',
    69: 'A4', // A440 - 440 Hz
    70: 'A#4',
    71: 'B4',
    72: 'C5',
  };
  
  /// Initialize the audio system
  Future<bool> initialize() async {
    debugPrint('AudioHelper: Attempting to initialize audio system');
    if (_initialized) {
      debugPrint('AudioHelper: Already initialized');
      return true;
    }
    
    try {
      debugPrint('AudioHelper: Creating audio players for common notes');
      // Pre-create a few players for common notes
      for (final noteNumber in [60, 64, 67, 69, 72]) {
        try {
          debugPrint('AudioHelper: Creating player for note $noteNumber');
          final player = AudioPlayer();
          await player.setVolume(0.5);
          _players[noteNumber] = player;
          debugPrint('AudioHelper: Successfully created player for note $noteNumber');
        } catch (e) {
          debugPrint('AudioHelper: Error creating player for note $noteNumber: $e');
          // Continue with other notes even if one fails
        }
      }
      
      _initialized = true;
      debugPrint('AudioHelper: Successfully initialized with ${_players.length} players');
      return true;
    } catch (e) {
      debugPrint('AudioHelper: Failed to initialize: $e');
      // Try to clean up any created players
      for (final player in _players.values) {
        try {
          await player.dispose();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      _players.clear();
      return false;
    }
  }
  
  /// Play a note with the specified MIDI note number
  Future<bool> playNote(int instrumentId, int noteNumber, int velocity) async {
    if (!_initialized) {
      debugPrint('AudioHelper not initialized');
      return false;
    }
    
    try {
      // Get or create player for this note
      final player = _players[noteNumber] ?? AudioPlayer();
      if (!_players.containsKey(noteNumber)) {
        _players[noteNumber] = player;
      }
      
      // Set volume based on velocity (0-127)
      final volume = velocity / 127.0;
      await player.setVolume(volume);
      
      // Choose the appropriate asset based on the note
      String assetPath;
      
      // Using the available wav files in assets/wav/
      if (noteNumber == 60) {
        assetPath = 'assets/wav/D3.wav'; // Use D3 for C4
      } else if (noteNumber == 64) {
        assetPath = 'assets/wav/F3.wav'; // Use F3 for E4
      } else if (noteNumber == 67) {
        assetPath = 'assets/wav/Gsharp3.wav'; // Use Gsharp3 for G4
      } else if (noteNumber == 69) {
        assetPath = 'assets/wav/D3.wav'; // Use D3 for A4 (could be transposed)
      } else if (noteNumber == 72) {
        assetPath = 'assets/wav/F3.wav'; // Use F3 for C5
      } else {
        // Default to D3 for other notes
        assetPath = 'assets/wav/D3.wav';
        
        // Try to adjust playback rate for pitch (limited capability)
        final playbackRate = _calculatePlaybackRate(noteNumber);
        await player.setPlaybackRate(playbackRate);
      }
      
      debugPrint('Playing audio asset: $assetPath');
      
      // Play the sound
      await player.play(AssetSource(assetPath));
      
      return true;
    } catch (e) {
      debugPrint('Error playing note: $e');
      return false;
    }
  }
  
  /// Stop playing the specified note
  Future<bool> stopNote(int instrumentId, int noteNumber) async {
    if (!_initialized) {
      debugPrint('AudioHelper not initialized');
      return false;
    }
    
    try {
      final player = _players[noteNumber];
      if (player != null) {
        await player.stop();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error stopping note: $e');
      return false;
    }
  }
  
  /// Play a test tone (A4 = 440Hz)
  Future<bool> playTestTone() async {
    return playNote(0, 69, 100); // A4 at medium velocity
  }
  
  /// Stop the test tone
  Future<bool> stopTestTone() async {
    return stopNote(0, 69);
  }
  
  /// Calculate playback rate for pitch shifting
  double _calculatePlaybackRate(int noteNumber) {
    // A4 (MIDI note 69) is our reference at rate 1.0
    // Each semitone is a factor of 2^(1/12)
    return pow(2, (noteNumber - 69) / 12);
  }
  
  /// Calculate 2^x
  double pow(double base, double exponent) {
    return base.toDouble() * base.toDouble();
  }
  
  /// Dispose all resources
  Future<bool> dispose() async {
    if (!_initialized) {
      return true;
    }
    
    try {
      // Release all players
      for (final player in _players.values) {
        await player.dispose();
      }
      _players.clear();
      _initialized = false;
      
      return true;
    } catch (e) {
      debugPrint('Error disposing audio helper: $e');
      return false;
    }
  }
} 
import 'track.dart';

/// Represents a musical sequence with tracks and playback state
class Sequence {
  /// Unique identifier for the sequence
  final int id;
  
  /// Tempo in BPM
  double bpm;
  
  /// Time signature numerator (beats per measure)
  int timeSignatureNumerator;
  
  /// Time signature denominator (beat unit)
  int timeSignatureDenominator;
  
  /// Whether the sequence is currently playing
  bool isPlaying;
  
  /// Whether the sequence is set to loop
  bool looping;
  
  /// Total length of the sequence in beats
  double lengthInBeats;
  
  /// Current playback position in beats
  double currentBeat;
  
  /// Tracks contained in this sequence
  final List<Track> tracks;

  /// Creates a new sequence
  Sequence({
    required this.id,
    required this.bpm,
    this.timeSignatureNumerator = 4,
    this.timeSignatureDenominator = 4,
    this.isPlaying = false,
    this.looping = false,
    this.lengthInBeats = 16.0,
    this.currentBeat = 0.0,
    List<Track>? tracks,
  }) : tracks = tracks ?? [];

  /// Add a track to the sequence
  void addTrack(Track track) {
    tracks.add(track);
  }

  /// Remove a track from the sequence
  bool removeTrack(int trackId) {
    final initialLength = tracks.length;
    tracks.removeWhere((track) => track.id == trackId);
    return tracks.length != initialLength;
  }

  /// Find a track by ID
  Track? findTrack(int trackId) {
    try {
      return tracks.firstWhere((track) => track.id == trackId);
    } catch (e) {
      return null;
    }
  }

  /// Calculate the length of the sequence based on the notes in the tracks
  void calculateLength() {
    double maxEndBeat = 0.0;
    
    for (final track in tracks) {
      for (final note in track.notes) {
        final endBeat = note.startBeat + note.durationBeats;
        if (endBeat > maxEndBeat) {
          maxEndBeat = endBeat;
        }
      }
    }
    
    // Add one bar of space after the last note
    final beatsPerBar = timeSignatureNumerator.toDouble();
    lengthInBeats = maxEndBeat + beatsPerBar;
  }

  @override
  String toString() {
    return 'Sequence{id: $id, bpm: $bpm, timeSignature: $timeSignatureNumerator/$timeSignatureDenominator, tracks: ${tracks.length}}';
  }
} 